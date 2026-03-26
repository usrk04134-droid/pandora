USING Esab.Utils.Assets.Mock;
USING Esab.Mock;
USING Esab.Utils.Assets;
USING Esab.Motion;

NAMESPACE Esab.Motion.Mock

    CLASS AnalogAxisMock EXTENDS Asset IMPLEMENTS IAxis
        VAR PUBLIC
            InvalidateHomingMock : MethodMock;
            SetObjectRadiusMock : LRealMethodMock;
            SetJogSpeedMock : LRealMethodMock;
            SetJogHighSpeedMock : LRealMethodMock;
            GetObjectRadiusMock : LRealMethodMock;
            GetObjectCircumferenceMock : LRealMethodMock;
            GetObjectPositionMock : LRealMethodMock;
            GetJogSpeedMock : LRealMethodMock;
            GetJogHighSpeedMock : LRealMethodMock;
            PowerOnMock : MethodMock;
            PowerOffMock : MethodMock;
            ResetMock : BoolMethodMock;
            ExecutePositioningCommandMock : Esab.Motion.Mock.ExecutePositioningCommandMethodMock;
            ExecutePositioningCommandModeMock : ExecutePositioningCommandMethodMock;
            ExecuteHomingCommandMock : Esab.Motion.Mock.ExecuteHomingCommandMethodMock;
            HaltMock : MethodMock;
            JogPositiveMock : BoolMethodMock;
            JogNegativeMock : BoolMethodMock;
            IsEnabledMock : BoolMethodMock;
            IsBusyMock : BoolMethodMock;
            HasErrorMock : BoolMethodMock;
            AtStandstillMock : BoolMethodMock;
            IsHomedMock : BoolMethodMock;
            ActualLinearPositionMock : LRealMethodMock;
            ActualLinearVelocityMock : LRealMethodMock;
            ActualAngularPositionMock : LRealMethodMock;
            ActualAngularVelocityMock : LRealMethodMock;
        END_VAR

        METHOD PUBLIC MockReset
            InvalidateHomingMock.Reset();
            SetObjectRadiusMock.Reset();
            GetObjectRadiusMock.Reset();
            GetObjectCircumferenceMock.Reset();
            GetObjectPositionMock.Reset();
            PowerOnMock.Reset();
            PowerOffMock.Reset();
            ResetMock.Reset();
            ExecutePositioningCommandMock.Reset();
            ExecuteHomingCommandMock.Reset();
            HaltMock.Reset();
            JogPositiveMock.Reset();
            JogNegativeMock.Reset();
            IsEnabledMock.Reset();
            IsBusyMock.Reset();
            HasErrorMock.Reset();
            AtStandstillMock.Reset();
            IsHomedMock.Reset();
            ActualLinearPositionMock.Reset();
            ActualLinearVelocityMock.Reset();
            ActualAngularPositionMock.Reset();
            ActualAngularVelocityMock.Reset();
        END_METHOD

        METHOD PUBLIC InvalidateHoming
            InvalidateHomingMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC SetJogSpeed
            VAR_INPUT
                value : LREAL;
            END_VAR

            SetJogSpeedMock.Value := value;
            SetJogSpeedMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC SetJogHighSpeed
            VAR_INPUT
                value : LREAL;
            END_VAR

            SetJogHighSpeedMock.Value := value;
            SetJogHighSpeedMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC SetObjectRadius
            VAR_INPUT
                value : LREAL;
            END_VAR

            SetObjectRadiusMock.Value := value;
            SetObjectRadiusMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC GetObjectRadius : LREAL
            GetObjectRadius := GetObjectRadiusMock.Value;
            GetObjectRadiusMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC GetObjectCircumference : LREAL
            GetObjectCircumference := GetObjectCircumferenceMock.Value;
            GetObjectCircumferenceMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC GetObjectPosition : LREAL
            GetObjectPosition := GetObjectPositionMock.Value;
            GetObjectPositionMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC GetJogSpeed : LREAL;
            GetJogSpeed := GetJogSpeedMock.Value;
            GetJogSpeedMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC GetJogHighSpeed : LREAL;
            GetJogHighSpeed := GetJogHighSpeedMock.Value;
            GetJogHighSpeedMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC PowerOn
            PowerOnMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC PowerOff
            PowerOffMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC Reset
            VAR_INPUT
                Restart : BOOL;
            END_VAR

            ResetMock.Value := Restart;
            ResetMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC ExecutePositioningCommand : AxisCommandError
            VAR_INPUT
                command : AxisPositioningCommand;
            END_VAR

            ExecutePositioningCommandMock.Command := command;
            ExecutePositioningCommandMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC ExecuteHomingCommand : AxisCommandError
            VAR_INPUT
                command : AxisHomingCommand;
            END_VAR

            ExecuteHomingCommandMock.Command := command;
            ExecuteHomingCommandMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC Halt
            HaltMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC JogPositive
            VAR_INPUT
                highSpeed : BOOL := FALSE;
            END_VAR

            JogPositiveMock.Value := highSpeed;
            JogPositiveMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC JogNegative
            VAR_INPUT
                highSpeed : BOOL := FALSE;
            END_VAR

            JogNegativeMock.Value := highSpeed;
            JogNegativeMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC IsEnabled : BOOL
            IsEnabled := IsEnabledMock.Value;
            IsEnabledMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC IsBusy : BOOL
            IsBusy := IsBusyMock.Value;
            IsBusyMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC HasError : BOOL
            HasError := HasErrorMock.Value;
            HasErrorMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC AtStandstill : BOOL
            AtStandstill := AtStandstillMock.Value;
            AtStandstillMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC IsHomed : BOOL
            IsHomed := IsHomedMock.Value;
            IsHomedMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC ActualLinearPosition : LREAL
            ActualLinearPosition := ActualLinearPositionMock.Value;
            ActualLinearPositionMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC ActualLinearVelocity : LREAL
            ActualLinearVelocity := ActualLinearVelocityMock.Value;
            ActualLinearVelocityMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC ActualAngularPosition : LREAL
            ActualAngularPosition := ActualAngularPositionMock.Value;
            ActualAngularPositionMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC ActualAngularVelocity : LREAL
            ActualAngularVelocity := ActualAngularVelocityMock.Value;
            ActualAngularVelocityMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC OVERRIDE Observe : IAssetObservable
            Observe := NULL;
        END_METHOD
    END_CLASS
END_NAMESPACE