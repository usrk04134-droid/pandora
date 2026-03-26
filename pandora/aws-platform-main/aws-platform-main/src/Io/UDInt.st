USING Esab.Utils;

NAMESPACE Esab.Io

    INTERFACE IUDIntInput
        /// Reads a new value
        METHOD Read
            VAR_INPUT
                value : UDINT;
            END_VAR
        END_METHOD

        /// Returns the last value read
        METHOD GetValue : UDINT
        END_METHOD
    END_INTERFACE

    INTERFACE IUDIntOutput
        /// Writes the value to the output
        METHOD Write
            VAR_OUTPUT
                value : UDINT;
            END_VAR
        END_METHOD

        /// Sets the current value to the given value
        METHOD SetValue
            VAR_INPUT
                value: UDINT;
            END_VAR
        END_METHOD
    END_INTERFACE

    CLASS UDIntInput EXTENDS Input IMPLEMENTS IUDIntInput
        VAR PRIVATE
            _lastValue : UDINT;
            _value : UDINT;
        END_VAR

        METHOD PUBLIC Read
            VAR_INPUT
                value : UDINT;
            END_VAR

            VAR_TEMP
                convertedValue : UDINT;
            END_VAR

            convertedValue := value;

            IF THIS.Endianness = Endianness#Little THEN
                convertedValue := TO_UDINT(Flip(value));
            END_IF;

            _lastValue := _value;
            _value := convertedValue;

            IF THIS.HasChanged() AND _inputChangedHandler <> NULL THEN
                _inputChangedHandler.InputChanged(REF(THIS));
            END_IF;
        END_METHOD

        METHOD PUBLIC GetValue : UDINT
            GetValue := _value;
        END_METHOD

        METHOD PUBLIC OVERRIDE HasChanged : BOOL
            HasChanged := _lastValue <> _value;
        END_METHOD
    END_CLASS

    CLASS UDIntOutput EXTENDS Output IMPLEMENTS IUDIntOutput
        VAR PRIVATE
            _value : UDINT;
        END_VAR

        METHOD PUBLIC Write
            VAR_OUTPUT
                value : UDINT;
            END_VAR

            VAR_TEMP
                convertedValue : UDINT;
            END_VAR

            convertedValue := _value;

            IF THIS.Endianness = Endianness#Little THEN
                convertedValue := TO_UDINT(Flip(_value));
            END_IF;

            value := convertedValue;
        END_METHOD

        METHOD PUBLIC SetValue
            VAR_INPUT
                value: UDINT;
            END_VAR

            _value := value;
        END_METHOD
    END_CLASS

END_NAMESPACE