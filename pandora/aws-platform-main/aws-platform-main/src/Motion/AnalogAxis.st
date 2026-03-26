USING Esab.Motion.MeasurementSystem;
USING Esab.Utils.Assets;
USING Esab.Utils.Timer;
USING Esab.Utils.Alarming;
USING Esab.Io;

USING System.FastMath;

NAMESPACE Esab.Motion

    /// Implements an axis with the following properties:
    ///     - The axis is controlled via digital and analog I/O:
    ///         - Forwards/positive direction (digital out)
    ///         - Backwards/negative direction (digital out)
    ///         - Speed (analog out)
    /// To measure the position (if applicable) a measurement system should
    /// be provided. The axis will work "fine" without it but it will be limited to
    /// speed control without feedback.
    CLASS AnalogAxis EXTENDS Asset IMPLEMENTS IAxis, IMeasurementSystemListener
        VAR PRIVATE
            _io : REF_TO AnalogAxisIo;
            _runtimeParameters : REF_TO AnalogAxisRuntimeParameters;
            _hardwareConfiguration : REF_TO AnalogAxisHardwareConfiguration;
            _measurementSystem : IMeasurementSystem1D;
            _speedMeasurementTimer : ITimer;
            _speedMonitoringAlarm : IAlarm;

            _observable : AxisObservable;

            _setVelocity : LREAL := 0.0;
            _jogPositive : BOOL := FALSE;
            _jogNegative : BOOL := FALSE;
            _highSpeed : BOOL := FALSE;
            _isJogging : BOOL := FALSE;
            _isHomed : BOOL := FALSE;
            _poweredOn : BOOL := FALSE;
            _measuring : BOOL := FALSE;
            _hasPassedReferencePointOnce : BOOL := FALSE;
        END_VAR

        METHOD PUBLIC Setup
            VAR_INPUT
                io : REF_TO AnalogAxisIo;
                runtimeParameters : REF_TO AnalogAxisRuntimeParameters;
                hardwareConfiguration : REF_TO AnalogAxisHardwareConfiguration;
                measurementSystem : IMeasurementSystem1D;
                speedMeasurementTimer : ITimer;
                speedMonitoringAlarm : IAlarm;
                setupAlarm : IAlarm;
            END_VAR

            _io := io;
            _runtimeParameters := runtimeParameters;
            _hardwareConfiguration := hardwareConfiguration;
            _measurementSystem := measurementSystem;
            _speedMeasurementTimer := speedMeasurementTimer;
            _speedMonitoringAlarm := speedMonitoringAlarm;
            _setupAlarm := setupAlarm;

            _isSetup := _io <> NULL AND
                        _hardwareConfiguration <> NULL AND
                        _runtimeParameters <> NULL AND
                        _measurementSystem <> NULL AND
                        _speedMonitoringAlarm <> NULL;

            IF _isSetup THEN
                _measurementSystem.SetListener(THIS);
            END_IF;
        END_METHOD

        METHOD PUBLIC OVERRIDE Execute
            VAR_TEMP
                _actualSpeedInMmPerS : LREAL;
                _speedPercentage : LREAL;
            END_VAR

            SUPER.Execute();

            IF _setupAlarm.IsActive() THEN
                RETURN;
            END_IF;

            _measurementSystem.Execute();

            _speedMeasurementTimer.Execute(_measuring, _runtimeParameters^.SpeedSettlingTime);

            IF _measuring THEN
                IF _speedMeasurementTimer.Expired() THEN
                    THIS.AdjustMaxSpeed();
                    _measuring := FALSE;
                END_IF;
            ELSE
                IF _isJogging OR _jogPositive OR _jogNegative THEN
                    IF NOT _isJogging AND (_jogPositive OR _jogNegative) THEN
                        IF _jogPositive THEN
                            IF _highSpeed THEN
                                THIS.SetVelocity(_runtimeParameters^.Axis.JogHighSpeed);
                            ELSE
                                THIS.SetVelocity(_runtimeParameters^.Axis.JogSpeed);
                            END_IF;
                        ELSIF _jogNegative THEN
                            IF _highSpeed THEN
                                THIS.SetVelocity(-_runtimeParameters^.Axis.JogHighSpeed);
                            ELSE
                                THIS.SetVelocity(-_runtimeParameters^.Axis.JogSpeed);
                            END_IF;
                        END_IF;

                        _isJogging := TRUE;
                    END_IF;

                    IF _isJogging AND NOT (_jogPositive OR _jogNegative) THEN
                        THIS.Halt();
                        _isJogging := FALSE;
                    END_IF;
                END_IF;
            END_IF;

            _jogPositive := FALSE;
            _jogNegative := FALSE;
            _highSpeed := FALSE;

            _speedMonitoringAlarm.Execute(NOT THIS.AtStandstill() AND ABS(THIS.ActualLinearVelocity() - _setVelocity) > 0.05);

            THIS.UpdateState();
            THIS.UpdateObservable();
        END_METHOD

        METHOD PUBLIC PowerOn
            _poweredOn := TRUE;
            _io^.Outputs.RemoteControl.Set();
        END_METHOD

        METHOD PUBLIC PowerOff
            _poweredOn := FALSE;
            _io^.Outputs.RemoteControl.Reset();
        END_METHOD

        METHOD PUBLIC Reset
            VAR_INPUT
                Restart : BOOL;
            END_VAR

            ;
        END_METHOD

        METHOD PUBLIC ExecutePositioningCommand : AxisCommandError
            VAR_INPUT
                command : AxisPositioningCommand;
            END_VAR

            VAR_TEMP
                _error : AxisCommandError := AxisCommandError#NoError;
            END_VAR

            IF NOT THIS.IsEnabled() THEN
                ExecutePositioningCommand := AxisCommandError#AxisNotEnabled;
                RETURN;
            END_IF;

            CASE command.CommandType OF
                AxisCommandType#Velocity:
                    THIS.SetVelocity(command.Velocity);
                AxisCommandType#Halt:
                    THIS.SetVelocity(0.0);
            ELSE
                _error := AxisCommandError#UnsupportedCommandType;
            END_CASE;

            ExecutePositioningCommand := _error;
        END_METHOD

        METHOD PUBLIC ExecuteHomingCommand : AxisCommandError
            VAR_INPUT
                command : AxisHomingCommand;
            END_VAR

            VAR_TEMP
                _error : AxisCommandError := AxisCommandError#NoError;
            END_VAR

            IF NOT THIS.IsEnabled() THEN
                ExecuteHomingCommand := AxisCommandError#AxisNotEnabled;
                RETURN;
            END_IF;

            CASE command.HomingType OF
                AxisHomingType#Active:
                    THIS.SetVelocity(_runtimeParameters^.MeasuringSpeed);
                    _measuring := TRUE;
            END_CASE;

            ExecuteHomingCommand := _error;
        END_METHOD

        METHOD PUBLIC InvalidateHoming
            _isHomed := FALSE;
            _hasPassedReferencePointOnce := FALSE;
        END_METHOD

        METHOD PUBLIC Halt
            _jogNegative := FALSE;
            _jogPositive := FALSE;
            _isJogging := FALSE;

            THIS.SetVelocity(0.0);
        END_METHOD

        METHOD PUBLIC SetJogSpeed
            VAR_INPUT
                value : LREAL;
            END_VAR

            _runtimeParameters^.Axis.JogSpeed := value;
        END_METHOD

        METHOD PUBLIC SetJogHighSpeed
            VAR_INPUT
                value : LREAL;
            END_VAR

            _runtimeParameters^.Axis.JogHighSpeed := value;
        END_METHOD

        METHOD PUBLIC SetObjectRadius
            VAR_INPUT
                value : LREAL;
            END_VAR

            _runtimeParameters^.Axis.ObjectRadius := value;
        END_METHOD

        METHOD PUBLIC JogPositive
            VAR_INPUT
                highSpeed : BOOL := FALSE;
            END_VAR

            IF NOT THIS.IsEnabled() THEN
                RETURN;
            END_IF;

            _highSpeed := highSpeed;
            _jogPositive := TRUE;
            _jogNegative := FALSE;
        END_METHOD

        METHOD PUBLIC JogNegative
            VAR_INPUT
                highSpeed : BOOL := FALSE;
            END_VAR

            IF NOT THIS.IsEnabled() THEN
                RETURN;
            END_IF;

            _highSpeed := highSpeed;
            _jogPositive := FALSE;
            _jogNegative := TRUE;
        END_METHOD

        METHOD PUBLIC IsEnabled : BOOL
            IsEnabled := _poweredOn;
        END_METHOD

        METHOD PUBLIC IsBusy : BOOL
            IsBusy := NOT THIS.AtStandstill();
        END_METHOD

        METHOD PUBLIC HasError : BOOL
            HasError := THIS._speedMonitoringAlarm.IsActive() OR THIS._setupAlarm.IsActive();
        END_METHOD

        METHOD PUBLIC AtStandstill : BOOL
            AtStandstill := ABS(THIS.ActualLinearVelocity()) < 0.5;
        END_METHOD

        METHOD PUBLIC IsHomed : BOOL
            IsHomed := _isHomed;
        END_METHOD

        METHOD PUBLIC ActualLinearPosition : LREAL
            ActualLinearPosition := _measurementSystem.GetMeasuredPosition();
        END_METHOD

        METHOD PUBLIC ActualLinearVelocity : LREAL
            ActualLinearVelocity := _measurementSystem.GetMeasuredVelocity();
        END_METHOD

        METHOD PUBLIC ActualAngularPosition : LREAL
            VAR_TEMP
                _position : LREAL := 0.0;
            END_VAR

            IF _hardwareConfiguration^.Axis.AxisType = AxisType#Rotary THEN
                _position := _measurementSystem.GetMeasuredPosition() / (2 * Constants#PI * _runtimeParameters^.Axis.ObjectRadius) * 360.0;
            END_IF;

            ActualAngularPosition := _position;
        END_METHOD

        METHOD PUBLIC ActualAngularVelocity : LREAL
            VAR_TEMP
                _velocity : LREAL := 0.0;
            END_VAR

            IF _hardwareConfiguration^.Axis.AxisType = AxisType#Rotary THEN
                _velocity := _measurementSystem.GetMeasuredVelocity() / (2 * Constants#PI * _runtimeParameters^.Axis.ObjectRadius) * 360.0;
            END_IF;

            ActualAngularVelocity := _velocity;
        END_METHOD

        METHOD PUBLIC OVERRIDE Observe : IAssetObservable
            Observe := _observable;
        END_METHOD

        METHOD PUBLIC ArrivedAtReferencePoint
            IF _hasPassedReferencePointOnce THEN
                THIS.SetRadiusFromCircumference(_measurementSystem.GetMeasuredPosition());
                _isHomed := TRUE;
            ELSE
                _hasPassedReferencePointOnce := TRUE;
            END_IF;

            _measurementSystem.ResetMeasuredPosition();
        END_METHOD

        METHOD PRIVATE SetRadiusFromCircumference
            VAR_INPUT
                circumference : LREAL;
            END_VAR

            _runtimeParameters^.Axis.ObjectRadius := circumference / (2 * Constants#PI);
        END_METHOD

        METHOD PRIVATE UpdateObservable
            _observable.State := THIS.GetState();
            _observable.Enabled := THIS.IsEnabled();
            _observable.Accelerating := FALSE;
            _observable.Decelerating := FALSE;
            _observable.Standstill := THIS.AtStandstill();
            _observable.Homed := THIS.IsHomed();
            _observable.Error := THIS.HasError();
            _observable.ErrorId := WORD#16#0000;
            _observable.Busy := THIS.IsBusy();
            _observable.Done := FALSE;
            _observable.LatestCommandId := 16#0000;
            _observable.LinearPosition := THIS.ActualLinearPosition();
            _observable.LinearVelocity := THIS.ActualLinearVelocity();
            _observable.AngularPosition := THIS.ActualAngularPosition();
            _observable.AngularVelocity := THIS.ActualAngularVelocity();
        END_METHOD

        METHOD PRIVATE UpdateState
            IF THIS.HasError() THEN
                _currentState := AxisState#Error;
            ELSIF THIS.IsBusy() THEN
                _currentState := AxisState#Moving;
            ELSIF THIS.IsEnabled() THEN
                _currentState := AxisState#Enabled;
            ELSE
                _currentState := AxisState#Disabled;
            END_IF;
        END_METHOD

        METHOD PRIVATE SetVelocity
            VAR_INPUT
                velocity : LREAL;
            END_VAR

            VAR_TEMP
                speed : REAL;
            END_VAR

            _setVelocity := velocity;

            speed := TO_REAL(ABS(velocity) / _hardwareConfiguration^.MaximumSpeed);

            IF velocity > 0.01 THEN
                _io^.Outputs.SpeedReference.SetValue(speed);
                _io^.Outputs.Forward.Set();
                _io^.Outputs.Reverse.Reset();
            ELSIF velocity < -0.01 THEN
                _io^.Outputs.SpeedReference.SetValue(speed);
                _io^.Outputs.Forward.Reset();
                _io^.Outputs.Reverse.Set();
            ELSE
                _io^.Outputs.SpeedReference.SetValue(REAL#0.0);
                _io^.Outputs.Forward.Reset();
                _io^.Outputs.Reverse.Reset();
            END_IF;
        END_METHOD

        METHOD PRIVATE AdjustMaxSpeed
            _hardwareConfiguration^.MaximumSpeed := _measurementSystem.GetMeasuredVelocity() / _setVelocity * _hardwareConfiguration^.MaximumSpeed;
            // We also need to update the outputs when we adjust the max speed
            THIS.SetVelocity(_setVelocity);
        END_METHOD
    END_CLASS

    TYPE
        AnalogAxisRuntimeParameters : STRUCT
            Axis : AxisRuntimeParameters;
            MeasuringSpeed : LREAL := 8.33;
            SpeedSettlingTime : LTIME := LT#5s;
        END_STRUCT;

        AnalogAxisHardwareConfiguration : STRUCT
            Axis : AxisHardwareConfiguration;
            MaximumSpeed : LREAL := 100.0;
        END_STRUCT;
    END_TYPE

    TYPE
        AnalogAxisIo : STRUCT
            Inputs : AnalogAxisInputs;
            Outputs : AnalogAxisOutputs;
        END_STRUCT;

        AnalogAxisInputs : STRUCT
            Error : DigitalInput;
        END_STRUCT;

        AnalogAxisOutputs : STRUCT
            Forward : DigitalOutput;
            Reverse : DigitalOutput;
            RemoteControl : DigitalOutput;
            SpeedReference : RealNormalizedOutput;
        END_STRUCT;
    END_TYPE

END_NAMESPACE