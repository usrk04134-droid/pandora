USING Esab.Utils.Alarming;
USING Esab.Utils.Assets;
USING Esab.Io;

NAMESPACE Esab.Hmi.Modules

    CLASS TwinPushButton EXTENDS Asset IMPLEMENTS ITwinPushButton
        VAR PRIVATE
            _io : REF_TO TwinPushButtonIo;
            _listener : IPushButtonListener := NULL;
        END_VAR

        METHOD PUBLIC Setup
            VAR_INPUT
                io : REF_TO TwinPushButtonIo;
                setupAlarm : IAlarm;
            END_VAR

            _io := io;
            _setupAlarm := setupAlarm;

            _isSetup := _io <> NULL;
        END_METHOD

        METHOD PUBLIC OVERRIDE Observe : IAssetObservable
            Observe := NULL; // Push button cannot be observed
        END_METHOD

        METHOD PUBLIC OVERRIDE Execute
            SUPER.Execute();

            IF _setupAlarm.IsActive() THEN
                RETURN;
            END_IF;

            IF _listener <> NULL THEN
                IF _io^.Direction1.RisingEdge() OR _io^.Direction2.RisingEdge() THEN
                    _listener.OnPushButtonPressed(THIS.GetIdentifier());
                ELSIF _io^.Direction1.GetValue() OR _io^.Direction2.GetValue() THEN
                    _listener.OnPushButton(THIS.GetIdentifier());
                ELSIF _io^.Direction1.FallingEdge() OR _io^.Direction2.FallingEdge() THEN
                    _listener.OnPushButtonReleased(THIS.GetIdentifier());
                END_IF;
            END_IF;
        END_METHOD

        METHOD PUBLIC IsPressed : BOOL
            IsPressed := THIS.IsInDirection1() OR THIS.IsInDirection2();
        END_METHOD

        METHOD PUBLIC IsInDirection1 : BOOL
            IsInDirection1 := _io^.Direction1.GetValue();
        END_METHOD

        METHOD PUBLIC IsInDirection2 : BOOL
            IsInDirection2 := _io^.Direction2.GetValue();
        END_METHOD

        METHOD PUBLIC SetStatus
            VAR_INPUT
                status : BOOL := FALSE;
            END_VAR

            _io^.Status.SetValue(status);
        END_METHOD

        METHOD PUBLIC SetStatus
            VAR_INPUT
                frequency : LREAL := 0.0;
            END_VAR

            ;
        END_METHOD

        METHOD PUBLIC SetListener
            VAR_INPUT
                listener : IPushButtonListener;
            END_VAR

            _listener := listener;
        END_METHOD
    END_CLASS

    TYPE
        TwinPushButtonIo : STRUCT
            Direction1 : DigitalInput;
            Direction2 : DigitalInput;
            Status : DigitalOutput;
        END_STRUCT;
    END_TYPE

END_NAMESPACE