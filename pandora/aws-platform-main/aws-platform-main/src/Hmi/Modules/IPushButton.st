
NAMESPACE Esab.Hmi.Modules

    INTERFACE IPushButton
        METHOD IsPressed : BOOL
        END_METHOD

        METHOD SetStatus
            VAR_INPUT
                status : BOOL := FALSE;
            END_VAR
        END_METHOD

        METHOD SetStatus
            VAR_INPUT
                frequency : LREAL := 0.0;
            END_VAR
        END_METHOD

        METHOD SetListener
            VAR_INPUT
                listener : IPushButtonListener;
            END_VAR
        END_METHOD
    END_INTERFACE

    INTERFACE ITwinPushButton EXTENDS IPushButton
        METHOD IsInDirection1 : BOOL
        END_METHOD

        METHOD IsInDirection2 : BOOL
        END_METHOD
    END_INTERFACE

    INTERFACE IPushButtonListener
        METHOD OnPushButtonPressed
            VAR_INPUT
                id : Esab.AssetIdentifier;
            END_VAR
        END_METHOD

        METHOD OnPushButton
            VAR_INPUT
                id : Esab.AssetIdentifier;
            END_VAR
        END_METHOD

        METHOD OnPushButtonReleased
            VAR_INPUT
                id : Esab.AssetIdentifier;
            END_VAR
        END_METHOD
    END_INTERFACE

END_NAMESPACE