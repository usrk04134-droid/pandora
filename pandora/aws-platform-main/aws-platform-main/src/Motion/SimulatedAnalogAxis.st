USING Esab.Utils.Assets;
USING Esab.Utils.Alarming;

USING System.Timer;
USING System.FastMath;

NAMESPACE Esab.Motion

    CLASS SimulatedAnalogAxis EXTENDS Asset IMPLEMENTS IAxis
        VAR PRIVATE
            _runtimeParameters : REF_TO AnalogAxisRuntimeParameters;
            _hardwareConfiguration : REF_TO AnalogAxisHardwareConfiguration;
            _observable : AxisObservable;
            _lastRuntime : LTIME;
            _runtime : LTIME;
            _runtimeTimer : TimeAccumulator;
            _poweredOn : BOOL;
            _velocity : LREAL;
            _position : LREAL;
            _isJogging : BOOL;
            _isHomed : BOOL;
            _jogPositive : BOOL;
            _jogNegative : BOOL;
            _highSpeed : BOOL;
        END_VAR

        METHOD PUBLIC Setup
            VAR_INPUT
                runtimeParameters : REF_TO AnalogAxisRuntimeParameters;
                hardwareConfiguration : REF_TO AnalogAxisHardwareConfiguration;
                setupAlarm : IAlarm;
            END_VAR

            _runtimeParameters := runtimeParameters;
            _hardwareConfiguration := hardwareConfiguration;
            _setupAlarm := setupAlarm;

            _isSetup := _runtimeParameters <> NULL AND _hardwareConfiguration <> NULL;

            IF _isSetup THEN
                THIS.PowerOn();
            END_IF;
        END_METHOD

        METHOD PUBLIC OVERRIDE Execute
            VAR_TEMP
                moving : BOOL;
                passedTime : LREAL;
            END_VAR

            SUPER.Execute();

            IF _setupAlarm.IsActive() THEN
                RETURN;
            END_IF;

            _runtimeTimer(signal := NOT THIS.AtStandstill(), duration := LT#42d, reset := THIS.AtStandstill(), accumulatedTime => _runtime);

            passedTime := TO_LREAL(TO_LINT(_runtime))/1000.0;

            _position := _velocity * passedTime;

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

            _jogPositive := FALSE;
            _jogNegative := FALSE;
            _highSpeed := FALSE;

            _lastRuntime := _runtime;

            THIS.UpdateObservable();
        END_METHOD

        METHOD PUBLIC PowerOn
            _poweredOn := TRUE;
        END_METHOD

        METHOD PUBLIC PowerOff
            _poweredOn := FALSE;
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

            ;
        END_METHOD

        METHOD PUBLIC InvalidateHoming
            _isHomed := FALSE;
        END_METHOD

        METHOD PUBLIC Halt
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
            IsBusy := Abs(_velocity) > 0.1;
        END_METHOD

        METHOD PUBLIC HasError : BOOL
            ;
        END_METHOD

        METHOD PUBLIC AtStandstill : BOOL
            AtStandstill := ABS(THIS.ActualLinearVelocity()) < 0.5;
        END_METHOD

        METHOD PUBLIC IsHomed : BOOL
            IsHomed := _isHomed;
        END_METHOD

        METHOD PUBLIC ActualLinearPosition : LREAL
            ActualLinearPosition := _position;
        END_METHOD

        METHOD PUBLIC ActualLinearVelocity : LREAL
            ActualLinearVelocity := _velocity;
        END_METHOD

        METHOD PUBLIC ActualAngularPosition : LREAL
            VAR_TEMP
                _angularPosition : LREAL := 0.0;
            END_VAR

            IF _hardwareConfiguration^.Axis.AxisType = AxisType#Rotary THEN
                _angularPosition := _position / (2 * Constants#PI * _runtimeParameters^.Axis.ObjectRadius) * 360.0;
            END_IF;

            ActualAngularPosition := _angularPosition;
        END_METHOD

        METHOD PUBLIC ActualAngularVelocity : LREAL
            VAR_TEMP
                _angularVelocity : LREAL := 0.0;
            END_VAR

            IF _hardwareConfiguration^.Axis.AxisType = AxisType#Rotary THEN
                _angularVelocity := _velocity / (2 * Constants#PI * _runtimeParameters^.Axis.ObjectRadius) * 360.0;
            END_IF;

            ActualAngularVelocity := _angularVelocity;
        END_METHOD

        METHOD PUBLIC OVERRIDE Observe : IAssetObservable
            Observe := _observable;
        END_METHOD

        METHOD PRIVATE SetVelocity
            VAR_INPUT
                velocity : LREAL;
            END_VAR

            _velocity := velocity;
        END_METHOD

        METHOD PRIVATE UpdateObservable
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
    END_CLASS

END_NAMESPACE