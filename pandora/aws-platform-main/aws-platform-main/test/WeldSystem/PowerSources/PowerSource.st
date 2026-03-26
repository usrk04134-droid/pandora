USING AxUnit;

NAMESPACE Esab.WeldSystem.PowerSources.Test

    {TestFixture}
    CLASS MotorConfigurationTests
        VAR PRIVATE
            _configuration : MotorConfiguration;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            ;
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            ;
        END_METHOD

        {Test}
        METHOD PUBLIC ScaleFactorCalculation
            VAR_TEMP
                _scaleFactor1 : UINT;
                _scaleFactor2 : UINT;
            END_VAR

            // Uses the example VEC4000 values from the PAB Fieldbus profile documentation
            _configuration.Gear.N1 := UINT#156;
            _configuration.Gear.N2 := UINT#1;
            _configuration.Rpm := UINT#4800;
            _configuration.FeedRollDiameter := UINT#49;
            _configuration.EncoderPpr := UINT#32;

            CalculateMotorScaleFactors(REF(_configuration), _scaleFactor1, _scaleFactor2);

            Assert.Equal(_scaleFactor1, UINT#4737);
            Assert.Equal(_scaleFactor2, UINT#2560);
        END_METHOD
    END_CLASS

END_NAMESPACE