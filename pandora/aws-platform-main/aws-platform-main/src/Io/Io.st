USING Esab.Io;

NAMESPACE Esab.Io

    CLASS ABSTRACT Input
        VAR PUBLIC
            Id : UINT;
            /// The endianness of the read value.
            /// If this is "little" it will be converted to big for use in the PLC-program
            Endianness : Endianness := Endianness#Big;
        END_VAR

        VAR PROTECTED
            _inputChangedHandler : InputChangedListener;
        END_VAR

        METHOD PUBLIC SetChangedHandler
            VAR_INPUT
                handler : InputChangedListener;
            END_VAR

            _inputChangedHandler := handler;
        END_METHOD

        METHOD PUBLIC ABSTRACT HasChanged : BOOL
        END_METHOD
    END_CLASS

    CLASS Output
        VAR PUBLIC
            /// The endianness that the target value is expected to have by the consumer of the output.
            Endianness : Endianness := Endianness#Big;
        END_VAR
    END_CLASS

    INTERFACE InputChangedListener
        METHOD InputChanged
            VAR_INPUT
                input : REF_TO Input;
            END_VAR
        END_METHOD
    END_INTERFACE

    TYPE
        /// Used in Inputs and Outputs to convert endianness properly.
        /// The PLC uses big endian, while data coming from some outside source may be little.
        Endianness : INT(Big := 0, Little := 1);
    END_TYPE

END_NAMESPACE