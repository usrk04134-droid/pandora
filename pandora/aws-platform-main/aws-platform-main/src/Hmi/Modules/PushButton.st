USING Esab.Utils.Alarming;
USING Esab.Utils.Assets;
USING Esab.Utils.Timer;
USING Esab.Io;

NAMESPACE Esab.Hmi.Modules

    CLASS PushButton EXTENDS Asset IMPLEMENTS IPushButton
        VAR PRIVATE
            _io : REF_TO PushButtonIo;
            _onTimer : ITimer;
            _listener : IPushButtonListener := NULL;

            _status : BOOL := FALSE;
            _shadowStatus : BOOL := FALSE;
            _statusFrequency : LREAL := 0.0;
        END_VAR

        METHOD PUBLIC Setup
            VAR_INPUT
                io : REF_TO PushButtonIo;
                onTimer : ITimer := NULL;
                setupAlarm : IAlarm;
            END_VAR

            _io := io;
            _onTimer := onTimer;
            _setupAlarm := setupAlarm;

            _isSetup := _io <> NULL;
        END_METHOD

        METHOD PUBLIC OVERRIDE Execute
            SUPER.Execute();

            IF _setupAlarm.IsActive() THEN
                RETURN;
            END_IF;

            IF _listener <> NULL THEN
                IF _io^.Pressed.RisingEdge() THEN
                    _listener.OnPushButtonPressed(THIS.GetIdentifier());
                ELSIF _io^.Pressed.GetValue() THEN
                    _listener.OnPushButton(THIS.GetIdentifier());
                ELSIF _io^.Pressed.FallingEdge() THEN
                    _listener.OnPushButtonReleased(THIS.GetIdentifier());
                END_IF;
            END_IF;

            THIS.UpdateStatus();
        END_METHOD

        METHOD PUBLIC OVERRIDE Observe : IAssetObservable
            Observe := NULL; // Push button cannot be observed
        END_METHOD

        METHOD PUBLIC IsPressed : BOOL
            IsPressed := _io^.Pressed.GetValue();
        END_METHOD

        METHOD PUBLIC SetStatus
            VAR_INPUT
                status : BOOL := FALSE;
            END_VAR

            _status := status;
            _shadowStatus := _status;
            _statusFrequency := 0.0;

            THIS.UpdateStatus();
        END_METHOD

        METHOD PUBLIC SetStatus
            VAR_INPUT
                frequency : LREAL := 0.0;
            END_VAR

            _status := TRUE;
            _shadowStatus := _status;
            _statusFrequency := frequency;

            THIS.UpdateStatus();
        END_METHOD

        METHOD PUBLIC SetListener
            VAR_INPUT
                listener : IPushButtonListener;
            END_VAR

            _listener := listener;
        END_METHOD

        METHOD PRIVATE UpdateStatus
            IF _status THEN
                IF _onTimer <> NULL AND _statusFrequency > 0.1 THEN
                    _onTimer.Execute(TRUE, TO_LTIME(TO_LINT((1.0/_statusFrequency)/2.0*1000.0)));
                    IF _onTimer.Expired() THEN
                        _onTimer.Execute(FALSE);
                        _shadowStatus := NOT _shadowStatus;
                    END_IF;
                ELSE
                    _shadowStatus := _status;
                END_IF;
            ELSE
                IF _onTimer <> NULL THEN
                    _onTimer.Execute(FALSE);
                END_IF;

                _shadowStatus := FALSE;
            END_IF;

            _io^.Status.SetValue(_shadowStatus);
        END_METHOD
    END_CLASS

    TYPE
        PushButtonIo : STRUCT
            Pressed : DigitalInput;
            Status : DigitalOutput;
        END_STRUCT;
    END_TYPE

END_NAMESPACE