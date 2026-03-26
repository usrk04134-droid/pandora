USING Esab.Utils.Alarming.Mock;
USING Esab.WeldSystem.Flux;

USING AxUnit;

NAMESPACE Esab.WeldSystem.Flux.Test

    {TestFixture}
    CLASS BigBagFluxSystemTests
        VAR PRIVATE
            _flux : BigBag.FluxSystem;
            _io : BigBag.Io;
            _bigBagErrorAlarm : AlarmMock;
            _setupAlarm : AlarmMock;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            _flux.Setup(REF(_io), _bigBagErrorAlarm, _setupAlarm);
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            _io.Input.Temperature.Scale := REAL#0.1;
            _io.Input.BigBagError.Read(FALSE);
            _io.Input.Temperature.Read(INT#0);

            _io.Output.Recover.SetValue(FALSE);
            _io.Output.Release.SetValue(FALSE);
        END_METHOD

        {Test}
        METHOD PUBLIC ReleaseRecover
            VAR_TEMP
                _releasing : BOOL;
                _recovering : BOOL;
            END_VAR

            _flux.Release();

            _io.Output.Release.Write(_releasing);
            _io.Output.Recover.Write(_recovering);
            Assert.Equal(_releasing, TRUE);
            Assert.Equal(_recovering, FALSE);
            Assert.Equal(_flux.IsReleasing(), TRUE);
            Assert.Equal(_flux.IsRecovering(), FALSE);

            _flux.Recover();

            _io.Output.Release.Write(_releasing);
            _io.Output.Recover.Write(_recovering);
            Assert.Equal(_releasing, TRUE);
            Assert.Equal(_recovering, TRUE);
            Assert.Equal(_flux.IsReleasing(), TRUE);
            Assert.Equal(_flux.IsRecovering(), TRUE);

            _flux.StopRelease();

            _io.Output.Release.Write(_releasing);
            _io.Output.Recover.Write(_recovering);
            Assert.Equal(_releasing, FALSE);
            Assert.Equal(_recovering, TRUE);
            Assert.Equal(_flux.IsReleasing(), FALSE);
            Assert.Equal(_flux.IsRecovering(), TRUE);

            _flux.StopRecover();

            _io.Output.Release.Write(_releasing);
            _io.Output.Recover.Write(_recovering);
            Assert.Equal(_releasing, FALSE);
            Assert.Equal(_recovering, FALSE);
            Assert.Equal(_flux.IsReleasing(), FALSE);
            Assert.Equal(_flux.IsRecovering(), FALSE);
        END_METHOD

        {Test}
        METHOD PUBLIC AlarmHandling
            _flux.Execute();
            Assert.Equal(_bigBagErrorAlarm.ExecuteMock.GetCallCount(), UINT#1);
            Assert.Equal(_bigBagErrorAlarm.ExecuteMock.SIG, FALSE);

            _io.Input.BigBagError.Read(TRUE);
            _flux.Execute();
            Assert.Equal(_bigBagErrorAlarm.ExecuteMock.SIG, TRUE);

            _io.Input.BigBagError.Read(FALSE);
            _flux.Execute();
            Assert.Equal(_bigBagErrorAlarm.ExecuteMock.SIG, FALSE);
        END_METHOD

        {Test}
        METHOD PUBLIC ReadingTemperature
            _io.Input.Temperature.Read(INT#23);
            _flux.Execute();
            Assert.Equal(_io.Input.Temperature.GetValue(), REAL#2.3);
        END_METHOD
    END_CLASS
END_NAMESPACE