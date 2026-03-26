USING Esab.Utils.Alarming;
USING Esab.Utils.Assets;
USING Esab.Io;

NAMESPACE Esab.Peripheral
    CLASS ActivatableAsset EXTENDS Asset IMPLEMENTS IActivatableAsset
        VAR PRIVATE
            _io : REF_TO Io;
            _active : BOOL;
            _observable: ActivatableObservable;
        END_VAR

        METHOD PUBLIC Setup
            VAR_INPUT
                io : REF_TO Io;
                setupAlarm : IAlarm;
            END_VAR

            _io := io;
            _setupAlarm := setupAlarm;
            _active := False;
            _isSetup := _io <> NULL;
        END_METHOD

        METHOD PUBLIC OVERRIDE Execute
            SUPER.Execute();

            IF _setupAlarm.IsActive() THEN
                RETURN;
            END_IF;

            _io^.Active.SetValue(_active);
            _observable.Active := _active;
        END_METHOD

        METHOD PUBLIC IsActive : BOOL
            IsActive := _active;
        END_METHOD

        METHOD PUBLIC Activate
            _active := TRUE;
            _io^.Active.SetValue(_active);
        END_METHOD

        METHOD PUBLIC Deactivate
            _active := FALSE;
            _io^.Active.SetValue(_active);
        END_METHOD

        METHOD PUBLIC OVERRIDE Observe: IAssetObservable
            Observe := _observable;
        END_METHOD
    END_CLASS

    TYPE
        Io : STRUCT
            Active : DigitalOutput;
        END_STRUCT;
    END_TYPE
END_NAMESPACE