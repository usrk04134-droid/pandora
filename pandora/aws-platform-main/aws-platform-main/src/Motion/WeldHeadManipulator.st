USING Esab.Hmi.Modules;
USING Esab.Utils.Assets;
USING Esab.Utils.Alarming;
USING System.FastMath;

NAMESPACE Esab.Motion

    INTERFACE IWeldHeadManipulator
        METHOD Enable : WeldHeadManipulatorErrorCode
        END_METHOD

        METHOD Disable
        END_METHOD

        /// Interpolated motion, axes will arrive at the same time
        METHOD Move : WeldHeadManipulatorErrorCode
            VAR_INPUT
                position : ARRAY [0..1] OF LREAL := [0.0, 0.0];
                speed : LREAL := -1;
            END_VAR
        END_METHOD

        /// Non-interpolated movement
        METHOD Move : WeldHeadManipulatorErrorCode
            VAR_INPUT
                position : ARRAY [0..1] OF LREAL := [0.0, 0.0];
                speed : ARRAY [0..1] OF LREAL := [-1.0, -1.0];
            END_VAR
        END_METHOD

        METHOD IsEnabled : BOOL
        END_METHOD

        METHOD GetPosition : ARRAY [0..1] OF LREAL
        END_METHOD

        METHOD GetSpeed : LREAL
        END_METHOD

        METHOD GetVelocity : ARRAY [0..1] OF LREAL
        END_METHOD

        METHOD GetControlMode : WeldHeadManipulatorControlMode
        END_METHOD

        METHOD SetControlMode
            VAR_INPUT
                controlMode : WeldHeadManipulatorControlMode;
            END_VAR
        END_METHOD
    END_INTERFACE

    /// Class that wraps all axes that are used to manipulate the welding head.
    /// Depending on the hardware configuration this may include:
    /// - Horizontal slide axis
    /// - Vertical slide axis
    /// - Tilt (Not implemented)
    /// - Clock position slide (Not implemented)
    CLASS WeldHeadManipulator EXTENDS Asset IMPLEMENTS IAssetRequester, IWeldHeadManipulator, IPositionChangedListener
        VAR PRIVATE
            _runtimeParameters : REF_TO WeldHeadManipulatorRuntimeParameters;
            _hardwareConfiguration : REF_TO WeldHeadManipulatorHardwareConfiguration;
            _assetsManager : IAssetsManager;

            _horizontalSlide : IAxis;
            _verticalSlide : IAxis;

            _horizontalSlideObservable : REF_TO AxisObservable;
            _verticalSlideObservable : REF_TO AxisObservable;

            _horizontalSlideCommand : Esab.Motion.AxisPositioningCommand;
            _verticalSlideCommand : Esab.Motion.AxisPositioningCommand;

            _currentJogDirection : JoystickPosition := JoystickPosition#None;
            _motionJoystick : IJoystick := NULL;
        END_VAR

        METHOD PUBLIC Setup
            VAR_INPUT
                runtimeParameters : REF_TO WeldHeadManipulatorRuntimeParameters;
                hardwareConfiguration : REF_TO WeldHeadManipulatorHardwareConfiguration;
                assetsManager : IAssetsManager;
                setupAlarm : IAlarm;
            END_VAR

            _runtimeParameters := runtimeParameters;
            _hardwareConfiguration := hardwareConfiguration;
            _assetsManager := assetsManager;

            _isSetup := _runtimeParameters <> NULL AND _hardwareConfiguration <> NULL AND _assetsManager <> NULL;
        END_METHOD

        METHOD PUBLIC OVERRIDE Execute
            SUPER.Execute();

            IF _setupAlarm.IsActive() THEN
                RETURN;
            END_IF;

            THIS.RequestMotionJoystick();

            IF _horizontalSlideObservable = NULL THEN
                _horizontalSlideObservable ?= _assetsManager.ObserveAsset(Esab.AssetIdentifier#HorizontalSlideAxis);
            END_IF;

            IF _verticalSlideObservable = NULL THEN
                _verticalSlideObservable ?= _assetsManager.ObserveAsset(Esab.AssetIdentifier#VerticalSlideAxis);
            END_IF;

            IF _runtimeParameters^.controlMode = WeldHeadManipulatorControlMode#JoystickJog THEN
                THIS.HandleSlideJog();
            END_IF;
        END_METHOD

        METHOD PUBLIC Enable : WeldHeadManipulatorErrorCode
            VAR_TEMP
                currentPosition : ARRAY [0..1] OF LREAL;
            END_VAR

            IF NOT THIS.RequestAndLockAxis() THEN
                Enable := WeldHeadManipulatorErrorCode#AssetsNotAvailable;
                RETURN;
            END_IF;

            IF NOT _horizontalSlide.IsEnabled() THEN
                _horizontalSlide.PowerOn();
            END_IF;

            IF NOT _verticalSlide.IsEnabled() THEN
                _verticalSlide.PowerOn();
            END_IF;

            IF _horizontalSlide.HasError() OR _verticalSlide.HasError() THEN
                Enable := WeldHeadManipulatorErrorCode#AxisError;
                RETURN;
            END_IF;

            currentPosition[0] := _horizontalSlide.ActualLinearPosition();
            currentPosition[1] := _verticalSlide.ActualLinearPosition();

            THIS.Move(currentPosition, -1.0);
        END_METHOD

        METHOD PUBLIC Disable
            IF _horizontalSlide <> NULL THEN
                _horizontalSlide.Halt();
            END_IF;

            IF _verticalSlide <> NULL THEN
                _verticalSlide.Halt();
            END_IF;

            THIS.UnlockAxis();
        END_METHOD

        METHOD PUBLIC Move : WeldHeadManipulatorErrorCode
            VAR_INPUT
                position : ARRAY [0..1] OF LREAL := [0.0, 0.0];
                speed : LREAL := -1;
            END_VAR

            VAR_TEMP
                speedComponents : ARRAY [0..1] OF LREAL;
                currentPosition : ARRAY [0..1] OF LREAL;
            END_VAR

            IF _horizontalSlide = NULL OR _verticalSlide = NULL THEN
                Move := WeldHeadManipulatorErrorCode#AssetsNotAvailable;
                RETURN;
            END_IF;

            IF _horizontalSlide.HasError() OR _verticalSlide.HasError() THEN
                Move := WeldHeadManipulatorErrorCode#AxisError;
                RETURN;
            END_IF;

            currentPosition[0] := _horizontalSlide.ActualLinearPosition();
            currentPosition[1] := _verticalSlide.ActualLinearPosition();

            IF speed > 1.0 THEN
                speedComponents := THIS.CalculateSpeed(speed, currentPosition, position);
            ELSIF speed < 0.0 THEN
                speedComponents := THIS.CalculateSpeed(_runtimeParameters^.defaultSpeed, currentPosition, position);
            ELSE
                Move := WeldHeadManipulatorErrorCode#SpeedSetTooLow;
                RETURN;
            END_IF;

            _horizontalSlideCommand.CommandType := AxisCommandType#Absolute;
            _horizontalSlideCommand.Velocity := speedComponents[0];
            _horizontalSlideCommand.Position := position[0];

            _verticalSlideCommand.CommandType := AxisCommandType#Absolute;
            _verticalSlideCommand.Velocity := speedComponents[1];
            _verticalSlideCommand.Position := position[1];

            _horizontalSlide.ExecutePositioningCommand(_horizontalSlideCommand);
            _verticalSlide.ExecutePositioningCommand(_verticalSlideCommand);
        END_METHOD

        METHOD PUBLIC Move : WeldHeadManipulatorErrorCode
            VAR_INPUT
                position : ARRAY [0..1] OF LREAL := [0.0, 0.0];
                speed : ARRAY [0..1] OF LREAL := [-1.0, -1.0];
            END_VAR

            VAR_TEMP
                speedComponents : ARRAY [0..1] OF LREAL;
            END_VAR

            IF _horizontalSlide = NULL OR _verticalSlide = NULL THEN
                Move := WeldHeadManipulatorErrorCode#AssetsNotAvailable;
                RETURN;
            END_IF;

            IF _horizontalSlide.HasError() OR _verticalSlide.HasError() THEN
                Move := WeldHeadManipulatorErrorCode#AxisError;
                RETURN;
            END_IF;

            IF _runtimeParameters^.controlMode <> WeldHeadManipulatorControlMode#MoveToPosition THEN
                Move := WeldHeadManipulatorErrorCode#IncorrectControlMode;
                RETURN;
            END_IF;

            speedComponents := speed;

            _horizontalSlideCommand.CommandType := AxisCommandType#Absolute;
            _horizontalSlideCommand.Velocity := speedComponents[0];
            _horizontalSlideCommand.Position := position[0];

            _verticalSlideCommand.CommandType := AxisCommandType#Absolute;
            _verticalSlideCommand.Velocity := speedComponents[1];
            _verticalSlideCommand.Position := position[1];

            _horizontalSlide.ExecutePositioningCommand(_horizontalSlideCommand);
            _verticalSlide.ExecutePositioningCommand(_verticalSlideCommand);
        END_METHOD

        METHOD PUBLIC IsEnabled : BOOL
            IF THIS.InControl() THEN
                IsEnabled := _horizontalSlide.IsEnabled() AND _verticalSlide.IsEnabled();
            ELSE
                IsEnabled := FALSE;
            END_IF;
        END_METHOD

        METHOD PUBLIC GetPosition : ARRAY [0..1] OF LREAL
            IF _horizontalSlideObservable <> NULL AND _verticalSlideObservable <> NULL THEN
                GetPosition[0] := _horizontalSlideObservable^.LinearPosition;
                GetPosition[1] := _verticalSlideObservable^.LinearPosition;
            END_IF;
        END_METHOD

        METHOD PUBLIC GetSpeed : LREAL
            IF _horizontalSlideObservable <> NULL AND _verticalSlideObservable <> NULL THEN
                GetSpeed := Sqrt(_horizontalSlideObservable^.LinearVelocity * _horizontalSlideObservable^.LinearVelocity +
                                 _verticalSlideObservable^.LinearVelocity * _verticalSlideObservable^.LinearVelocity);
            END_IF;
        END_METHOD

        METHOD PUBLIC GetVelocity : ARRAY [0..1] OF LREAL
            IF _horizontalSlideObservable <> NULL AND _verticalSlideObservable <> NULL THEN
                GetVelocity[0] := _horizontalSlideObservable^.LinearVelocity;
                GetVelocity[1] := _verticalSlideObservable^.LinearVelocity;
            END_IF;
        END_METHOD

        METHOD PUBLIC GetControlMode : WeldHeadManipulatorControlMode
            GetControlMode := _runtimeParameters^.controlMode;
        END_METHOD

        METHOD PUBLIC SetControlMode
            VAR_INPUT
                controlMode : WeldHeadManipulatorControlMode;
            END_VAR;

            IF controlMode <> WeldHeadManipulatorControlMode#JoystickJog THEN
                _currentJogDirection := JoystickPosition#None;
            END_IF;

            _runtimeParameters^.controlMode := controlMode;
        END_METHOD

        METHOD PUBLIC AssetAssigned
            VAR_INPUT
                asset : REF_TO Esab.Utils.Assets.Asset;
            END_VAR

            ;
        END_METHOD

        METHOD PUBLIC AssetRemoved
            VAR_INPUT
                identifier : INT;
            END_VAR

            ;
        END_METHOD

        METHOD PUBLIC OVERRIDE Observe : IAssetObservable
            ;
        END_METHOD

        METHOD PRIVATE RequestAndLockAxis : BOOL
            VAR_TEMP
                success : BOOL := TRUE;
                asset : REF_TO Asset := NULL;
            END_VAR

            IF _hardwareConfiguration^.horizontalSlideAxis AND _horizontalSlide = NULL THEN
                asset := _assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#HorizontalSlideAxis);
                IF asset <> NULL THEN
                    _horizontalSlide ?= asset^;
                ELSE
                    success := FALSE;
                END_IF;
            END_IF;

            IF _hardwareConfiguration^.verticalSlideAxis AND _verticalSlide = NULL THEN
                asset := _assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#VerticalSlideAxis);
                IF asset <> NULL THEN
                    _verticalSlide ?= asset^;
                ELSE
                    success := FALSE;
                END_IF;
            END_IF;

            IF success THEN
                IF _horizontalSlide <> NULL THEN
                    asset ?= _horizontalSlide;
                    asset^.Lock();
                END_IF;

                IF _verticalSlide <> NULL THEN
                    asset ?= _verticalSlide;
                    asset^.Lock();
                END_IF;
            END_IF;

            RequestAndLockAxis := success;
        END_METHOD

        METHOD PRIVATE InControl : BOOL
            VAR_TEMP
                asset : REF_TO asset;
            END_VAR

            InControl := TRUE;

            IF _horizontalSlide <> NULL THEN
                asset ?= _horizontalSlide;
                IF NOT asset^.IsLocked() THEN
                    InControl := FALSE;
                END_IF;
            ELSE
                InControl := FALSE;
            END_IF;

            IF _verticalSlide <> NULL THEN
                asset ?= _verticalSlide;
                IF NOT asset^.IsLocked() THEN
                    InControl := FALSE;
                END_IF;
            ELSE
                InControl := FALSE;
            END_IF;
        END_METHOD

        METHOD PRIVATE UnlockAxis
            VAR_TEMP
                asset : REF_TO Asset;
            END_VAR

            IF _horizontalSlide <> NULL THEN
                asset ?= _horizontalSlide;
                asset^.Unlock();
            END_IF;

            IF _verticalSlide <> NULL THEN
                asset ?= _verticalSlide;
                asset^.Unlock();
            END_IF;
        END_METHOD

        METHOD PRIVATE CalculateSpeed : ARRAY [0..1] OF LREAL
            VAR_INPUT
                speed : LREAL;
                currentPosition : ARRAY [0..1] OF LREAL;
                targetPosition : ARRAY [0..1] OF LREAL;
            END_VAR

            VAR_TEMP
                theta : LREAL;
                distance : ARRAY [0..1] OF LREAL;
            END_VAR

            distance[0] := Abs(targetPosition[0]-currentPosition[0]);
            distance[1] := Abs(targetPosition[1]-currentPosition[1]);

            theta := ATan(distance[1] / distance[0]);

            CalculateSpeed[0] := speed * Cos(theta);
            CalculateSpeed[1] := speed * Sin(theta);

            IF CalculateSpeed[0] < 1.0 THEN
                CalculateSpeed[0] := 1.0;
            END_IF;

            IF CalculateSpeed[1] < 1.0 THEN
                CalculateSpeed[1] := 1.0;
            END_IF;
        END_METHOD

        METHOD PUBLIC OnPositionChanged
            VAR_INPUT
                position : JoystickPosition;
            END_VAR
                IF _runtimeParameters^.controlMode <> WeldHeadManipulatorControlMode#JoystickJog THEN
                    RETURN;
                END_IF;

                _currentJogDirection := position;
        END_METHOD

        METHOD PRIVATE HandleSlideJog
            IF _horizontalSlide = NULL OR _verticalSlide = NULL THEN
                RETURN;
            END_IF;

            IF _horizontalSlide.HasError() OR _verticalSlide.HasError() THEN
                RETURN;
            END_IF;

            CASE _currentJogDirection OF
                JoystickPosition#None:
                    _horizontalSlide.Halt();
                    _verticalSlide.Halt();
                JoystickPosition#Center:
                    _horizontalSlide.Halt();
                    _verticalSlide.Halt();
                JoystickPosition#Up:
                    _horizontalSlide.Halt();
                    _verticalSlide.JogPositive();
                JoystickPosition#Down:
                    _horizontalSlide.Halt();
                    _verticalSlide.JogNegative();
                JoystickPosition#Square:
                    _horizontalSlide.JogPositive();
                    _verticalSlide.Halt();
                JoystickPosition#Triangle:
                    _horizontalSlide.JogNegative();
                    _verticalSlide.Halt();
            END_CASE;
        END_METHOD

        METHOD PRIVATE RequestMotionJoystick
            VAR_TEMP
                assetHandle : REF_TO Asset;
            END_VAR

            IF _motionJoystick = NULL THEN
                assetHandle := THIS._assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#P_Joystick_MotionJoystick);

                IF assetHandle <> NULL THEN
                    _motionJoystick ?= assetHandle^;
                    IF _motionJoystick <> NULL THEN
                        _motionJoystick.SetPositionChangedListener(THIS);
                    END_IF;
                END_IF;
            END_IF;
        END_METHOD

    END_CLASS

    TYPE
        WeldHeadManipulatorRuntimeParameters : STRUCT
        /// Speed used when move command speed < 0.0
            defaultSpeed : LREAL := 10.0;
            controlMode : WeldHeadManipulatorControlMode;
        END_STRUCT;

        WeldHeadManipulatorHardwareConfiguration : STRUCT
            /// X-axis
            horizontalSlideAxis : BOOL := TRUE;
            /// Z-axis
            verticalSlideAxis : BOOL := TRUE;
        END_STRUCT;

        WeldHeadManipulatorErrorCode : INT(
            NoError := 0,
            AssetsNotAvailable := 1,
            AxisError := 2,
            SpeedSetTooLow := 3,
            IncorrectControlMode := 4
        ) := WeldHeadManipulatorErrorCode#NoError;

        WeldHeadManipulatorControlMode : INT(
            NoControl := 0,
            JoystickJog := 1,
            MoveToPosition := 2
        ) := WeldHeadManipulatorControlMode#NoControl;
    END_TYPE
END_NAMESPACE