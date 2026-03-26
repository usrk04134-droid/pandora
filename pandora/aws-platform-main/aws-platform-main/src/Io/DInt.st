USING Esab.Utils;

NAMESPACE Esab.Io

    INTERFACE IDIntInput
        /// Reads a new value
        METHOD Read
            VAR_INPUT
                value : DINT;
            END_VAR
        END_METHOD

        /// Returns the last value read
        METHOD GetValue : DINT
        END_METHOD
    END_INTERFACE

    INTERFACE IDIntOutput
        /// Writes the value to the output
        METHOD Write
            VAR_OUTPUT
                value : DINT;
            END_VAR
        END_METHOD

        /// Sets the current value to the given value
        METHOD SetValue
            VAR_INPUT
                value: DINT;
            END_VAR
        END_METHOD
    END_INTERFACE

    CLASS DIntInput EXTENDS Input IMPLEMENTS IDIntInput
        VAR PRIVATE
            _lastValue : DINT;
            _value : DINT;
        END_VAR

        METHOD PUBLIC Read
            VAR_INPUT
                value : DINT;
            END_VAR

            VAR_TEMP
                convertedValue : DINT;
            END_VAR

            convertedValue := value;

            IF THIS.Endianness = Endianness#Little THEN
                convertedValue := TO_DINT(Flip(value));
            END_IF;

            _lastValue := _value;
            _value := convertedValue;

            IF THIS.HasChanged() AND _inputChangedHandler <> NULL THEN
                _inputChangedHandler.InputChanged(REF(THIS));
            END_IF;
        END_METHOD

        METHOD PUBLIC GetValue : DINT
            GetValue := _value;
        END_METHOD

        METHOD PUBLIC OVERRIDE HasChanged : BOOL
            HasChanged := _lastValue <> _value;
        END_METHOD
    END_CLASS

    CLASS DIntOutput EXTENDS Output IMPLEMENTS IDIntOutput
        VAR PRIVATE
            _value : DINT;
        END_VAR

        METHOD PUBLIC Write
            VAR_OUTPUT
                value : DINT;
            END_VAR

            VAR_TEMP
                convertedValue : DINT;
            END_VAR

            convertedValue := _value;

            IF THIS.Endianness = Endianness#Little THEN
                convertedValue := TO_DINT(Flip(_value));
            END_IF;

            value := convertedValue;
        END_METHOD

        METHOD PUBLIC SetValue
            VAR_INPUT
                value: DINT;
            END_VAR

            _value := value;
        END_METHOD
    END_CLASS

END_NAMESPACE