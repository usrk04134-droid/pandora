USING Siemens.Simatic.S71500.Alarming;
USING Esab.Mock;

NAMESPACE Esab.Utils.Alarming.Mock

    CLASS ExecuteMethodMock EXTENDS MethodMock
        VAR PUBLIC
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

        METHOD PUBLIC OVERRIDE Reset
            SIG := FALSE;
            SD_1 := pass(0);
            SD_2 := pass(0);
            SD_3 := pass(0);
            SD_4 := pass(0);
            SD_5 := pass(0);
            SD_6 := pass(0);
            SD_7 := pass(0);
            SD_8 := pass(0);
            SD_9 := pass(0);
            SD_10 := pass(0);
            SUPER.Reset();
        END_METHOD
    END_CLASS

    CLASS AlarmMock IMPLEMENTS IAlarm
        VAR PUBLIC
            ExecuteMock : ExecuteMethodMock;
            IsActiveMock : BoolMethodMock;
        END_VAR

        METHOD PUBLIC MockReset
            ExecuteMock.Reset();
            IsActiveMock.Reset();
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

            ExecuteMock.IncrementCallCount();
            ExecuteMock.SIG := SIG;
            ExecuteMock.SD_1 := SD_1;
            ExecuteMock.SD_2 := SD_2;
            ExecuteMock.SD_3 := SD_3;
            ExecuteMock.SD_4 := SD_4;
            ExecuteMock.SD_5 := SD_5;
            ExecuteMock.SD_6 := SD_6;
            ExecuteMock.SD_7 := SD_7;
            ExecuteMock.SD_8 := SD_8;
            ExecuteMock.SD_9 := SD_9;
            ExecuteMock.SD_10 := SD_10;
        END_METHOD

        METHOD PUBLIC IsActive : BOOL
            IsActive := IsActiveMock.Value;
            IsACtiveMock.IncrementCallCount();
        END_METHOD
    END_CLASS

END_NAMESPACE
