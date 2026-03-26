USING AxUnit;

NAMESPACE Esab.Utils.Filters.Test

    {TestFixture}
    {Category(Filters)}
    CLASS NoFilterTests
        VAR PRIVATE
            _filter : NoFilter;
        END_VAR

        {Test}
        METHOD PUBLIC NoFilter
            _filter.Measurement(1.0);
            Assert.Equal(_filter.Filtered(), 1.0);

            _filter.Measurement(10.0);
            Assert.Equal(_filter.Filtered(), 10.0);

            _filter.Measurement(-5.0);
            Assert.Equal(_filter.Filtered(), -5.0);
        END_METHOD

        {Test}
        METHOD PUBLIC Reset
            _filter.Measurement(1.0);
            Assert.Equal(_filter.Filtered(), 1.0);

            _filter.Reset();
            Assert.Equal(_filter.Filtered(), 0.0);
        END_METHOD
    END_CLASS

END_NAMESPACE