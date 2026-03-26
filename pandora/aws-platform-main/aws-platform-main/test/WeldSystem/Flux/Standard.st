USING Esab.WeldSystem.Flux;

USING AxUnit;

NAMESPACE Esab.WeldSystem.Flux.Test

    {TestFixture}
    CLASS BasicFluxSystemTests
        VAR PRIVATE
            _flux : Standard.FluxSystem;
            _io : Standard.Io;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            _flux.Setup(REF(_io));
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            _io.Input.LowLevel.Read(FALSE);
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
    END_CLASS

END_NAMESPACE