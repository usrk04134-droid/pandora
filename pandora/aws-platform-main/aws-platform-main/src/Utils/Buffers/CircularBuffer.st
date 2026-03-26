NAMESPACE Esab.Utils.Buffers

    CLASS CircularBuffer
        VAR PUBLIC
            Buffer : REF_TO ARRAY[*] OF LREAL;
            Size : INT;
        END_VAR

        /// Gets the value at [index]
        METHOD PUBLIC ValueAt : LREAL
            VAR_INPUT
                index : INT;
            END_VAR

            ValueAt := Buffer^[THIS.IndexAt(index)];
        END_METHOD

        /// Sets the value at [index]
        METHOD PUBLIC ValueAt
            VAR_INPUT
                index : INT;
                value : LREAL;
            END_VAR

            Buffer^[THIS.IndexAt(index)] := value;
        END_METHOD

        /// Sets all values in the buffer to 0
        METHOD PUBLIC Clear
            VAR_TEMP
                _index : INT := 0;
            END_VAR

            FOR _index := 0 TO Size-1 DO
                Buffer^[_index] := 0.0;
            END_FOR;
        END_METHOD

        /// Returns the index wrapped to the bounds of the buffer
        METHOD PUBLIC IndexAt : INT
            VAR_INPUT
                index : INT;
            END_VAR

            VAR_TEMP
                _index : INT := 0;
            END_VAR

            _index := index MOD Size;

            IF _index < 0 THEN
                _index := Size + _index;
            END_IF;

            IndexAt := _index;
        END_METHOD
    END_CLASS

END_NAMESPACE