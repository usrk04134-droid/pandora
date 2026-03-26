NAMESPACE Esab.Utils
    FUNCTION Flip : WORD
        VAR_INPUT
            value : WORD;
        END_VAR

        VAR_TEMP
            _value : WORD;
        END_VAR

        _value.%B0 := value.%B1;
        _value.%B1 := value.%B0;

        Flip := _value;
    END_FUNCTION

    FUNCTION Flip : DWORD
        VAR_INPUT
            value : DWORD;
        END_VAR

        VAR_TEMP
            _value : DWORD;
        END_VAR

        _value.%B0 := value.%B3;
        _value.%B1 := value.%B2;
        _value.%B2 := value.%B1;
        _value.%B3 := value.%B0;

        Flip := _value;
    END_FUNCTION

    FUNCTION Flip : WORD
        VAR_INPUT
            value : INT;
        END_VAR

        Flip := Flip(TO_WORD(value));
    END_FUNCTION

    FUNCTION Flip : DWORD
        VAR_INPUT
            value : DINT;
        END_VAR

        Flip := Flip(TO_DWORD(value));
    END_FUNCTION

    FUNCTION Flip : WORD
        VAR_INPUT
            value : UINT;
        END_VAR

        Flip := Flip(TO_WORD(value));
    END_FUNCTION

    FUNCTION Flip : DWORD
        VAR_INPUT
            value : UDINT;
        END_VAR

        Flip := Flip(TO_DWORD(value));
    END_FUNCTION

    FUNCTION Flip : DWORD
        VAR_INPUT
            value : REAL;
        END_VAR

        Flip := Flip(TO_DWORD(value));
    END_FUNCTION
END_NAMESPACE