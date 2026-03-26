USING Esab.Mock;

NAMESPACE Esab.Io.Mock

    CLASS DigitalInputMock EXTENDS Input IMPLEMENTS IDigitalInput
        VAR PUBLIC
            ReadMock : BoolMethodMock;
            GetValueMock : BoolMethodMock;
            RisingEdgeMock : BoolMethodMock;
            FallingEdgeMock : BoolMethodMock;
            HasChangedMock : BoolMethodMock;
        END_VAR

        METHOD PUBLIC MockReset
            ReadMock.Reset();
            GetValueMock.Reset();
            RisingEdgeMock.Reset();
            FallingEdgeMock.Reset();
            HasChangedMock.Reset();
        END_METHOD

        METHOD PUBLIC Read
            VAR_INPUT
                value : BOOL;
            END_VAR

            ReadMock.IncrementCallCount();
            ReadMock.Value := value;
        END_METHOD

        METHOD PUBLIC GetValue : BOOL
            GetValueMock.IncrementCallCount();
            GetValue := GetValueMock.Value;
        END_METHOD

        METHOD PUBLIC RisingEdge : BOOL
            RisingEdgeMock.IncrementCallCount();
            RisingEdge := RisingEdgeMock.Value;
        END_METHOD

        METHOD PUBLIC FallingEdge : BOOL
            FallingEdgeMock.IncrementCallCount();
            FallingEdge := FallingEdgeMock.Value;
        END_METHOD

        METHOD PUBLIC OVERRIDE HasChanged : BOOL
            HasChangedMock.IncrementCallCount();
            HasChanged := HasChangedMock.Value;
        END_METHOD
    END_CLASS

    CLASS DigitalOutputMock IMPLEMENTS IDigitalOutput
        VAR PUBLIC
            WriteMock : BoolMethodMock;
            SetValueMock : BoolMethodMock;
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
                value : BOOL;
            END_VAR

            WriteMock.IncrementCallCount();
            value := WriteMock.Value;
        END_METHOD

        METHOD PUBLIC SetValue
            VAR_INPUT
                value: BOOL;
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