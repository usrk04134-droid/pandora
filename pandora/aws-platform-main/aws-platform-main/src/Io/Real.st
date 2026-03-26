USING Esab.Utils;

USING System.FastMath;

NAMESPACE Esab.Io

    INTERFACE IRealInput
        /// Reads a new value
        /// The value will be read, and scaling applied.
        METHOD Read
            VAR_INPUT
                value : REAL;
            END_VAR
        END_METHOD

        /// Reads a new value (DWORD)
        /// Here it is assumed that the DWORD bytes are representing a REAL
        METHOD Read
            VAR_INPUT
                value : DWORD;
            END_VAR
        END_METHOD

        /// Reads a new value (UINT)
        /// The value will be read, converted to real, and scaling applied.
        METHOD Read
            VAR_INPUT
                value : UINT;
            END_VAR
        END_METHOD

        /// Reads a new value (INT)
        /// The value will be read, converted to real, and scaling applied.
        METHOD Read
            VAR_INPUT
                value : INT;
            END_VAR
        END_METHOD

        /// Returns the last value read
        METHOD GetValue : REAL
        END_METHOD
    END_INTERFACE

    INTERFACE IRealOutput
        /// Writes the value to the output
        METHOD Write
            VAR_OUTPUT
                value : REAL;
            END_VAR
        END_METHOD

        /// Writes the value to the output (DWORD)
        METHOD Write
            VAR_OUTPUT
                value : DWORD;
            END_VAR
        END_METHOD

        /// Writes the value to the output (INT)
        METHOD Write
            VAR_OUTPUT
                value : INT;
            END_VAR
        END_METHOD

        /// Sets the current value to the given value
        METHOD SetValue
            VAR_INPUT
                value: REAL;
            END_VAR
        END_METHOD
    END_INTERFACE

    CLASS RealInput EXTENDS Input IMPLEMENTS IRealInput
        VAR PUBLIC
            /// Delta used when deciding if this input has changed
            ChangeDelta : REAL := REAL#0.01;
            /// Scaling will be applied when reading the input
            /// E.g. if the input read is a DINT with the unit 0.1 radishes, a scale of 0.1 will result in GetValue() returning a
            /// REAL with the unit 1.0 radishes, so input = DINT#2 -> GetValue() = 0.2 radishes.
            Scale : REAL := REAL#1.0;
        END_VAR

        VAR PRIVATE
            _lastValue : REAL;
            _value : REAL;
        END_VAR

        METHOD PUBLIC Read
            VAR_INPUT
                value : REAL;
            END_VAR

            VAR_TEMP
                convertedValue : REAL;
            END_VAR

            convertedValue := value;

            IF endianness = Endianness#Little THEN
                convertedValue := TO_REAL(Flip(value));
            END_IF;

            _lastValue := _value;
            _value := convertedValue * THIS.Scale;

            IF THIS.HasChanged() AND _inputChangedHandler <> NULL THEN
                _inputChangedHandler.InputChanged(REF(THIS));
            END_IF;
        END_METHOD

        METHOD PUBLIC Read
            VAR_INPUT
                value : DWORD;
            END_VAR

            VAR_TEMP
                convertedValue : REAL;
            END_VAR

            convertedValue := TO_REAL(value);

            IF THIS.Endianness = Endianness#Little THEN
                convertedValue := TO_REAL(Flip(value));
            END_IF;

            _lastValue := _value;
            _value := convertedValue * THIS.Scale;

            IF THIS.HasChanged() AND _inputChangedHandler <> NULL THEN
                _inputChangedHandler.InputChanged(REF(THIS));
            END_IF;
        END_METHOD

        METHOD PUBLIC Read
            VAR_INPUT
                value : UINT;
            END_VAR

            VAR_TEMP
                convertedValue : REAL;
            END_VAR

            convertedValue := TO_REAL(value);

            IF THIS.Endianness = Endianness#Little THEN
                convertedValue := TO_REAL(Flip(TO_REAL(value)));
            END_IF;

            _lastValue := _value;
            _value := convertedValue * THIS.Scale;

            IF THIS.HasChanged() AND _inputChangedHandler <> NULL THEN
                _inputChangedHandler.InputChanged(REF(THIS));
            END_IF;
        END_METHOD

        METHOD PUBLIC Read
            VAR_INPUT
                value : INT;
            END_VAR

            VAR_TEMP
                convertedValue : REAL;
            END_VAR

            convertedValue := value;

            IF THIS.Endianness = Endianness#Little THEN
                convertedValue := TO_REAL(Flip(TO_REAL(value)));
            END_IF;

            _lastValue := _value;
            _value := convertedValue * THIS.Scale;

            IF THIS.HasChanged() AND _inputChangedHandler <> NULL THEN
                _inputChangedHandler.InputChanged(REF(THIS));
            END_IF;
        END_METHOD

        METHOD PUBLIC GetValue : REAL
            GetValue := _value;
        END_METHOD

        METHOD PUBLIC OVERRIDE HasChanged : BOOL
            HasChanged := ABS(_lastValue - _value) > ChangeDelta;
        END_METHOD
    END_CLASS

    /// Implements a normalized real input.
    /// If bipolar = TRUE then the value in the range [Minimum, Maximum] will be normalized to [-1.0, 1.0]
    /// If bipolar = FALSE then the value in the range [Minimum, Maximum] will be normalized to [0.0, 1.0] (this is the default)
    CLASS RealNormalizedInput EXTENDS Input IMPLEMENTS IRealInput
        VAR PUBLIC
            /// Delta used when deciding if this input has changed
            ChangeDelta : REAL := REAL#0.01;
            /// If this is a bipolar input or not
            Bipolar : BOOL := FALSE;
            /// Minimum possible input value
            Minimum : REAL := REAL#0.0;
            /// Maximum possible input value
            Maximum : REAL := REAL#27648.0;
        END_VAR

        VAR PRIVATE
            _lastValue : REAL;
            _value : REAL;
        END_VAR

        METHOD PUBLIC Read
            VAR_INPUT
                value : REAL;
            END_VAR

            VAR_TEMP
                convertedValue : REAL;
            END_VAR

            convertedValue := value;

            IF endianness = Endianness#Little THEN
                convertedValue := TO_REAL(Flip(value));
            END_IF;

            convertedValue := THIS.Normalize(convertedValue);

            _lastValue := _value;
            _value := convertedValue;

            IF THIS.HasChanged() AND _inputChangedHandler <> NULL THEN
                _inputChangedHandler.InputChanged(REF(THIS));
            END_IF;
        END_METHOD

        METHOD PUBLIC Read
            VAR_INPUT
                value : DWORD;
            END_VAR

            VAR_TEMP
                convertedValue : REAL;
            END_VAR

            convertedValue := TO_REAL(value);

            IF endianness = Endianness#Little THEN
                convertedValue := TO_REAL(Flip(value));
            END_IF;

            convertedValue := THIS.Normalize(convertedValue);

            _lastValue := _value;
            _value := convertedValue;

            IF THIS.HasChanged() AND _inputChangedHandler <> NULL THEN
                _inputChangedHandler.InputChanged(REF(THIS));
            END_IF;
        END_METHOD

        METHOD PUBLIC Read
            VAR_INPUT
                value : UINT;
            END_VAR

            VAR_TEMP
                convertedValue : REAL;
            END_VAR

            convertedValue := TO_REAL(value);

            IF endianness = Endianness#Little THEN
                convertedValue := TO_REAL(Flip(TO_REAL(value)));
            END_IF;

            convertedValue := THIS.Normalize(convertedValue);

            _lastValue := _value;
            _value := convertedValue;

            IF THIS.HasChanged() AND _inputChangedHandler <> NULL THEN
                _inputChangedHandler.InputChanged(REF(THIS));
            END_IF;
        END_METHOD

        METHOD PUBLIC Read
            VAR_INPUT
                value : INT;
            END_VAR

            VAR_TEMP
                convertedValue : REAL;
            END_VAR

            convertedValue := TO_REAL(value);

            IF endianness = Endianness#Little THEN
                convertedValue := TO_REAL(Flip(TO_REAL(value)));
            END_IF;

            convertedValue := THIS.Normalize(convertedValue);

            _lastValue := _value;
            _value := convertedValue;

            IF THIS.HasChanged() AND _inputChangedHandler <> NULL THEN
                _inputChangedHandler.InputChanged(REF(THIS));
            END_IF;
        END_METHOD

        METHOD PUBLIC GetValue : REAL
            GetValue := _value;
        END_METHOD

        METHOD PUBLIC OVERRIDE HasChanged : BOOL
            HasChanged := ABS(_lastValue - _value) > ChangeDelta;
        END_METHOD

        METHOD PRIVATE Normalize : REAL
            VAR_INPUT
                value : REAL;
            END_VAR

            VAR_TEMP
                _normalized : REAL;
            END_VAR


            IF THIS.Bipolar THEN
                _normalized := (value - THIS.Minimum) / (THIS.Maximum - THIS.Minimum) * REAL#2.0 - REAL#1.0;
            ELSE
                _normalized := (value - THIS.Minimum) / (THIS.Maximum - THIS.Minimum);
            END_IF;

            Normalize := _normalized;
        END_METHOD
    END_CLASS

    CLASS RealOutput EXTENDS Output IMPLEMENTS IRealOutput
        VAR PUBLIC
            /// Scaling will be applied when writing the output
            /// E.g. if the output written is a DINT with the unit 0.1 radishes, a scale of 0.1 will result in Write() outputting
            /// a number with the unit 0.1 radishes, so SetValue(REAL#0.2) -> output = DINT#2 radishes.
            Scale : REAL := REAL#1.0;
        END_VAR

        VAR PRIVATE
            _value : REAL;
        END_VAR

        METHOD PUBLIC Write
            VAR_OUTPUT
                value : REAL;
            END_VAR

            VAR_TEMP
                convertedValue : REAL;
            END_VAR

            convertedValue := _value / THIS.Scale;

            IF THIS.Endianness = Endianness#Little THEN
                convertedValue := TO_REAL(Flip(convertedValue));
            END_IF;

            value := convertedValue;
        END_METHOD

        METHOD PUBLIC Write
            VAR_OUTPUT
                value : DWORD;
            END_VAR

            VAR_TEMP
                convertedValue : DWORD;
            END_VAR

            convertedValue := TO_DWORD(_value / THIS.Scale);

            IF THIS.Endianness = Endianness#Little THEN
                convertedValue := Flip(convertedValue);
            END_IF;

            value := convertedValue;
        END_METHOD

        METHOD PUBLIC Write
            VAR_OUTPUT
                value : UINT;
            END_VAR

            VAR_TEMP
                convertedValue : UINT;
            END_VAR

            convertedValue := TO_UINT(_value / THIS.Scale);

            IF THIS.Endianness = Endianness#Little THEN
                convertedValue := TO_UINT(Flip(convertedValue));
            END_IF;

            value := convertedValue;
        END_METHOD

        METHOD PUBLIC Write
            VAR_OUTPUT
                value : INT;
            END_VAR

            VAR_TEMP
                convertedValue : INT;
            END_VAR

            convertedValue := TO_INT(_value / THIS.Scale);

            IF THIS.Endianness = Endianness#Little THEN
                convertedValue := TO_INT(Flip(convertedValue));
            END_IF;

            value := convertedValue;
        END_METHOD

        METHOD PUBLIC SetValue
            VAR_INPUT
                value: REAL;
            END_VAR

            _value := value;
        END_METHOD
    END_CLASS

    CLASS RealNormalizedOutput EXTENDS Output IMPLEMENTS IRealOutput
        VAR PUBLIC
            /// If this is a bipolar output or not
            Bipolar : BOOL := FALSE;
            /// Minimum possible output value
            Minimum : REAL := REAL#0.0;
            /// Maximum possible output value
            Maximum : REAL := REAL#27648.0;
        END_VAR

        VAR PRIVATE
            _value : REAL;
        END_VAR

        METHOD PUBLIC Write
            VAR_OUTPUT
                value : REAL;
            END_VAR

            VAR_TEMP
                convertedValue : REAL;
            END_VAR

            convertedValue := THIS.Normalize(_value);

            IF THIS.Endianness = Endianness#Little THEN
                convertedValue := TO_REAL(Flip(convertedValue));
            END_IF;

            value := convertedValue;
        END_METHOD

        METHOD PUBLIC Write
            VAR_OUTPUT
                value : DWORD;
            END_VAR

            VAR_TEMP
                convertedValue : DWORD;
            END_VAR

            convertedValue := TO_DWORD(THIS.Normalize(_value));

            IF THIS.Endianness = Endianness#Little THEN
                convertedValue := Flip(convertedValue);
            END_IF;

            value := convertedValue;
        END_METHOD

        METHOD PUBLIC Write
            VAR_OUTPUT
                value : UINT;
            END_VAR

            VAR_TEMP
                convertedValue : UINT;
            END_VAR

            convertedValue := TO_UINT(THIS.Normalize(_value));

            IF THIS.Endianness = Endianness#Little THEN
                convertedValue := TO_UINT(Flip(convertedValue));
            END_IF;

            value := convertedValue;
        END_METHOD

        METHOD PUBLIC Write
            VAR_OUTPUT
                value : INT;
            END_VAR

            VAR_TEMP
                convertedValue : INT;
            END_VAR

            convertedValue := TO_INT(THIS.Normalize(_value));

            IF THIS.Endianness = Endianness#Little THEN
                convertedValue := TO_INT(Flip(convertedValue));
            END_IF;

            value := convertedValue;
        END_METHOD

        METHOD PUBLIC SetValue
            VAR_INPUT
                value: REAL;
            END_VAR

            _value := value;

            IF value > 1.0 THEN
                _value := REAL#1.0;
            ELSIF Bipolar && value < -1.0 THEN
                _value := REAL#-1.0;
            ELSIF NOT Bipolar && value < 0.0 THEN
                _value := REAL#0.0;
            END_IF;
        END_METHOD

        METHOD PRIVATE Normalize : REAL
            VAR_INPUT
                value : REAL;
            END_VAR

            VAR_TEMP
                _normalized : REAL;
            END_VAR


            IF THIS.Bipolar THEN
                _normalized := (value + REAL#1.0) / REAL#2.0 * (THIS.Maximum - THIS.Minimum) + THIS.Minimum;
            ELSE
                _normalized := value * (THIS.Maximum - THIS.Minimum) + THIS.Minimum;
            END_IF;

            Normalize := _normalized;
        END_METHOD
    END_CLASS

END_NAMESPACE