"""HIL Test case for joint tracking functionality"""

import time
from pathlib import Path

import pytest
from loguru import logger


class TestJointTracking:
    """Test suite for joint tracking"""

    @pytest.mark.plc_only
    def test_joint_tracking_initial_state(self, setup_plc, addresses):
        plc = setup_plc
        logger.info("Check joint tracking status")
        status, _ = plc.read(var=addresses["joint_tracking_button"])
        logger.info(f"Joint tracking status: {status}")
        assert status == 1

    @pytest.mark.usefixtures("reset_slide_cross_positions" ,"joint_tracking_sim_setup")
    def test_joint_tracking_run_for_sim(self, setup_plc, update_adaptio_config, addresses):
        update = update_adaptio_config
        update(Path(__file__).parent / Path("adaptio_configs/image_simulation"))
        plc = setup_plc
        started, _ = plc.write(var=addresses["joint_tracking_button"], value=3)
        logger.info(f"Joint tracking started: write_ok={started}")

        status, _ = plc.read(var=addresses["joint_tracking_button_flag"])
        logger.info(f"Joint tracking flag: {status}")
        assert status == True
        time.sleep(5)

        stopped, _ = plc.write(var=addresses["joint_tracking_button"], value=1)
        logger.info(f"Joint tracking stopped: write_ok={stopped}")

    @pytest.mark.usefixtures("reset_slide_cross_positions", "joint_tracking_abw_sim_setup")
    def test_joint_tracking_run_for_abw_sim(self, setup_plc, addresses):
        plc = setup_plc
        started, _ = plc.write(var=addresses["joint_tracking_button"], value=3)
        logger.info(f"Joint tracking started: write_ok={started}")

        status, _ = plc.read(var=addresses["joint_tracking_button_flag"])
        logger.info(f"Joint tracking flag: {status}")
        assert status == True
        time.sleep(5)

        stopped, _ = plc.write(var=addresses["joint_tracking_button"], value=1)
        logger.info(f"Joint tracking stopped: write_ok={stopped}")