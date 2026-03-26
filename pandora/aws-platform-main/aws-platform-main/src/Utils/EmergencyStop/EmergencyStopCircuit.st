USING Esab.Io;
USING Esab.Utils.Assets;

NAMESPACE Esab.Utils.EmergencyStop

    CLASS EmergencyStopCircuit EXTENDS Asset IMPLEMENTS IEmergencyStopCircuit
        VAR PUBLIC
            Io : REF_TO EmergencyStopCircuitIo := NULL;
        END_VAR

        VAR PRIVATE
            _observable : EmergencyStopCircuitObservable;
            _listener : IEmergencyStopListener := NULL;
        END_VAR

        METHOD PUBLIC IsInitialized : BOOL
            IsInitialized := Io <> NULL;
        END_METHOD

        METHOD PUBLIC OVERRIDE Execute
            IF NOT THIS.IsInitialized() THEN
                RETURN;
            END_IF;

            THIS.UpdateObservable();

            IF _listener <> NULL THEN
                IF Io^.LoopClosed.FallingEdge() THEN
                    _listener.EmergencyStopActivated();
                END_IF;

                IF Io^.LoopClosed.RisingEdge() THEN
                    _listener.EmergencyStopReset();
                END_IF;
            END_IF;
        END_METHOD

        METHOD PUBLIC OVERRIDE Observe : IAssetObservable
            Observe := _observable;
        END_METHOD

        METHOD PUBLIC IsActive : BOOL
            IF Io <> NULL THEN
                IsActive := NOT Io^.LoopClosed.GetValue();
            ELSE
                IsActive := TRUE;
            END_IF;
        END_METHOD

        METHOD PUBLIC SetListener
            VAR_INPUT
                listener : IEmergencyStopListener;
            END_VAR

            _listener := listener;
        END_METHOD

        METHOD PRIVATE UpdateObservable
            _observable.Active := THIS.IsActive();
        END_METHOD
    END_CLASS

    TYPE
        EmergencyStopCircuitIo : STRUCT
            LoopClosed : DigitalInput;
        END_STRUCT;
    END_TYPE

END_NAMESPACE