USING Esab.Utils;

NAMESPACE Esab.Io

    INTERFACE IIntInput
        /// Reads a new value
        METHOD Read
            VAR_INPUT
                value : INT;
            END_VAR
        END_METHOD

        /// Returns the last value read
        METHOD GetValue : INT
        END_METHOD
    END_INTERFACE

    INTERFACE IIntOutput
        /// Writes the value to the output
        METHOD Write
            VAR_OUTPUT
                value : INT;
            END_VAR
        END_METHOD

        /// Sets the current value to the given value
        METHOD SetValue
            VAR_INPUT
                value: INT;
            END_VAR
        END_METHOD
    END_INTERFACE

    CLASS IntInput EXTENDS Input IMPLEMENTS IIntInput
        VAR PRIVATE
            _lastValue : INT;
            _value : INT;
        END_VAR

        METHOD PUBLIC Read
            VAR_INPUT
                value : INT;
            END_VAR

            VAR_TEMP
                convertedValue : INT;
            END_VAR

            convertedValue := value;

            IF THIS.Endianness = Endianness#Little THEN
                convertedValue := TO_INT(Flip(value));
            END_IF;

            _lastValue := _value;
            _value := convertedValue;

            IF THIS.HasChanged() AND _inputChangedHandler <> NULL THEN
                _inputChangedHandler.InputChanged(REF(THIS));
            END_IF;
        END_METHOD

        METHOD PUBLIC GetValue : INT
            GetValue := _value;
        END_METHOD

        METHOD PUBLIC OVERRIDE HasChanged : BOOL
            HasChanged := _lastValue <> _value;
        END_METHOD
    END_CLASS

    CLASS IntOutput EXTENDS Output IMPLEMENTS IIntOutput

        VAR PRIVATE
            _value : INT;
        END_VAR

        METHOD PUBLIC Write
            VAR_OUTPUT
                value : INT;
            END_VAR

            VAR_TEMP
                convertedValue : INT;
            END_VAR

            convertedValue := _value;

            IF THIS.Endianness = Endianness#Little THEN
                convertedValue := TO_INT(Flip(_value));
            END_IF;

            value := convertedValue;
        END_METHOD

        METHOD PUBLIC SetValue
            VAR_INPUT
                value: INT;
            END_VAR

            _value := value;
        END_METHOD
    END_CLASS

END_NAMESPACE