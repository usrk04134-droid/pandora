USING Esab.Utils.Timer.Mock;
USING Esab.Utils.Assets;

USING AxUnit;

NAMESPACE Esab.Utils.Fsm.Test

    {TestFixture}
    CLASS FsmTests
        VAR PRIVATE
            _fsm : StateMachine;
            _state1 : State1;
            _state2 : State2;
            _timedState1 : TimedState1;
            _stateTimer : OnDelayMock;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            _fsm.RegisterState(_state1);
            _fsm.RegisterState(_state2);
            _fsm.RegisterState(_timedState1);

            _fsm.Setup(States#State1, _stateTimer);
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            _state1.OnEntryCounter := 0;
            _state1.OnExecuteCounter := 0;
            _state1.OnExitCounter := 0;

            _state2.OnEntryCounter := 0;
            _state2.OnExecuteCounter := 0;
            _state2.OnExitCounter := 0;

            _stateTimer.MockReset();
        END_METHOD

        METHOD PRIVATE Execute
            _fsm.Execute();
        END_METHOD

        {Test}
        METHOD PUBLIC SimpleFsm
            Assert.Equal(_state1.OnEntryCounter, 0);
            Assert.Equal(_state1.OnExecuteCounter, 0);
            Assert.Equal(_state1.OnExitCounter, 0);

            THIS.Execute();

            Assert.Equal(_state1.OnEntryCounter, 1);
            Assert.Equal(_state1.OnExecuteCounter, 0);
            Assert.Equal(_state1.OnExitCounter, 0);

            THIS.Execute();

            Assert.Equal(_state1.OnEntryCounter, 1);
            Assert.Equal(_state1.OnExecuteCounter, 1);
            Assert.Equal(_state1.OnExitCounter, 0);

            THIS.Execute();
            THIS.Execute();
            THIS.Execute();
            THIS.Execute();

            Assert.Equal(_state1.OnEntryCounter, 1);
            Assert.Equal(_state1.OnExecuteCounter, 5);
            Assert.Equal(_state1.OnExitCounter, 0);

            THIS.Execute();

            Assert.Equal(_state1.OnEntryCounter, 1);
            Assert.Equal(_state1.OnExecuteCounter, 5);
            Assert.Equal(_state1.OnExitCounter, 1);

            THIS.Execute();

            Assert.Equal(_state1.OnEntryCounter, 1);
            Assert.Equal(_state1.OnExecuteCounter, 5);
            Assert.Equal(_state1.OnExitCounter, 1);
            Assert.Equal(_state2.OnEntryCounter, 1);
            Assert.Equal(_state2.OnExecuteCounter, 0);
            Assert.Equal(_state2.OnExitCounter, 0);


            THIS.Execute();

            Assert.Equal(_state1.OnEntryCounter, 1);
            Assert.Equal(_state1.OnExecuteCounter, 5);
            Assert.Equal(_state1.OnExitCounter, 1);
            Assert.Equal(_state2.OnEntryCounter, 1);
            Assert.Equal(_state2.OnExecuteCounter, 1);
            Assert.Equal(_state2.OnExitCounter, 0);

            THIS.Execute();
            THIS.Execute();
            THIS.Execute();
            THIS.Execute();

            Assert.Equal(_state1.OnEntryCounter, 1);
            Assert.Equal(_state1.OnExecuteCounter, 5);
            Assert.Equal(_state1.OnExitCounter, 1);
            Assert.Equal(_state2.OnEntryCounter, 1);
            Assert.Equal(_state2.OnExecuteCounter, 5);
            Assert.Equal(_state2.OnExitCounter, 0);

            THIS.Execute();

            Assert.Equal(_state1.OnEntryCounter, 1);
            Assert.Equal(_state1.OnExecuteCounter, 5);
            Assert.Equal(_state1.OnExitCounter, 1);
            Assert.Equal(_state2.OnEntryCounter, 1);
            Assert.Equal(_state2.OnExecuteCounter, 5);
            Assert.Equal(_state2.OnExitCounter, 1);

            THIS.Execute();

            Assert.Equal(_state1.OnEntryCounter, 2);
            Assert.Equal(_state1.OnExecuteCounter, 5);
            Assert.Equal(_state1.OnExitCounter, 1);
            Assert.Equal(_state2.OnEntryCounter, 1);
            Assert.Equal(_state2.OnExecuteCounter, 5);
            Assert.Equal(_state2.OnExitCounter, 1);
        END_METHOD

        {Test}
        METHOD PUBLIC TimedFsm
            _fsm.Setup(States#TimedState1, _stateTimer);

            THIS.Execute();

            Assert.Equal(_stateTimer.ExecuteMock.GetCallCount(), UINT#1);
            Assert.Equal(_stateTimer.ExecuteMock.Value, FALSE);

            THIS.Execute();

            Assert.Equal(_stateTimer.ExecuteMock.GetCallCount(), UINT#2);
            Assert.Equal(_stateTimer.ExecuteMock.Value, TRUE);
            Assert.Equal(_stateTimer.ExecuteMock.Duration, LTIME#5s);

            _stateTimer.ExpiredMock.Value := TRUE;

            THIS.Execute();

            Assert.Equal(_timedState1.OnTimeoutCounter, 1);
        END_METHOD
    END_CLASS

    CLASS State1 EXTENDS State
        VAR PUBLIC
            OnEntryCounter : INT := 0;
            OnExecuteCounter : INT := 0;
            OnExitCounter : INT := 0;
        END_VAR

        METHOD PUBLIC OVERRIDE OnEntry
            VAR_INPUT
                fsm : IStateMachine;
            END_VAR

            OnEntryCounter := OnEntryCounter + 1;
        END_METHOD

        METHOD PUBLIC OVERRIDE OnExecute : INT
            VAR_INPUT
                fsm : IStateMachine;
            END_VAR

            OnExecuteCounter := OnExecuteCounter + 1;

            IF OnExecuteCounter > 4 THEN
                OnExecute := States#State2;
            ELSE
                OnExecute := THIS.Id();
            END_IF;
        END_METHOD

        METHOD PUBLIC OVERRIDE OnExit
            VAR_INPUT
                fsm : IStateMachine;
            END_VAR

            OnExitCounter := OnExitCounter + 1;
        END_METHOD

        METHOD PUBLIC OVERRIDE Id : INT
            Id := States#State1;
        END_METHOD
    END_CLASS

    CLASS State2 EXTENDS State
        VAR PUBLIC
            OnEntryCounter : INT := 0;
            OnExecuteCounter : INT := 0;
            OnExitCounter : INT := 0;
        END_VAR

        METHOD PUBLIC OVERRIDE OnEntry
            VAR_INPUT
                fsm : IStateMachine;
            END_VAR

            OnEntryCounter := OnEntryCounter + 1;
        END_METHOD

        METHOD PUBLIC OVERRIDE OnExecute : INT
            VAR_INPUT
                fsm : IStateMachine;
            END_VAR

            OnExecuteCounter := OnExecuteCounter + 1;

            IF OnExecuteCounter > 4 THEN
                OnExecute := States#State1;
            ELSE
                OnExecute := THIS.Id();
            END_IF;
        END_METHOD

        METHOD PUBLIC OVERRIDE OnExit
            VAR_INPUT
                fsm : IStateMachine;
            END_VAR

            OnExitCounter := OnExitCounter + 1;
        END_METHOD

        METHOD PUBLIC OVERRIDE Id : INT
            Id := States#State2;
        END_METHOD
    END_CLASS

    CLASS TimedState1 EXTENDS State
        VAR PUBLIC
            OnTimeoutCounter : INT := 0;
        END_VAR

        METHOD PUBLIC OVERRIDE OnEntry
            VAR_INPUT
                fsm : IStateMachine;
            END_VAR

            OnTimeoutCounter := 0;
        END_METHOD

        METHOD PUBLIC OVERRIDE OnExecute : INT
            VAR_INPUT
                fsm : IStateMachine;
            END_VAR

            ;
        END_METHOD

        METHOD PUBLIC OVERRIDE OnTimeout
            OnTimeoutCounter := OnTimeoutCounter + 1;
        END_METHOD

        METHOD PUBLIC OVERRIDE GetTimeout : LTIME
            GetTimeout := LTIME#5s;
        END_METHOD

        METHOD PUBLIC OVERRIDE Id : INT
            Id := States#TimedState1;
        END_METHOD
    END_CLASS

    TYPE
        States : INT(
            State1 := 1,
            State2 := 2,
            TimedState1 := 3
        );
    END_TYPE
END_NAMESPACE