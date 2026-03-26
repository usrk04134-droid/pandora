USING Esab.Io;
USING Esab.Utils.Alarming;
USING Esab.Utils.Assets;
USING Esab.Utils.Timer;
USING Esab.Hmi.Modules;

USING Siemens.Simatic.S71500.Alarming;

NAMESPACE Esab.Hmi.Modules

    CLASS DiscreteJoystick EXTENDS Asset IMPLEMENTS IJoystick
        VAR PUBLIC
        END_VAR

        VAR PRIVATE
            _io : REF_TO DiscreteJoystickIo;
            _longHoldTimer : ITimer := NULL;

            _previousPosition : JoystickPosition := JoystickPosition#Center;
            _placementChangedDirection : JoystickPosition := JoystickPosition#None;
            _lastLongHold : BOOL := FALSE;
            _longHold : BOOL;

            _clickListener : IClickListener;
            _longHoldListener : ILongHoldListener;
            _directionListener : IPositionChangedListener;
        END_VAR

        METHOD PUBLIC Setup
            VAR_INPUT
                io : REF_TO DiscreteJoystickIo;
                longHoldTimer : ITimer;
                setupAlarm : IAlarm;
            END_VAR

            _io := io;
            _longHoldTimer := longHoldTimer;
            _setupAlarm := setupAlarm;

            _isSetup := _io <> NULL AND _longHoldTimer <> NULL;
        END_METHOD

        METHOD PUBLIC OVERRIDE Execute
            VAR_TEMP
                _newPosition : JoystickPosition;
            END_VAR

            SUPER.Execute();

            IF _setupAlarm.IsActive() THEN
                RETURN;
            END_IF;

            _newPosition := THIS.GetPosition();

            IF _longHoldListener <> NULL THEN
                _longHoldTimer.Execute(_io^.Up.GetValue() OR _io^.Down.GetValue() OR _io^.Triangle.GetValue() OR _io^.Square.GetValue(), LT#1s);
                _longHold := _longHoldTimer.Expired();

                IF _longHold AND NOT _lastLongHold THEN
                    _longHoldListener.OnLongHoldDetected(THIS.GetPosition());
                ELSIF _longHold AND _lastLongHold THEN
                    _longHoldListener.OnLongHold(THIS.GetPosition());
                ELSIF NOT _longHold AND _lastLongHold THEN
                    _longHoldListener.OnLongHoldReleased(_previousPosition);
                END_IF;
            ELSE
                _longHoldTimer.Execute(FALSE, LT#1s);
                _longHold := FALSE;
            END_IF;

            IF _clickListener <> NULL THEN
                IF _newPosition = JoystickPosition#Center &&
                   _previousPosition <> JoystickPosition#Center &&
                    NOT (_longHold OR _lastLongHold) THEN

                    _clickListener.OnClick(_previousPosition);
                END_IF;
            END_IF;

            IF _directionListener <> NULL THEN
                IF _newPosition <> _previousPosition THEN
                    _directionListener.OnPositionChanged(_newPosition);
                END_IF;
            END_IF;

            _lastLongHold := _longHold;
            _previousPosition := _newPosition;
        END_METHOD

        METHOD PUBLIC GetPosition : JoystickPosition
            IF NOT _isSetup THEN
                RETURN;
            END_IF;

            IF _io^.Up.GetValue() THEN
                GetPosition := JoystickPosition#Up;
            ELSIF _io^.Down.GetValue() THEN
                GetPosition := JoystickPosition#Down;
            ELSIF _io^.Triangle.GetValue() THEN
                GetPosition := JoystickPosition#Triangle;
            ELSIF _io^.Square.GetValue() THEN
                GetPosition := JoystickPosition#Square;
            ELSE
                GetPosition := JoystickPosition#Center;
            END_IF;
        END_METHOD

        METHOD PUBLIC SetClickListener
            VAR_INPUT
                listener : IClickListener;
            END_VAR

            _clickListener := listener;
        END_METHOD

        METHOD PUBLIC SetLongHoldListener
            VAR_INPUT
                listener : ILongHoldListener;
            END_VAR

            _longHoldListener := listener;
        END_METHOD

        METHOD PUBLIC SetPositionChangedListener
            VAR_INPUT
                listener : IPositionChangedListener;
            END_VAR

            _directionListener := listener;
        END_METHOD

        METHOD PUBLIC OVERRIDE Observe : IAssetObservable
            Observe := NULL; // Joystick does not currently have an observable.
        END_METHOD
    END_CLASS

    TYPE
        DiscreteJoystickIo : STRUCT
            Up : DigitalInput;
            Down : DigitalInput;
            Triangle : DigitalInput;
            Square : DigitalInput;
        END_STRUCT;
    END_TYPE

END_NAMESPACE