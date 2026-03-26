USING Esab.Utils.Assets;
USING Esab.Utils.Alarming;

USING Siemens.Simatic.S71500.MotionControl;
USING Siemens.Simatic.S71500.MotionControl.Native;


NAMESPACE Esab.Motion

    /// Implements a technology object position axis.
    /// This implementation depends on the Siemens TO object for motion.
    /// Currently does not support AxisType#Rotary.
    CLASS ToPosAxis EXTENDS Asset IMPLEMENTS IAxis
        VAR PRIVATE
            _axis : itfPosAxis := NULL;
            _runtimeParameters : REF_TO AxisRuntimeParameters;

            _latestAxisPositioningCommand : AxisPositioningCommand;
            _latestAxisHomingCommand : AxisHomingCommand;
            _latestCommand : itfCommand := NULL;
            _latestHomingCommand : itfHomeCommand := NULL;
            _jogPositive : BOOL := FALSE;
            _jogNegative : BOOL := FALSE;
            _jogUseHighSpeed : BOOL := FALSE;
            _observable : AxisObservable;
        END_VAR

        METHOD PUBLIC Setup
            VAR_INPUT
                axis : itfPosAxis;
                runtimeParameters : REF_TO AxisRuntimeParameters;
                setupAlarm : IAlarm;
            END_VAR

            _axis := axis;
            _runtimeParameters := runtimeParameters;
            _setupAlarm := setupAlarm;

            _isSetup := _axis <> NULL AND _runtimeParameters <> NULL;

            IF _isSetup AND NOT THIS.IsEnabled() THEN
                THIS.PowerOn();
            END_IF;
        END_METHOD

        METHOD PUBLIC OVERRIDE Execute
            SUPER.Execute();

            IF _setupAlarm.IsActive() THEN
                RETURN;
            END_IF;

            IF _jogUseHighSpeed THEN
                _axis.MoveJog(_jogPositive, _jogNegative, _runtimeParameters^.JogHighSpeed, -1.0, -1.0, -1.0, TRUE);
            ELSE
                _axis.MoveJog(_jogPositive, _jogNegative, _runtimeParameters^.JogSpeed, -1.0, -1.0, -1.0, TRUE);
            END_IF;

            _jogUseHighSpeed := FALSE;
            _jogPositive := FALSE;
            _jogNegative := FALSE;

            THIS.UpdateObservable();
        END_METHOD

        METHOD PUBLIC OVERRIDE UpdateState
            IF _setupAlarm.IsActive() THEN
                _currentState := AxisState#Error;
            ELSIF _axis.GetStatus().error THEN
                _currentState := AxisState#Error;
            ELSIF _latestHomingCommand <> NULL THEN
                _currentState := AxisState#Homing;
            ELSIF NOT _axis.GetStatus().standstill THEN
                _currentState := AxisState#Moving;
            ELSIF _axis.GetStatus().enable THEN
                _currentState := AxisState#Enabled;
            ELSE
                _currentState := AxisState#Disabled;
            END_IF;
        END_METHOD

        METHOD PUBLIC PowerOn
            _latestCommand := _axis.PowerOn(TRUE);
        END_METHOD

        METHOD PUBLIC PowerOff
            _latestCommand := _axis.PowerOff();
        END_METHOD

        METHOD PUBLIC Reset
            VAR_INPUT
                Restart : BOOL;
            END_VAR

            _latestAxisPositioningCommand.CommandType := AxisCommandType#Invalid;
            _latestCommand := NULL;
            _latestHomingCommand := NULL;

            _axis.ResetAlarms();

            IF Restart THEN
                _axis.Restart();
            END_IF;
        END_METHOD

        METHOD PUBLIC ExecutePositioningCommand : AxisCommandError
            VAR_INPUT
                command: AxisPositioningCommand;
            END_VAR

            CASE command.CommandType OF
                AxisCommandType#Absolute:
                    _latestCommand := _axis.MoveAbsolute(
                        Position := command.Position,
                        Velocity := command.Velocity,
                        Acceleration := command.Acceleration,
                        Deceleration := command.Deceleration,
                        Jerk := command.Jerk,
                        Direction := DirectionModulo#Positive
                    );
                AxisCommandType#Relative:
                    _latestCommand := _axis.MoveRelative(
                        Distance := command.Position,
                        Velocity := command.Velocity,
                        Acceleration := command.Acceleration,
                        Deceleration := command.Deceleration,
                        Jerk := command.Jerk
                    );
                AxisCommandType#Velocity:
                    _latestCommand := _axis.MoveVelocity(
                        Velocity := command.Velocity,
                        Acceleration := command.Acceleration,
                        Deceleration := command.Deceleration,
                        Jerk := command.Jerk,
                        Direction := Direction#VelocitySpecified,
                        PositionControlled := TRUE
                    );
                AxisCommandType#Halt:
                    _latestCommand := _axis.Halt(
                        Deceleration := command.Deceleration,
                        Jerk := command.Jerk
                    );
            END_CASE;

            //_invalidCommandAlarm(SIG := NOT (command.Type_ > AxisCommandType#Invalid AND
            //                                 command.Type_ < AxisCommandType#Last)
            //                    );

            _latestAxisPositioningCommand := command;
        END_METHOD

        METHOD PUBLIC ExecuteHomingCommand : AxisCommandError
            VAR_INPUT
                command: AxisHomingCommand;
            END_VAR

            CASE command.HomingType OF
                AxisHomingType#DirectAbsolute:
                    _latestHomingCommand := _axis.HomeDirect(command.Position, HomingModeDirect#ActualPositionAbsolute);
                AxisHomingType#DirectRelative:
                    _latestHomingCommand := _axis.HomeDirect(command.Position, HomingModeDirect#ActualPositionRelative);
                AxisHomingType#AbsoluteEncoderAdjustementAbsolute:
                    _latestHomingCommand := _axis.HomeAbsEncoder(command.Position, HomingModeAbsEncoder#AdjustmentSensorAbsolute);
            END_CASE;
        END_METHOD

        METHOD PUBLIC InvalidateHoming
            ;
        END_METHOD

        METHOD PUBLIC Halt
            _latestCommand := _axis.Halt();
        END_METHOD

        METHOD PUBLIC SetJogSpeed
            VAR_INPUT
                value : LREAL;
            END_VAR

            _runtimeParameters^.JogSpeed := value;
        END_METHOD

        METHOD PUBLIC SetJogHighSpeed
            VAR_INPUT
                value : LREAL;
            END_VAR

            _runtimeParameters^.JogHighSpeed := value;
        END_METHOD

        METHOD PUBLIC SetObjectRadius
            VAR_INPUT
                value : LREAL;
            END_VAR

            _runtimeParameters^.ObjectRadius := value;
        END_METHOD

        METHOD PUBLIC JogPositive
            VAR_INPUT
                highSpeed : BOOL := FALSE;
            END_VAR

            _jogUseHighSpeed := highSpeed;
            _jogPositive := TRUE;
        END_METHOD

        METHOD PUBLIC JogNegative
            VAR_INPUT
                highSpeed : BOOL := FALSE;
            END_VAR

            _jogUseHighSpeed := highSpeed;
            _jogNegative := TRUE;
        END_METHOD

        METHOD PUBLIC IsEnabled : BOOL
            IsEnabled := _axis.GetStatus().enable;
        END_METHOD

        METHOD PUBLIC IsBusy : BOOL
            IsBusy := FALSE;

            IF _latestCommand <> NULL THEN
                IsBusy := _latestCommand.Busy();
            ELSIF _latestHomingCommand <> NULL THEN
                IsBusy := _latestHomingCommand.Busy();
            END_IF;
        END_METHOD

        METHOD PUBLIC HasError : BOOL
            HasError := FALSE;

            IF _latestCommand <> NULL THEN
                HasError := _latestCommand.Error();
            ELSIF _latestHomingCommand <> NULL THEN
                HasError := _latestHomingCommand.Error();
            END_IF;
        END_METHOD

        METHOD PUBLIC AtStandstill : BOOL
            AtStandstill := _axis.GetStatus().standstill;
        END_METHOD

        METHOD PUBLIC IsHomed : BOOL
            IsHomed := _axis.GetStatus().homingDone;
        END_METHOD

        METHOD PUBLIC ActualLinearPosition : LREAL
            ActualLinearPosition := _axis.GetPositioningAxisRef()^.ActualPosition;
        END_METHOD

        METHOD PUBLIC ActualLinearVelocity : LREAL
            ActualLinearVelocity := _axis.GetPositioningAxisRef()^.ActualVelocity;
        END_METHOD

        METHOD PUBLIC ActualAngularPosition : LREAL
            ;
        END_METHOD

        METHOD PUBLIC ActualAngularVelocity : LREAL
            ;
        END_METHOD

        METHOD PUBLIC OVERRIDE Observe : IAssetObservable
            Observe := _observable;
        END_METHOD

        METHOD PRIVATE UpdateObservable
            _observable.Enabled := THIS.IsEnabled();
            _observable.Accelerating := FALSE; // TODO: Implement
            _observable.Decelerating := FALSE; // TODO: Implement
            _observable.Standstill := THIS.AtStandstill();
            _observable.Homed := THIS.IsHomed();
            _observable.Error := THIS.HasError();
            _observable.ErrorId := WORD#16#FFFF; // TODO: Implement
            _observable.Busy := THIS.IsBusy();
            _observable.Done := FALSE; // TODO: Implement
            _observable.LinearPosition := THIS.ActualLinearPosition();
            _observable.LinearVelocity := THIS.ActualLinearVelocity();
            _observable.LatestCommandId := -1; // TODO: Implement
        END_METHOD
    END_CLASS

END_NAMESPACE