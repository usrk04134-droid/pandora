"""HIL test suite for the slide cross positioning"""

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


class TestSlideCrossAxis:
    """Test suite for the slide cross axis"""

    @pytest.mark.plc_only
    @pytest.mark.usefixtures("enable_horizontal_slide_axis")
    @pytest.mark.usefixtures("reset_slide_cross_positions")
    def test_horizontal_absolute_positioning(self, setup_plc, addresses):
        plc = setup_plc

        position = 40.0
        speed = 10.0

        # Execution & Verification
        ## Set position and set type to 'absolute'
        plc.write(var=addresses["slide_cross_horizontal_motion_set_type"], value=1)
        time.sleep(1)

        plc.write(var=addresses["slide_cross_horizontal_motion_set_target_position"], value=position)
        time.sleep(1)
        
        ## Set speed and set start horizontal positioning to 'absolute'
        plc.write(var=addresses["slide_cross_horizontal_motion_set_speed"], value=speed)
        time.sleep(1)

        Horizontalslide_start, _ = plc.write(var=addresses["slide_cross_horizontal_positioning_start"], value=True)
        assert Horizontalslide_start
        
        logger.info("Starting horizontal absolute positioning test")
        time.sleep(10)

        actual_position, _ = plc.read(var=addresses["slide_cross_horizontal_position"])
        logger.info(f"Reading actual or current position of horizontal axis : {actual_position}")
        assert actual_position - position == pytest.approx(0.0, abs=0.001)

    @pytest.mark.plc_only
    @pytest.mark.usefixtures("enable_vertical_slide_axis")
    @pytest.mark.usefixtures("reset_slide_cross_positions")
    def test_vertical_absolute_positioning(self, setup_plc, addresses):
        plc = setup_plc

        position = 40.0
        speed = 10.0

        # Execution & Verification
        ## Set position and set type to 'absolute'
        plc.write(var=addresses["slide_cross_vertical_motion_set_type"], value=1)
        time.sleep(1)

        plc.write(var=addresses["slide_cross_vertical_motion_set_target_position"], value=position)
        time.sleep(1)
        
        ## Set speed and set start vertical positioning to 'absolute'
        plc.write(var=addresses["slide_cross_vertical_motion_set_speed"], value=speed)
        time.sleep(1)

        Vertical_start, _ = plc.write(var=addresses["slide_cross_vertical_positioning_start"], value=True)
        assert Vertical_start

        logger.info("Starting vertical absolute positioning test")
        time.sleep(1)

        actual_position, _ = plc.read(var=addresses["slide_cross_vertical_busy_status"])
        logger.info(f"Reading actual or current position of vertical axis : {actual_position}")
        assert True == actual_position 
