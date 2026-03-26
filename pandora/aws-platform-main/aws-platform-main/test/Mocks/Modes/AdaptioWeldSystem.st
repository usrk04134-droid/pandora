USING Esab.WeldSystem;
USING Esab.Utils.Fsm;
USING Esab.Mock;

NAMESPACE Esab.Modes.Mock

    CLASS AdaptioWeldSequenceMock IMPLEMENTS IWeldSequence
        VAR PUBLIC
            SetupMock : MethodMock;
            ExecuteMock : MethodMock;
            ResetMock : MethodMock;
            SetWeldAxisMock : MethodMock;
            GetWeldAxisMock : MethodMock;
            SetWeldSystemMock : MethodMock;
            GetWeldSystemMock : MethodMock;
            StartMock : MethodMock;
            StopMock : MethodMock;
            QuickStopMock : MethodMock;
        END_VAR

        METHOD PUBLIC MockReset
            SetupMock.Reset();
            ExecuteMock.Reset();
            ResetMock.Reset();
            SetWeldAxisMock.Reset();
            GetWeldAxisMock.Reset();
            SetWeldSystemMock.Reset();
            GetWeldSystemMock.Reset();
            StartMock.Reset();
            StopMock.Reset();
            QuickStopMock.Reset();
        END_METHOD

        METHOD PUBLIC Setup : StateMachineErrorCode
            VAR_INPUT
                weldAxisObservable : REF_TO Esab.Motion.AxisObservable;
                weldSystem : IWeldSystemOrchestrator;
            END_VAR

            SetupMock.IncrementCallCount();
            Setup := StateMachineErrorCode#NoError;
        END_METHOD

        METHOD PUBLIC Execute : StateMachineErrorCode
            ExecuteMock.IncrementCallCount();
            Execute := StateMachineErrorCode#NoError;
        END_METHOD

        METHOD PUBLIC Reset : StateMachineErrorCode
            ResetMock.IncrementCallCount();
            Reset := StateMachineErrorCode#NoError;
        END_METHOD

        METHOD PUBLIC SetWeldAxis
            VAR_INPUT
                weldAxisObservable : REF_TO Esab.Motion.AxisObservable;
            END_VAR

            SetWeldAxisMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC GetWeldAxis : REF_TO Esab.Motion.AxisObservable
            GetWeldAxisMock.IncrementCallCount();
            GetWeldAxis := NULL;
        END_METHOD

        METHOD PUBLIC SetWeldSystem
            VAR_INPUT
                weldSystem : IWeldSystemOrchestrator;
            END_VAR

            SetWeldAxisMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC GetWeldSystem : IWeldSystemOrchestrator
            GetWeldSystemmock.IncrementCallCount();
            GetWeldSystem := NULL;
        END_METHOD

        METHOD PUBLIC Start
            StartMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC Stop
            StopMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC QuickStop
            QuickStopMock.IncrementCallCount();
        END_METHOD
    END_CLASS


END_NAMESPACE