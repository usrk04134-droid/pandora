USING Esab.Mock;

NAMESPACE Esab.WeldSystem.PowerSources.Mock

    CLASS HeartbeatMock IMPLEMENTS IHeartBeat
        VAR PUBLIC
            IsInitializedMock : BoolMethodMock;
            ExecuteMock : MethodMock;
            AliveMock : BoolMethodMock;
            DeadMock : BoolMethodMock;
        END_VAR

        METHOD PUBLIC MockReset
            IsInitializedMock.Reset();
            ExecuteMock.Reset();
            AliveMock.Reset();
            DeadMock.Reset();
        END_METHOD

        METHOD PUBLIC IsInitialized : BOOL
            IsInitializedMock.IncrementCallCount();
            IsInitialized := IsInitializedMock.Value;
        END_METHOD

        METHOD PUBLIC Execute
            ExecuteMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC Alive : BOOL
            AliveMock.IncrementCallCount();
            Alive := AliveMock.Value;
        END_METHOD

        METHOD PUBLIC Dead : BOOL
            DeadMock.IncrementCallCount();
            Dead := DeadMock.Value;
        END_METHOD
    END_CLASS

END_NAMESPACE