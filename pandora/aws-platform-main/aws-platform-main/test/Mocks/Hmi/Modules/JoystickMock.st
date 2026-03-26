USING Esab.Mock;
USING Esab.Utils.Assets;

NAMESPACE Esab.Hmi.Modules.Mock

    CLASS JoystickMock EXTENDS Asset IMPLEMENTS IJoystick
        VAR PUBLIC
            IsInitializedMock : BoolMethodMock;
            ExecuteMock : MethodMock;
            GetPositionMock : PositionMock;
            SetClickListenerMock : MethodMock;
            SetLongHoldListenerMock : MethodMock;
            SetPositionChangedListenerMock : MethodMock;
        END_VAR

        METHOD PUBLIC MockReset
            IsInitializedMock.Reset();
            ExecuteMock.Reset();
            GetPositionMock.Reset();
            SetClickListenerMock.Reset();
            SetLongHoldListenerMock.Reset();
            SetPositionChangedListenerMock.Reset();
        END_METHOD

        METHOD PUBLIC IsInitialized : BOOL
            IsInitializedMock.IncrementCallCount();
            IsInitialized := IsInitializedMock.Value;
        END_METHOD

        METHOD PUBLIC OVERRIDE Execute
            ExecuteMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC GetPosition : JoystickPosition
            GetPositionMock.IncrementCallCount();
            GetPosition := GetPositionMock.Value;
        END_METHOD

        METHOD PUBLIC SetClickListener
            VAR_INPUT
                listener : IClickListener;
            END_VAR

            SetClickListenerMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC SetLongHoldListener
            VAR_INPUT
                listener : ILongHoldListener;
            END_VAR

            SetLongHoldListenerMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC SetPositionChangedListener
            VAR_INPUT
                listener : IPositionChangedListener;
            END_VAR

            SetPositionChangedListenerMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC OVERRIDE Observe : IAssetObservable
            Observe := NULL;
        END_METHOD
    END_CLASS

    CLASS PositionMock EXTENDS MethodMock
        VAR PUBLIC
            Value : JoystickPosition;
        END_VAR
    END_CLASS

END_NAMESPACE