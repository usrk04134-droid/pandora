NAMESPACE Esab.Utils.Filters

    CLASS NoFilter IMPLEMENTS IFilter
        VAR PRIVATE
            _currentValue : LREAL;
        END_VAR

        METHOD PUBLIC Initialize
            ;
        END_METHOD

        METHOD PUBLIC Measurement
            VAR_INPUT
                value : LREAL;
            END_VAR

            _currentValue := value;
        END_METHOD

        METHOD PUBLIC Filtered : LREAL
            Filtered := _currentValue;
        END_METHOD

        METHOD PUBLIC SetWindowSize
            VAR_INPUT
                size : INT;
            END_VAR

            ;
        END_METHOD

        METHOD PUBLIC Reset
            _currentValue := 0.0;
        END_METHOD
    END_CLASS

END_NAMESPACE