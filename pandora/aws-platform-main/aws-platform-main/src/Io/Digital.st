NAMESPACE Esab.Io

    INTERFACE IDigitalInput
        /// Reads a new value
        METHOD Read
            VAR_INPUT
                value : BOOL;
            END_VAR
        END_METHOD

        /// Returns the last value read
        METHOD GetValue : BOOL
        END_METHOD

        /// Returns TRUE if the input experienced a rising edge
        METHOD RisingEdge : BOOL
        END_METHOD

        /// Returns TRUE if the input experienced a falling edge
        METHOD FallingEdge : BOOL
        END_METHOD
    END_INTERFACE

    INTERFACE IDigitalOutput
        /// Writes the value to the output
        METHOD Write
            VAR_OUTPUT
                value : BOOL;
            END_VAR
        END_METHOD

        /// Sets the current value to the given value
        METHOD SetValue
            VAR_INPUT
                value: BOOL;
            END_VAR
        END_METHOD

        /// Sets the current value to TRUE
        METHOD Set
        END_METHOD

        /// Reset the current value to FALSE
        METHOD Reset
        END_METHOD

        /// Toggles the current value
        METHOD Toggle
        END_METHOD
    END_INTERFACE

    CLASS DigitalInput EXTENDS Input IMPLEMENTS IDigitalInput
        VAR PRIVATE
            _currentValue : BOOL;
            _lastValue : BOOL;
        END_VAR

        METHOD PUBLIC Read
            VAR_INPUT
                value : BOOL;
            END_VAR

            _lastValue := _currentValue;
            _currentValue := value;

            IF _inputChangedHandler <> NULL AND THIS.RisingEdge() THEN
                _inputChangedHandler.InputChanged(REF(THIS));
            END_IF;

            IF _inputChangedHandler <> NULL AND THIS.FallingEdge() THEN
                _inputChangedHandler.InputChanged(REF(THIS));
            END_IF;
        END_METHOD

        METHOD PUBLIC GetValue : BOOL
            GetValue := _currentValue;
        END_METHOD

        METHOD PUBLIC RisingEdge : BOOL
            RisingEdge := NOT _lastValue AND _currentValue;
        END_METHOD

        METHOD PUBLIC FallingEdge : BOOL
            FallingEdge := _lastValue AND NOT _currentValue;
        END_METHOD

        METHOD PUBLIC OVERRIDE HasChanged : BOOL
            HasChanged := _lastValue <> _currentValue;
        END_METHOD
    END_CLASS

    CLASS DigitalOutput EXTENDS Output IMPLEMENTS IDigitalOutput
        VAR PRIVATE
            _value : BOOL;
        END_VAR

        METHOD PUBLIC Write
            VAR_OUTPUT
                value : BOOL;
            END_VAR

            value := _value;
        END_METHOD

        METHOD PUBLIC SetValue
            VAR_INPUT
                value: BOOL;
            END_VAR

            _value := value;
        END_METHOD

        METHOD PUBLIC Set
            _value := TRUE;
        END_METHOD

        METHOD PUBLIC Reset
            _value := FALSE;
        END_METHOD

        METHOD PUBLIC Toggle
            _value := NOT _value;
        END_METHOD
    END_CLASS

    CLASS DigitalInOut EXTENDS DigitalInput IMPLEMENTS IDigitalOutput
        VAR PRIVATE
            _value : BOOL;
        END_VAR

        METHOD PUBLIC Write
            VAR_OUTPUT
                value : BOOL;
            END_VAR

            value := _value;
        END_METHOD

        METHOD PUBLIC SetValue
            VAR_INPUT
                value: BOOL;
            END_VAR

            _value := value;
        END_METHOD

        METHOD PUBLIC Set
            _value := TRUE;
        END_METHOD

        METHOD PUBLIC Reset
            _value := FALSE;
        END_METHOD

        METHOD PUBLIC Toggle
            _value := NOT _value;
        END_METHOD
    END_CLASS

END_NAMESPACE