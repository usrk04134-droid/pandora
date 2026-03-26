USING Esab.Mock;
USING Esab.Utils.Assets;
USING Esab.Mock;

NAMESPACE Esab.Motion.Mock
    CLASS WeldHeadManipulatorMock EXTENDS Asset IMPLEMENTS IWeldHeadManipulator
        VAR PUBLIC
            EnableMock : WeldHeadManipulatorErrorCodeMock;
            DisableMock : MethodMock;
            MoveInterpolatedMock : MoveInterpolatedMethodMock;
            MoveMock : MoveMethodMock;
            IsEnabledMock : BoolMethodMock;
            GetPositionMock : LRealArray2MethodMock;
            GetSpeedMock : LRealMethodMock;
            GetVelocityMock : LRealArray2MethodMock;
            GetControlModeMock : GetControlModeMethodMock;
            SetControlModeMock : SetControlModeMethodMock;
        END_VAR

        METHOD PUBLIC MockReset
            EnableMock.Reset();
            DisableMock.Reset();
            MoveMock.Reset();
            IsEnabledMock.Reset();
            GetPositionMock.Reset();
            GetSpeedMock.Reset();
            GetVelocityMock.Reset();
            GetControlModeMock.Reset();
            SetControlModeMock.Reset();
        END_METHOD

        METHOD PUBLIC Enable : WeldHeadManipulatorErrorCode
            EnableMock.IncrementCallCount();
            Enable := EnableMock.ErrorCode;
        END_METHOD

        METHOD PUBLIC Disable
            DisableMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC Move : WeldHeadManipulatorErrorCode
            VAR_INPUT
                position : ARRAY [0..1] OF LREAL := [0.0, 0.0];
                speed : LREAL := -1;
            END_VAR

            MoveInterpolatedMock.Speed := speed;
            MoveInterpolatedMock.Position := position;
            MoveInterpolatedMock.IncrementCallCount();
            Move := MoveMock.ErrorCode;
        END_METHOD

        METHOD PUBLIC Move : WeldHeadManipulatorErrorCode
            VAR_INPUT
                position : ARRAY [0..1] OF LREAL := [0.0, 0.0];
                speed : ARRAY [0..1] OF LREAL := [-1.0, -1.0];
            END_VAR

            MoveMock.Speed := speed;
            MoveMock.Position := position;
            MoveMock.IncrementCallCount();
            Move := MoveMock.ErrorCode;
        END_METHOD

        METHOD PUBLIC IsEnabled : BOOL
            IsEnabledMock.IncrementCallCount();
            IsEnabled := IsEnabledMock.Value;
        END_METHOD

        METHOD PUBLIC OVERRIDE Observe : IAssetObservable
            Observe := NULL;
        END_METHOD

        METHOD PUBLIC GetPosition : ARRAY [0..1] OF LREAL
            GetPositionMock.IncrementCallCount();
            GetPosition := GetPositionMock.Value;
        END_METHOD

        METHOD PUBLIC GetSpeed : LREAL
            GetSpeedMock.IncrementCallCount();
            GetSpeed := GetSpeedMock.Value;
        END_METHOD

        METHOD PUBLIC GetVelocity : ARRAY [0..1] OF LREAL
            GetVelocityMock.IncrementCallCount();
            GetVelocity := GetVelocityMock.Value;
        END_METHOD
    
        METHOD PUBLIC GetControlMode : WeldHeadManipulatorControlMode
            GetControlModeMock.IncrementCallCount();
            GetControlMode := GetControlModeMock.ControlMode;
        END_METHOD 
    
        METHOD PUBLIC SetControlMode
            VAR_INPUT
                controlMode : WeldHeadManipulatorControlMode;
            END_VAR

            SetControlModeMock.ControlMode := controlMode;
            SetControlModeMock.IncrementCallCount();
        END_METHOD
    END_CLASS

    CLASS MoveInterpolatedMethodMock EXTENDS WeldHeadManipulatorErrorCodeMock
        VAR PUBLIC
            Speed : LREAL;
            Position : ARRAY [0..1] OF LREAL;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();

            Speed := -1.0;
            Position[0] := 0.0;
            Position[1] := 0.0;
        END_METHOD
    END_CLASS

    CLASS MoveMethodMock EXTENDS WeldHeadManipulatorErrorCodeMock
        VAR PUBLIC
            Speed : ARRAY [0..1] OF LREAL;
            Position : ARRAY [0..1] OF LREAL;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();

            Speed[0] := -1.0;
            Speed[1] := -1.0;
            Position[0] := 0.0;
            Position[1] := 0.0;
        END_METHOD
    END_CLASS

    CLASS GetControlModeMethodMock EXTENDS WeldHeadManipulatorControlModeMock
    END_CLASS

    CLASS SetControlModeMethodMock EXTENDS MethodMock
        VAR PUBLIC
            ControlMode : WeldHeadManipulatorControlMode := WeldHeadManipulatorControlMode#NoControl;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();

            ControlMode := WeldHeadManipulatorControlMode#NoControl;
        END_METHOD
    END_CLASS

    CLASS WeldHeadManipulatorErrorCodeMock EXTENDS MethodMock
        VAR PUBLIC
            ErrorCode : WeldHeadManipulatorErrorCode;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();

            ErrorCode := WeldHeadManipulatorErrorCode#NoError;
        END_METHOD
    END_CLASS

    CLASS WeldHeadManipulatorControlModeMock EXTENDS MethodMock
        VAR PUBLIC
            ControlMode : WeldHeadManipulatorControlMode;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();

            ControlMode := WeldHeadManipulatorControlMode#NoControl;
        END_METHOD
    END_CLASS

    CLASS LRealArray2MethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value : ARRAY [0..1] OF LREAL;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Value[0] := 0.0;
            Value[1] := 0.0;
        END_METHOD
    END_CLASS
END_NAMESPACE