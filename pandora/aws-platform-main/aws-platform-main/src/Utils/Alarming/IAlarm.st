USING Siemens.Simatic.S71500.Alarming;

NAMESPACE Esab.Utils.Alarming

INTERFACE IAlarm
    METHOD Execute
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
    END_METHOD

    METHOD IsActive : BOOL
    END_METHOD
END_INTERFACE
END_NAMESPACE