USING Esab.Utils.Timer;
NAMESPACE Esab.Utils.Fsm
    INTERFACE IState
        METHOD OnEntry
            VAR_INPUT
                fsm : IStateMachine;
            END_VAR
        END_METHOD

        /// State execution, should return the next state ID in case of state switching
        /// If no switch should occur, the current state should be returned.
        METHOD OnExecute : INT
            VAR_INPUT
                fsm : IStateMachine;
            END_VAR
        END_METHOD

        METHOD OnExit
            VAR_INPUT
                fsm : IStateMachine;
            END_VAR
        END_METHOD

        METHOD OnTimeout
        END_METHOD

        /// This should return the timeout time, implement/override.
        METHOD GetTimeout : LTIME
        END_METHOD

        METHOD Id : INT
        END_METHOD
    END_INTERFACE

    INTERFACE IStateMachine
        METHOD Setup : StateMachineErrorCode
            VAR_INPUT
                initialState : INT;
                stateTimer : ITimer;
            END_VAR
        END_METHOD

        METHOD Execute : StateMachineErrorCode
        END_METHOD

        METHOD Reset : StateMachineErrorCode
        END_METHOD

        METHOD GetCurrentStateExecutionTime : LTIME
        END_METHOD

        METHOD GetCurrentState : INT
        END_METHOD

        METHOD RegisterState : StateMachineErrorCode
            VAR_INPUT
                state : IState;
            END_VAR
        END_METHOD
    END_INTERFACE

    /// Abstract base class that implements IState and provides default implementations for OnEntry and OnExit.
    /// OnExecute is abstract, since that is where the main logic goes.
    /// Id is also abstract, that should return the state ID.
    CLASS ABSTRACT State IMPLEMENTS IState
        METHOD PUBLIC OnEntry
            VAR_INPUT
                fsm : IStateMachine;
            END_VAR

            ;
        END_METHOD

        METHOD PUBLIC ABSTRACT OnExecute : INT
            VAR_INPUT
                fsm : IStateMachine;
            END_VAR
        END_METHOD

        METHOD PUBLIC OnExit
            VAR_INPUT
                fsm : IStateMachine;
            END_VAR

            ;
        END_METHOD

        METHOD PUBLIC OnTimeout
            ;
        END_METHOD

        METHOD PUBLIC GetTimeout : LTIME
            GetTimeout := LTIME#365D;
        END_METHOD

        METHOD PUBLIC ABSTRACT Id : INT
        END_METHOD
    END_CLASS

    CLASS StateMachine IMPLEMENTS IStateMachine
        VAR CONSTANT PUBLIC
            MAX_STATE_ID : INT := 39;
        END_VAR

        VAR PRIVATE
            _previousState : IState := NULL;
            _currentState : IState := NULL;
            _nextState : IState := NULL;
            _initialState : IState := NULL;
            _states : ARRAY [0..MAX_STATE_ID] OF IState;

            _stateTimer : ITimer;
        END_VAR

        METHOD PUBLIC Setup : StateMachineErrorCode
            VAR_INPUT
                initialState : INT;
                stateTimer : ITimer;
            END_VAR

            VAR_TEMP
                idValid : StateMachineErrorCode;
            END_VAR

            idValid := THIS.ValidateStateId(initialState);

            IF idValid <> StateMachineErrorCode#NoError THEN
                Setup := idValid;
                RETURN;
            END_IF;

            _initialState := _states[initialState];
            _previousState := NULL;
            _currentState := _initialState;
            _nextState := _initialState;
            _stateTimer := stateTimer;
        END_METHOD

        METHOD PUBLIC Execute : StateMachineErrorCode
            VAR_TEMP
                nextStateId : INT;
                idValid : StateMachineErrorCode;
            END_VAR

            IF _nextState <> _previousState THEN
                IF _nextState <> _currentState THEN
                    IF _previousState <> NULL THEN
                        _previousState.OnExit(THIS);
                    END_IF;
                ELSIF _previousState <> _nextState THEN
                    IF _currentState <> NULL THEN
                        _currentState.OnEntry(THIS);

                        IF _stateTimer <> NULL THEN
                            _stateTimer.Execute(FALSE);
                        END_IF;
                    END_IF;
                END_IF;

                _previousState := _currentState;
                _currentState := _nextState;
            ELSE
                _previousState := _currentState;
                _currentState := _nextState;

                IF _currentState <> NULL THEN
                    nextStateId := _currentState.OnExecute(THIS);

                    IF _stateTimer <> NULL THEN
                        _stateTimer.Execute(TRUE, _currentState.GetTimeout());

                        IF _stateTimer.Expired() THEN
                            _currentState.OnTimeout();
                        END_IF;
                    END_IF;

                    idValid := THIS.ValidateStateId(nextStateId);

                    IF idValid <> StateMachineErrorCode#NoError THEN
                        Execute := idValid;
                        RETURN;
                    END_IF;

                    _nextState := _states[nextStateId];
                END_IF;
            END_IF;
        END_METHOD

        METHOD PUBLIC Reset : StateMachineErrorCode
            IF _initialState = NULL THEN
                Reset := StateMachineErrorCode#StateIsNull;
                RETURN;
            END_IF;

            _previousState := NULL;
            _currentState := _initialState;
            _nextState := _initialState;
        END_METHOD

        METHOD PUBLIC GetCurrentStateExecutionTime : LTIME
            IF _stateTimer <> NULL THEN
                GetCurrentStateExecutionTime := _stateTimer.ElapsedTime();
            ELSE
                GetCurrentStateExecutionTime := LTIME#0s;
            END_IF;
        END_METHOD

        METHOD PUBLIC GetCurrentState : INT
            GetCurrentState := _currentState.Id();
        END_METHOD

        METHOD PUBLIC RegisterState : StateMachineErrorCode
            VAR_INPUT
                state : IState;
            END_VAR

            VAR_TEMP
                id : INT := -1;
            END_VAR

            IF state = NULL THEN
                RegisterState := StateMachineErrorCode#StateIsNull;
                RETURN;
            END_IF;

            id := state.Id();

            IF id < 0 OR id > MAX_STATE_ID THEN
                RegisterState := StateMachineErrorCode#StateIdOutsideOfBounds;
                RETURN;
            END_IF;

            _states[id] := state;
        END_METHOD

        METHOD PRIVATE ValidateStateId : StateMachineErrorCode
            VAR_INPUT
                id : INT;
            END_VAR

            IF id < 0 OR id > MAX_STATE_ID THEN
                ValidateStateId := StateMachineErrorCode#StateIdOutsideOfBounds;
            END_IF;

            IF _states[id] = NULL THEN
                ValidateStateId := StateMachineErrorCode#StateNotRegistered;
            END_IF;
        END_METHOD
    END_CLASS

    TYPE
        StateMachineErrorCode : INT(
            NoError := 0,
            /// A requested state is not registered in the state machine
            StateNotRegistered := 1,
            /// The given state ID is outside of (0..MAX_STATE_ID)
            StateIdOutsideOfBounds := 2,
            /// A state null reference was encountered
            StateIsNull := 3,
            /// The state machine is not setup properly
            IncompleteSetup := 4
        ) := StateMachineErrorCode#NoError;
    END_TYPE
END_NAMESPACE