USING Esab.Mock;
USING Esab.WeldSystem.Flux;
USING Esab.Utils.Assets;

CLASS FluxSystemMock EXTENDS Asset IMPLEMENTS IFluxSystem
    VAR PUBLIC
        IsInitializedMock : BoolMethodMock;
        ExecuteMock : MethodMock;
        ReleaseMock : MethodMock;
        RecoverMock : MethodMock;
        StopReleaseMock : MethodMock;
        StopRecoverMock : MethodMock;
        IsReleasingMock : BoolMethodMock;
        IsRecoveringMock : BoolMethodMock;
        ObserveMock : MethodMock;
        ObservableMock : FluxSystemObservable;
    END_VAR

    VAR PRIVATE
        _observable : FluxSystemObservable;
    END_VAR

    METHOD PUBLIC MockReset
        IsInitializedMock.Reset();
        ExecuteMock.Reset();
        ReleaseMock.Reset();
        RecoverMock.Reset();
        StopReleaseMock.Reset();
        StopRecoverMock.Reset();
        IsReleasingMock.Reset();
        IsRecoveringMock.Reset();
        ObserveMock.Reset();

        ObservableMock := _observable;
    END_METHOD

    METHOD PUBLIC IsInitialized : BOOL
        IsInitialized := IsInitializedMock.Value;
        IsInitializedMock.IncrementCallCount();
    END_METHOD

    METHOD PUBLIC OVERRIDE Execute
        ExecuteMock.IncrementCallCount();
    END_METHOD

    METHOD PUBLIC Release
        ReleaseMock.IncrementCallCount();
    END_METHOD

    METHOD PUBLIC Recover
        RecoverMock.IncrementCallCount();
    END_METHOD

    METHOD PUBLIC StopRelease
        StopReleaseMock.IncrementCallCount();
    END_METHOD

    METHOD PUBLIC StopRecover
        StopRecoverMock.IncrementCallCount();
    END_METHOD

    METHOD PUBLIC IsReleasing : BOOL
        IsReleasing := IsReleasingMock.Value;
        IsReleasingMock.IncrementCallCount();
    END_METHOD

    METHOD PUBLIC IsRecovering : BOOL
        IsRecovering := IsRecoveringMock.Value;
        IsRecoveringMock.IncrementCallCount();
    END_METHOD

    METHOD PUBLIC OVERRIDE Observe : IAssetObservable
        Observe := ObservableMock;
        ObserveMock.IncrementCallCount();
    END_METHOD
END_CLASS