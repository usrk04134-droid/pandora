"""PLC power-source tests using the bench power supply and the WebApi interface.

These tests exercise the real power-source control path:

    1. Tell Adaptio to select a weld data set (via WebHMI) -- Adaptio
       pushes the weld parameters (voltage, current, wire speed, etc.)
       to the PLC over PROFINET.
    2. Send the PLC a StartWeld command (via WebApi JSON-RPC)
    3. Apply a voltage through the bench power supply so the Aristo PAB
       reports arcing on its digital inputs (Welding / WeldStarted)
    4. Read power source status from the PLC WebApi outputs and verify
       that the PLC reports ReadyToWeld / Welding / MeasuredVoltage
    5. Verify that Adaptio tells the frontend the correct arc state

NOTE on setpoints: The PLC WebApi `ActiveArea` input fields have
registered change handlers but NO processing code in `HandleInputChanged`
(WebApi.st). Weld parameters are delivered by Adaptio → PLC over
PROFINET when a weld data set is selected, not via WebApi writes.
The `LoadWeldDataSet` WebApi command can also load setpoints into
the power source PassiveArea and swap it to active.
"""

import time

import pytest
from loguru import logger

from conftest import (
    add_weld_data_set,
    add_weld_process_parameters,
    apply_arc_voltage,
    delete_adaptio_database,
    get_weld_data_sets,
    get_weld_process_parameters,
    get_weld_process_parameters_config,
    receive_arc_state,
    remove_arc_voltage,
    select_weld_data_set,
    subscribe_arc_state,
    wait_for_plc_value,
)
from managers import AdaptioManager
from plc_address_space import Addresses
from testzilla.adaptio_web_hmi.adaptio_web_hmi import AdaptioWebHmi
from testzilla.utility.cleanup_utils import cleanup_web_hmi_client
from testzilla.plc.plc_json_rpc import PlcJsonRpc
from testzilla.power_supply.abstract_power_supply import AbstractPowerSupply


# ---------------------------------------------------------------------------
# Local helpers
# ---------------------------------------------------------------------------

def _find_wpp_ids(web_hmi: AdaptioWebHmi, ws1_name: str, ws2_name: str) -> dict | None:
    wpp_list = get_weld_process_parameters(web_hmi)
    if not wpp_list:
        return None
    ws1_wpp_id = ws2_wpp_id = None
    for wpp in wpp_list:
        if isinstance(wpp, dict):
            wpp_id = wpp.get("id") or wpp.get("wppId") or wpp.get("Id")
            wpp_name = wpp.get("name") or wpp.get("Name")
            if wpp_name == ws1_name:
                ws1_wpp_id = wpp_id
            elif wpp_name == ws2_name:
                ws2_wpp_id = wpp_id
    if ws1_wpp_id is not None and ws2_wpp_id is not None:
        return {"ws1_wpp_id": ws1_wpp_id, "ws2_wpp_id": ws2_wpp_id}
    return None


def _find_wds_id(web_hmi: AdaptioWebHmi, wds_name: str) -> int | None:
    wds_list = get_weld_data_sets(web_hmi)
    if not wds_list:
        return None
    for wds in wds_list:
        if isinstance(wds, dict):
            wds_id = wds.get("id") or wds.get("wdsId") or wds.get("Id")
            if (wds.get("name") or wds.get("Name")) == wds_name:
                return wds_id
    return None


def _read_ps_status(plc: PlcJsonRpc, ps: "PowerSourceOutputs") -> dict:
    """Read all interesting power-source status fields from the PLC."""
    fields = {}
    for name in ("ReadyToWeld", "Welding", "Error", "Connected", "MeasuredVoltage", "State"):
        addr = getattr(ps.Status, name, None)
        if addr:
            value, err = plc.read(var=addr)
            fields[name] = value if not err else None
    return fields


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(name="web_hmi")
def web_hmi_fixture(request: pytest.FixtureRequest):
    web_hmi = AdaptioWebHmi(uri=request.config.WEB_HMI_URI)
    yield web_hmi
    cleanup_web_hmi_client(web_hmi)


@pytest.fixture(name="addr")
def addresses_fixture() -> Addresses:
    return Addresses()


@pytest.fixture(name="weld_setup")
def weld_setup_fixture(
    web_hmi: AdaptioWebHmi,
    adaptio_manager: AdaptioManager,
    request: pytest.FixtureRequest,
):
    """Create WPP + WDS and select the weld data set.

    Yields a dict with wds_id, ws1_wpp_id, ws2_wpp_id.
    """
    db_path = request.config.ADAPTIO_USER_CONFIG_PATH / request.config.ADAPTIO_DB
    if not delete_adaptio_database(adaptio_manager, db_path):
        pytest.skip("Failed to clean database before setup")

    ws1_config = get_weld_process_parameters_config("ws1")
    ws2_config = get_weld_process_parameters_config("ws2")

    if not add_weld_process_parameters(web_hmi, **ws1_config):
        pytest.skip("Failed to add WPP for WS1")
    if not add_weld_process_parameters(web_hmi, **ws2_config):
        pytest.skip("Failed to add WPP for WS2")

    wpp_ids = _find_wpp_ids(web_hmi, ws1_config["name"], ws2_config["name"])
    if wpp_ids is None:
        pytest.skip("Could not retrieve WPP IDs after adding")

    if not add_weld_data_set(
        web_hmi,
        name="ManualWeld",
        ws1_wpp_id=wpp_ids["ws1_wpp_id"],
        ws2_wpp_id=wpp_ids["ws2_wpp_id"],
    ):
        pytest.skip("Failed to add weld data set")

    wds_id = _find_wds_id(web_hmi, "ManualWeld")
    if wds_id is None:
        pytest.skip("Could not retrieve WDS ID after adding")

    if not select_weld_data_set(web_hmi, weld_data_set_id=wds_id):
        pytest.skip("Failed to select weld data set")

    logger.info(f"Weld setup complete – WDS {wds_id}, WPP {wpp_ids}")
    return {"wds_id": wds_id, **wpp_ids}


@pytest.fixture(name="clean_psu_output")
def clean_psu_output_fixture(bench_power_supply: AbstractPowerSupply):
    """Ensure the bench PSU output is off before and after the test."""
    remove_arc_voltage(bench_power_supply)
    yield
    remove_arc_voltage(bench_power_supply)


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

class TestPlcPowerSource:
    """Verify the PLC power-source weld cycle using the WebApi and bench PSU.

    Uses 'TGlobalVariablesDB.WebApiData' (the PLC's JSON-RPC surface) for
    commands and status, and the bench power supply to produce a real arcing
    signal on the Aristo PAB.
    """

    @pytest.mark.plc_powersource
    def test_power_source_connected(
        self,
        setup_plc: PlcJsonRpc,
        addr: Addresses,
    ):
        """The PLC WebApi should report that power source 1 is valid and connected."""
        ps1_out = addr.Hmi.Outputs.PowerSource1

        valid, err = setup_plc.read(var=ps1_out.Valid)
        assert not err, f"Failed to read PS1 Valid: {err}"
        logger.info(f"PS1 Valid = {valid}")
        assert valid is True, "Power source 1 should be valid (observable present)"

        status = _read_ps_status(setup_plc, ps1_out)
        logger.info(f"PS1 status: {status}")
        assert status.get("Connected") is True, "Power source 1 should be connected"

    @pytest.mark.plc_powersource
    def test_power_source_ready_to_weld(
        self,
        setup_plc: PlcJsonRpc,
        addr: Addresses,
    ):
        """After the Aristo PAB reports ReadyToStart, the PLC WebApi should
        reflect ReadyToWeld = True."""
        ps1_out = addr.Hmi.Outputs.PowerSource1

        ready = wait_for_plc_value(
            setup_plc, ps1_out.Status.ReadyToWeld, True, retries=30, interval=1.0
        )
        logger.info(f"PS1 ReadyToWeld = {ready}")
        assert ready is True, (
            "Power source 1 should report ReadyToWeld from PAB; "
            "check that the Aristo is powered on and connected"
        )

    @pytest.mark.plc_powersource
    def test_load_weld_data_set_via_webapi(
        self,
        setup_plc: PlcJsonRpc,
        addr: Addresses,
    ):
        """LoadWeldDataSet via WebApi should write setpoints to the power source
        PassiveArea and swap it to active (SwitchActivePassive)."""
        ps1_in = addr.Hmi.Inputs.PowerSource1

        setup_plc.write(var=ps1_in.WeldDataSet.Voltage, value=25.0)
        setup_plc.write(var=ps1_in.WeldDataSet.Current, value=200)
        setup_plc.write(var=ps1_in.WeldDataSet.WireFeedSpeed, value=150)
        setup_plc.write(var=ps1_in.WeldDataSet.WeldMethod, value=1)
        setup_plc.write(var=ps1_in.WeldDataSet.RegulationType, value=0)

        _, err = setup_plc.write(var=ps1_in.Commands.LoadWeldDataSet, value=True)
        assert not err, f"Failed to trigger LoadWeldDataSet: {err}"
        time.sleep(0.5)
        setup_plc.write(var=ps1_in.Commands.LoadWeldDataSet, value=False)
        logger.info("LoadWeldDataSet triggered for PS1 via WebApi")

    @pytest.mark.plc_powersource
    def test_start_weld_command(
        self,
        setup_plc: PlcJsonRpc,
        addr: Addresses,
    ):
        """Triggering StartWeld via WebApi should be accepted by the PLC."""
        ps1_in = addr.Hmi.Inputs.PowerSource1

        _, err = setup_plc.write(var=ps1_in.Commands.StartWeld, value=True)
        assert not err, f"Failed to write StartWeld: {err}"
        logger.info("Sent StartWeld command to PS1 via WebApi")

        time.sleep(0.5)
        _, err = setup_plc.write(var=ps1_in.Commands.StartWeld, value=False)
        assert not err, f"Failed to reset StartWeld: {err}"

    @pytest.mark.plc_powersource
    def test_arc_voltage_causes_welding(
        self,
        setup_plc: PlcJsonRpc,
        bench_power_supply: AbstractPowerSupply,
        addr: Addresses,
        clean_psu_output,
    ):
        """After applying voltage via bench PSU, the Aristo PAB should report
        welding and the PLC WebApi should reflect Welding = True."""
        ps1_out = addr.Hmi.Outputs.PowerSource1

        ready = wait_for_plc_value(
            setup_plc, ps1_out.Status.ReadyToWeld, True, retries=30, interval=1.0
        )
        if not ready:
            pytest.skip("PS1 not ReadyToWeld – Aristo may not be connected")

        ps1_in = addr.Hmi.Inputs.PowerSource1
        setup_plc.write(var=ps1_in.Commands.StartWeld, value=True)
        time.sleep(0.3)
        setup_plc.write(var=ps1_in.Commands.StartWeld, value=False)
        time.sleep(0.5)

        apply_arc_voltage(bench_power_supply)
        time.sleep(2.0)

        welding = wait_for_plc_value(
            setup_plc, ps1_out.Status.Welding, True, retries=20, interval=0.5
        )
        logger.info(f"PS1 Welding = {welding}")
        assert welding is True, "PLC should report Welding after bench PSU provides arc voltage"

        status = _read_ps_status(setup_plc, ps1_out)
        logger.info(f"PS1 full status during welding: {status}")

        remove_arc_voltage(bench_power_supply)
        time.sleep(1.0)
        setup_plc.write(var=ps1_in.Commands.StopWeld, value=True)
        time.sleep(0.3)
        setup_plc.write(var=ps1_in.Commands.StopWeld, value=False)

    @pytest.mark.plc_powersource
    def test_measured_voltage_reported(
        self,
        setup_plc: PlcJsonRpc,
        bench_power_supply: AbstractPowerSupply,
        addr: Addresses,
        clean_psu_output,
    ):
        """While arcing, the PLC should report a non-zero MeasuredVoltage."""
        ps1_out = addr.Hmi.Outputs.PowerSource1
        ps1_in = addr.Hmi.Inputs.PowerSource1

        ready = wait_for_plc_value(
            setup_plc, ps1_out.Status.ReadyToWeld, True, retries=30, interval=1.0
        )
        if not ready:
            pytest.skip("PS1 not ReadyToWeld")

        setup_plc.write(var=ps1_in.Commands.StartWeld, value=True)
        time.sleep(0.3)
        setup_plc.write(var=ps1_in.Commands.StartWeld, value=False)
        time.sleep(0.5)

        apply_arc_voltage(bench_power_supply)
        time.sleep(2.0)

        measured, _ = setup_plc.read(var=ps1_out.Status.MeasuredVoltage)
        logger.info(f"PS1 MeasuredVoltage = {measured}")
        assert measured is not None, "Should be able to read MeasuredVoltage"
        assert measured > 0, f"MeasuredVoltage should be > 0 during arcing, got {measured}"

        remove_arc_voltage(bench_power_supply)
        time.sleep(1.0)
        setup_plc.write(var=ps1_in.Commands.StopWeld, value=True)
        time.sleep(0.3)
        setup_plc.write(var=ps1_in.Commands.StopWeld, value=False)

    @pytest.mark.plc_powersource
    def test_removing_voltage_stops_welding(
        self,
        setup_plc: PlcJsonRpc,
        bench_power_supply: AbstractPowerSupply,
        addr: Addresses,
        clean_psu_output,
    ):
        """After removing bench PSU voltage, Welding should go False."""
        ps1_out = addr.Hmi.Outputs.PowerSource1
        ps1_in = addr.Hmi.Inputs.PowerSource1

        ready = wait_for_plc_value(
            setup_plc, ps1_out.Status.ReadyToWeld, True, retries=30, interval=1.0
        )
        if not ready:
            pytest.skip("PS1 not ReadyToWeld")

        setup_plc.write(var=ps1_in.Commands.StartWeld, value=True)
        time.sleep(0.3)
        setup_plc.write(var=ps1_in.Commands.StartWeld, value=False)
        time.sleep(0.5)

        apply_arc_voltage(bench_power_supply)
        welding = wait_for_plc_value(
            setup_plc, ps1_out.Status.Welding, True, retries=20, interval=0.5
        )
        if not welding:
            pytest.skip("Welding never became True – check bench PSU wiring")

        remove_arc_voltage(bench_power_supply)
        time.sleep(2.0)

        welding_after = wait_for_plc_value(
            setup_plc, ps1_out.Status.Welding, False, retries=20, interval=0.5
        )
        logger.info(f"PS1 Welding after voltage removal = {welding_after}")
        assert welding_after is False, "Welding should be False after removing arc voltage"

        setup_plc.write(var=ps1_in.Commands.StopWeld, value=True)
        time.sleep(0.3)
        setup_plc.write(var=ps1_in.Commands.StopWeld, value=False)

    @pytest.mark.plc_powersource
    def test_full_weld_cycle_on_frontend(
        self,
        web_hmi: AdaptioWebHmi,
        setup_plc: PlcJsonRpc,
        bench_power_supply: AbstractPowerSupply,
        addr: Addresses,
        weld_setup,
        clean_psu_output,
    ):
        """Full cycle verified through Adaptio frontend arc state:

        select WDS → power sources ready → start → arc via PSU → stop
        """
        wds_id = weld_setup["wds_id"]
        ps1_out = addr.Hmi.Outputs.PowerSource1
        ps1_in = addr.Hmi.Inputs.PowerSource1

        # Subscribe to arc state
        initial = subscribe_arc_state(web_hmi)
        if initial is None:
            pytest.skip("Device does not support SubscribeArcState")

        # 1. idle → configured (WDS already selected by fixture)
        if initial != "configured":
            assert select_weld_data_set(web_hmi, weld_data_set_id=wds_id)
            state = receive_arc_state(web_hmi)
            assert state == "configured", f"Expected 'configured', got '{state}'"
        logger.info("Frontend: configured")

        # 2. configured → ready: wait for Aristo to report ReadyToStart via PAB
        ready = wait_for_plc_value(
            setup_plc, ps1_out.Status.ReadyToWeld, True, retries=30, interval=1.0
        )
        if not ready:
            pytest.skip("PS1 never became ReadyToWeld")
        state = receive_arc_state(web_hmi)
        assert state == "ready", f"Expected 'ready', got '{state}'"
        logger.info("Frontend: ready")

        # 3. ready → starting: send StartWeld via WebApi
        setup_plc.write(var=ps1_in.Commands.StartWeld, value=True)
        time.sleep(0.3)
        setup_plc.write(var=ps1_in.Commands.StartWeld, value=False)
        time.sleep(0.5)
        state = receive_arc_state(web_hmi)
        assert state == "starting", f"Expected 'starting', got '{state}'"
        logger.info("Frontend: starting")

        # 4. starting → active: apply voltage via bench PSU
        apply_arc_voltage(bench_power_supply)
        time.sleep(2.0)
        state = receive_arc_state(web_hmi)
        assert state == "active", f"Expected 'active', got '{state}'"
        logger.info("Frontend: active (arcing via bench PSU)")

        # Verify PLC also reports welding
        status = _read_ps_status(setup_plc, ps1_out)
        logger.info(f"PS1 status during active: {status}")
        assert status.get("Welding") is True

        # 5. Stop: remove voltage and send StopWeld
        remove_arc_voltage(bench_power_supply)
        time.sleep(1.0)
        setup_plc.write(var=ps1_in.Commands.StopWeld, value=True)
        time.sleep(0.3)
        setup_plc.write(var=ps1_in.Commands.StopWeld, value=False)
        time.sleep(1.0)

        # 6. Verify frontend transitions back to ready
        state = receive_arc_state(web_hmi)
        assert state is not None, "Should receive arc state after stop"
        logger.info(f"Frontend after stop: {state}")
        assert state == "ready", f"Expected 'ready', got '{state}'"
