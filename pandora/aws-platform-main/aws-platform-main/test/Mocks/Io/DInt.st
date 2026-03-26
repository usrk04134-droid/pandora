USING Esab.Mock;

NAMESPACE Esab.Io.Mock

    CLASS DIntInputMock EXTENDS Input IMPLEMENTS IDIntInput
        VAR PUBLIC
            ReadMock : DIntMethodMock;
            GetValueMock : DIntMethodMock;
            HasChangedMock : BoolMethodMock;
        END_VAR

        METHOD PUBLIC MockReset
            ReadMock.Reset();
            GetValueMock.Reset();
        END_METHOD

        METHOD PUBLIC Read
            VAR_INPUT
                value : DINT;
            END_VAR

            ReadMock.IncrementCallCount();
            ReadMock.Value := value;
        END_METHOD

        METHOD PUBLIC GetValue : DINT
            GetValueMock.IncrementCallCount();
            GetValue := GetValueMock.Value;
        END_METHOD

        METHOD PUBLIC OVERRIDE HasChanged : BOOL
            HasChangedMock.IncrementCallCount();
            HasChanged := HasChangedMock.Value;
        END_METHOD
    END_CLASS

    CLASS DintOutputMock IMPLEMENTS IDintOutput
        VAR PUBLIC
            WriteMock : DIntMethodMock;
            SetValueMock : DIntMethodMock;
            SetMock : MethodMock;
            ResetMock : MethodMock;
            ToggleMock : MethodMock;
        END_VAR

        METHOD PUBLIC MockReset
            WriteMock.Reset();
            SetValueMock.Reset();
            SetMock.Reset();
            ResetMock.Reset();
            ToggleMock.Reset();
        END_METHOD

        METHOD PUBLIC Write
            VAR_OUTPUT
                value : DINT;
            END_VAR

            WriteMock.IncrementCallCount();
            value := WriteMock.Value;
        END_METHOD

        METHOD PUBLIC SetValue
            VAR_INPUT
                value: DINT;
            END_VAR

            SetValueMock.IncrementCallCount();
            SetValueMock.Value := value;
        END_METHOD

        METHOD PUBLIC Set
            SetMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC Reset
            ResetMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC Toggle
            ToggleMock.IncrementCallCount();
        END_METHOD
    END_CLASS

END_NAMESPACE