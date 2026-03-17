"""HIL test cases for weld data handling and starting a manual weld (Gen 2).

Full use-case coverage for sysfun-welddata-handling.md, matching the sequence
verified by the Adaptio block tests (``weld_start.cc`` and
``manual_weld_test.cc``):

1. Create Weld Process Parameters (WPP) for each weld system (WS1, WS2).
2. Create a Weld Data Set (WDS) referencing those WPPs.
3. SelectWeldDataSet → Adaptio configures the weld systems and the arc state
   transitions to CONFIGURED, then to READY once the power sources report
   READY_TO_START.
4. The operator presses the hardware start button which starts the arc
   (simulated in HIL by writing the Start flag on the PLC).

Arc state machine (ManualWeld::ArcState, ``manual_weld.h``):
    idle  →  configured  →  ready  →  starting  →  active

All Adaptio interactions use the typed ``AdaptioWebHmi`` API over the WebHMI
WebSocket.  Arc state verification uses the *push-subscription* pattern:
    • ``client.subscribe_arc_state()`` – subscribe once; receive immediate push.
    • ``client.wait_for_arc_state(state)`` – block until the next matching push.

This mirrors the block-test pattern:
    SubscribeArcState → ReceiveJsonByName("ArcState")
    ... do work ...
    ReceiveJsonByName("ArcState")  # next push on state change

The PLC Start flag (``DataToAdaptio.Adaptio.Start``) is used only to fire the
hardware start-button signal; no PLC state is read or asserted.
"""

import time
from concurrent.futures import ThreadPoolExecutor
from concurrent.futures import TimeoutError as FutureTimeout
from typing import Iterator

import pytest
from loguru import logger
from pydantic_core import ValidationError as PydanticCoreValidationError

from testzilla.adaptio_web_hmi.adaptio_web_hmi import AdaptioWebHmi as AdaptioWebHmiClient
from testzilla.plc.plc_json_rpc import PlcJsonRpc
from testzilla.utility.cleanup_utils import cleanup_web_hmi_client

# ---------------------------------------------------------------------------
# Default weld process parameters mirroring Gen 2 block-test defaults
# (helpers_weld_parameters.h: WPP_DEFAULT_WS1 / WPP_DEFAULT_WS2)
# ---------------------------------------------------------------------------

WPP_DEFAULT_WS1 = {
    "name": "ManualWS1",
    "method": "dc",
    "regulationType": "cc",
    "startAdjust": 10,
    "startType": "scratch",
    "voltage": 25.0,
    "current": 200.0,
    "wireSpeed": 15.0,
    "iceWireSpeed": 0.0,
    "acFrequency": 60.0,
    "acOffset": 1.2,
    "acPhaseShift": 0.5,
    "craterFillTime": 2.0,
    "burnBackTime": 1.0,
}

WPP_DEFAULT_WS2 = {
    "name": "ManualWS2",
    "method": "dc",
    "regulationType": "cc",
    "startAdjust": 10,
    "startType": "direct",
    "voltage": 28.0,
    "current": 180.0,
    "wireSpeed": 14.0,
    "iceWireSpeed": 0.0,
    "acFrequency": 60.0,
    "acOffset": 1.2,
    "acPhaseShift": 0.5,
    "craterFillTime": 2.0,
    "burnBackTime": 1.0,
}

# PLC address for the hardware start-button signal.
# Writing ``True`` here is equivalent to the operator pressing the physical
# start button; Adaptio converts it to a ButtonState::START event which
# triggers the arc start command (``manual_weld.cc::OnButtonStateChange``).
_PLC_START_ADDR = '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.Adaptio.Start'

# ---------------------------------------------------------------------------
# Thread-safety helpers
# ---------------------------------------------------------------------------


def _run_sync_in_thread(func, *args, timeout=None, **kwargs):
    """Run a blocking function in a separate thread and return its result.

    All ``AdaptioWebHmiClient`` instances are created *inside* the worker
    thread so that ``WebSocketClientSync`` creates its own asyncio event loop
    instead of capturing a loop that may already be running in the test thread
    (which would cause ``run_until_complete`` to raise "event loop already
    running").
    """
    with ThreadPoolExecutor(max_workers=1) as executor:
        future = executor.submit(func, *args, **kwargs)
        try:
            return future.result(timeout=timeout)
        except FutureTimeout:
            future.cancel()
            raise TimeoutError("Operation timed out")


def _with_client(uri: str, func):
    """Create an ``AdaptioWebHmiClient``, run ``func(client)``, then close.

    The client is created inside the calling (worker) thread so it owns its
    own asyncio event loop.  Any exception raised by ``func`` propagates
    normally.
    """
    client = AdaptioWebHmiClient(uri=uri)
    try:
        return func(client)
    finally:
        cleanup_web_hmi_client(client)


def _extract_field(response, field: str):
    """Extract *field* from an Adaptio WebHMI response.

    Checks three locations in order:
    1. Top-level key on the raw dict (e.g., ``{"result": "ok", ...}``).
    2. Inside ``payload`` of the raw dict (e.g., ``{"payload": {"result": "ok"}}``,
       as in ``SelectWeldDataSetRsp``).
    3. ``response.payload[field]`` for ``AdaptioWebHmiMessage`` model instances
       (``id`` is always in the payload; ``result`` is usually top-level but can
       also appear inside payload).

    Returns ``None`` when the field is not found.
    """
    if isinstance(response, dict):
        return response.get(field) or response.get("payload", {}).get(field)
    # AdaptioWebHmiMessage instance
    top = getattr(response, field, None)
    if top is not None:
        return top
    if hasattr(response, "payload"):
        return response.payload.get(field)
    return None


def _extract_result(response) -> str | None:
    """Extract the ``result`` string from an Adaptio WebHMI response."""
    return _extract_field(response, "result")


def _extract_id(response) -> int | None:
    """Extract the ``id`` integer from an Adaptio WebHMI response."""
    return _extract_field(response, "id")
    return None


def _press_start_button(plc: PlcJsonRpc) -> None:
    """Simulate a momentary hardware start-button press via the PLC.

    Writes ``True`` to the Adaptio Start flag, waits 200 ms (pulse width),
    then resets to ``False``.  Adaptio's ``ControllerMessenger`` converts this
    rising edge into a ``ButtonState::START`` event, which causes
    ``ManualWeld::OnButtonStateChange`` to issue
    ``WeldControlCommand::START`` and transition the arc state to STARTING.

    The PLC is used only as a *trigger*; no PLC output is read or asserted.
    """
    logger.info("Pressing hardware start button via PLC")
    plc.write(var=_PLC_START_ADDR, value=True)
    time.sleep(0.2)
    plc.write(var=_PLC_START_ADDR, value=False)
    logger.info("Start button pulse sent")


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture(name="weld_process_parameters_setup", scope="function")
def weld_process_parameters_setup_fixture(request: pytest.FixtureRequest) -> Iterator[tuple[int, int]]:
    """Add WPP for WS1 and WS2; yield ``(wpp_id_ws1, wpp_id_ws2)``; clean up.

    Uses the typed ``AdaptioWebHmi.add_weld_process_parameters()`` API so the
    fixture interacts with the real Adaptio message handlers, not raw WebSocket
    strings.
    """
    uri = request.config.WEB_HMI_URI
    wpp_ids: list[int] = []

    for wpp, label in [(WPP_DEFAULT_WS1, "WS1"), (WPP_DEFAULT_WS2, "WS2")]:
        def _add(client, _wpp=wpp):
            return client.add_weld_process_parameters(**_wpp)

        try:
            response = _run_sync_in_thread(_with_client, uri, _add, timeout=15)
        except TimeoutError:
            logger.exception(f"Timeout adding WPP for {label}")
            pytest.skip(f"Timeout adding WPP for {label}")
            return

        result = _extract_result(response)
        if result != "ok":
            pytest.skip(f"Could not add WPP for {label}: result={result!r}")
        wpp_id = _extract_id(response)
        if wpp_id is None:
            pytest.skip(f"No ID returned when adding WPP for {label}")
        logger.info(f"WPP {label} added with id={wpp_id}")
        wpp_ids.append(wpp_id)

    yield wpp_ids[0], wpp_ids[1]

    # Cleanup: remove each WPP that was created
    for wpp_id in wpp_ids:
        def _remove(client, _id=wpp_id):
            return client.send_and_receive_message(
                None,
                "RemoveWeldProcessParameters",
                "RemoveWeldProcessParametersRsp",
                {"id": _id},
            )

        try:
            _run_sync_in_thread(_with_client, uri, _remove, timeout=10)
            logger.debug(f"Removed WPP with id={wpp_id}")
        except TimeoutError:
            logger.warning(f"Timeout removing WPP with id={wpp_id}")


@pytest.fixture(name="weld_data_set_setup", scope="function")
def weld_data_set_setup_fixture(
    request: pytest.FixtureRequest,
    weld_process_parameters_setup: tuple[int, int],
) -> Iterator[int]:
    """Add a WDS referencing both WPPs; yield the WDS ID; clean up.

    Depends on ``weld_process_parameters_setup``.
    """
    uri = request.config.WEB_HMI_URI
    wpp_id_ws1, wpp_id_ws2 = weld_process_parameters_setup
    wds_id: int | None = None

    def _add_wds(client):
        return client.add_weld_data_set(name="ManualWeld", ws1WppId=wpp_id_ws1, ws2WppId=wpp_id_ws2)

    try:
        response = _run_sync_in_thread(_with_client, uri, _add_wds, timeout=15)
    except TimeoutError:
        logger.exception("Timeout adding weld data set")
        pytest.skip("Timeout adding weld data set")
        return

    result = _extract_result(response)
    if result != "ok":
        pytest.skip(f"Could not add weld data set: result={result!r}")
    wds_id = _extract_id(response)
    if wds_id is None:
        pytest.skip("No ID returned when adding weld data set")
    logger.info(f"Weld data set added with id={wds_id}")

    yield wds_id

    def _remove_wds(client):
        return client.send_and_receive_message(
            None,
            "RemoveWeldDataSet",
            "RemoveWeldDataSetRsp",
            {"id": wds_id},
        )

    try:
        _run_sync_in_thread(_with_client, uri, _remove_wds, timeout=10)
        logger.debug(f"Removed weld data set with id={wds_id}")
    except TimeoutError:
        logger.warning(f"Timeout removing weld data set with id={wds_id}")


# ---------------------------------------------------------------------------
# Test suite
# ---------------------------------------------------------------------------


class TestManualWeldStart:
    """HIL test suite for the complete manual weld start use case (Gen 2).

    Matches the block-test sequences in ``weld_start.cc`` and
    ``manual_weld_test.cc``:

    Block-test analogue:
        AddWeldProcessParameters(WS1)  ←→  test_add_weld_process_parameters_ws1
        AddWeldProcessParameters(WS2)  ←→  test_add_weld_process_parameters_ws2
        AddWeldDataSet                 ←→  test_add_weld_data_set
        SelectWeldDataSet              ←→  test_select_weld_data_set
        ArcState == "configured"       ←→  test_select_weld_data_set_transitions_to_configured
        ArcState == "ready"            ←→  (covered in test_complete_weld_start_sequence)
        PressStart (PLC flag)          ←→  test_complete_weld_start_sequence step 4
        ArcState == "starting"         ←→  test_complete_weld_start_sequence step 4
    """

    # ------------------------------------------------------------------
    # Individual-step tests (typed API, one connection per call)
    # ------------------------------------------------------------------

    def test_add_weld_process_parameters_ws1(self, request: pytest.FixtureRequest) -> None:
        """Adding WPP for WS1 via ``AdaptioWebHmi.add_weld_process_parameters()`` returns "ok".

        Calls the typed method which sends ``AddWeldProcessParameters`` and
        waits for ``AddWeldProcessParametersRsp``.
        """
        logger.info("Testing add_weld_process_parameters for WS1")

        def _test(client):
            rsp = client.add_weld_process_parameters(**WPP_DEFAULT_WS1)
            result = _extract_result(rsp)
            assert result == "ok", f"Expected 'ok', got: {result!r}"
            logger.info(f"WPP WS1 added with id={_extract_id(rsp)}")

        try:
            _run_sync_in_thread(_with_client, request.config.WEB_HMI_URI, _test, timeout=15)
        except TimeoutError:
            pytest.fail("Timed out waiting for AddWeldProcessParametersRsp (WS1)")

    def test_add_weld_process_parameters_ws2(self, request: pytest.FixtureRequest) -> None:
        """Adding WPP for WS2 via ``AdaptioWebHmi.add_weld_process_parameters()`` returns "ok".

        Calls the typed method which sends ``AddWeldProcessParameters`` and
        waits for ``AddWeldProcessParametersRsp``.
        """
        logger.info("Testing add_weld_process_parameters for WS2")

        def _test(client):
            rsp = client.add_weld_process_parameters(**WPP_DEFAULT_WS2)
            result = _extract_result(rsp)
            assert result == "ok", f"Expected 'ok', got: {result!r}"
            logger.info(f"WPP WS2 added with id={_extract_id(rsp)}")

        try:
            _run_sync_in_thread(_with_client, request.config.WEB_HMI_URI, _test, timeout=15)
        except TimeoutError:
            pytest.fail("Timed out waiting for AddWeldProcessParametersRsp (WS2)")

    @pytest.mark.usefixtures("weld_process_parameters_setup")
    def test_add_weld_data_set(
        self,
        request: pytest.FixtureRequest,
        weld_process_parameters_setup: tuple[int, int],
    ) -> None:
        """Adding a WDS referencing both WPPs via ``add_weld_data_set()`` returns "ok".

        Requires both WPPs to be present (provided by ``weld_process_parameters_setup``).
        """
        wpp_id_ws1, wpp_id_ws2 = weld_process_parameters_setup
        logger.info(f"Testing add_weld_data_set (ws1WppId={wpp_id_ws1}, ws2WppId={wpp_id_ws2})")

        def _test(client):
            rsp = client.add_weld_data_set(name="ManualWeld", ws1WppId=wpp_id_ws1, ws2WppId=wpp_id_ws2)
            result = _extract_result(rsp)
            assert result == "ok", f"Expected 'ok', got: {result!r}"
            logger.info(f"Weld data set added with id={_extract_id(rsp)}")

        try:
            _run_sync_in_thread(_with_client, request.config.WEB_HMI_URI, _test, timeout=15)
        except TimeoutError:
            pytest.fail("Timed out waiting for AddWeldDataSetRsp")

    def test_select_weld_data_set(
        self,
        request: pytest.FixtureRequest,
        weld_data_set_setup: int,
    ) -> None:
        """Selecting an existing WDS via ``select_weld_data_set()`` returns "ok".

        Requires a WDS to exist (provided by ``weld_data_set_setup``).
        """
        wds_id = weld_data_set_setup
        logger.info(f"Testing select_weld_data_set (id={wds_id})")

        def _test(client):
            rsp = client.select_weld_data_set(id=wds_id)
            result = _extract_result(rsp)
            assert result == "ok", f"Expected 'ok', got: {result!r}"
            logger.info(f"WDS id={wds_id} selected successfully")

        try:
            _run_sync_in_thread(_with_client, request.config.WEB_HMI_URI, _test, timeout=15)
        except TimeoutError:
            pytest.fail("Timed out waiting for SelectWeldDataSetRsp")

    # ------------------------------------------------------------------
    # Arc state tests (push-subscription pattern, like block tests)
    # ------------------------------------------------------------------

    def test_arc_state_is_idle_initially(self, request: pytest.FixtureRequest) -> None:
        """Before any WDS is selected the arc state push is "idle".

        Calls ``subscribe_arc_state()`` which sends ``SubscribeArcState`` and
        receives the immediate push.  Adaptio's ``ManualWeld`` pushes the
        current state right after subscription is registered – this matches
        the block-test pattern:
            SubscribeArcState → ReceiveJsonByName("ArcState") == "idle"
        """
        logger.info("Verifying initial arc state is 'idle' via SubscribeArcState")

        def _test(client):
            msg = client.subscribe_arc_state()
            state = msg.payload.get("state")
            assert state == "idle", f"Expected initial arc state 'idle', got: {state!r}"
            logger.info("Initial arc state confirmed as 'idle'")

        try:
            _run_sync_in_thread(_with_client, request.config.WEB_HMI_URI, _test, timeout=15)
        except TimeoutError:
            pytest.fail("Timed out waiting for initial ArcState push")

    def test_select_weld_data_set_transitions_to_configured(
        self,
        request: pytest.FixtureRequest,
        weld_data_set_setup: int,
    ) -> None:
        """SelectWeldDataSet causes Adaptio to push ArcState "configured".

        Pattern (mirrors ``manual_weld_test.cc::select_weld_data_set_transitions_state``):
            SubscribeArcState   → push "idle"
            SelectWeldDataSet   → push "configured"

        Adaptio's ``ManualWeld::OnSelectWeldDataSet`` configures both weld
        systems and calls ``SetState(ArcState::CONFIGURED)`` which immediately
        triggers a push.
        """
        uri = request.config.WEB_HMI_URI
        wds_id = weld_data_set_setup
        logger.info(f"Testing SelectWeldDataSet (id={wds_id}) → arc state 'configured'")

        def _test(client):
            # Subscribe first – consume immediate "idle" push
            init = client.subscribe_arc_state()
            logger.debug(f"Initial arc state: {init.payload.get('state')!r}")

            # Select the weld data set (configures weld systems)
            rsp = client.select_weld_data_set(id=wds_id)
            result = _extract_result(rsp)
            assert result == "ok", f"SelectWeldDataSet failed: {result!r}"
            logger.info(f"WDS id={wds_id} selected; waiting for 'configured' push")

            # Wait for the ArcState push that Adaptio sends on CONFIGURED transition
            arc = client.wait_for_arc_state("configured", timeout_s=10.0)
            assert arc.payload.get("state") == "configured"
            logger.info("Arc state transitioned to 'configured' ✓")

        try:
            _run_sync_in_thread(_with_client, uri, _test, timeout=30)
        except TimeoutError as exc:
            pytest.fail(f"Arc state did not transition to 'configured': {exc}")

    # ------------------------------------------------------------------
    # End-to-end flow test (steps 1–4 of the use case)
    # ------------------------------------------------------------------

    def test_complete_weld_start_sequence(
        self,
        request: pytest.FixtureRequest,
        setup_plc: PlcJsonRpc,
    ) -> None:
        """Complete weld start sequence from WPP creation through arc STARTING.

        Mirrors the ``WeldStart::manual_weld_start`` and
        ``ManualWeld::start_stop_weld_state_machine`` block tests:

            1. ``add_weld_process_parameters(WS1)``  → "ok"
            1b. ``add_weld_process_parameters(WS2)`` → "ok"
            2. ``add_weld_data_set``                 → "ok"
            3a. ``select_weld_data_set``             → ArcState push "configured"
            3b. (power sources report READY_TO_START) → ArcState push "ready"
            4. PLC Start flag pulse                  → ArcState push "starting"

        A single persistent ``AdaptioWebHmi`` connection is used for the
        entire sequence so that arc state pushes are not missed between steps.

        PLC data / outputs are NOT asserted; the PLC is used only to send the
        start-button signal.
        """
        uri = request.config.WEB_HMI_URI
        logger.info("Starting complete weld start sequence test")

        def _test(client):
            # ---- Subscribe to arc state first (matches block test pattern) ----
            # Block test: SubscribeArcState → ReceiveJsonByName("ArcState") == "idle"
            init = client.subscribe_arc_state()
            assert init.payload.get("state") == "idle", (
                f"Expected initial arc state 'idle', got: {init.payload.get('state')!r}"
            )
            logger.info("Arc state subscription active; initial state is 'idle'")

            # ---- Step 1a: Add WPP for WS1 ------------------------------------
            # Block test: AddWeldProcessParameters(mfx.Main(), WPP_DEFAULT_WS1, true)
            logger.info("Step 1a: add_weld_process_parameters (WS1)")
            rsp = client.add_weld_process_parameters(**WPP_DEFAULT_WS1)
            assert _extract_result(rsp) == "ok", f"WPP WS1 failed: {_extract_result(rsp)!r}"
            wpp1_id = _extract_id(rsp)
            logger.info(f"WPP WS1 added with id={wpp1_id}")

            # ---- Step 1b: Add WPP for WS2 ------------------------------------
            # Block test: AddWeldProcessParameters(mfx.Main(), WPP_DEFAULT_WS2, true)
            logger.info("Step 1b: add_weld_process_parameters (WS2)")
            rsp = client.add_weld_process_parameters(**WPP_DEFAULT_WS2)
            assert _extract_result(rsp) == "ok", f"WPP WS2 failed: {_extract_result(rsp)!r}"
            wpp2_id = _extract_id(rsp)
            logger.info(f"WPP WS2 added with id={wpp2_id}")

            # ---- Step 2: Add WDS ---------------------------------------------
            # Block test: AddWeldDataSet(mfx.Main(), "ManualWeld", 1, 2, true)
            logger.info("Step 2: add_weld_data_set")
            rsp = client.add_weld_data_set(name="ManualWeld", ws1WppId=wpp1_id, ws2WppId=wpp2_id)
            assert _extract_result(rsp) == "ok", f"AddWeldDataSet failed: {_extract_result(rsp)!r}"
            wds_id = _extract_id(rsp)
            logger.info(f"WDS added with id={wds_id}")

            # ---- Step 3a: Select WDS → ArcState "configured" ----------------
            # Block test: SelectWeldDataSet → ReceiveJsonByName("ArcState") == "configured"
            logger.info("Step 3a: select_weld_data_set")
            rsp = client.select_weld_data_set(id=wds_id)
            assert _extract_result(rsp) == "ok", f"SelectWeldDataSet failed: {_extract_result(rsp)!r}"
            logger.info("WDS selected; waiting for arc state push 'configured'")

            arc = client.wait_for_arc_state("configured", timeout_s=10.0)
            assert arc.payload.get("state") == "configured"
            logger.info("Arc state reached 'configured' ✓")

            # ---- Step 3b: Wait for READY (power sources READY_TO_START) ------
            # Block test: MakeReady(mfx) → ReceiveJsonByName("ArcState") == "ready"
            # In HIL, real power sources report READY_TO_START automatically;
            # ManualWeld::UpdateReadiness() triggers the READY transition.
            logger.info("Step 3b: waiting for arc state push 'ready' (power sources READY_TO_START)")
            arc = client.wait_for_arc_state("ready", timeout_s=60.0)
            assert arc.payload.get("state") == "ready"
            logger.info("Arc state reached 'ready' ✓")

            # ---- Step 4: Start-button → ArcState "starting" -----------------
            # Block test: PressStart(mfx) → ReceiveJsonByName("ArcState") == "starting"
            # In HIL, the start button is simulated by writing the PLC Start flag.
            # ManualWeld::OnButtonStateChange(START) issues WeldControlCommand::START
            # and calls SetState(ArcState::STARTING).
            logger.info("Step 4: pressing hardware start button via PLC")
            _press_start_button(setup_plc)

            arc = client.wait_for_arc_state("starting", timeout_s=10.0)
            assert arc.payload.get("state") == "starting"
            logger.info("Arc state reached 'starting' ✓ — arc start sequence complete")

        try:
            # 120 s: 10 (configured) + 60 (ready) + 10 (starting) + margin
            _run_sync_in_thread(_with_client, uri, _test, timeout=120)
        except TimeoutError as exc:
            pytest.fail(f"Arc state transition timed out: {exc}")

    # ------------------------------------------------------------------
    # End-to-end flow (no PLC / arc state subscription not needed)
    # ------------------------------------------------------------------

    def test_full_manual_weld_setup(self, request: pytest.FixtureRequest) -> None:
        """All four WebHMI steps (WPP+WPP+WDS+Select) complete successfully.

        Validates the full data-setup sequence without arc state verification
        (no PLC required):
            1. add_weld_process_parameters (WS1)
            2. add_weld_process_parameters (WS2)
            3. add_weld_data_set
            4. select_weld_data_set
        Each step must return result "ok".
        """
        uri = request.config.WEB_HMI_URI
        logger.info("Testing full manual weld setup flow (WebHMI API)")

        def _test(client):
            # Step 1a
            logger.info("Step 1a: add_weld_process_parameters (WS1)")
            rsp = client.add_weld_process_parameters(**WPP_DEFAULT_WS1)
            assert _extract_result(rsp) == "ok", f"WPP WS1 failed: {_extract_result(rsp)!r}"
            wpp1_id = _extract_id(rsp)
            logger.info(f"WPP WS1 id={wpp1_id}")

            # Step 1b
            logger.info("Step 1b: add_weld_process_parameters (WS2)")
            rsp = client.add_weld_process_parameters(**WPP_DEFAULT_WS2)
            assert _extract_result(rsp) == "ok", f"WPP WS2 failed: {_extract_result(rsp)!r}"
            wpp2_id = _extract_id(rsp)
            logger.info(f"WPP WS2 id={wpp2_id}")

            # Step 2
            logger.info("Step 2: add_weld_data_set")
            rsp = client.add_weld_data_set(name="ManualWeld", ws1WppId=wpp1_id, ws2WppId=wpp2_id)
            assert _extract_result(rsp) == "ok", f"AddWeldDataSet failed: {_extract_result(rsp)!r}"
            wds_id = _extract_id(rsp)
            logger.info(f"WDS id={wds_id}")

            # Step 3
            logger.info("Step 3: select_weld_data_set")
            rsp = client.select_weld_data_set(id=wds_id)
            assert _extract_result(rsp) == "ok", f"SelectWeldDataSet failed: {_extract_result(rsp)!r}"
            logger.info("Full manual weld setup completed successfully")

        try:
            _run_sync_in_thread(_with_client, uri, _test, timeout=60)
        except TimeoutError:
            pytest.fail("Timed out during full manual weld setup flow")

    # ------------------------------------------------------------------
    # Negative / validation tests
    # ------------------------------------------------------------------

    def test_add_weld_data_set_with_invalid_wpp_id_fails(self, request: pytest.FixtureRequest) -> None:
        """Adding a WDS with a non-existent WPP ID returns "fail".

        Verifies that Adaptio's ``WeldSequenceConfigImpl`` rejects a WDS
        referencing WPP IDs that do not exist.
        """
        logger.info("Testing add_weld_data_set with invalid WPP IDs")

        def _test(client):
            try:
                rsp = client.add_weld_data_set(name="InvalidWeld", ws1WppId=99999, ws2WppId=99998)
                result = _extract_result(rsp)
                assert result == "fail", f"Expected 'fail' for invalid WPP IDs, got: {result!r}"
                logger.info("Correctly received 'fail' for invalid WPP IDs")
            except PydanticCoreValidationError as exc:
                # Adaptio may return a failure response with a non-standard schema
                raw_input = next(
                    (err["input"] for err in exc.errors() if "input" in err),
                    None,
                )
                if raw_input is not None:
                    result = raw_input.get("result") or raw_input.get("payload", {}).get("result")
                    assert result == "fail", f"Expected 'fail', got: {result!r}"
                    logger.info("Correctly received 'fail' for invalid WPP IDs")
                else:
                    raise

        try:
            _run_sync_in_thread(_with_client, request.config.WEB_HMI_URI, _test, timeout=15)
        except TimeoutError:
            pytest.fail("Timed out waiting for AddWeldDataSetRsp (invalid IDs)")

    def test_select_nonexistent_weld_data_set_fails(self, request: pytest.FixtureRequest) -> None:
        """Selecting a WDS with a non-existent ID returns "fail".

        Verifies that Adaptio's ``ManualWeld::OnSelectWeldDataSet`` rejects
        an ID that has not been registered.
        """
        logger.info("Testing select_weld_data_set with non-existent ID")

        def _test(client):
            try:
                rsp = client.select_weld_data_set(id=99999)
                result = _extract_result(rsp)
                assert result == "fail", f"Expected 'fail' for non-existent WDS, got: {result!r}"
                logger.info("Correctly received 'fail' for non-existent WDS ID")
            except PydanticCoreValidationError as exc:
                raw_input = next(
                    (err["input"] for err in exc.errors() if "input" in err),
                    None,
                )
                if raw_input is not None:
                    result = raw_input.get("result") or raw_input.get("payload", {}).get("result")
                    assert result == "fail", f"Expected 'fail', got: {result!r}"
                    logger.info("Correctly received 'fail' for non-existent WDS ID")
                else:
                    raise

        try:
            _run_sync_in_thread(_with_client, request.config.WEB_HMI_URI, _test, timeout=15)
        except TimeoutError:
            pytest.fail("Timed out waiting for SelectWeldDataSetRsp (non-existent ID)")
