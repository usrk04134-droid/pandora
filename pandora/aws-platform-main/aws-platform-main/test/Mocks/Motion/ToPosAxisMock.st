USING Esab.Mock;
USING Esab.Utils.Assets;

NAMESPACE Esab.Motion.Mock

    CLASS ToPosAxisMock EXTENDS Asset IMPLEMENTS IAxis
        VAR PUBLIC
            PowerOnMock : MethodMock;
            PowerOffMock : MethodMock;
            ResetMock : MethodMock;
            ExecuteMock : MethodMock;
            ExecutePositioningCommandMock : ExecutePositioningCommandMethodMock;
            ExecuteHomingCommandMock : ExecuteHomingCommandMethodMock;
            InvalidateHomingMock : MethodMock;
            HaltMock : MethodMock;
            SetJogSpeedMock : LRealMethodMock;
            SetJogHighSpeedMock : LRealMethodMock;
            SetObjectRadiusMock : LRealMethodMock;
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

        VAR PRIVATE
            _observable : AxisObservable;
        END_VAR

        METHOD PUBLIC MockReset
            PowerOnMock.Reset();
            PowerOffMock.Reset();
            ResetMock.Reset();
            ExecuteMock.Reset();
            ExecutePositioningCommandMock.Reset();
            ExecuteHomingCommandMock.Reset();
            HaltMock.Reset();
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

            ResetMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC OVERRIDE Execute
            ExecuteMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC ExecutePositioningCommand : AxisCommandError
            VAR_INPUT
                command: AxisPositioningCommand;
            END_VAR

            ExecutePositioningCommandMock.IncrementCallCount();
            ExecutePositioningCommandMock.Command := command;
        END_METHOD

        METHOD PUBLIC ExecuteHomingCommand : AxisCommandError
            VAR_INPUT
                command: AxisHomingCommand;
            END_VAR

            ExecuteHomingCommandMock.IncrementCallCount();
            ExecuteHomingCommandMock.Command := command;
        END_METHOD

        METHOD PUBLIC InvalidateHoming
            ;
        END_METHOD

        METHOD PUBLIC Halt
            HaltMock.IncrementCallCount();
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
            Observe := _observable;
        END_METHOD
    END_CLASS

    CLASS ExecutePositioningCommandMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Command : AxisPositioningCommand;
        END_VAR

        VAR PRIVATE
            _defaultCommand : AxisPositioningCommand;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Command := _defaultCommand;
        END_METHOD
    END_CLASS

    CLASS ExecuteHomingCommandMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Command : AxisHomingCommand;
        END_VAR

        VAR PRIVATE
            _defaultCommand : AxisHomingCommand;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Command := _defaultCommand;
        END_METHOD
    END_CLASS

END_NAMESPACE