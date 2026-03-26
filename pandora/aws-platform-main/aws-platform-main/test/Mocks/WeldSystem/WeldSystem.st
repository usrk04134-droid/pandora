USING Esab.Mock;
USING Esab.Mock;
USING Esab.Mock;
USING Esab.Mock;
USING Esab.Utils.Assets;

NAMESPACE Esab.WeldSystem.Mock
    CLASS WeldSystemOrchestratorMock EXTENDS Asset IMPLEMENTS IWeldSystemOrchestrator
        VAR PUBLIC
            StartMock : WeldSystemOrchestratorErrorCodeMethodMock;
            StopMock : BoolMethodMock;
            SwitchWeldDataSetMock : SwitchWeldDataSetMethodMock;
            AttachPowerSourceMock : IntMethodMock;
            DetachPowerSourceMock : IntMethodMock;
            GetPowerSourceSetPointsMock : GetPowerSourceSetPointsMethodMock;
            SetStartModeMock : Esab.WeldSystem.PowerSources.Mock.StartTypeMethodMock;
            GetHeadTorchIndexMock : IntMethodMock;
            GetNextEnabledPowerSourceMock : IntIntMethodMock;
            StartWeldingMock : IntMethodMock;
            StopWeldingMock : IntMethodMock;
            IsWeldingMock : BoolMethodMock;
            IsWeldingIndexedMock : IntBoolMethodMock;
            ReadyToWeldMock : BoolMethodMock;
            WireOffsetMock : IntLRealMethodMock;
        END_VAR

        METHOD PUBLIC MockReset
            StartMock.Reset();
            StopMock.Reset();
            SwitchWeldDataSetMock.Reset();
            AttachPowerSourceMock.Reset();
            DetachPowerSourceMock.Reset();
        END_METHOD

        METHOD PUBLIC Start
            VAR_OUTPUT
                error : WeldSystemOrchestratorErrorCode;
            END_VAR

            StartMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC Stop
            VAR_INPUT
                noStopPhase : BOOL;
            END_VAR

            StopMock.Value := noStopPhase;
            StopMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC SwitchWeldDataSet
            VAR_INPUT
                id : INT;
            END_VAR

            VAR_OUTPUT
                error : WeldSystemOrchestratorErrorCode;
            END_VAR

            SwitchWeldDataSetMock.Id := id;
            SwitchWeldDataSetMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC AttachPowerSource
            VAR_INPUT
                id : INT;
            END_VAR

            AttachPowerSourceMock.Value := id;
            AttachPowerSourceMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC DetachPowerSource
            VAR_INPUT
                id : INT;
            END_VAR

            DetachPowerSourceMock.Value := id;
            DetachPowerSourceMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC OVERRIDE Observe : IAssetObservable
            Observe := NULL;
        END_METHOD

        METHOD PUBLIC GetPowerSourceSetPoints : REF_TO Esab.WeldSystem.PowerSources.SetPoints
            VAR_INPUT
                id : INT;
                active : BOOL := TRUE;
            END_VAR

            VAR_OUTPUT
                error : WeldSystemOrchestratorErrorCode;
            END_VAR

            GetPowerSourceSetPointsMock.IncrementCallCount();
            GetPowerSourceSetPointsMock.Id := id;
            GetPowerSourceSetPointsMock.Active := active;
            error := GetPowerSourceSetPointsMock.Error;

            GetPowerSourceSetPoints := GetPowerSourceSetPointsMock.Value;
        END_METHOD

        METHOD PUBLIC SetStartMode
            VAR_INPUT
                startMode : Esab.WeldSystem.PowerSources.StartType;
            END_VAR

            SetStartModeMock.IncrementCallCount();
            SetStartModeMock.Value := startMode;
        END_METHOD

        METHOD PUBLIC GetHeadTorchIndex : INT
            GetHeadTorchIndexMock.IncrementCallCount();
            GetHeadTorchIndex := GetHeadTorchIndexMock.Value;
        END_METHOD

        METHOD PUBLIC GetNextEnabledPowerSource : INT
            VAR_INPUT
                index : INT;
            END_VAR

            GetNextEnabledPowerSourceMock.IncrementCallCount();
            GetNextEnabledPowerSourceMock.Value1 := index;
            GetNextEnabledPowerSource := GetNextEnabledPowerSourceMock.Value2;
        END_METHOD

        METHOD PUBLIC StartWelding
            VAR_INPUT
                index : INT;
            END_VAR

            StartWeldingMock.IncrementCallCount();
            StartWeldingMock.Value := index;
        END_METHOD

        METHOD PUBLIC StopWelding
            VAR_INPUT
                index : INT;
            END_VAR

            StopWeldingMock.IncrementCallCount();
            StopWeldingMock.Value := index;
        END_METHOD

        METHOD PUBLIC IsWelding : BOOL
            IsWeldingMock.IncrementCallCount();
            IsWelding := IsWeldingMock.Value;
        END_METHOD

        METHOD PUBLIC IsWelding : BOOL
            VAR_INPUT
                index : INT;
            END_VAR

            IsWeldingIndexedMock.IncrementCallCount();
            IsWeldingIndexedMock.Value1 := index;
            IsWelding := IsWeldingIndexedMock.Value2;
        END_METHOD

        METHOD PUBLIC ReadyToWeld : BOOL
            ReadyToWeldMock.IncrementCallCount();
            ReadyToWeld := ReadyToWeldMock.Value;
        END_METHOD

        METHOD PUBLIC WireOffset : LREAL
            VAR_INPUT
                index : INT;
            END_VAR

            WireOffsetMock.IncrementCallCount();
            WireOffsetMock.Value1 := index;
            WireOffset := WireOffsetMock.Value2;
        END_METHOD
    END_CLASS

    CLASS SwitchWeldDataSetMethodMock EXTENDS WeldSystemOrchestratorErrorCodeMethodMock
        VAR PUBLIC
            Id : INT;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();

            Id := -1;
        END_METHOD
    END_CLASS

    CLASS WeldSystemOrchestratorErrorCodeMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value : WeldSystemOrchestratorErrorCode;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();

            Value := -1;
        END_METHOD

    END_CLASS

    CLASS GetPowerSourceSetPointsMethodMock EXTENDS Esab.WeldSystem.PowerSources.Mock.SetPointsRefMethodMock
        VAR PUBLIC
            Id : INT;
            Active : BOOL;
            Error : WeldSystemOrchestratorErrorCode;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();

            Id := -1;
            Active := FALSE;
            Error := -1;
            Value := NULL;
        END_METHOD
    END_CLASS
END_NAMESPACE