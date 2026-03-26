USING Siemens.Simatic.S71500.Alarming;

NAMESPACE Esab.Utils.Alarming
    CLASS AlarmWrapper IMPLEMENTS IAlarm
        VAR PRIVATE
            _alarm : REF_TO ProgramAlarm;
            _isSetup : BOOL := FALSE;
        END_VAR

        METHOD PUBLIC Setup
            VAR_INPUT
                alarm : REF_TO ProgramAlarm;
            END_VAR

            _alarm := alarm;

            _isSetup := _alarm <> NULL;
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

            IF NOT _isSetup THEN
                RETURN;
            END_IF;

            _alarm^(
                SIG  := SIG,
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
    END_CLASS
END_NAMESPACE