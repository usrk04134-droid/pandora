USING Esab.Utils.Assets;

NAMESPACE Esab.Utils.EmergencyStop

    INTERFACE IEmergencyStopCircuit
        METHOD IsActive : BOOL
        END_METHOD

        METHOD SetListener
            VAR_INPUT
                listener : IEmergencyStopListener;
            END_VAR
        END_METHOD
    END_INTERFACE

    INTERFACE IEmergencyStopListener
        METHOD EmergencyStopActivated
        END_METHOD

        METHOD EmergencyStopReset
        END_METHOD
    END_INTERFACE

    CLASS EmergencyStopCircuitObservable IMPLEMENTS IAssetObservable
        VAR PUBLIC
            Active : BOOL := FALSE;
        END_VAR
    END_CLASS

END_NAMESPACE