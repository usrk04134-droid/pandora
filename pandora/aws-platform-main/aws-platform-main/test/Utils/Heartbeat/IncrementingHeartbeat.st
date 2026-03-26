USING AxUnit;
USING Esab.Utils.Timer.Mock;
USING Esab.Utils.Alarming.Mock;
USING Esab.Io;

NAMESPACE Esab.Utils.Heartbeat.Test

    {TestFixture}
    {Category(Heartbeat)}
    CLASS IncrementingHeartbeatTests
        VAR PRIVATE
            _heartbeat : IncrementingHeartbeat;

            _input : DIntInput;
            _output : DIntOutput;
            _timer : OnDelayMock;
            _alarm : AlarmMock;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            _heartbeat.Setup(
                _input,
                _output,
                _timer,
                _alarm
            );
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            _input.Read(DINT#0);
            _output.SetValue(DINT#0);
            _alarm.MockReset();
            _timer.MockReset();
        END_METHOD

        {Test}
        METHOD PUBLIC Incrementing
            VAR_TEMP
                out : DINT;
                lastOut : DINT;
            END_VAR

            _output.Write(out);
            lastOut := out;

            _heartbeat.Execute();

            _output.Write(out);
            Assert.Greater(out, lastOut);
            lastOut := out;

            _heartbeat.Execute();

            _output.Write(out);
            Assert.Greater(out, lastOut);
            lastOut := out;
        END_METHOD

        {Test}
        METHOD PUBLIC AlarmTrigger
            VAR_TEMP
                out : DINT;
            END_VAR

            Assert.Equal(_input.GetValue(), DINT#0);

            _heartbeat.Execute();

            Assert.Equal(_alarm.ExecuteMock.GetCallCount(), UINT#1);
            Assert.Equal(_alarm.ExecuteMock.SIG, FALSE);

            _timer.ExpiredMock.Value := TRUE;

            _heartbeat.Execute();

            Assert.Equal(_alarm.ExecuteMock.GetCallCount(), UINT#2);
            Assert.Equal(_alarm.ExecuteMock.SIG, TRUE);
        END_METHOD
    END_CLASS

END_NAMESPACE