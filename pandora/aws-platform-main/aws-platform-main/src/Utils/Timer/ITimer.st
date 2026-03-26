NAMESPACE Esab.Utils.Timer

    INTERFACE ITimer
        /// Cyclic execute
        METHOD Execute
            VAR_INPUT
                signal : BOOL;
                duration : LTIME;
            END_VAR
        END_METHOD

        /// Returns TRUE if this timer is expired
        METHOD Expired : BOOL
        END_METHOD

        /// Returns the elapsed time
        METHOD ElapsedTime : LTIME
        END_METHOD
    END_INTERFACE

END_NAMESPACE