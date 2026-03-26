USING Esab.Utils.Assets;

NAMESPACE Esab.Motion

    /// Interface defining an axis.
    /// The interface supports both linear and rotary axes, defined through hardware configuration.
    INTERFACE IAxis
        METHOD PowerOn
        END_METHOD

        METHOD PowerOff
        END_METHOD

        METHOD Reset
            VAR_INPUT
                Restart : BOOL;
            END_VAR
        END_METHOD

        METHOD ExecutePositioningCommand : AxisCommandError
            VAR_INPUT
                command : AxisPositioningCommand;
            END_VAR
        END_METHOD

        METHOD ExecuteHomingCommand : AxisCommandError
            VAR_INPUT
                command: AxisHomingCommand;
            END_VAR
        END_METHOD

        METHOD InvalidateHoming
        END_METHOD

        METHOD Halt
        END_METHOD

        METHOD SetJogSpeed
            VAR_INPUT
                value : LREAL;
            END_VAR
        END_METHOD

        METHOD SetJogHighSpeed
            VAR_INPUT
                value : LREAL;
            END_VAR
        END_METHOD

        METHOD SetObjectRadius
            VAR_INPUT
                value : LREAL;
            END_VAR
        END_METHOD

        METHOD JogPositive
            VAR_INPUT
                highSpeed : BOOL := FALSE;
            END_VAR
        END_METHOD

        METHOD JogNegative
            VAR_INPUT
                highSpeed : BOOL := FALSE;
            END_VAR
        END_METHOD

        METHOD IsEnabled : BOOL
        END_METHOD

        METHOD IsBusy : BOOL
        END_METHOD

        METHOD IsHomed : BOOL
        END_METHOD

        METHOD HasError : BOOL
        END_METHOD

        METHOD AtStandstill : BOOL
        END_METHOD

        METHOD ActualLinearPosition : LREAL
        END_METHOD

        METHOD ActualLinearVelocity : LREAL
        END_METHOD

        METHOD ActualAngularPosition : LREAL
        END_METHOD

        METHOD ActualAngularVelocity : LREAL
        END_METHOD
    END_INTERFACE

    TYPE
        AxisCommandError : INT(
            NoError := 0,
            UnsupportedCommandType := 1,
            UnsupportedHomingType := 2,
            AxisNotEnabled := 3
        ) := AxisCommandError#NoError;

        AxisPositioningCommand : STRUCT
            CommandType : AxisCommandType := AxisCommandType#Absolute;
            /// NOTE: Only modulo axes supports setting the mode.
            PositioningDirection : AxisPositioningDirection := AxisPositioningDirection#Nearest;
            Id : INT := 0;
            Position : LREAL := 0.0;
            Velocity : LREAL := -1.0;
            Acceleration : LREAL := -1.0;
            Deceleration : LREAL := -1.0;
            Jerk : LREAL := -1.0;
        END_STRUCT;

        AxisCommandType : INT(
            Invalid     := -1,
            Absolute    := 0,
            Relative    := 1,
            Velocity    := 2,
            Halt        := 3
        ) := AxisCommandType#Invalid;

        AxisPositioningDirection : INT(
            Nearest := 0,
            Positive := 1,
            Negative := 2
        ) := AxisPositioningDirection#Nearest;

        AxisHomingCommand : STRUCT
            HomingType : AxisHomingType := AxisHomingType#DirectAbsolute;
            Position : LREAL := 0.0;
        END_STRUCT;

        AxisHomingType : INT(
            Invalid := -1,
            DirectAbsolute := 0,
            DirectRelative := 1,
            Active := 2,
            Passive := 3,
            AbsoluteEncoderAdjustementRelative := 4,
            AbsoluteEncoderAdjustementAbsolute := 5
        ) := AxisHomingType#Invalid;

        AxisState : INT(
            Enabled := 0,
            Disabled := 1,
            Error := 2,
            Homing := 3,
            Moving := 4
        ) := AxisState#Disabled;

        AxisType : INT(
            Linear := 0,
            Rotary := 1
        ) := AxisType#Rotary;

        AxisRuntimeParameters : STRUCT
            JogSpeed : LREAL := 10.0;
            JogHighSpeed : LREAL := 20.0;
            ObjectRadius : LREAL := 1500.0;
        END_STRUCT;

        AxisHardwareConfiguration : STRUCT
            AxisType : AxisType := AxisType#Linear;
        END_STRUCT;
    END_TYPE

    CLASS AxisObservable IMPLEMENTS IAssetObservable
        VAR PUBLIC
            State : AxisState;
            Enabled : BOOL;
            Accelerating : BOOL;
            Decelerating : BOOL;
            Standstill : BOOL;
            Homed : BOOL;
            Error : BOOL;
            ErrorId : WORD;
            Busy : BOOL;
            Done : BOOL;
            LatestCommandId : INT;
            LinearPosition : LREAL;
            LinearVelocity : LREAL;
            AngularPosition : LREAL;
            AngularVelocity : LREAL;
            ObjectRadius : LREAL;
        END_VAR
    END_CLASS

END_NAMESPACE