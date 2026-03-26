USING Esab.Io;
USING Esab.Mock;
USING AxUnit;

NAMESPACE Esab.Utils.EmergencyStop.Test

    {TestFixture}
    CLASS EmergencyStopCircuitTests
        VAR PUBLIC
            _circuit : EmergencyStopCircuit;
            _circuitIo : EmergencyStopCircuitIo;
            _circuitObservable : REF_TO EmergencyStopCircuitObservable;
            _listener : ListenerMock;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            _circuit.Io := REF(_circuitIo);
            _circuitObservable ?= _circuit.Observe();
            _circuit.SetListener(_listener);
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            _circuitIo.LoopClosed.Read(TRUE);
            _circuitIo.LoopClosed.Read(TRUE);

            THIS.Execute();
            THIS.Execute();

            _listener.MockReset();
        END_METHOD

        METHOD PRIVATE Execute
            _circuit.Execute();
        END_METHOD

        {Test}
        METHOD PUBLIC Test
            Assert.Equal(_circuit.IsActive(), FALSE);
            Assert.Equal(_circuitObservable^.Active, FALSE);
            Assert.Equal(_listener.EmergencyStopActivatedMock.GetCallCount(), UINT#0);
            Assert.Equal(_listener.EmergencyStopResetMock.GetCallCount(), UINT#0);

            _circuitIo.LoopClosed.Read(FALSE);
            THIS.Execute();

            Assert.Equal(_circuit.IsActive(), TRUE);
            Assert.Equal(_circuitObservable^.Active, TRUE);
            Assert.Equal(_listener.EmergencyStopActivatedMock.GetCallCount(), UINT#1);
            Assert.Equal(_listener.EmergencyStopResetMock.GetCallCount(), UINT#0);

            _circuitIo.LoopClosed.Read(TRUE);
            THIS.Execute();

            Assert.Equal(_circuit.IsActive(), FALSE);
            Assert.Equal(_circuitObservable^.Active, FALSE);
            Assert.Equal(_listener.EmergencyStopActivatedMock.GetCallCount(), UINT#1);
            Assert.Equal(_listener.EmergencyStopResetMock.GetCallCount(), UINT#1);
        END_METHOD
    END_CLASS

    CLASS ListenerMock IMPLEMENTS IEmergencyStopListener
        VAR PUBLIC
            EmergencyStopActivatedMock : MethodMock;
            EmergencyStopResetMock : MethodMock;
        END_VAR

        METHOD PUBLIC MockReset
            EmergencyStopActivatedMock.Reset();
            EmergencyStopResetMock.Reset();
        END_METHOD

        METHOD PUBLIC EmergencyStopActivated
            EmergencyStopActivatedMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC EmergencyStopReset
            EmergencyStopResetMock.IncrementCallCount();
        END_METHOD
    END_CLASS

END_NAMESPACE