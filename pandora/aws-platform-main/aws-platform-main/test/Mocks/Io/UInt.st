USING Esab.Mock;

NAMESPACE Esab.Io.Mock

    CLASS UIntInputMock EXTENDS Input IMPLEMENTS IUIntInput
        VAR PUBLIC
            ReadUIntMock : UIntMethodMock;
            ReadByteMock : ByteMethodMock;
            GetValueMock : UIntMethodMock;
            HasChangedMock : BoolMethodMock;
        END_VAR

        METHOD PUBLIC MockReset
            ReadUIntMock.Reset();
            ReadByteMock.Reset();
            GetValueMock.Reset();
            HasChangedMock.Reset();
        END_METHOD

        METHOD PUBLIC Read
            VAR_INPUT
                value : UINT;
            END_VAR

            ReadUIntMock.IncrementCallCount();
            ReadUIntMock.Value := value;
        END_METHOD

        METHOD PUBLIC Read
            VAR_INPUT
                value : BYTE;
            END_VAR

            ReadByteMock.IncrementCallCount();
            ReadByteMock.Value := value;
        END_METHOD

        METHOD PUBLIC GetValue : UINT
            GetValueMock.IncrementCallCount();
            GetValue := GetValueMock.Value;
        END_METHOD

        METHOD PUBLIC OVERRIDE HasChanged : BOOL
            HasChangedMock.IncrementCallCount();
            HasChanged := HasChangedMock.Value;
        END_METHOD
    END_CLASS

    CLASS UIntOutputMock IMPLEMENTS IUIntOutput
        VAR PUBLIC
            WriteUIntMock : UIntMethodMock;
            WriteByteMock : ByteMethodMock;
            SetValueUIntMock : UIntMethodMock;
            SetValueByteMock : ByteMethodMock;
            SetMock : MethodMock;
            ResetMock : MethodMock;
            ToggleMock : MethodMock;
        END_VAR

        METHOD PUBLIC MockReset
            WriteUIntMock.Reset();
            WriteByteMock.Reset();
            SetValueUIntMock.Reset();
            SetValueByteMock.Reset();
            SetMock.Reset();
            ResetMock.Reset();
            ToggleMock.Reset();
        END_METHOD

        METHOD PUBLIC Write
            VAR_OUTPUT
                value : UINT;
            END_VAR

            WriteUIntMock.IncrementCallCount();
            value := WriteUIntMock.Value;
        END_METHOD

        METHOD PUBLIC Write
            VAR_OUTPUT
                value : BYTE;
            END_VAR

            WriteByteMock.IncrementCallCount();
            value := WriteByteMock.Value;
        END_METHOD

        METHOD PUBLIC SetValue
            VAR_INPUT
                value: UINT;
            END_VAR

            SetValueUIntMock.IncrementCallCount();
            SetValueUIntMock.Value := value;
        END_METHOD

        METHOD PUBLIC SetValue
            VAR_INPUT
                value: BYTE;
            END_VAR

            SetValueByteMock.IncrementCallCount();
            SetValueByteMock.Value := value;
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