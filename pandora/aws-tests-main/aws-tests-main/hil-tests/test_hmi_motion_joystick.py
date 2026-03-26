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


class TestHmiMotionJoystick:
    """Test suite for slide cross jogging with the joystick"""

    @pytest.mark.skip(reason="Not valid for the current release")
    @pytest.mark.plc_only
    @pytest.mark.usefixtures("enable_horizontal_slide_axis")
    @pytest.mark.usefixtures("disable_high_speed")
    def test_horizontal_jog_triangle(self, setup_plc, addresses_lp3):
        plc = setup_plc

        jog_speed = 10.0
        plc.write(var=addresses_lp3.Hmi.Inputs.HorizontalSlide.Parameters.JogSpeed, value=jog_speed)
        plc.write(var=addresses_lp3.Hmi.Inputs.HorizontalSlide.Parameters.JogHighSpeed, value=jog_speed*2)

        logger.info("Jogging horizontal slide axis positive")
        prevpos, _ = plc.read(var=addresses_lp3.Hmi.Outputs.HorizontalSlide.Status.Position)
        plc.write(var=addresses_lp3.Io.Inputs.DI_MotionJoystick_Triangle, value=True)
        time.sleep(1)
        vel, _ = plc.read(var=addresses_lp3.Hmi.Outputs.HorizontalSlide.Status.Velocity)
        pos, _ = plc.read(var=addresses_lp3.Hmi.Outputs.HorizontalSlide.Status.Position)
        assert pos < prevpos
        assert -vel - jog_speed == pytest.approx(0.0)

        time.sleep(1)
        plc.write(var=addresses_lp3.Io.Inputs.DI_MotionJoystick_Triangle, value=False)
        time.sleep(0.5)
        vel, _ = plc.read(var=addresses_lp3.Hmi.Outputs.HorizontalSlide.Status.Velocity)
        assert vel == pytest.approx(0.0)


    @pytest.mark.skip(reason="Not valid for the current release")
    @pytest.mark.plc_only
    @pytest.mark.usefixtures("enable_horizontal_slide_axis")
    @pytest.mark.usefixtures("disable_high_speed")
    def test_horizontal_jog_square(self, setup_plc, addresses_lp3):
        plc = setup_plc

        jog_speed = 10.0
        plc.write(var=addresses_lp3.Hmi.Inputs.HorizontalSlide.Parameters.JogSpeed, value=jog_speed)
        plc.write(var=addresses_lp3.Hmi.Inputs.HorizontalSlide.Parameters.JogHighSpeed, value=jog_speed*2)

        logger.info("Jogging horizontal slide axis positive")
        prevpos, _ = plc.read(var=addresses_lp3.Hmi.Outputs.HorizontalSlide.Status.Position)
        plc.write(var=addresses_lp3.Io.Inputs.DI_MotionJoystick_Square, value=True)
        time.sleep(1)
        vel, _ = plc.read(var=addresses_lp3.Hmi.Outputs.HorizontalSlide.Status.Velocity)
        pos, _ = plc.read(var=addresses_lp3.Hmi.Outputs.HorizontalSlide.Status.Position)
        assert pos > prevpos
        assert vel - jog_speed == pytest.approx(0.0)

        time.sleep(1)
        plc.write(var=addresses_lp3.Io.Inputs.DI_MotionJoystick_Square, value=False)
        time.sleep(0.5)
        vel, _ = plc.read(var=addresses_lp3.Hmi.Outputs.HorizontalSlide.Status.Velocity)
        assert vel == pytest.approx(0.0)



    @pytest.mark.skip(reason="Not valid for the current release")
    @pytest.mark.plc_only
    @pytest.mark.usefixtures("enable_horizontal_slide_axis")
    @pytest.mark.usefixtures("enable_high_speed")
    def test_horizontal_jog_triangle_high_speed(self, setup_plc, addresses_lp3):
        plc = setup_plc

        jog_speed = 10.0
        plc.write(var=addresses_lp3.Hmi.Inputs.HorizontalSlide.Parameters.JogSpeed, value=jog_speed)
        plc.write(var=addresses_lp3.Hmi.Inputs.HorizontalSlide.Parameters.JogHighSpeed, value=jog_speed*2)

        logger.info("Setting high speed")
        prevpos, _ = plc.read(var=addresses_lp3.Hmi.Outputs.HorizontalSlide.Status.Position)
        plc.write(var=addresses_lp3.Io.Inputs.DI_MotionJoystick_Triangle, value=True)
        time.sleep(1)
        vel, _ = plc.read(var=addresses_lp3.Hmi.Outputs.HorizontalSlide.Status.Velocity)
        pos, _ = plc.read(var=addresses_lp3.Hmi.Outputs.HorizontalSlide.Status.Position)
        assert pos < prevpos
        assert -vel - jog_speed*2 == pytest.approx(0.0)

        time.sleep(1)
        plc.write(var=addresses_lp3.Io.Inputs.DI_MotionJoystick_Triangle, value=False)
        time.sleep(0.5)
        vel, _ = plc.read(var=addresses_lp3.Hmi.Outputs.HorizontalSlide.Status.Velocity)
        assert vel == pytest.approx(0.0)



    @pytest.mark.skip(reason="Not valid for the current release")
    @pytest.mark.plc_only
    @pytest.mark.usefixtures("enable_horizontal_slide_axis")
    @pytest.mark.usefixtures("enable_high_speed")
    def test_horizontal_jog_square_high_speed(self, setup_plc, addresses_lp3):
        plc = setup_plc

        jog_speed = 10.0
        plc.write(var=addresses_lp3.Hmi.Inputs.HorizontalSlide.Parameters.JogSpeed, value=jog_speed)
        plc.write(var=addresses_lp3.Hmi.Inputs.HorizontalSlide.Parameters.JogHighSpeed, value=jog_speed*2)

        logger.info("Setting high speed")
        prevpos, _ = plc.read(var=addresses_lp3.Hmi.Outputs.HorizontalSlide.Status.Position)
        plc.write(var=addresses_lp3.Io.Inputs.DI_MotionJoystick_Square, value=True)
        time.sleep(1)
        vel, _ = plc.read(var=addresses_lp3.Hmi.Outputs.HorizontalSlide.Status.Velocity)
        pos, _ = plc.read(var=addresses_lp3.Hmi.Outputs.HorizontalSlide.Status.Position)
        assert pos > prevpos
        assert vel - jog_speed*2 == pytest.approx(0.0)

        time.sleep(1)
        plc.write(var=addresses_lp3.Io.Inputs.DI_MotionJoystick_Square, value=False)
        time.sleep(0.5)
        vel, _ = plc.read(var=addresses_lp3.Hmi.Outputs.HorizontalSlide.Status.Velocity)
        assert vel == pytest.approx(0.0)


    @pytest.mark.skip(reason="Not valid for the current release")
    @pytest.mark.plc_only
    @pytest.mark.usefixtures("enable_vertical_slide_axis")
    @pytest.mark.usefixtures("disable_high_speed")
    def test_vertical_jog_down(self, setup_plc, addresses_lp3):
        plc = setup_plc

        jog_speed = 10.0
        plc.write(var=addresses_lp3.Hmi.Inputs.VerticalSlide.Parameters.JogSpeed, value=jog_speed)
        plc.write(var=addresses_lp3.Hmi.Inputs.VerticalSlide.Parameters.JogHighSpeed, value=jog_speed*2)

        logger.info("Jogging vertical slide axis positive")
        prevpos, _ = plc.read(var=addresses_lp3.Hmi.Outputs.VerticalSlide.Status.Position)
        plc.write(var=addresses_lp3.Io.Inputs.DI_MotionJoystick_Down, value=True)
        time.sleep(1)
        vel, _ = plc.read(var=addresses_lp3.Hmi.Outputs.VerticalSlide.Status.Velocity)
        pos, _ = plc.read(var=addresses_lp3.Hmi.Outputs.VerticalSlide.Status.Position)
        assert pos < prevpos
        assert vel - jog_speed == pytest.approx(0.0)

        time.sleep(1)
        plc.write(var=addresses_lp3.Io.Inputs.DI_MotionJoystick_Down, value=False)
        time.sleep(0.5)
        vel, _ = plc.read(var=addresses_lp3.Hmi.Outputs.VerticalSlide.Status.Velocity)
        assert vel == pytest.approx(0.0)


    @pytest.mark.skip(reason="Not valid for the current release")
    @pytest.mark.plc_only
    @pytest.mark.usefixtures("enable_vertical_slide_axis")
    @pytest.mark.usefixtures("disable_high_speed")
    def test_vertical_jog_up(self, setup_plc, addresses_lp3):
        plc = setup_plc

        jog_speed = 10.0
        plc.write(var=addresses_lp3.Hmi.Inputs.VerticalSlide.Parameters.JogSpeed, value=jog_speed)
        plc.write(var=addresses_lp3.Hmi.Inputs.VerticalSlide.Parameters.JogHighSpeed, value=jog_speed*2)

        logger.info("Jogging vertical slide axis positive")
        prevpos, _ = plc.read(var=addresses_lp3.Hmi.Outputs.VerticalSlide.Status.Position)
        plc.write(var=addresses_lp3.Io.Inputs.DI_MotionJoystick_Up, value=True)
        time.sleep(1)
        vel, _ = plc.read(var=addresses_lp3.Hmi.Outputs.VerticalSlide.Status.Velocity)
        pos, _ = plc.read(var=addresses_lp3.Hmi.Outputs.VerticalSlide.Status.Position)
        assert pos > prevpos
        assert vel - jog_speed == pytest.approx(0.0)

        time.sleep(1)
        plc.write(var=addresses_lp3.Io.Inputs.DI_MotionJoystick_Up, value=False)
        time.sleep(0.5)
        vel, _ = plc.read(var=addresses_lp3.Hmi.Outputs.VerticalSlide.Status.Velocity)
        assert vel == pytest.approx(0.0)



    @pytest.mark.skip(reason="Not valid for the current release")
    @pytest.mark.plc_only
    @pytest.mark.usefixtures("enable_vertical_slide_axis")
    @pytest.mark.usefixtures("enable_high_speed")
    def test_vertical_jog_down_high_speed(self, setup_plc, addresses_lp3):
        plc = setup_plc

        jog_speed = 10.0
        plc.write(var=addresses_lp3.Hmi.Inputs.VerticalSlide.Parameters.JogSpeed, value=jog_speed)
        plc.write(var=addresses_lp3.Hmi.Inputs.VerticalSlide.Parameters.JogHighSpeed, value=jog_speed*2)

        logger.info("Setting high speed")
        prevpos, _ = plc.read(var=addresses_lp3.Hmi.Outputs.VerticalSlide.Status.Position)
        plc.write(var=addresses_lp3.Io.Inputs.DI_MotionJoystick_Down, value=True)
        time.sleep(1)
        vel, _ = plc.read(var=addresses_lp3.Hmi.Outputs.VerticalSlide.Status.Velocity)
        assert vel - jog_speed*2 == pytest.approx(0.0)

        time.sleep(1)
        plc.write(var=addresses_lp3.Io.Inputs.DI_MotionJoystick_Down, value=False)
        time.sleep(0.5)
        vel, _ = plc.read(var=addresses_lp3.Hmi.Outputs.VerticalSlide.Status.Velocity)
        pos, _ = plc.read(var=addresses_lp3.Hmi.Outputs.VerticalSlide.Status.Position)
        assert pos < prevpos
        assert vel == pytest.approx(0.0)



    @pytest.mark.skip(reason="Not valid for the current release")
    @pytest.mark.plc_only
    @pytest.mark.usefixtures("enable_vertical_slide_axis")
    @pytest.mark.usefixtures("enable_high_speed")
    def test_vertical_jog_up_high_speed(self, setup_plc, addresses_lp3):
        plc = setup_plc

        jog_speed = 10.0
        plc.write(var=addresses_lp3.Hmi.Inputs.VerticalSlide.Parameters.JogSpeed, value=jog_speed)
        plc.write(var=addresses_lp3.Hmi.Inputs.VerticalSlide.Parameters.JogHighSpeed, value=jog_speed*2)

        logger.info("Setting high speed")
        prevpos, _ = plc.read(var=addresses_lp3.Hmi.Outputs.VerticalSlide.Status.Position)
        plc.write(var=addresses_lp3.Io.Inputs.DI_MotionJoystick_Up, value=True)
        time.sleep(1)
        vel, _ = plc.read(var=addresses_lp3.Hmi.Outputs.VerticalSlide.Status.Velocity)
        assert vel - jog_speed*2 == pytest.approx(0.0)

        time.sleep(1)
        plc.write(var=addresses_lp3.Io.Inputs.DI_MotionJoystick_Up, value=False)
        time.sleep(0.5)
        vel, _ = plc.read(var=addresses_lp3.Hmi.Outputs.VerticalSlide.Status.Velocity)
        pos, _ = plc.read(var=addresses_lp3.Hmi.Outputs.VerticalSlide.Status.Position)
        assert pos > prevpos
        assert vel == pytest.approx(0.0)


