USING AxUnit;

NAMESPACE Esab.Api.Test

    {TestFixture}
    CLASS DigitalOutputGroupTests
        VAR PRIVATE
            output : DigitalOutputGroup;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            ;
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            output.Output.Reset();
            output.Value := FALSE;
        END_METHOD

        {Test}
        METHOD PUBLIC MyTestMethod
            output.Output.Set();
            Assert.Equal(output.Value, FALSE);
            output.Write();
            Assert.Equal(output.Value, TRUE);

            output.Output.Reset();
            Assert.Equal(output.Value, TRUE);
            output.Write();
            Assert.Equal(output.Value, FALSE);
        END_METHOD
    END_CLASS

END_NAMESPACE