USING Esab.Motion.MeasurementSystem;
USING Esab.Utils.Alarming.Mock;
USING Esab.Motion.MeasurementSystems.Mock;
USING Esab.Io.Mock;
USING Esab.Utils.Timer.Mock;
USING Esab.Utils.Assets;

USING AxUnit;

NAMESPACE Esab.Motion.Test

    {TestFixture}
    CLASS AnalogAxisTests
        VAR PRIVATE
            _linearAnalogAxis : AnalogAxis;
            _rotaryAnalogAxis : AnalogAxis;
            _simulatedLinearAnalogAxis : SimulatedAnalogAxis;
            _simulatedRotaryAnalogAxis : SimulatedAnalogAxis;

            _io : AnalogAxisIo;
            _defaultIo : AnalogAxisIo;
            _runtimeParameters : AnalogAxisRuntimeParameters;
            _defaultRuntimeParameters : AnalogAxisRuntimeParameters;
            _hardwareConfiguration : AnalogAxisHardwareConfiguration;
            _defaultHardwareConfiguration : AnalogAxisHardwareConfiguration;

            _speedMeasurementTimer : OnDelayMock;
            _speedWheel : SpeedWheelMock;
            _speedAlarm : AlarmMock;

            _axis : IAxis;
            _axisAsset : REF_TO Asset;
            _observable : REF_TO AxisObservable;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            _defaultRuntimeParameters.MeasuringSpeed := 10.0;
            _defaultRuntimeParameters.SpeedSettlingTime := LTIME#10s;
            _defaultRuntimeParameters.Axis.JogSpeed := 20.0;
            _defaultRuntimeParameters.Axis.JogHighSpeed := 40.0;
            _defaultRuntimeParameters.Axis.ObjectRadius := 314.15;

            _defaultHardwareConfiguration.Axis.AxisType := AxisType#Linear;
            _defaultHardwareConfiguration.MaximumSpeed := 100.0;

            _linearAnalogAxis.Setup(
                REF(_io),
                REF(_runtimeParameters),
                REF(_hardwareConfiguration),
                _speedWheel,
                _speedMeasurementTimer,
                _speedAlarm,
                NULL
            );

            _rotaryAnalogAxis.Setup(
                REF(_io),
                REF(_runtimeParameters),
                REF(_hardwareConfiguration),
                _speedWheel,
                _speedMeasurementTimer,
                _speedAlarm,
                NULL
            );

            _simulatedLinearAnalogAxis.Setup(
                REF(_runtimeParameters),
                REF(_hardwareConfiguration),
                NULL
            );

            _simulatedRotaryAnalogAxis.Setup(
                REF(_runtimeParameters),
                REF(_hardwareConfiguration),
                NULL
            );
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            _io := _defaultIo;
            _runtimeParameters := _defaultRuntimeParameters;
            _hardwareConfiguration := _defaultHardwareConfiguration;

            _speedWheel.MockReset();
            _speedMeasurementTimer.MockReset();
            _speedAlarm.MockReset();
        END_METHOD



        {Test(axisNo := 1)}
        {Test(axisNo := 2)}
        {Test(axisNo := 3)}
        {Test(axisNo := 4)}
        METHOD PUBLIC PowerOnOff
            VAR_INPUT
                axisNo : INT;
            END_VAR

            VAR_TEMP
                _enabled : BOOL := FALSE;
            END_VAR

            THIS.SetAxis(axisNo);

            _axis.PowerOn();
            _axisAsset^.Execute();

            Assert.Equal(_axis.IsEnabled(), TRUE);
            Assert.Equal(_observable^.Enabled, TRUE);

            IF axisNo = 1 OR axisNo = 2 THEN
                _io.Outputs.RemoteControl.Write(_enabled);
                Assert.Equal(_enabled, TRUE);
            ELSE
                Assert.Equal(_axis.IsEnabled(), TRUE);
            END_IF;

            _axis.PowerOff();
            _axisAsset^.Execute();

            Assert.Equal(_observable^.Enabled, FALSE);

            IF axisNo = 1 OR axisNo = 2 THEN
                _io.Outputs.RemoteControl.Write(_enabled);
                Assert.Equal(_enabled, FALSE);
            ELSE
                Assert.Equal(_axis.IsEnabled(), FALSE);
            END_IF;
        END_METHOD

        {Test(axisNo := 1)}
        {Test(axisNo := 2)}
        {Test(axisNo := 3)}
        {Test(axisNo := 4)}
        METHOD PUBLIC AbsolutePositioning
            VAR_INPUT
                axisNo : INT;
            END_VAR

            VAR_TEMP
                _command : AxisPositioningCommand;
                _commandError : AxisCommandError;
                _speedReference : REAL;
            END_VAR

            THIS.SetAxis(axisNo);

            _axis.PowerOn();

            _command.Id := 42;
            _command.Acceleration := -1.0;
            _command.Deceleration := -1.0;
            _command.Jerk := -1.0;
            _command.PositioningDirection := AxisPositioningDirection#Positive;
            _command.CommandType := AxisCommandType#Absolute;
            _command.Position := 100.0;
            _command.Velocity := 10.0;

            _commandError := _axis.ExecutePositioningCommand(_command);

            Assert.Equal(_commandError, AxisCommandError#UnsupportedCommandType);
        END_METHOD

        {Test(axisNo := 1)}
        {Test(axisNo := 2)}
        {Test(axisNo := 3)}
        {Test(axisNo := 4)}
        METHOD PUBLIC RelativePositioning
            VAR_INPUT
                axisNo : INT;
            END_VAR

            VAR_TEMP
                _command : AxisPositioningCommand;
                _commandError : AxisCommandError;
                _speedReference : REAL;
            END_VAR

            THIS.SetAxis(axisNo);

            _axis.PowerOn();

            _command.Id := 42;
            _command.Acceleration := -1.0;
            _command.Deceleration := -1.0;
            _command.Jerk := -1.0;
            _command.PositioningDirection := AxisPositioningDirection#Positive;
            _command.CommandType := AxisCommandType#Relative;
            _command.Position := 100.0;
            _command.Velocity := 10.0;

            _commandError := _axis.ExecutePositioningCommand(_command);

            Assert.Equal(_commandError, AxisCommandError#UnsupportedCommandType);
        END_METHOD

        {Test(axisNo := 1)}
        {Test(axisNo := 2)}
        {Test(axisNo := 3)}
        {Test(axisNo := 4)}
        METHOD PUBLIC ForwardVelocity
            VAR_INPUT
                axisNo : INT;
            END_VAR

            VAR_TEMP
                _command : AxisPositioningCommand;
                _forward : BOOL;
                _reverse : BOOL;
                _speedReference : INT;
            END_VAR

            THIS.SetAxis(axisNo);

            _runtimeParameters.Axis.ObjectRadius := 750.0;

            _command.CommandType := AxisCommandType#Velocity;
            _command.Velocity := 100.0;

            _axis.PowerOn();

            Assert.Equal(_observable^.Busy, FALSE);

            _axis.ExecutePositioningCommand(_command);
            _speedWheel.GetMeasuredVelocityMock.Value := 100.0;
            _axisAsset^.Execute();

            IF axisNo = 1 OR axisNo = 2 THEN
                _io.Outputs.Forward.Write(_forward);
                _io.Outputs.Reverse.Write(_reverse);
                _io.Outputs.SpeedReference.Write(_speedReference);

                Assert.Equal(_forward, TRUE);
                Assert.Equal(_reverse, FALSE);
                Assert.Equal(_speedReference, 27648);
            END_IF;

            IF _hardwareConfiguration.Axis.AxisType = AxisType#Linear THEN
                Assert.Equal(_axis.ActualLinearVelocity(), 100.0);
                Assert.Equal(_observable^.LinearVelocity, 100.0);
                
                Assert.Equal(_axis.ActualAngularVelocity(), 0.0);
                Assert.Equal(_observable^.AngularVelocity, 0.0);
            ELSE
                Assert.Equal(_axis.ActualLinearVelocity(), 100.0);
                Assert.Equal(_observable^.LinearVelocity, 100.0);
                
                Assert.InRange(_axis.ActualAngularVelocity(), 7.63, 0.01);
                Assert.InRange(_observable^.AngularVelocity, 7.63, 0.01);
            END_IF;

            Assert.Equal(_observable^.Busy, TRUE);
        END_METHOD

        {Test(axisNo := 1)}
        {Test(axisNo := 2)}
        {Test(axisNo := 3)}
        {Test(axisNo := 4)}
        METHOD PUBLIC ReverseVelocity
            VAR_INPUT
                axisNo : INT;
            END_VAR

            VAR_TEMP
                _command : AxisPositioningCommand;
                _forward : BOOL;
                _reverse : BOOL;
                _speedReference : INT;
            END_VAR

            THIS.SetAxis(axisNo);

            _runtimeParameters.Axis.ObjectRadius := 750.0;

            _command.CommandType := AxisCommandType#Velocity;
            _command.Velocity := -100.0;

            _axis.PowerOn();

            Assert.Equal(_observable^.Busy, FALSE);

            _axis.ExecutePositioningCommand(_command);
            _speedWheel.GetMeasuredVelocityMock.Value := -100.0;
            _axisAsset^.Execute();

            IF axisNo = 1 OR axisNo = 2 THEN
                _io.Outputs.Forward.Write(_forward);
                _io.Outputs.Reverse.Write(_reverse);
                _io.Outputs.SpeedReference.Write(_speedReference);

                Assert.Equal(_forward, FALSE);
                Assert.Equal(_reverse, TRUE);
                Assert.Equal(_speedReference, 27648);
            END_IF;

            IF _hardwareConfiguration.Axis.AxisType = AxisType#Linear THEN
                Assert.Equal(_axis.ActualLinearVelocity(), -100.0);
                Assert.Equal(_observable^.LinearVelocity, -100.0);

                Assert.Equal(_axis.ActualAngularVelocity(), 0.0);
                Assert.Equal(_observable^.AngularVelocity, 0.0);
            ELSE
                Assert.Equal(_axis.ActualLinearVelocity(), -100.0);
                Assert.Equal(_observable^.LinearVelocity, -100.0);
                
                Assert.InRange(_axis.ActualAngularVelocity(), -7.63, 0.01);
                Assert.InRange(_observable^.AngularVelocity, -7.63, 0.01);
            END_IF;

            Assert.Equal(_observable^.Busy, TRUE);
        END_METHOD

        // Not run for simulated axis, because we currently do not mock the time accumulator.
        // So there is no way to fake the time progressing.
        {Test(axisNo := 1)}
        {Test(axisNo := 2)}
        METHOD PUBLIC Position
            VAR_INPUT
                axisNo : INT;
            END_VAR

            VAR_TEMP
                _forward : BOOL;
                _reverse : BOOL;
                _speed : INT;
            END_VAR

            THIS.SetAxis(axisNo);

            _speedWheel.GetMeasuredPositionMock.Value := 500.0;
            _runtimeParameters.Axis.ObjectRadius := 750.0;

            _axisAsset^.Execute();

            IF _hardwareConfiguration.Axis.AxisType = AxisType#Linear THEN
                Assert.Equal(_axis.ActualLinearPosition(), 500.0);
                Assert.Equal(_observable^.LinearPosition, 500.0);

                Assert.Equal(_axis.ActualAngularPosition(), 0.0);
                Assert.Equal(_observable^.AngularPosition, 0.0);
            ELSE
                Assert.Equal(_axis.ActualLinearPosition(), 500.0);
                Assert.Equal(_observable^.LinearPosition, 500.0);
                
                Assert.InRange(_axis.ActualAngularPosition(), 38.20, 0.01);
                Assert.InRange(_observable^.AngularPosition, 38.20, 0.01);
            END_IF;
        END_METHOD

        {Test(axisNo := 1)}
        {Test(axisNo := 2)}
        {Test(axisNo := 3)}
        {Test(axisNo := 4)}
        METHOD PUBLIC JogPositive
            VAR_INPUT
                axisNo : INT;
            END_VAR

            VAR_TEMP
                _forward : BOOL;
                _reverse : BOOL;
                _speed : INT;
            END_VAR

            THIS.SetAxis(axisNo);

            _runtimeParameters.Axis.JogSpeed := 50.0;
            _runtimeParameters.Axis.JogHighSpeed := 100.0;

            _axis.PowerOn();

            _axis.JogPositive();
            _speedWheel.GetMeasuredVelocityMock.Value := 50.0;
            _axisAsset^.Execute();

            _io.Outputs.Forward.Write(_forward);
            _io.Outputs.Reverse.Write(_reverse);
            _io.Outputs.SpeedReference.Write(_speed);

            IF axisNo = 1 OR axisNo = 2 THEN
                Assert.Equal(_forward, TRUE);
                Assert.Equal(_reverse, FALSE);
                Assert.Equal(_speed, 27648/2);
            END_IF;

            Assert.Equal(_axis.ActualLinearVelocity(), 50.0);
            Assert.Equal(_observable^.LinearVelocity, 50.0);

            _axis.JogPositive();
            _axisAsset^.Execute();
            _axis.JogPositive();
            _axisAsset^.Execute();
            _axis.JogPositive();
            _axisAsset^.Execute();
            _axis.JogPositive();
            _axisAsset^.Execute();

            _io.Outputs.Forward.Write(_forward);
            _io.Outputs.Reverse.Write(_reverse);
            _io.Outputs.SpeedReference.Write(_speed);

            IF axisNo = 1 OR axisNo = 2 THEN
                Assert.Equal(_forward, TRUE);
                Assert.Equal(_reverse, FALSE);
                Assert.Equal(_speed, 27648/2);
            END_IF;

            Assert.Equal(_axis.ActualLinearVelocity(), 50.0);
            Assert.Equal(_observable^.LinearVelocity, 50.0);

            _speedWheel.GetMeasuredVelocityMock.Value := 0.0;

            _axisAsset^.Execute(); // Execute cycle without JogPositive, check that it stops.

            _io.Outputs.Forward.Write(_forward);
            _io.Outputs.Reverse.Write(_reverse);
            _io.Outputs.SpeedReference.Write(_speed);

            IF axisNo = 1 OR axisNo = 2 THEN
                Assert.Equal(_forward, FALSE);
                Assert.Equal(_reverse, FALSE);
                Assert.Equal(_speed, 0);
            END_IF;

            Assert.Equal(_axis.ActualLinearVelocity(), 0.0);
            Assert.Equal(_observable^.LinearVelocity, 0.0);
        END_METHOD

        {Test(axisNo := 1)}
        {Test(axisNo := 2)}
        {Test(axisNo := 3)}
        {Test(axisNo := 4)}
        METHOD PUBLIC JogNegative
            VAR_INPUT
                axisNo : INT;
            END_VAR

            VAR_TEMP
                _forward : BOOL;
                _reverse : BOOL;
                _speed : INT;
            END_VAR

            THIS.SetAxis(axisNo);

            _runtimeParameters.Axis.JogSpeed := 50.0;
            _runtimeParameters.Axis.JogHighSpeed := 100.0;
            

            _axis.PowerOn();

            _axis.JogNegative();
            _speedWheel.GetMeasuredVelocityMock.Value := -50.0;
            _axisAsset^.Execute();

            IF axisNo = 1 OR axisNo = 2 THEN
                _io.Outputs.Forward.Write(_forward);
                _io.Outputs.Reverse.Write(_reverse);
                _io.Outputs.SpeedReference.Write(_speed);

                Assert.Equal(_forward, FALSE);
                Assert.Equal(_reverse, TRUE);
                Assert.Equal(_speed, 27648/2);
            END_IF;

            Assert.Equal(_axis.ActualLinearVelocity(), -50.0);
            Assert.Equal(_observable^.LinearVelocity, -50.0);

            _axis.JogNegative();
            _axisAsset^.Execute();
            _axis.JogNegative();
            _axisAsset^.Execute();
            _axis.JogNegative();
            _axisAsset^.Execute();
            _axis.JogNegative();
            _axisAsset^.Execute();

            _io.Outputs.Forward.Write(_forward);
            _io.Outputs.Reverse.Write(_reverse);
            _io.Outputs.SpeedReference.Write(_speed);

            IF axisNo = 1 OR axisNo = 2 THEN
                Assert.Equal(_forward, FALSE);
                Assert.Equal(_reverse, TRUE);
                Assert.Equal(_speed, 27648/2);
            END_IF;

            Assert.Equal(_axis.ActualLinearVelocity(), -50.0);
            Assert.Equal(_observable^.LinearVelocity, -50.0);

            _speedWheel.GetMeasuredVelocityMock.Value := 0.0;

            _axisAsset^.Execute(); // Execute cycle without JogPositive, check that it stops.

            _io.Outputs.Forward.Write(_forward);
            _io.Outputs.Reverse.Write(_reverse);
            _io.Outputs.SpeedReference.Write(_speed);

            IF axisNo = 1 OR axisNo = 2 THEN
                Assert.Equal(_forward, FALSE);
                Assert.Equal(_reverse, FALSE);
                Assert.Equal(_speed, 0);
            END_IF;


            Assert.Equal(_axis.ActualLinearVelocity(), 0.0);
            Assert.Equal(_observable^.LinearVelocity, 0.0);
        END_METHOD

        {Test(axisNo := 1)}
        {Test(axisNo := 2)}
        //{Test(axisNo := 3)}
        //{Test(axisNo := 4)}
        METHOD PUBLIC SpeedMonitoringAlarm
            VAR_INPUT
                axisNo : INT;
            END_VAR

            VAR_TEMP
                _command : AxisPositioningCommand;
            END_VAR

            THIS.SetAxis(axisNo);

            _command.CommandType := AxisCommandType#Velocity;
            _command.Velocity := 100.0;

            _axis.PowerOn();

            _axis.ExecutePositioningCommand(_command);
            _speedWheel.GetMeasuredVelocityMock.Value := 50.0;
            _axisAsset^.Execute();

            Assert.Equal(_speedAlarm.ExecuteMock.GetCallCount() > UINT#0, TRUE);
            Assert.Equal(_speedAlarm.ExecuteMock.SIG, TRUE);
            _speedAlarm.IsActiveMock.Value := TRUE;
            _axisAsset^.Execute();

            //Assert.Equal(_observable^.State, RollerBedState#Error);
        END_METHOD

        {Test(axisNo := 1)}
        {Test(axisNo := 2)}
        //{Test(axisNo := 3)}
        //{Test(axisNo := 4)}
        METHOD PUBLIC Calibrate
            VAR_INPUT
                axisNo : INT;
            END_VAR

            VAR_TEMP
                _measurementListener : IMeasurementSystemListener;
            END_VAR

            THIS.SetAxis(axisNo);

            _measurementListener ?= _axis;
            Assert.Equal(_measurementListener <> NULL, TRUE);

            _runtimeParameters.Axis.ObjectRadius := 1500.0;

            _speedWheel.GetMeasuredPositionMock.Value := 0.0;
            _measurementListener.ArrivedAtReferencePoint();
            _axisAsset^.Execute();

            Assert.Greater(_speedWheel.GetMeasuredPositionMock.GetCallCount(), UINT#0);

            _speedWheel.GetMeasuredPositionMock.Value := 4398.22;
            _measurementListener.ArrivedAtReferencePoint();
            _axisAsset^.Execute();

            Assert.Greater(_speedWheel.GetMeasuredPositionMock.GetCallCount(), UINT#1);
            Assert.InRange(_runtimeParameters.Axis.ObjectRadius, 700.0, 0.01);
            Assert.Equal(_axis.IsHomed(), TRUE);
            Assert.Equal(_observable^.Homed, TRUE);
        END_METHOD

        {Test(axisNo := 1)}
        {Test(axisNo := 2)}
        METHOD PUBLIC SpeedAdaptationIncreaseMax
            VAR_INPUT
                axisNo : INT;
            END_VAR

            VAR_TEMP
                _speed : INT;
                _command : AxisHomingCommand;
            END_VAR

            THIS.SetAxis(axisNo);

            _runtimeParameters.MeasuringSpeed := 5.0;
            _hardwareConfiguration.MaximumSpeed := 10.0;
            _command.HomingType := AxisHomingType#Active;

            _axis.ExecuteHomingCommand(_command);
            _speedWheel.GetMeasuredVelocityMock.Value := 10.0;
            _io.Outputs.SpeedReference.Write(_speed);
            _speedMeasurementTimer.ExpiredMock.Value := TRUE;
            Assert.Equal(_speed, 27648/2);
            _axisAsset^.Execute();
            _axisAsset^.Execute();
            _axisAsset^.Execute();
            _axisAsset^.Execute();

            Assert.Equal(_hardwareConfiguration.MaximumSpeed, 20.0);
            _io.Outputs.SpeedReference.Write(_speed);
            Assert.Equal(_speed, 27648/4);
        END_METHOD

        {Test(axisNo := 1)}
        {Test(axisNo := 2)}
        METHOD PUBLIC SpeedAdaptationDecreaseMax
            VAR_INPUT
                axisNo : INT;
            END_VAR

            VAR_TEMP
                _speed : INT;
                _command : AxisHomingCommand;
            END_VAR

            THIS.SetAxis(axisNo);

            _runtimeParameters.MeasuringSpeed := 5.0;
            _hardwareConfiguration.MaximumSpeed := 10.0;
            _command.HomingType := AxisHomingType#Active;

            _axis.ExecuteHomingCommand(_command);
            _speedWheel.GetMeasuredVelocityMock.Value := 2.5;
            _io.Outputs.SpeedReference.Write(_speed);
            _speedMeasurementTimer.ExpiredMock.Value := TRUE;
            Assert.Equal(_speed, 27648/2);
            _axisAsset^.Execute();
            _axisAsset^.Execute();
            _axisAsset^.Execute();
            _axisAsset^.Execute();

            Assert.Equal(_hardwareConfiguration.MaximumSpeed, 5.0);
            _io.Outputs.SpeedReference.Write(_speed);
            Assert.Equal(_speed, 27648);
        END_METHOD

        {Test(axisNo := 1)}
        {Test(axisNo := 2)}
        {Test(axisNo := 3)}
        {Test(axisNo := 4)}
        METHOD PUBLIC SetJogSpeed
            VAR_INPUT
                axisNo : INT;
            END_VAR

            VAR_TEMP
                _speed : INT;
                _command : AxisHomingCommand;
            END_VAR

            THIS.SetAxis(axisNo);

            _axis.SetJogSpeed(5.0);

            Assert.Equal(_runtimeParameters.Axis.JogSpeed, 5.0);
        END_METHOD

        {Test(axisNo := 1)}
        {Test(axisNo := 2)}
        {Test(axisNo := 3)}
        {Test(axisNo := 4)}
        METHOD PUBLIC SetJogHighSpeed
            VAR_INPUT
                axisNo : INT;
            END_VAR

            VAR_TEMP
                _speed : INT;
                _command : AxisHomingCommand;
            END_VAR

            THIS.SetAxis(axisNo);

            _axis.SetJogHighSpeed(10.0);

            Assert.Equal(_runtimeParameters.Axis.JogHighSpeed, 10.0);
        END_METHOD

        {Test(axisNo := 1)}
        {Test(axisNo := 2)}
        {Test(axisNo := 3)}
        {Test(axisNo := 4)}
        METHOD PUBLIC SetObjectRadius
            VAR_INPUT
                axisNo : INT;
            END_VAR

            VAR_TEMP
                _speed : INT;
                _command : AxisHomingCommand;
            END_VAR

            THIS.SetAxis(axisNo);

            _axis.SetObjectRadius(1000.0);

            Assert.Equal(_runtimeParameters.Axis.ObjectRadius, 1000.0);
        END_METHOD

        METHOD PRIVATE SetAxis
            VAR_INPUT
                axisNo : INT;
            END_VAR

            CASE axisNo OF
                1:
                    _axis := _linearAnalogAxis;
                2:
                    _hardwareConfiguration.Axis.AxisType := AxisType#Rotary;
                    _axis := _rotaryAnalogAxis;
                3:
                    _axis := _simulatedLinearAnalogAxis;
                4:
                    _hardwareConfiguration.Axis.AxisType := AxisType#Rotary;
                    _axis := _simulatedRotaryAnalogAxis;
            END_CASE;

            Assert.Equal(_axis <> NULL, TRUE);

            _axisAsset ?= _axis;
            Assert.Equal(_axisAsset <> NULL, TRUE);

            _observable ?= _axisAsset^.Observe();
            Assert.Equal(_observable <> NULL, TRUE);
        END_METHOD
    END_CLASS

END_NAMESPACE