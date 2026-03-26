USING Esab.Motion.Mock;
USING Esab.Utils.Assets;
USING Esab.Hmi.Modules;
USING Esab.Utils.Timer.Mock;
USING AxUnit;
USING System.FastMath;

NAMESPACE Esab.Motion.Test

    {TestFixture}
    CLASS WeldHeadManipulatorTests
        VAR PRIVATE
            _manipulator : WeldHeadManipulator;
            _runtimeParameters : WeldHeadManipulatorRuntimeParameters;
            _hardwareConfiguration : WeldHeadManipulatorHardwareConfiguration;

            _joystick : DiscreteJoystick;
            _joystickIo : DiscreteJoystickIo;
            _joystickTimer : OnDelayMock;

            _horizontalSlide : ToPosAxisMock;
            _verticalSlide : ToPosAxisMock;
            _assetsManager : AssetsManager;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            _joystick.Setup(REF(_joystickIo), _joystickTimer);
            _joystick.SetIdentifier(AssetIdentifier#P_Joystick_MotionJoystick);
            _assetsManager.RegisterAsset(REF(_joystick));

            _horizontalSlide.SetIdentifier(Esab.AssetIdentifier#HorizontalSlideAxis);
            _assetsManager.RegisterAsset(REF(_horizontalSlide));

            _verticalSlide.SetIdentifier(Esab.AssetIdentifier#VerticalSlideAxis);
            _assetsManager.RegisterAsset(REF(_verticalSlide));

            _manipulator.Setup(REF(_runtimeParameters), REF(_hardwareConfiguration), _assetsManager);
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            _horizontalSlide.MockReset();
            _verticalSlide.MockReset();
            _manipulator.Disable();
        END_METHOD

        {Test}
        METHOD PUBLIC EnableDisable
            _horizontalSlide.IsEnabledMock.Value := TRUE;
            _verticalSlide.IsEnabledMock.Value := TRUE;

            Assert.Equal(_assetsManager.RequestAssetHandle(NULL, Esab.AssetIdentifier#HorizontalSlideAxis) <> NULL, TRUE);
            Assert.Equal(_assetsManager.RequestAssetHandle(NULL, Esab.AssetIdentifier#VerticalSlideAxis) <> NULL, TRUE);

            Assert.Equal(_manipulator.Enable(), WeldHeadManipulatorErrorCode#NoError);

            Assert.Equal(_assetsManager.RequestAssetHandle(NULL, Esab.AssetIdentifier#HorizontalSlideAxis) = NULL, TRUE);
            Assert.Equal(_assetsManager.RequestAssetHandle(NULL, Esab.AssetIdentifier#VerticalSlideAxis) = NULL, TRUE);
            Assert.Equal(_manipulator.IsEnabled(), TRUE);

            _manipulator.Disable();

            Assert.Equal(_assetsManager.RequestAssetHandle(NULL, Esab.AssetIdentifier#HorizontalSlideAxis) <> NULL, TRUE);
            Assert.Equal(_assetsManager.RequestAssetHandle(NULL, Esab.AssetIdentifier#VerticalSlideAxis) <> NULL, TRUE);
            Assert.Equal(_manipulator.IsEnabled(), FALSE);

            Assert.Equal(_manipulator.Enable(), WeldHeadManipulatorErrorCode#NoError);

            Assert.Equal(_assetsManager.RequestAssetHandle(NULL, Esab.AssetIdentifier#HorizontalSlideAxis) = NULL, TRUE);
            Assert.Equal(_assetsManager.RequestAssetHandle(NULL, Esab.AssetIdentifier#VerticalSlideAxis) = NULL, TRUE);
            Assert.Equal(_manipulator.IsEnabled(), TRUE);

            _manipulator.Disable();

            Assert.Equal(_assetsManager.RequestAssetHandle(NULL, Esab.AssetIdentifier#HorizontalSlideAxis) <> NULL, TRUE);
            Assert.Equal(_assetsManager.RequestAssetHandle(NULL, Esab.AssetIdentifier#VerticalSlideAxis) <> NULL, TRUE);
            Assert.Equal(_manipulator.IsEnabled(), FALSE);
        END_METHOD

        {Test(speed := 10.0, x_act_pos := 0.0, x_pos := 11.0, z_act_pos := 0.0, z_pos := 7.0)}
        {Test(speed := 10.0, x_act_pos := 0.0, x_pos := 11.0, z_act_pos := 0.0, z_pos := -7.0)}
        {Test(speed := 10.0, x_act_pos := 0.0, x_pos := -11.0, z_act_pos := 0.0, z_pos := 7.0)}
        {Test(speed := 10.0, x_act_pos := 0.0, x_pos := -11.0, z_act_pos := 0.0, z_pos := -7.0)}
        {Test(speed := 10.0, x_act_pos := 20.0, x_pos := 25.0, z_act_pos := 20.0, z_pos := 25.0)}
        {Test(speed := 10.0, x_act_pos := 20.0, x_pos := 25.0, z_act_pos := 20.0, z_pos := 15.0)}
        {Test(speed := 10.0, x_act_pos := 20.0, x_pos := 15.0, z_act_pos := 20.0, z_pos := 25.0)}
        {Test(speed := 10.0, x_act_pos := 20.0, x_pos := 15.0, z_act_pos := 20.0, z_pos := 15.0)}
        METHOD PUBLIC Positioning
            VAR_INPUT
                speed : LREAL;
                x_act_pos : LREAL;
                x_pos : LREAL;
                z_act_pos : LREAL;
                z_pos : LREAL;
            END_VAR

            VAR_TEMP
                position : ARRAY [0..1] OF LREAL;
                distance : ARRAY [0..1] OF LREAL;
                x_vel : LREAL;
                z_vel : LREAL;
            END_VAR

            position[0] := x_pos;
            position[1] := z_pos;

            distance[0] := Abs(x_pos - x_act_pos);
            distance[1] := Abs(z_pos - z_act_pos);

            _horizontalSlide.ActualLinearPositionMock.Value := x_act_pos;
            _verticalSlide.ActualLinearPositionMock.Value := z_act_pos;

            _manipulator.Enable();

            Assert.Equal(_horizontalSlide.ExecutePositioningCommandMock.GetCallCount(), UINT#1);
            Assert.Equal(_verticalSlide.ExecutePositioningCommandMock.GetCallCount(), UINT#1);

            // Assert that we issued a command to move the axis to their current position.
            Assert.Equal(_horizontalSlide.ExecutePositioningCommandMock.Command.CommandType, AxisCommandType#Absolute);
            Assert.Equal(_horizontalSlide.ExecutePositioningCommandMock.Command.Position, x_act_pos);

            Assert.Equal(_verticalSlide.ExecutePositioningCommandMock.Command.CommandType, AxisCommandType#Absolute);
            Assert.Equal(_verticalSlide.ExecutePositioningCommandMock.Command.Position, z_act_pos);

            // Set new target positions
            _manipulator.Move(position, speed);

            Assert.Equal(_horizontalSlide.ExecutePositioningCommandMock.GetCallCount(), UINT#2);
            Assert.Equal(_verticalSlide.ExecutePositioningCommandMock.GetCallCount(), UINT#2);

            Assert.Equal(_horizontalSlide.ExecutePositioningCommandMock.Command.CommandType, AxisCommandType#Absolute);
            Assert.Equal(_horizontalSlide.ExecutePositioningCommandMock.Command.Position, x_pos);

            Assert.Equal(_verticalSlide.ExecutePositioningCommandMock.Command.CommandType, AxisCommandType#Absolute);
            Assert.Equal(_verticalSlide.ExecutePositioningCommandMock.Command.Position, z_pos);

            // Assert that the axis will arrive at target position at the same time
            x_vel := _horizontalSlide.ExecutePositioningCommandMock.Command.Velocity;
            z_vel := _verticalSlide.ExecutePositioningCommandMock.Command.Velocity;
            Assert.InRange(distance[0]/x_vel, distance[1]/z_vel, 0.1); // It is acceptable if they are calculated to arrive within 0.1s of each other.
        END_METHOD

        {Test(speed := 10.0, x_act_pos := 0.0, x_pos := 11.0)}
        METHOD PUBLIC PositionHorizontalOnly
            VAR_INPUT
                speed : LREAL;
                x_act_pos : LREAL;
                x_pos : LREAL;
            END_VAR

            VAR_TEMP
                position : ARRAY [0..1] OF LREAL;
                distance : ARRAY [0..1] OF LREAL;
                x_vel : LREAL;
                z_act_pos : LREAL := 10.0;
            END_VAR

            position[0] := x_pos;
            position[1] := z_act_pos;

            distance[0] := Abs(x_pos - x_act_pos);
            distance[1] := 0.0;

            _horizontalSlide.ActualLinearPositionMock.Value := x_act_pos;
            _verticalSlide.ActualLinearPositionMock.Value := z_act_pos;

            _manipulator.Enable();

            _manipulator.Move(position, speed);

            Assert.Equal(_horizontalSlide.ExecutePositioningCommandMock.GetCallCount(), UINT#2);
            Assert.Equal(_verticalSlide.ExecutePositioningCommandMock.GetCallCount(), UINT#2);

            Assert.Equal(_horizontalSlide.ExecutePositioningCommandMock.Command.CommandType, AxisCommandType#Absolute);
            Assert.Equal(_horizontalSlide.ExecutePositioningCommandMock.Command.Position, x_pos);
            Assert.Equal(_horizontalSlide.ExecutePositioningCommandMock.Command.Velocity, speed);

            Assert.Equal(_verticalSlide.ExecutePositioningCommandMock.Command.CommandType, AxisCommandType#Absolute);
            Assert.Equal(_verticalSlide.ExecutePositioningCommandMock.Command.Position, z_act_pos);
        END_METHOD

        {Test(x_pos := 11.0, z_pos := 7.0, x_speed := 10.0, z_speed := 5.0)}
        METHOD PUBLIC MoveNonInterpolated
            VAR_INPUT
                x_speed : LREAL;
                z_speed : LREAL;
                x_pos : LREAL;
                z_pos : LREAL;
            END_VAR

            VAR_TEMP
                position : ARRAY [0..1] OF LREAL;
                speed : ARRAY [0..1] OF LREAL;
            END_VAR

            position[0] := x_pos;
            position[1] := z_pos;

            speed[0] := x_speed;
            speed[1] := z_speed;

            _horizontalSlide.ActualLinearPositionMock.Value := 0.0;
            _verticalSlide.ActualLinearPositionMock.Value := 0.0;

            _manipulator.Enable();
            _manipulator.SetControlMode(WeldHeadManipulatorControlMode#MoveToPosition);

            Assert.Equal(_horizontalSlide.ExecutePositioningCommandMock.GetCallCount(), UINT#1);
            Assert.Equal(_verticalSlide.ExecutePositioningCommandMock.GetCallCount(), UINT#1);

            // Assert that we issued a command to move the axis to their current position.
            Assert.Equal(_horizontalSlide.ExecutePositioningCommandMock.Command.CommandType, AxisCommandType#Absolute);
            Assert.Equal(_horizontalSlide.ExecutePositioningCommandMock.Command.Position, 0.0);

            Assert.Equal(_verticalSlide.ExecutePositioningCommandMock.Command.CommandType, AxisCommandType#Absolute);
            Assert.Equal(_verticalSlide.ExecutePositioningCommandMock.Command.Position, 0.0);

            // Set new target positions
            _manipulator.Move(position, speed);

            Assert.Equal(_horizontalSlide.ExecutePositioningCommandMock.GetCallCount(), UINT#2);
            Assert.Equal(_verticalSlide.ExecutePositioningCommandMock.GetCallCount(), UINT#2);

            Assert.Equal(_horizontalSlide.ExecutePositioningCommandMock.Command.CommandType, AxisCommandType#Absolute);
            Assert.Equal(_horizontalSlide.ExecutePositioningCommandMock.Command.Position, x_pos);
            Assert.Equal(_horizontalSlide.ExecutePositioningCommandMock.Command.Velocity, x_speed);

            Assert.Equal(_verticalSlide.ExecutePositioningCommandMock.Command.CommandType, AxisCommandType#Absolute);
            Assert.Equal(_verticalSlide.ExecutePositioningCommandMock.Command.Position, z_pos);
            Assert.Equal(_verticalSlide.ExecutePositioningCommandMock.Command.Velocity, z_speed);
        END_METHOD

        METHOD PRIVATE Execute
            _assetsManager.Execute();
            _manipulator.Execute();
        END_METHOD

        {Test(position := 1)}
        {Test(position := 2)}
        {Test(position := 3)}
        {Test(position := 4)}
        METHOD PUBLIC JoystickJogOfWeldHeadManipulator
            VAR_INPUT
                position : INT;
            END_VAR

            VAR_TEMP
                asset : REF_TO Asset;
                joystickPosition : JoystickPosition;
            END_VAR

            _manipulator.Execute();
            _manipulator.SetControlMode(WeldHeadManipulatorControlMode#JoystickJog);
            _manipulator.Enable();

            joystickPosition := position;

            // Trigger long hold callback
            CASE joystickPosition OF
                JoystickPosition#Up:
                    _joystickIo.Up.Read(TRUE);
                JoystickPosition#Down:
                    _joystickIo.Down.Read(TRUE);
                JoystickPosition#Triangle:
                    _joystickIo.Triangle.Read(TRUE);
                JoystickPosition#Square:
                    _joystickIo.Square.Read(TRUE);
            END_CASE;

            THIS.Execute();
            CASE joystickPosition OF
                JoystickPosition#Up:
                    Assert.Equal(_verticalSlide.JogPositiveMock.GetCallCount(), UINT#1);
                JoystickPosition#Down:
                    Assert.Equal(_verticalSlide.JogNegativeMock.GetCallCount(), UINT#1);
                JoystickPosition#Triangle:
                    Assert.Equal(_horizontalSlide.JogNegativeMock.GetCallCount(), UINT#1);
                JoystickPosition#Square:
                    Assert.Equal(_horizontalSlide.JogPositiveMock.GetCallCount(), UINT#1);
            END_CASE;

            THIS.Execute();
            THIS.Execute();
            THIS.Execute();
            THIS.Execute();

            CASE joystickPosition OF
                JoystickPosition#Up:
                    Assert.Equal(_verticalSlide.JogPositiveMock.GetCallCount(), UINT#5);
                JoystickPosition#Down:
                    Assert.Equal(_verticalSlide.JogNegativeMock.GetCallCount(), UINT#5);
                JoystickPosition#Triangle:
                    Assert.Equal(_horizontalSlide.JogNegativeMock.GetCallCount(), UINT#5);
                JoystickPosition#Square:
                    Assert.Equal(_horizontalSlide.JogPositiveMock.GetCallCount(), UINT#5);
            END_CASE;

            CASE joystickPosition OF
                JoystickPosition#Up:
                    _joystickIo.Up.Read(FALSE);
                JoystickPosition#Down:
                    _joystickIo.Down.Read(FALSE);
                JoystickPosition#Triangle:
                    _joystickIo.Triangle.Read(FALSE);
                JoystickPosition#Square:
                    _joystickIo.Square.Read(FALSE);
            END_CASE;
            _joystickTimer.MockReset();

            THIS.Execute();

            CASE joystickPosition OF
                JoystickPosition#Up:
                    Assert.Equal(_verticalSlide.JogPositiveMock.GetCallCount(), UINT#5);
                JoystickPosition#Down:
                    Assert.Equal(_verticalSlide.JogNegativeMock.GetCallCount(), UINT#5);
                JoystickPosition#Triangle:
                    Assert.Equal(_horizontalSlide.JogNegativeMock.GetCallCount(), UINT#5);
                JoystickPosition#Square:
                    Assert.Equal(_horizontalSlide.JogPositiveMock.GetCallCount(), UINT#5);
            END_CASE;

            _manipulator.SetControlMode(WeldHeadManipulatorControlMode#MoveToPosition);
        END_METHOD

    END_CLASS
END_NAMESPACE