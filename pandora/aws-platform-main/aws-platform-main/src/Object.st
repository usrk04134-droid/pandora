USING Esab.Utils.Alarming;

USING Siemens.Simatic.S71500.Alarming;

NAMESPACE Esab

    CLASS Object
        VAR PROTECTED
            _isSetup : BOOL := FALSE;
            _setupAlarm : IAlarm := NULL;

            {S7.Alarm = NoAck, "Object not setup properly"}
            _defaultSetupAlarm : ProgramAlarm;
            _defaultSetupAlarmWrapper : AlarmWrapper;

            _currentState : INT;
        END_VAR

        METHOD PUBLIC Execute
            IF _setupAlarm = NULL THEN
                _defaultSetupAlarmWrapper.Setup(REF(_defaultSetupAlarm));
                _setupAlarm := _defaultSetupAlarmWrapper;
            END_IF;

            _setupAlarm.Execute(NOT _isSetup);

            THIS.UpdateState();
        END_METHOD

        /// Updates the current object status (state), by default it is set to 0 which should signify "OK/healthy/idle" in all implementers.
        METHOD PUBLIC UpdateState
            _currentState := 0;
        END_METHOD

        METHOD PUBLIC GetState : INT
            GetState := _currentState;
        END_METHOD
    END_CLASS

END_NAMESPACE