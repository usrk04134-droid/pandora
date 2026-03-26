USING Esab.Utils.Buffers;

NAMESPACE Esab.Utils.Filters

    CLASS CenteredMovingAverage IMPLEMENTS IFilter
        VAR CONSTANT PUBLIC
            MAX_WINDOW_SIZE : INT := INT#10;
        END_VAR

        VAR PRIVATE
            _buffer : CircularBuffer;
            _samples : ARRAY[0..(MAX_WINDOW_SIZE*2)] OF LREAL;
            _numberOfSamplesInBuffer : INT := 0;
            _currentIndex : INT := 0;
            _currentAverage : LREAL := 0.0;
        END_VAR

        METHOD PUBLIC Initialize
            _buffer.Buffer := REF(_samples);
            THIS.Reset();
        END_METHOD

        METHOD PUBLIC Measurement
            VAR_INPUT
                value : LREAL;
            END_VAR

            VAR_TEMP
                _lastValue : LREAL := 0.0;
            END_VAR

            _lastValue := _buffer.ValueAt(_currentIndex);
            _buffer.ValueAt(_currentIndex, value);

            IF _numberOfSamplesInBuffer < _buffer.Size THEN
                _numberOfSamplesInBuffer := _numberOfSamplesInBuffer + 1;
            END_IF;

            _currentAverage := _currentAverage + (_buffer.ValueAt(_currentIndex) - _lastValue)/_numberOfSamplesInBuffer;

            _currentIndex := _buffer.IndexAt(_currentIndex + 1);
        END_METHOD

        METHOD PUBLIC Filtered : LREAL
            Filtered := _currentAverage;
        END_METHOD

        /// Sets the window size.
        /// This defines how many samples are used on each side of the sample being averaged.
        /// Ex: SetWindowSize(3)
        /// -> 1 2 3 4 5 6 7
        ///          ↑
        ///    Averaged sample
        ///
        /// Maximum value = MAX_WINDOW_SIZE
        METHOD PUBLIC SetWindowSize
            VAR_INPUT
                size : INT;
            END_VAR

            VAR_TEMP
                _size : INT;
            END_VAR

            _size := size;

            IF _size > MAX_WINDOW_SIZE THEN
                _size := MAX_WINDOW_SIZE;
            END_IF;

            IF _size < 1 THEN
                _size := 1;
            END_IF;

            _buffer.Size := _size * 2 + 1;
        END_METHOD

        METHOD PUBLIC Reset
            _currentAverage := 0;
            _currentIndex := 0;
            _numberOfSamplesInBuffer := 0;
            _buffer.Clear();
        END_METHOD
    END_CLASS

END_NAMESPACE