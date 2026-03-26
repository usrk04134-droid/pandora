USING Esab.Utils.Alarming;
USING Esab.Utils.Timer;
USING Esab.Utils.Io;

NAMESPACE Esab.Utils.Heartbeat

    /// Implements a heartbeat which sets an output to an incremented value of the input.
    /// The alarm is optional.
    CLASS IncrementingHeartbeat IMPLEMENTS IHeartbeat
        VAR PRIVATE
            _input : IDIntInput;
            _output : IDIntOutput;
            _timer: ITimer;
            _alarm : IAlarm;

            _value : DINT;
            _lastValue : DINT;
            _alive : BOOL;
            _isSetup : BOOL := FALSE;

            _heartbeatValue : DINT := DINT#0;
        END_VAR

        METHOD PUBLIC Setup
            VAR_INPUT
                input : IDIntInput;
                output : IDIntOutput;
                timer : ITimer;
                alarm : IAlarm;
            END_VAR

            _input := input;
            _output := output;
            _timer := timer;
            _alarm := alarm;

            _isSetup := input <> NULL AND
                        output <> NULL AND
                        timer <> NULL;
        END_METHOD

        METHOD PUBLIC Execute
            IF NOT _isSetup THEN
                _alive := FALSE;
                RETURN;
            END_IF;

            _lastValue := _value;
            _value := _input.GetValue();
            _heartbeatValue := _heartbeatValue + 1;
            _output.SetValue(_heartbeatValue);

            _timer.Execute(_value = _lastValue, LT#500ms);
            _alive := NOT _timer.Expired();

            IF _alarm <> NULL THEN
                _alarm.Execute(NOT _alive);
            END_IF;
        END_METHOD

        METHOD PUBLIC Alive : BOOL
            Alive := _alive;
        END_METHOD

        METHOD PUBLIC Dead : BOOL
            Dead := NOT _alive;
        END_METHOD
    END_CLASS

END_NAMESPACE