USING Esab.Utils;

NAMESPACE Esab.Io

    INTERFACE IWordInput
        /// Reads a new value
        METHOD Read
            VAR_INPUT
                value : WORD;
            END_VAR
        END_METHOD

        /// Reads a new value (BYTE)
        METHOD Read
            VAR_INPUT
                value : BYTE;
            END_VAR
        END_METHOD

        /// Returns the last value read
        METHOD GetValue : WORD
        END_METHOD
    END_INTERFACE

    INTERFACE IWordOutput
        /// Writes the value to the output
        METHOD Write
            VAR_OUTPUT
                value : WORD;
            END_VAR
        END_METHOD

        /// Writes the value to the output (BYTE overload)
        METHOD Write
            VAR_OUTPUT
                value : BYTE;
            END_VAR
        END_METHOD

        /// Sets the current value to the given value
        METHOD SetValue
            VAR_INPUT
                value: WORD;
            END_VAR
        END_METHOD

        /// Sets the current value to the given value (BYTE)
        METHOD SetValue
            VAR_INPUT
                value: BYTE;
            END_VAR
        END_METHOD
    END_INTERFACE

    CLASS WordInput EXTENDS Input IMPLEMENTS IWordInput
        VAR PRIVATE
            _lastValue : WORD;
            _value : WORD;
        END_VAR

        METHOD PUBLIC Read
            VAR_INPUT
                value : WORD;
            END_VAR

            VAR_TEMP
                convertedValue : WORD;
            END_VAR

            convertedValue := value;

            IF THIS.Endianness = Endianness#Little THEN
                convertedValue := Flip(value);
            END_IF;

            _lastValue := _value;
            _value := convertedValue;

            IF THIS.HasChanged() AND _inputChangedHandler <> NULL THEN
                _inputChangedHandler.InputChanged(REF(THIS));
            END_IF;
        END_METHOD

        METHOD PUBLIC Read
            VAR_INPUT
                value : BYTE;
            END_VAR

            VAR_TEMP
                convertedValue : WORD := WORD#0;
            END_VAR

            convertedValue.%B0 := value;

            _lastValue := _value;
            _value := convertedValue;

            IF THIS.HasChanged() AND _inputChangedHandler <> NULL THEN
                _inputChangedHandler.InputChanged(REF(THIS));
            END_IF;
        END_METHOD

        METHOD PUBLIC GetValue : WORD
            GetValue := _value;
        END_METHOD

        METHOD PUBLIC OVERRIDE HasChanged : BOOL
            HasChanged := _lastValue <> _value;
        END_METHOD
    END_CLASS

    CLASS WordOutput EXTENDS Output IMPLEMENTS IWordOutput

        VAR PRIVATE
            _value : WORD;
        END_VAR

        METHOD PUBLIC Write
            VAR_OUTPUT
                value : WORD;
            END_VAR

            VAR_TEMP
                convertedValue : WORD;
            END_VAR

            convertedValue := _value;

            IF THIS.Endianness = Endianness#Little THEN
                convertedValue := Flip(_value);
            END_IF;

            value := convertedValue;
        END_METHOD

        METHOD PUBLIC Write
            VAR_OUTPUT
                value : BYTE;
            END_VAR

            value := _value.%B0;
        END_METHOD

        METHOD PUBLIC SetValue
            VAR_INPUT
                value: WORD;
            END_VAR

            _value := value;
        END_METHOD

        METHOD PUBLIC SetValue
            VAR_INPUT
                value: BYTE;
            END_VAR

            _value := WORD#0;
            _value.%B0 := value;
        END_METHOD
    END_CLASS

END_NAMESPACE