USING Esab.Utils.Timer;

USING Siemens.Simatic.S71500.Alarming;

NAMESPACE Esab.Utils.Alarming
    CLASS TimedAlarmWrapper EXTENDS Object IMPLEMENTS IAlarm
        VAR PRIVATE
            _alarm : REF_TO ProgramAlarm;
            _timer : ITimer;
            _timeout : LTIME;
            _defaultTimer : OnDelay;
        END_VAR

        /// Setup the alarm, if timer is NULL a default timer (OnDelay) will be used.
        METHOD PUBLIC Setup
            VAR_INPUT
                alarm : REF_TO ProgramAlarm;
                timeout : LTIME;
                timer : ITimer := NULL;
            END_VAR

            _alarm := alarm;

            IF timer = NULL THEN
                _timer := _defaultTimer;
            ELSE
                _timer := timer;
            END_IF;

            _timeout := timeout;

            _isSetup := _alarm <> NULL AND _timer <> NULL;
        END_METHOD

        METHOD PUBLIC Execute
            VAR_INPUT
                SIG : BOOL;
                SD_1 : variantType;
                SD_2 : variantType;
                SD_3 : variantType;
                SD_4 : variantType;
                SD_5 : variantType;
                SD_6 : variantType;
                SD_7 : variantType;
                SD_8 : variantType;
                SD_9 : variantType;
                SD_10 : variantType;
            END_VAR

            IF _setupAlarm.IsActive() THEN
                RETURN;
            END_IF;

            _timer.Execute(SIG, _timeout);

            _alarm^(
                SIG  := _timer.Expired(),
                SD_1 := SD_1,
                SD_2 := SD_2,
                SD_3 := SD_3,
                SD_4 := SD_4,
                SD_5 := SD_5,
                SD_6 := SD_6,
                SD_7 := SD_7,
                SD_8 := SD_8,
                SD_9 := SD_9,
                SD_10 := SD_10
            );
        END_METHOD

        METHOD PUBLIC IsActive : BOOL
            IsActive := _alarm^.SIG;
        END_METHOD

        METHOD PUBLIC SetTimeout
            VAR_INPUT
                timeout : LTIME;
            END_VAR

            _timeout := timeout;
        END_METHOD
    END_CLASS
END_NAMESPACE