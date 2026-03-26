USING Esab.Mock;
USING Esab.Io;

NAMESPACE Esab.Io.Mock

    CLASS HighSpeedCounterMock IMPLEMENTS IHighSpeedCounter
        VAR PUBLIC
            ExecuteMock : MethodMock;
            SetHardwareConfigurationMock : HighSpeedCounterHardwareConfigurationMethodMock;
            EnableMock : MethodMock;
            DisableMock : MethodMock;
            GetCountValueMock  : DIntMethodMock;
            GetMeasuredValueMock : DIntMethodMock;
            GetUpperCountingLimitMock : DIntMethodMock;
            GetLowerCountingLimitMock : DIntMethodMock;
            SetCountValueMock : DIntMethodMock;
            HasErrorMock : BoolMethodMock;
            GetErrorIdMock : WordMethodMock;
        END_VAR

        METHOD PUBLIC MockReset
            ExecuteMock.Reset();
            EnableMock.Reset();
            DisableMock.Reset();
            GetCountValueMock.Reset();
            GetMeasuredValueMock.Reset();
            SetCountValueMock.Reset();
            HasErrorMock.Reset();
            GetErrorIdMock.Reset();
        END_METHOD

        METHOD PUBLIC Execute
            ExecuteMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC SetHardwareConfiguration
            VAR_INPUT
                hwConfiguration : REF_TO HighSpeedCounterHardwareConfiguration;
            END_VAR

            SetHardwareConfigurationMock.Value := hwConfiguration;
            SetHardwareConfigurationMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC Enable
            EnableMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC Disable
            DisableMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC GetCountValue : DINT
            GetCountValueMock.IncrementCallCount();
            GetCountValue := GetCountValueMock.Value;
        END_METHOD

        METHOD PUBLIC GetMeasuredValue : DINT
            GetMeasuredValueMock.IncrementCallCount();
            GetMeasuredValue := GetMeasuredValueMock.Value;
        END_METHOD

        METHOD PUBLIC GetUpperCountingLimit : DINT
            GetUpperCountingLimitMock.IncrementCallCount();
            GetUpperCountingLimit := GetUpperCountingLimitMock.Value;
        END_METHOD

        METHOD PUBLIC GetLowerCountingLimit : DINT
            GetLowerCountingLimitMock.IncrementCallCount();
            GetLowerCountingLimit := GetLowerCountingLimitMock.Value;
        END_METHOD

        METHOD PUBLIC SetCountValue
            VAR_INPUT
                value : DINT;
            END_VAR

            SetCountValueMock.IncrementCallCount();
            SetCountValueMock.Value := value;
        END_METHOD

        METHOD PUBLIC HasError : BOOL
            HasErrorMock.IncrementCallCount();
            HasError := HasErrorMock.Value;
        END_METHOD

        METHOD PUBLIC GetErrorId : WORD
            GetErrorIdMock.IncrementCallCount();
            GetErrorId := GetErrorIdMock.Value;
        END_METHOD
    END_CLASS

    CLASS HighSpeedCounterHardwareConfigurationMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value : REF_TO HighSpeedCounterHardwareConfiguration;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            Value := NULL;
            SUPER.Reset();
        END_METHOD
    END_CLASS

END_NAMESPACE