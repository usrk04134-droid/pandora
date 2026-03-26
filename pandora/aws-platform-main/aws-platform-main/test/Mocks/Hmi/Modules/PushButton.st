USING Esab.Mock;
USING Esab.Mock;
USING Esab.Mock;
USING Esab.Mock;
USING Esab.Utils.Assets.Mock;
USING Esab.Utils.Assets;

NAMESPACE Esab.Hmi.Modules.Mock

    CLASS PushButtonMock EXTENDS Asset IMPLEMENTS IPushButton
        VAR PUBLIC
            IsPressedMock : BoolMethodMock;
            SetStatusSolid : BoolMethodMock;
            SetStatusFrequency : LRealMethodMock;
            SetListenerMock : PushButtonListenerMethodMock;
        END_VAR

        METHOD PUBLIC MockReset
            IsPressedMock.Reset();
            SetStatusSolid.Reset();
            SetStatusFrequency.Reset();
            SetListenerMock.Reset();
        END_METHOD

        METHOD PUBLIC IsPressed : BOOL
            IsPressed := IsPressedMock.Value;
            IsPressedMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC SetStatus
            VAR_INPUT
                status : BOOL := FALSE;
            END_VAR

            SetStatusSolid.Value := status;
            SetStatusSolid.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC SetStatus
            VAR_INPUT
                frequency : LREAL := 0.0;
            END_VAR

            SetStatusFrequency.Value := frequency;
            SetStatusFrequency.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC SetListener
            VAR_INPUT
                listener : IPushButtonListener;
            END_VAR

            SetListenerMock.Value := listener;
            SetListenerMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC OVERRIDE Observe : IAssetObservable
            Observe := NULL;
        END_METHOD
    END_CLASS

    CLASS PushButtonMockListener IMPLEMENTS IPushButtonListener
        VAR PUBLIC
            OnPushButtonPressedMock : AssetIdentifierMethodMock;
            OnPushButtonMock : AssetIdentifierMethodMock;
            OnPushButtonReleasedMock : AssetIdentifierMethodMock;
        END_VAR

        METHOD PUBLIC MockReset
            OnPushButtonPressedMock.Reset();
            OnPushButtonMock.Reset();
            OnPushButtonReleasedMock.Reset();
        END_METHOD

        METHOD PUBLIC OnPushButtonPressed
            VAR_INPUT
                id : AssetIdentifier;
            END_VAR

            OnPushButtonPressedMock.Value := id;
            OnPushButtonPressedMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC OnPushButton
            VAR_INPUT
                id : AssetIdentifier;
            END_VAR

            OnPushButtonMock.Value := id;
            OnPushButtonMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC OnPushButtonReleased
            VAR_INPUT
                id : AssetIdentifier;
            END_VAR

            OnPushButtonReleasedMock.Value := id;
            OnPushButtonReleasedMock.IncrementCallCount();
        END_METHOD
    END_CLASS

    CLASS PushButtonListenerMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value : IPushButtonListener;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Value := NULL;
        END_METHOD
    END_CLASS
END_NAMESPACE