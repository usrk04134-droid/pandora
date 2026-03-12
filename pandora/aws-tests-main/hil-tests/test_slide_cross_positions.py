"""HIL Test case for Slide cross positions with joint tracking"""

import time
from pathlib import Path
from typing import Any

import pytest
from loguru import logger
from testzilla.plc.models import PlcProgramWrite


def wait_for_value(plc, address: str, expected_value: Any, iterations: int = 10) -> bool:
    current_value = None
    for _ in range(iterations):
        current_value, _ = plc.read(var=address)
        if expected_value == current_value:
            return True
        time.sleep(1)

    return False


class TestSlideCross:
    """Test suite for slide cross positions"""

    @pytest.mark.plc_only
    @pytest.mark.usefixtures("reset_slide_cross_positions")
    def test_starting_slide_cross_positions(self, setup_plc, addresses):
        plc = setup_plc

        logger.info("Checking starting slide cross positions being sent from PLC to Adaptio")
        v_pos, _ = plc.read(var=addresses["slide_cross_x_position_to_adaptio"])
        h_pos, _ = plc.read(var=addresses["slide_cross_y_position_to_adaptio"])

        assert v_pos == 0.0
        assert h_pos == 0.0

    @pytest.mark.usefixtures("reset_slide_cross_positions", "joint_tracking_sim_setup")
    def test_slide_cross_position_after_joint_tracking(self, setup_plc, update_adaptio_config, addresses):
        update = update_adaptio_config
        update(Path(__file__).parent / Path("adaptio_configs/image_simulation"))
        plc = setup_plc

        v_pos_pre, _ = plc.read(var=addresses["slide_cross_y_position_from_adaptio"])
        logger.info(f"Vertical slide cross position from Adaptio: {v_pos_pre}")
        h_pos_pre, _ = plc.read(var=addresses["slide_cross_x_position_from_adaptio"])
        logger.info(f"Horizontal slide cross position from Adaptio: {h_pos_pre}")

        started, _ = plc.write(var=addresses["joint_tracking_button"], value=3)
        logger.info(f"Joint tracking started: write_ok={started}")

        status, _ = plc.read(var=addresses["joint_tracking_button_flag"])
        logger.info(f"Joint tracking flag: {status}")
        assert status == True
        time.sleep(5)

        stopped, _ = plc.write(var=addresses["joint_tracking_button"], value=1)
        logger.info(f"Joint tracking stopped: write_ok={stopped}")

        v_pos, _ = plc.read(var=addresses["slide_cross_y_position_from_adaptio"])
        logger.info(f"Vertical slide cross position from Adaptio: {v_pos}")
        h_pos, _ = plc.read(var=addresses["slide_cross_x_position_from_adaptio"])
        logger.info(f"Horizontal slide cross position from Adaptio: {h_pos}")

        assert v_pos != v_pos_pre or h_pos != h_pos_pre

    @pytest.mark.skip(reason="DB Changes")
    @pytest.mark.plc_only
    @pytest.mark.usefixtures("reset_slide_cross_positions")
    def test_move_vertical_slide__motion_type_absolute(self, setup_plc, addresses, request):
        # Preparation

        plc = setup_plc
        first_pos = -20.5
        second_pos = 20.5

        ## Cleanup
        def cleanup():
            plc.bulk_request(
                [
                    PlcProgramWrite(params={"var": addresses["slide_cross_vertical_motion_set_speed"], "value": 0.0}),
                    PlcProgramWrite(params={"var": addresses["slide_cross_vertical_motion_set_type"], "value": 0}),
                    PlcProgramWrite(
                        params={"var": addresses["slide_cross_vertical_motion_set_target_position"], "value": 0.0}
                    ),
                ]
            )

        request.addfinalizer(cleanup)

        # Execution & Verification

        ## Set speed and set motion type to 'absolute'
        type_set, _ = plc.write(var=addresses["slide_cross_vertical_motion_set_type"], value=1)
        assert type_set
        speed_set, _ = plc.write(var=addresses["slide_cross_vertical_motion_set_speed"], value=10.0)
        assert speed_set

        ## Set first position and start motion
        target_set, _ = plc.write(var=addresses["slide_cross_vertical_motion_set_target_position"], value=first_pos)
        assert target_set
        started, _ = plc.write(var=addresses["slide_cross_vertical_positioning_start"], value=True)
        assert started
        logger.info("Starting vertical slide positioning")

        ## Wait for start bit reset
        assert wait_for_value(plc, addresses["slide_cross_vertical_positioning_start"], False), "Start bit not reset"

        ## Verify the slide position for the first position
        status, _ = plc.read(var=addresses["slide_cross_vertical_position"])
        logger.info(f"Vertical slide positioning status: {status}")
        assert status == pytest.approx(first_pos, rel=1e-3)

        ## Set second position and start motion
        target_set, _ = plc.write(var=addresses["slide_cross_vertical_motion_set_target_position"], value=second_pos)
        assert target_set
        started, _ = plc.write(var=addresses["slide_cross_vertical_positioning_start"], value=True)
        assert started
        logger.info("Starting vertical slide positioning")

        ## Wait for start bit reset
        assert wait_for_value(plc, addresses["slide_cross_vertical_positioning_start"], False), "Start bit not reset"

        ## Verify the slide position for the second position
        status, _ = plc.read(var=addresses["slide_cross_vertical_position"])
        logger.info(f"Vertical slide positioning status: {status}")
        assert status == pytest.approx(second_pos, rel=1e-3)

    @pytest.mark.skip(reason="DB Changes")
    @pytest.mark.plc_only
    @pytest.mark.usefixtures("reset_slide_cross_positions")
    def test_move_vertical_slide__motion_type_relative(self, setup_plc, addresses, request):
        # Preparation

        plc = setup_plc
        first_pos = -10.0
        second_pos = 20.0

        ## Cleanup
        def cleanup():
            plc.bulk_request(
                [
                    PlcProgramWrite(params={"var": addresses["slide_cross_vertical_motion_set_speed"], "value": 0.0}),
                    PlcProgramWrite(params={"var": addresses["slide_cross_vertical_motion_set_type"], "value": 0}),
                    PlcProgramWrite(
                        params={"var": addresses["slide_cross_vertical_motion_set_target_position"], "value": 0.0}
                    ),
                ]
            )

        request.addfinalizer(cleanup)

        # Execution & Verification

        ## Set speed and the motion type to 'relative'
        type_set, _ = plc.write(var=addresses["slide_cross_vertical_motion_set_type"], value=0)
        assert type_set
        speed_set, _ = plc.write(var=addresses["slide_cross_vertical_motion_set_speed"], value=10.0)
        assert speed_set

        ## Set position to the first position and start motion
        target_set, _ = plc.write(var=addresses["slide_cross_vertical_motion_set_target_position"], value=first_pos)
        assert target_set
        started, _ = plc.write(var=addresses["slide_cross_vertical_positioning_start"], value=True)
        assert started
        logger.info("Starting vertical slide positioning")

        ## Wait for start bit reset
        assert wait_for_value(plc, addresses["slide_cross_vertical_positioning_start"], False), "Start bit not reset"

        ## Verify the slide position for the first position
        status, _ = plc.read(var=addresses["slide_cross_vertical_position"])
        logger.info(f"Vertical slide positioning status: {status}")
        assert status == pytest.approx(first_pos, rel=1e-3)

        ## Set position to the second position and start motion
        target_set, _ = plc.write(var=addresses["slide_cross_vertical_motion_set_target_position"], value=second_pos)
        assert target_set
        started, _ = plc.write(var=addresses["slide_cross_vertical_positioning_start"], value=True)
        assert started
        logger.info("Starting vertical slide positioning")

        ## Wait for start bit reset
        assert wait_for_value(plc, addresses["slide_cross_vertical_positioning_start"], False), "Start bit not reset"

        ## Verify the slide position for the second position
        status, _ = plc.read(var=addresses["slide_cross_vertical_position"])
        logger.info(f"Vertical slide positioning status: {status}")
        assert status == pytest.approx(first_pos + second_pos, rel=1e-3)

    @pytest.mark.skip(reason="DB Changes")
    @pytest.mark.plc_only
    @pytest.mark.usefixtures("reset_slide_cross_positions")
    def test_move_vertical_slide__motion_type_velocity(self, setup_plc, addresses, request):
        # Preparation
        plc = setup_plc

        ## Cleanup
        def cleanup():
            plc.bulk_request(
                [
                    PlcProgramWrite(params={"var": addresses["slide_cross_vertical_motion_set_speed"], "value": 0.0}),
                    PlcProgramWrite(params={"var": addresses["slide_cross_vertical_motion_set_type"], "value": 0}),
                    PlcProgramWrite(
                        params={"var": addresses["slide_cross_vertical_motion_set_target_position"], "value": 0.0}
                    ),
                ]
            )

        request.addfinalizer(cleanup)

        # Execution & Verification

        ## Set speed and the motion type to 'velocity'
        type_set, _ = plc.write(var=addresses["slide_cross_vertical_motion_set_type"], value=2)
        assert type_set
        speed_set, _ = plc.write(var=addresses["slide_cross_vertical_motion_set_speed"], value=10.0)
        assert speed_set

        ## Start motion
        started, _ = plc.write(var=addresses["slide_cross_vertical_positioning_start"], value=True)
        assert started
        logger.info("Starting vertical slide positioning")

        ## Wait for the velocity status to reach the set value
        assert wait_for_value(plc, addresses["slide_cross_vertical_velocity"], 10.0)
        logger.info("Vertical slide velocity reached set value")

    @pytest.mark.skip(reason="DB Changes")
    @pytest.mark.plc_only
    @pytest.mark.usefixtures("reset_slide_cross_positions")
    def test_move_horizontal_slide__motion_type_absolute(self, setup_plc, addresses, request):
        # Preparation

        plc = setup_plc
        first_pos = -20.0
        second_pos = 20.0

        ## Cleanup
        def cleanup():
            plc.bulk_request(
                [
                    PlcProgramWrite(params={"var": addresses["slide_cross_horizontal_motion_set_speed"], "value": 0.0}),
                    PlcProgramWrite(params={"var": addresses["slide_cross_horizontal_motion_set_type"], "value": 0}),
                    PlcProgramWrite(
                        params={"var": addresses["slide_cross_horizontal_motion_set_target_position"], "value": 0.0}
                    ),
                ]
            )

        request.addfinalizer(cleanup)

        # Execution & Verification

        ## Set speed and set motion type to 'absolute'
        type_set, _ = plc.write(var=addresses["slide_cross_horizontal_motion_set_type"], value=1)
        assert type_set
        speed_set, _ = plc.write(var=addresses["slide_cross_horizontal_motion_set_speed"], value=10.0)
        assert speed_set

        ## Set first position and start motion
        target_set, _ = plc.write(var=addresses["slide_cross_horizontal_motion_set_target_position"], value=first_pos)
        assert target_set
        started, _ = plc.write(var=addresses["slide_cross_horizontal_positioning_start"], value=True)
        assert started
        logger.info("Starting horizontal slide positioning")

        ## Wait for start bit reset
        assert wait_for_value(
            plc, addresses["slide_cross_horizontal_positioning_start"],
            False,
            15
        ), "Start bit not reset"

        ## Verify the slide position for the first position
        status, _ = plc.read(var=addresses["slide_cross_horizontal_position"])
        logger.info(f"Horizontal slide positioning status: {status}")
        assert status == pytest.approx(first_pos, rel=1e-3)

        ## Set second position and start motion
        target_set, _ = plc.write(var=addresses["slide_cross_horizontal_motion_set_target_position"], value=second_pos)
        assert target_set
        started, _ = plc.write(var=addresses["slide_cross_horizontal_positioning_start"], value=True)
        assert started
        logger.info("Starting horizontal slide positioning")

        ## Wait for start bit reset
        assert wait_for_value(
            plc,
            addresses["slide_cross_horizontal_positioning_start"],
            False,
            15
        ), "Start bit not reset"

        ## Verify the slide position for the second position
        status, _ = plc.read(var=addresses["slide_cross_horizontal_position"])
        logger.info(f"Horizontal slide positioning status: {status}")
        assert status == pytest.approx(second_pos, rel=1e-3)

    @pytest.mark.skip(reason="DB Changes")
    @pytest.mark.plc_only
    @pytest.mark.usefixtures("reset_slide_cross_positions")
    def test_move_horizontal_slide__motion_type_relative(self, setup_plc, addresses, request):
        # Preparation

        plc = setup_plc
        first_pos = -10.0
        second_pos = 20.0

        ## Cleanup
        def cleanup():
            plc.bulk_request(
                [
                    PlcProgramWrite(params={"var": addresses["slide_cross_horizontal_motion_set_speed"], "value": 0.0}),
                    PlcProgramWrite(params={"var": addresses["slide_cross_horizontal_motion_set_type"], "value": 0}),
                    PlcProgramWrite(
                        params={"var": addresses["slide_cross_horizontal_motion_set_target_position"], "value": 0.0}
                    ),
                ]
            )

        request.addfinalizer(cleanup)

        # Execution & Verification

        ## Set speed and the motion type to 'relative'
        type_set, _ = plc.write(var=addresses["slide_cross_horizontal_motion_set_type"], value=0)
        assert type_set
        speed_set, _ = plc.write(var=addresses["slide_cross_horizontal_motion_set_speed"], value=10.0)
        assert speed_set

        ## Set position to the first position and start motion
        target_set, _ = plc.write(var=addresses["slide_cross_horizontal_motion_set_target_position"], value=first_pos)
        assert target_set
        started, _ = plc.write(var=addresses["slide_cross_horizontal_positioning_start"], value=True)
        assert started
        logger.info("Starting horizontal slide positioning")

        ## Wait for start bit reset
        assert wait_for_value(plc, addresses["slide_cross_horizontal_positioning_start"], False), "Start bit not reset"

        ## Verify the slide position for the first position
        status, _ = plc.read(var=addresses["slide_cross_horizontal_position"])
        logger.info(f"Horizontal slide positioning status: {status}")
        assert status == pytest.approx(first_pos, rel=1e-3)

        ## Set position to the second position and start motion
        target_set, _ = plc.write(var=addresses["slide_cross_horizontal_motion_set_target_position"], value=second_pos)
        assert target_set
        started, _ = plc.write(var=addresses["slide_cross_horizontal_positioning_start"], value=True)
        assert started
        logger.info("Starting horizontal slide positioning")

        ## Wait for start bit reset
        assert wait_for_value(plc, addresses["slide_cross_horizontal_positioning_start"], False), "Start bit not reset"

        ## Verify the slide position for the second position
        status, _ = plc.read(var=addresses["slide_cross_horizontal_position"])
        logger.info(f"Horizontal slide positioning status: {status}")
        assert status == pytest.approx(first_pos + second_pos, rel=1e-3)

    @pytest.mark.skip(reason="DB Changes")
    @pytest.mark.plc_only
    @pytest.mark.usefixtures("reset_slide_cross_positions")
    def test_move_horizontal_slide__motion_type_velocity(self, setup_plc, addresses, request):
        # Preparation
        plc = setup_plc

        ## Cleanup
        def cleanup():
            plc.bulk_request(
                [
                    PlcProgramWrite(params={"var": addresses["slide_cross_horizontal_motion_set_speed"], "value": 0.0}),
                    PlcProgramWrite(params={"var": addresses["slide_cross_horizontal_motion_set_type"], "value": 0}),
                    PlcProgramWrite(
                        params={"var": addresses["slide_cross_horizontal_motion_set_target_position"], "value": 0.0}
                    ),
                ]
            )

        request.addfinalizer(cleanup)

        # Execution & Verification

        ## Set speed and the motion type to 'velocity'
        type_set, _ = plc.write(var=addresses["slide_cross_horizontal_motion_set_type"], value=2)
        assert type_set
        speed_set, _ = plc.write(var=addresses["slide_cross_horizontal_motion_set_speed"], value=10.0)
        assert speed_set

        ## Start motion
        started, _ = plc.write(var=addresses["slide_cross_horizontal_positioning_start"], value=True)
        assert started
        logger.info("Starting horizontal slide positioning")

        ## Wait for the velocity status to reach the set value
        assert wait_for_value(plc, addresses["slide_cross_horizontal_velocity"], 10.0)
        logger.info("Horizontal slide velocity reached set value")
