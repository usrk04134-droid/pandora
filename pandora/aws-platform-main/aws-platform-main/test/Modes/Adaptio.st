USING Esab.Utils.Heartbeat.Mock;
USING Esab.Motion.Mock;
USING Esab.Hmi.Modules.Mock;
USING Esab.Utils.Assets;
USING Esab.Utils.Alarming.Mock;
USING Esab.Utils.Timer.Mock;
USING Esab.Hmi.Modules.Mock;
USING Esab.WeldSystem.Mock;
USING Esab.Modes.Mock;
USING Esab.Motion;

USING AxUnit;
USING System.FastMath;

NAMESPACE Esab.Modes.Test

{TestFixture}
CLASS AdaptioTests
    VAR PRIVATE
        _adaptio : Adaptio;
        _io : AdaptioIo;
        _defaultIo : AdaptioIo;
        _runtimeParameters : AdaptioRuntimeParameters;
        _assetsManager : AssetsManager;
        _weldSequence : AdaptioWeldSequenceMock;
        _heartbeat : HeartbeatMock;
        _requestTimer : OnDelayMock;
        _joystickClickTimer : OnDelayMock;
        _setupAlarm : AlarmMock;

        _globalState : GlobalState;
        _startButton : PushButtonMock;
        _stopButton : PushButtonMock;
        _pJoystick : JoystickMock;
        _cJoystick : JoystickMock;
        _weldHeadManipulator : WeldHeadManipulatorMock;
        _horizontalSlideAxis : ToPosAxisMock;
        _verticalSlideAxis : ToPosAxisMock;
        _rollerBed : AnalogAxisMock;
        _weldSystemOrchestrator : WeldSystemOrchestratorMock;
    END_VAR

    {FixtureSetup}
    METHOD PUBLIC TestFixtureSetup
        _globalState.SetIdentifier(AssetIdentifier#GlobalState);
        _assetsManager.RegisterAsset(REF(_globalState));

        _startButton.SetIdentifier(AssetIdentifier#P_PushButton_Start);
        _assetsManager.RegisterAsset(REF(_startButton));

        _stopButton.SetIdentifier(AssetIdentifier#P_PushButton_Stop);
        _assetsManager.RegisterAsset(REF(_stopButton));

        _pJoystick.SetIdentifier(AssetIdentifier#P_Joystick_MotionJoystick);
        _assetsManager.RegisterAsset(REF(_pJoystick));

        _cJoystick.SetIdentifier(AssetIdentifier#C_Joystick_MotionJoystick);
        _assetsManager.RegisterAsset(REF(_cJoystick));

        _weldHeadManipulator.SetIdentifier(AssetIdentifier#WeldHeadManipulator);
        _assetsManager.RegisterAsset(REF(_weldHeadManipulator));

        _horizontalSlideAxis.SetIdentifier(AssetIdentifier#HorizontalSlideAxis);
        _assetsManager.RegisterAsset(REF(_horizontalSlideAxis));

        _verticalSlideAxis.SetIdentifier(AssetIdentifier#VerticalSlideAxis);
        _assetsManager.RegisterAsset(REF(_verticalSlideAxis));

        _rollerBed.SetIdentifier(AssetIdentifier#RollerBed);
        _assetsManager.RegisterAsset(REF(_rollerBed));

        _weldSystemOrchestrator.SetIdentifier(AssetIdentifier#WeldSystemOrchestrator);
        _assetsManager.RegisterAsset(REF(_weldSystemOrchestrator));

        _globalState.Setup(_assetsManager);

        _adaptio.Setup(REF(_io),
                       REF(_runtimeParameters),
                       _assetsManager,
                       _weldSequence,
                       _heartbeat,
                       _requestTimer,
                       _joystickClickTimer,
                       _setupAlarm);
    END_METHOD

    {TestSetup}
    METHOD PUBLIC TestSetup
        _io := _defaultIo;
        _requestTimer.MockReset();
        _joystickClickTimer.MockReset();
        _heartbeat.MockReset();
        _setupAlarm.MockReset();
        _startButton.MockReset();
        _stopButton.MockReset();
        _pJoystick.MockReset();
        _cJoystick.MockReset();
        _weldHeadManipulator.MockReset();
        _horizontalSlideAxis.MockReset();
        _verticalSlideAxis.MockReset();
        _rollerBed.MockReset();
        _weldSystemOrchestrator.MockReset();

        _globalState.SetMode(AwsPlatformMode#Adaptio);

        THIS.Execute();
        THIS.Execute();
        THIS.Execute();
    END_METHOD

    METHOD PRIVATE Execute
        _assetsManager.Execute();
        _adaptio.Execute();
    END_METHOD

    {Test}
    METHOD PUBLIC StartRequest
        VAR_TEMP
            value : BOOL := FALSE;
        END_VAR

        _adaptio.OnPushButtonReleased(Esab.AssetIdentifier#P_PushButton_Start);
        THIS.Execute();
        THIS.Execute();
        _io.ToAdaptio.SystemControl.StartRequest.Write(value);
        Assert.Equal(value, TRUE);
        _requestTimer.ExpiredMock.Value := TRUE;
        THIS.Execute();
        _io.ToAdaptio.SystemControl.StartRequest.Write(value);
        Assert.Equal(value, FALSE);
    END_METHOD

    {Test}
    METHOD PUBLIC StopRequest
        VAR_TEMP
            value : BOOL := FALSE;
        END_VAR

        _adaptio.OnPushButtonReleased(Esab.AssetIdentifier#P_PushButton_Stop);
        THIS.Execute();
        THIS.Execute();
        _io.ToAdaptio.SystemControl.StopRequest.Write(value);
        Assert.Equal(value, TRUE);
        _requestTimer.ExpiredMock.Value := TRUE;
        THIS.Execute();
        _io.ToAdaptio.SystemControl.StopRequest.Write(value);
        Assert.Equal(value, FALSE);
    END_METHOD

    {Test}
    METHOD PUBLIC QuickStopRequest
        VAR_TEMP
            value : BOOL := FALSE;
        END_VAR

        _adaptio.OnPushButtonReleased(Esab.AssetIdentifier#P_PushButton_Stop);
        THIS.Execute();
        THIS.Execute();
        _io.ToAdaptio.SystemControl.StopRequest.Write(value);
        Assert.Equal(value, TRUE);

        _adaptio.OnPushButtonReleased(Esab.AssetIdentifier#P_PushButton_Stop);
        THIS.Execute();
        THIS.Execute();
        _io.ToAdaptio.SystemControl.StopRequest.Write(value);
        Assert.Equal(value, FALSE);
        _io.ToAdaptio.SystemControl.QuickStopRequest.Write(value);
        Assert.Equal(value, TRUE);

        _requestTimer.ExpiredMock.Value := TRUE;
        THIS.Execute();
        _io.ToAdaptio.SystemControl.QuickStopRequest.Write(value);
        Assert.Equal(value, FALSE);
    END_METHOD

    {Test}
    METHOD PUBLIC InterpolatedMotion
        VAR_TEMP
            speed : REAL := REAL#5.0;
            x_pos : REAL := REAL#15.0;
            y_pos : REAL := REAL#7.5;
        END_VAR

        _io.FromAdaptio.WeldHeadManipulator.InterpolatedSpeed.Read(speed);
        _io.FromAdaptio.WeldHeadManipulator.XPosition.Read(x_pos);
        _io.FromAdaptio.WeldHeadManipulator.YPosition.Read(y_pos);

        _horizontalSlideAxis.ActualLinearPositionMock.Value := 0.0;
        _verticalSlideAxis.ActualLinearPositionMock.Value := 0.0;

        _io.FromAdaptio.WeldHeadManipulator.EnableMotion.Read(FALSE);
        _io.FromAdaptio.WeldHeadManipulator.EnableMotion.Read(TRUE);
        _io.FromAdaptio.WeldHeadManipulator.Interpolate.Read(TRUE);
        _io.FromAdaptio.WeldHeadManipulator.InterpolatedSpeed.Read(REAL#0.0);
        _io.FromAdaptio.WeldHeadManipulator.InterpolatedSpeed.Read(REAL#0.0);
        _io.FromAdaptio.WeldHeadManipulator.XPosition.Read(REAL#0.0);
        _io.FromAdaptio.WeldHeadManipulator.XPosition.Read(REAL#0.0);
        _io.FromAdaptio.WeldHeadManipulator.YPosition.Read(REAL#0.0);
        _io.FromAdaptio.WeldHeadManipulator.YPosition.Read(REAL#0.0);

        THIS.Execute();

        _io.FromAdaptio.WeldHeadManipulator.EnableMotion.Read(TRUE);
        Assert.Equal(_weldHeadManipulator.EnableMock.GetCallCount(), UINT#1);

        THIS.Execute();

        _weldHeadManipulator.IsEnabledMock.Value := TRUE;

        _io.FromAdaptio.WeldHeadManipulator.InterpolatedSpeed.Read(REAL#0.0);
        _io.FromAdaptio.WeldHeadManipulator.InterpolatedSpeed.Read(speed);
        _io.FromAdaptio.WeldHeadManipulator.XPosition.Read(REAL#0.0);
        _io.FromAdaptio.WeldHeadManipulator.XPosition.Read(x_pos);
        _io.FromAdaptio.WeldHeadManipulator.YPosition.Read(REAL#0.0);
        _io.FromAdaptio.WeldHeadManipulator.YPosition.Read(y_pos);

        THIS.Execute();

        Assert.Equal(_weldHeadManipulator.MoveInterpolatedMock.GetCallCount(), UINT#1);
        Assert.Equal(_weldHeadManipulator.MoveInterpolatedMock.Speed, speed);
        Assert.Equal(_weldHeadManipulator.MoveInterpolatedMock.Position[0], x_pos);
        Assert.Equal(_weldHeadManipulator.MoveInterpolatedMock.Position[1], y_pos);

        THIS.Execute();

        _io.FromAdaptio.WeldHeadManipulator.EnableMotion.Read(TRUE);
        _io.FromAdaptio.WeldHeadManipulator.EnableMotion.Read(FALSE);

        THIS.Execute();

        Assert.Equal(_weldHeadManipulator.DisableMock.GetCallCount(), UINT#1);
    END_METHOD

    {Test}
    METHOD PUBLIC NonInterpolatedMotion
        VAR_TEMP
            x_speed : REAL := REAL#5.0;
            y_speed : REAL := REAL#10.0;
            x_pos : REAL := REAL#15.0;
            y_pos : REAL := REAL#7.5;
        END_VAR

        _io.FromAdaptio.WeldHeadManipulator.XSpeed.Read(x_speed);
        _io.FromAdaptio.WeldHeadManipulator.YSpeed.Read(y_speed);
        _io.FromAdaptio.WeldHeadManipulator.XPosition.Read(x_pos);
        _io.FromAdaptio.WeldHeadManipulator.YPosition.Read(y_pos);

        _horizontalSlideAxis.ActualLinearPositionMock.Value := 0.0;
        _verticalSlideAxis.ActualLinearPositionMock.Value := 0.0;

        _io.FromAdaptio.WeldHeadManipulator.EnableMotion.Read(FALSE);
        _io.FromAdaptio.WeldHeadManipulator.EnableMotion.Read(TRUE);
        _io.FromAdaptio.WeldHeadManipulator.InterpolatedSpeed.Read(REAL#0.0);
        _io.FromAdaptio.WeldHeadManipulator.InterpolatedSpeed.Read(REAL#0.0);
        _io.FromAdaptio.WeldHeadManipulator.XPosition.Read(REAL#0.0);
        _io.FromAdaptio.WeldHeadManipulator.XPosition.Read(REAL#0.0);
        _io.FromAdaptio.WeldHeadManipulator.YPosition.Read(REAL#0.0);
        _io.FromAdaptio.WeldHeadManipulator.YPosition.Read(REAL#0.0);

        THIS.Execute();

        _io.FromAdaptio.WeldHeadManipulator.EnableMotion.Read(TRUE);
        Assert.Equal(_weldHeadManipulator.EnableMock.GetCallCount(), UINT#1);

        THIS.Execute();

        _weldHeadManipulator.IsEnabledMock.Value := TRUE;

        _io.FromAdaptio.WeldHeadManipulator.XSpeed.Read(REAL#0.0);
        _io.FromAdaptio.WeldHeadManipulator.XSpeed.Read(x_speed);
        _io.FromAdaptio.WeldHeadManipulator.YSpeed.Read(REAL#0.0);
        _io.FromAdaptio.WeldHeadManipulator.YSpeed.Read(y_speed);
        _io.FromAdaptio.WeldHeadManipulator.XPosition.Read(REAL#0.0);
        _io.FromAdaptio.WeldHeadManipulator.XPosition.Read(x_pos);
        _io.FromAdaptio.WeldHeadManipulator.YPosition.Read(REAL#0.0);
        _io.FromAdaptio.WeldHeadManipulator.YPosition.Read(y_pos);

        THIS.Execute();

        Assert.Equal(_weldHeadManipulator.MoveMock.GetCallCount(), UINT#1);
        Assert.Equal(_weldHeadManipulator.MoveMock.Speed[0], x_speed);
        Assert.Equal(_weldHeadManipulator.MoveMock.Speed[1], y_speed);
        Assert.Equal(_weldHeadManipulator.MoveMock.Position[0], x_pos);
        Assert.Equal(_weldHeadManipulator.MoveMock.Position[1], y_pos);

        THIS.Execute();

        _io.FromAdaptio.WeldHeadManipulator.EnableMotion.Read(TRUE);
        _io.FromAdaptio.WeldHeadManipulator.EnableMotion.Read(FALSE);

        THIS.Execute();

        Assert.Equal(_weldHeadManipulator.DisableMock.GetCallCount(), UINT#1);
    END_METHOD

    {Test}
    METHOD PUBLIC WeldSequenceStart
        _io.FromAdaptio.WeldControl.Start.Read(FALSE);
        _io.FromAdaptio.WeldControl.Start.Read(TRUE);

        _adaptio.Execute();

        Assert.Equal(_weldSequence.StartMock.GetCallCount(), UINT#1);
    END_METHOD

    {Test}
    METHOD PUBLIC WeldSequenceStop
        _io.FromAdaptio.WeldControl.Stop.Read(FALSE);
        _io.FromAdaptio.WeldControl.Stop.Read(TRUE);

        _adaptio.Execute();

        Assert.Equal(_weldSequence.StopMock.GetCallCount(), UINT#1);
    END_METHOD

    {Test}
    METHOD PUBLIC WeldSequenceQuickStop
        _io.FromAdaptio.WeldControl.QuickStop.Read(FALSE);
        _io.FromAdaptio.WeldControl.QuickStop.Read(TRUE);

        _adaptio.Execute();

        Assert.Equal(_weldSequence.QuickStopMock.GetCallCount(), UINT#1);
    END_METHOD

    {Test}
    METHOD PUBLIC WeldAxisEnable
        _io.FromAdaptio.WeldAxis.EnableMotion.Read(FALSE);
        _io.FromAdaptio.WeldAxis.EnableMotion.Read(TRUE);

        _adaptio.Execute();

        Assert.Greater(_rollerBed.PowerOnMock.GetCallCount(), UINT#0);
    END_METHOD

    {Test}
    METHOD PUBLIC WeldAxisDisable
        _io.FromAdaptio.WeldAxis.EnableMotion.Read(TRUE);
        _io.FromAdaptio.WeldAxis.EnableMotion.Read(FALSE);

        _adaptio.Execute();

        Assert.Greater(_rollerBed.PowerOffMock.GetCallCount(), UINT#0);
    END_METHOD

    {Test}
    METHOD PUBLIC WeldAxisHoming
        _rollerBed.IsEnabledMock.Value := TRUE;

        _io.FromAdaptio.WeldAxis.InvalidateReference.Read(FALSE);
        _io.FromAdaptio.WeldAxis.InvalidateReference.Read(TRUE);

        _adaptio.Execute();

        Assert.Greater(_rollerBed.HaltMock.GetCallCount(), UINT#0);
        Assert.Greater(_rollerBed.InvalidateHomingMock.GetCallCount(), UINT#0);
    END_METHOD

    {Test}
    METHOD PUBLIC WeldAxisRadiusChanged
        _rollerBed.IsEnabledMock.Value := TRUE;

        _io.FromAdaptio.WeldAxis.Radius.Read(REAL#4242.0);

        _adaptio.Execute();

        Assert.Greater(_rollerBed.SetObjectRadiusMock.GetCallCount(), UINT#0);
        Assert.InRange(_rollerBed.SetObjectRadiusMock.Value, 4242.0, REAL#0.01);
    END_METHOD
    /*
    {Test}
    METHOD PUBLIC WeldAxisSpeedMode
        _rollerBed.IsEnabledMock.Value := TRUE;

        _io.FromAdaptio.WeldAxis.MovementMode.Read(DINT#1); // Velocity
        _io.FromAdaptio.WeldAxis.MovementType.Read(DINT#0); // Closest
        _io.FromAdaptio.WeldAxis.Position.Read(REAL#10.0);
        _io.FromAdaptio.WeldAxis.Velocity.Read(REAL#11.0);


        Assert.Equal(_rollerBed.ExecutePositioningCommandMock.Command.CommandType, AxisCommandType#Velocity);
        Assert.Equal(_rollerBed.ExecutePositioningCommandMock.Command.Position, REAL#10.0);
        Assert.Equal(_rollerBed.ExecutePositioningCommandMock.Command.Velocity, REAL#11.0);
    END_METHOD

    {Test}
    METHOD PUBLIC WeldAxisPositionMode
        _rollerBed.IsEnabledMock.Value := TRUE;

        _io.FromAdaptio.WeldAxis.MovementMode.Read(DINT#0); // Position
        _io.FromAdaptio.WeldAxis.MovementType.Read(DINT#0); // Closest
        _io.FromAdaptio.WeldAxis.Position.Read(REAL#10.0);
        _io.FromAdaptio.WeldAxis.Velocity.Read(REAL#11.0);


        Assert.Equal(_rollerBed.ExecutePositioningCommandMock.Command.CommandType, AxisCommandType#Absolute);
        Assert.Equal(_rollerBed.ExecutePositioningCommandMock.Command.Position, REAL#10.0);
        Assert.Equal(_rollerBed.ExecutePositioningCommandMock.Command.Velocity, REAL#11.0);
    END_METHOD
    */
END_CLASS

END_NAMESPACE