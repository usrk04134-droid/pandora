USING AxUnit;

NAMESPACE Esab.Utils.Buffers.Test

    {TestFixture}
    {Category(Buffers)}
    CLASS CircularBufferTests
        VAR PRIVATE
            _buffer : CircularBuffer;
            _data : ARRAY[0..9] OF LREAL;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            _buffer.Buffer := REF(_data);
            _buffer.Size := 10;
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            _buffer.Clear();
        END_METHOD

        {Test}
        METHOD PUBLIC TestFill
            VAR_TEMP
                _index : INT := 0;
            END_VAR

            FOR _index := 0 TO 9 DO
                _buffer.ValueAt(_index, TO_REAL(_index));
            END_FOR;

            FOR _index := 0 TO 9 DO
                Assert.Equal(_buffer.ValueAt(_index), TO_REAL(_index));
            END_FOR;
        END_METHOD

        {Test}
        METHOD PUBLIC TestCircularFill
            VAR_TEMP
                _index : INT := 0;
            END_VAR

            FOR _index := 0 TO 15 DO
                _buffer.ValueAt(_index, TO_REAL(_index));
            END_FOR;

            Assert.Equal(_buffer.ValueAt(0), 10);
            Assert.Equal(_buffer.ValueAt(1), 11);
            Assert.Equal(_buffer.ValueAt(2), 12);
            Assert.Equal(_buffer.ValueAt(3), 13);
            Assert.Equal(_buffer.ValueAt(4), 14);
            Assert.Equal(_buffer.ValueAt(5), 15);
            Assert.Equal(_buffer.ValueAt(6), 6);
            Assert.Equal(_buffer.ValueAt(7), 7);
            Assert.Equal(_buffer.ValueAt(8), 8);
            Assert.Equal(_buffer.ValueAt(9), 9);
        END_METHOD

        {Test}
        METHOD PUBLIC TestCircularReverse
            VAR_TEMP
                _index : INT := 0;
            END_VAR

            FOR _index := 0 TO -15 BY -1 DO
                _buffer.ValueAt(_index, TO_REAL(_index));
            END_FOR;

            Assert.Equal(_buffer.ValueAt(-9), -9);
            Assert.Equal(_buffer.ValueAt(-8), -8);
            Assert.Equal(_buffer.ValueAt(-7), -7);
            Assert.Equal(_buffer.ValueAt(-6), -6);
            Assert.Equal(_buffer.ValueAt(-5), -15);
            Assert.Equal(_buffer.ValueAt(-4), -14);
            Assert.Equal(_buffer.ValueAt(-3), -13);
            Assert.Equal(_buffer.ValueAt(-2), -12);
            Assert.Equal(_buffer.ValueAt(-1), -11);
            Assert.Equal(_buffer.ValueAt(0), -10);
        END_METHOD

        {Test}
        METHOD PUBLIC TestClear
            VAR_TEMP
                _index : INT := 0;
            END_VAR

            FOR _index := 0 TO 15 DO
                _buffer.ValueAt(_index, TO_REAL(_index));
            END_FOR;

            _buffer.Clear();

            Assert.Equal(_buffer.ValueAt(0), 0);
            Assert.Equal(_buffer.ValueAt(1), 0);
            Assert.Equal(_buffer.ValueAt(2), 0);
            Assert.Equal(_buffer.ValueAt(3), 0);
            Assert.Equal(_buffer.ValueAt(4), 0);
            Assert.Equal(_buffer.ValueAt(5), 0);
            Assert.Equal(_buffer.ValueAt(6), 0);
            Assert.Equal(_buffer.ValueAt(7), 0);
            Assert.Equal(_buffer.ValueAt(8), 0);
            Assert.Equal(_buffer.ValueAt(9), 0);
        END_METHOD

        {Test}
        METHOD PUBLIC IndexAt
            Assert.Equal(_buffer.IndexAt(5), 5);
            Assert.Equal(_buffer.IndexAt(12), 2);
            Assert.Equal(_buffer.IndexAt(-5), 5);
        END_METHOD
    END_CLASS

END_NAMESPACE