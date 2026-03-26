NAMESPACE Esab.Utils.Timer

    CLASS OnDelay IMPLEMENTS ITimer
        VAR PRIVATE
            _onDelay : System.Timer.OnDelay;
        END_VAR

        METHOD PUBLIC Execute
            VAR_INPUT
                signal : BOOL;
                duration : LTIME;
            END_VAR

            _onDelay(signal, duration);
        END_METHOD

        METHOD PUBLIC Expired : BOOL
            Expired := _onDelay.output;
        END_METHOD

        METHOD PUBLIC ElapsedTime : LTIME
            ElapsedTime := _onDelay.elapsedTime;
        END_METHOD
    END_CLASS

END_NAMESPACE