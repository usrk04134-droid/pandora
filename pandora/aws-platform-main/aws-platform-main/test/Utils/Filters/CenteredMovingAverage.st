USING AxUnit;

NAMESPACE Esab.Utils.Filters.Test

    {TestFixture}
    {Category(Filters)}
    CLASS MovingAverageTests
        VAR PRIVATE
            _filter : CenteredMovingAverage;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            _filter.SetWindowSize(INT#3);
            _filter.Initialize();
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            _filter.Initialize();
        END_METHOD

        {Test}
        METHOD PUBLIC Fill
            _filter.Measurement(0.0);
            Assert.InRange(_filter.Filtered(), 0.0, 0.01);

            _filter.Measurement(1.0);
            Assert.InRange(_filter.Filtered(), 0.5, 0.01);

            _filter.Measurement(10.0);
            Assert.InRange(_filter.Filtered(), 3.83, 0.01);

            _filter.Measurement(5.0);
            Assert.InRange(_filter.Filtered(), 5.08, 0.01);

            _filter.Measurement(1.0);
            Assert.InRange(_filter.Filtered(), 5.28, 0.01);

            _filter.Measurement(10.0);
            Assert.InRange(_filter.Filtered(), 6.95, 0.01);

            _filter.Measurement(5.0);
            Assert.InRange(_filter.Filtered(), 7.66, 0.01);
        END_METHOD

        {Test}
        METHOD PUBLIC Continuous
            VAR_TEMP
                _index : INT := 0;
                _average : LREAL := 0;
            END_VAR

            FOR _index := 1 TO 7 DO
                _filter.Measurement(_index);
            END_FOR;

            _average := _filter.Filtered();

            FOR _index := 8 TO 20 DO
                _average := _average + (_index - (_index - 7))/7.0;
                _filter.Measurement(_index);
                Assert.Equal(_filter.Filtered(), _average);
            END_FOR;
        END_METHOD
    END_CLASS

END_NAMESPACE