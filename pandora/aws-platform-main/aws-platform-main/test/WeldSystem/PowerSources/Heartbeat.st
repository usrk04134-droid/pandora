USING Esab.Utils.Timer.Mock;
USING Esab.Io.Mock;

USING AxUnit;

NAMESPACE Esab.WeldSystem.PowerSources.Test

    {TestFixture}
    {Category(WeldSystem)}
    CLASS HeartbeatTests

        VAR PRIVATE
            _input : UIntInputMock;
            _timer : OnDelayMock;
            _heartbeat : Heartbeat;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            _heartbeat.Input := _input;
            _heartbeat.Timer := _timer;
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            _heartbeat.Input := _input;
            _heartbeat.Timer := _timer;
            _input.MockReset();
            _timer.MockReset();
        END_METHOD

        {Test}
        METHOD PUBLIC NullInitialized
            _heartbeat.Input := NULL;
            _heartbeat.Timer := NULL;

            Assert.Equal(_heartbeat.IsInitialized(), FALSE);
            _heartbeat.Execute(); // Should not crash
        END_METHOD

        {Test}
        METHOD PUBLIC Alive
            _timer.ExpiredMock.Value := FALSE;
            _heartbeat.Execute();

            Assert.Equal(_heartbeat.Alive(), TRUE);
        END_METHOD

        {Test}
        METHOD PUBLIC Dead
            _timer.ExpiredMock.Value := TRUE;
            _heartbeat.Execute();

            Assert.Equal(_heartbeat.Dead(), TRUE);
        END_METHOD
    END_CLASS

END_NAMESPACE