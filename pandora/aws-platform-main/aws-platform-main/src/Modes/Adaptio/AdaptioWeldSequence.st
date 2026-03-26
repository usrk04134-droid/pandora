USING Esab.WeldSystem;
USING Esab.WeldSystem;
USING Esab.Motion;
USING Esab.Utils.Fsm;
USING Esab.Utils.Assets;
USING Esab.Utils.Timer;

USING System.FastMath;

NAMESPACE Esab.Modes

    // TODO: This could probably be more generalized to support other welding sequences.
    INTERFACE IWeldSequence
        METHOD Setup : StateMachineErrorCode
            VAR_INPUT
                weldAxisObservable : REF_TO AxisObservable;
                weldSystem : IWeldSystemOrchestrator;
            END_VAR
        END_METHOD

        METHOD Execute : StateMachineErrorCode
        END_METHOD

        METHOD Reset : StateMachineErrorCode
        END_METHOD

        METHOD SetWeldAxis
            VAR_INPUT
                weldAxisObservable : REF_TO AxisObservable;
            END_VAR
        END_METHOD

        METHOD GetWeldAxis : REF_TO AxisObservable
        END_METHOD

        METHOD SetWeldSystem
            VAR_INPUT
                weldSystem : IWeldSystemOrchestrator;
            END_VAR
        END_METHOD

        METHOD GetWeldSystem : IWeldSystemOrchestrator
        END_METHOD

        METHOD Start
        END_METHOD

        METHOD Stop
        END_METHOD

        METHOD QuickStop
        END_METHOD
    END_INTERFACE

    CLASS AdaptioWeldSequence EXTENDS StateMachine IMPLEMENTS IWeldSequence
        VAR PRIVATE
            // States
            _initialState : InitialState;
            _startTorch : StartTorch;
            _waitForNextTorchStart : WaitForNextTorchStart;
            _welding : Welding;
            _stopTorch : StopTorch;
            _waitForNextTorchStop : WaitForNextTorchStop;
            _quickStopState : QuickStop;

            _isSetup : BOOL := FALSE;

            // Other
            _stateTimer : ITimer;
            _weldAxisObservable : REF_TO AxisObservable;
            _weldSystem : IWeldSystemOrchestrator;
            _start : BOOL := FALSE;
            _stop : BOOL := FALSE;
            _quickStop : BOOL := FALSE;
            _startPosition : LREAL := 0.0;
            _torchIndex : INT;
        END_VAR

        METHOD PUBLIC Setup
            VAR_INPUT
                stateTimer : ITimer;
            END_VAR

            _stateTimer := stateTimer;
        END_METHOD

        METHOD PUBLIC Setup : StateMachineErrorCode
            VAR_INPUT
                weldAxisObservable : REF_TO AxisObservable;
                weldSystem : IWeldSystemOrchestrator;
            END_VAR

            _weldSystem := weldSystem;
            _weldAxisObservable := weldAxisObservable;

            _isSetup :=  _weldSystem <> NULL AND _weldAxisObservable <> NULL;

            _initialState.Setup(REF(_start), REF(_torchIndex), _weldSystem);
            _startTorch.Setup(REF(_torchIndex), REF(_startPosition), _weldSystem, _weldAxisObservable, REF(_quickStop));
            _waitForNextTorchStart.Setup(REF(_torchIndex), REF(_startPosition), _weldSystem, _weldAxisObservable, REF(_quickStop));
            _welding.Setup(REF(_stop), REF(_torchIndex), _weldSystem, REF(_quickStop));
            _stopTorch.Setup(REF(_torchIndex), REF(_startPosition), _weldSystem, _weldAxisObservable, REF(_quickStop));
            _waitForNextTorchStop.Setup(REF(_torchIndex), REF(_startPosition), _weldSystem, _weldAxisObservable, REF(_quickStop));
            _quickStopState.Setup(_weldSystem);

            THIS.RegisterState(_initialState);
            THIS.RegisterState(_startTorch);
            THIS.RegisterState(_waitForNextTorchStart);
            THIS.RegisterState(_welding);
            THIS.RegisterState(_stopTorch);
            THIS.RegisterState(_waitForNextTorchStop);
            THIS.RegisterState(_quickStopState);

            SUPER.Setup(AdaptioWeldSequenceState#InitialState, _stateTimer);
        END_METHOD

        METHOD PUBLIC OVERRIDE Execute : StateMachineErrorCode
            IF NOT _isSetup THEN
                Execute := StateMachineErrorCode#IncompleteSetup;
                RETURN;
            END_IF;

            SUPER.Execute();
        END_METHOD

        METHOD PUBLIC OVERRIDE Reset : StateMachineErrorCode
            SUPER.Reset();

            _start := FALSE;
            _stop := FALSE;
            _quickStop := FALSE;
        END_METHOD

        METHOD PUBLIC SetWeldAxis
            VAR_INPUT
                weldAxisObservable : REF_TO AxisObservable;
            END_VAR

            _weldAxisObservable := weldAxisObservable;
        END_METHOD

        METHOD PUBLIC GetWeldAxis : REF_TO AxisObservable
            GetWeldAxis := _weldAxisObservable;
        END_METHOD

        METHOD PUBLIC SetWeldSystem
            VAR_INPUT
                weldSystem : IWeldSystemOrchestrator;
            END_VAR

            _weldSystem := weldSystem;
        END_METHOD

        METHOD PUBLIC GetWeldSystem : IWeldSystemOrchestrator
            GetWeldSystem := _weldSystem;
        END_METHOD

        METHOD PUBLIC Start
            _start := TRUE; // TODO: Add check so that we are not already running. We don't want a latent start after we have just stopped.
        END_METHOD

        METHOD PUBLIC Stop
            _stop := TRUE;
        END_METHOD

        METHOD PUBLIC QuickStop
            _quickStop := TRUE;
        END_METHOD
    END_CLASS

    CLASS InitialState EXTENDS State
        VAR PRIVATE
            _start : REF_TO BOOL;
            _torchIndex : REF_TO INT;
            _weldSystem : IWeldSystemOrchestrator;
        END_VAR

        METHOD PUBLIC Setup
            VAR_INPUT
                start : REF_TO BOOL;
                torchIndex : REF_TO INT;
                weldSystem : IWeldSystemOrchestrator;
            END_VAR

            _start := start;
            _torchIndex := torchIndex;
            _weldSystem := weldSystem;
        END_METHOD

        METHOD PUBLIC OVERRIDE OnExecute : INT
            VAR_INPUT
                fsm : IStateMachine;
            END_VAR

            OnExecute := THIS.Id();

            IF _start^ THEN
                OnExecute := AdaptioWeldSequenceState#StartTorch;
                RETURN;
            END_IF;
        END_METHOD

        METHOD PUBLIC OVERRIDE OnExit
            VAR_INPUT
                fsm : IStateMachine;
            END_VAR

            _start^ := FALSE;
            _torchIndex^ := _weldSystem.GetHeadTorchIndex();
        END_METHOD

        METHOD PUBLIC OVERRIDE Id : INT
            Id := AdaptioWeldSequenceState#InitialState;
        END_METHOD
    END_CLASS

    CLASS StartTorch EXTENDS State
        VAR PRIVATE
            _torchIndex : REF_TO INT;
            _startPosition : REF_TO LREAL;
            _weldSystem : IWeldSystemOrchestrator;
            _weldAxis : REF_TO AxisObservable;

            _startTimeout : BOOL := FALSE;
            _quickStop : REF_TO BOOL;
        END_VAR

        METHOD PUBLIC Setup
            VAR_INPUT
                torchIndex : REF_TO INT;
                startPosition : REF_TO LREAL;
                weldSystem : IWeldSystemOrchestrator;
                weldAxis : REF_TO AxisObservable;
                quickStop : REF_TO BOOL;
            END_VAR

            _torchIndex := torchIndex;
            _startPosition := startPosition;
            _weldSystem := weldSystem;
            _weldAxis := weldAxis;
            _quickStop := quickStop;
        END_METHOD

        METHOD PUBLIC OVERRIDE OnEntry
            VAR_INPUT
                fsm : IStateMachine;
            END_VAR

            _startTimeout := FALSE;
            _weldSystem.StartWelding(_torchIndex^);
        END_METHOD

        METHOD PUBLIC OVERRIDE OnExecute : INT
            VAR_INPUT
                fsm : IStateMachine;
            END_VAR

            OnExecute := THIS.Id();

            IF _quickStop^ THEN
                _quickStop^ := FALSE;
                OnExecute := AdaptioWeldSequenceState#QuickStop;
                RETURN;
            END_IF;

            IF _weldSystem.IsWelding(_torchIndex^) THEN
                _startPosition^ := _weldAxis^.LinearPosition;
                _torchIndex^ := _weldSystem.GetNextEnabledPowerSource(_torchIndex^);
                IF _torchIndex^ = -1 THEN
                    OnExecute := AdaptioWeldSequenceState#Welding;
                ELSE
                    OnExecute := AdaptioWeldSequenceState#WaitForNextTorchStart;
                END_IF;
            ELSIF _startTimeout THEN
                OnExecute := AdaptioWeldSequenceState#QuickStop;
            END_IF;
        END_METHOD

        METHOD PUBLIC OVERRIDE OnTimeout
            _startTimeout := TRUE;
        END_METHOD

        METHOD PUBLIC OVERRIDE GetTimeout : LTIME
            GetTimeout := LTIME#5s;
        END_METHOD

        METHOD PUBLIC OVERRIDE Id : INT
            Id := AdaptioWeldSequenceState#StartTorch;
        END_METHOD
    END_CLASS

    CLASS WaitForNextTorchStart EXTENDS State
        VAR PRIVATE
            _wireOffset : LREAL;

            _torchIndex : REF_TO INT;
            _startPosition : REF_TO LREAL;
            _weldSystem : IWeldSystemOrchestrator;
            _weldAxis : REF_TO AxisObservable;
            _quickStop : REF_TO BOOL;
        END_VAR

        METHOD PUBLIC OVERRIDE OnEntry
            VAR_INPUT
                fsm : IStateMachine;
            END_VAR

            _wireOffset := _weldSystem.WireOffset(_torchIndex^);
        END_METHOD

        METHOD PUBLIC Setup
            VAR_INPUT
                torchIndex : REF_TO INT;
                startPosition : REF_TO LREAL;
                weldSystem : IWeldSystemOrchestrator;
                weldAxis : REF_TO AxisObservable;
                quickStop : REF_TO BOOL;
            END_VAR

            _torchIndex := torchIndex;
            _startPosition := startPosition;
            _weldSystem := weldSystem;
            _weldAxis := weldAxis;
            _quickStop := quickStop;
        END_METHOD

        METHOD PUBLIC OVERRIDE OnExecute : INT
            VAR_INPUT
                fsm : IStateMachine;
            END_VAR

            OnExecute := THIS.Id();

            IF _quickStop^ THEN
                _quickStop^ := FALSE;
                OnExecute := AdaptioWeldSequenceState#QuickStop;
                RETURN;
            END_IF;

            IF Abs(_weldAxis^.LinearPosition - _startPosition^) >= _wireOffset THEN
                OnExecute := AdaptioWeldSequenceState#StartTorch;
            END_IF;
        END_METHOD

        METHOD PUBLIC OVERRIDE Id : INT
            Id := AdaptioWeldSequenceState#WaitForNextTorchStart;
        END_METHOD
    END_CLASS

    CLASS Welding EXTENDS State
        VAR PRIVATE
            _stop : REF_TO BOOL;
            _torchIndex : REF_TO INT;
            _weldSystem : IWeldSystemOrchestrator;
            _quickStop : REF_TO BOOL;
        END_VAR

        METHOD PUBLIC Setup
            VAR_INPUT
                stop : REF_TO BOOL;
                torchIndex : REF_TO INT;
                weldSystem : IWeldSystemOrchestrator;
                quickStop : REF_TO BOOL;
            END_VAR

            _stop := stop;
            _torchIndex := torchIndex;
            _weldSystem := weldSystem;
            _quickStop := quickStop;
        END_METHOD

        METHOD PUBLIC OVERRIDE OnExecute : INT
            VAR_INPUT
                fsm : IStateMachine;
            END_VAR

            OnExecute := THIS.Id();

            IF _quickStop^ THEN
                _quickStop^ := FALSE;
                OnExecute := AdaptioWeldSequenceState#QuickStop;
                RETURN;
            END_IF;

            IF _stop^ THEN
                OnExecute := AdaptioWeldSequenceState#StopTorch;
            END_IF;
        END_METHOD

        METHOD PUBLIC OVERRIDE OnExit
            VAR_INPUT
                fsm : IStateMachine;
            END_VAR

            _stop^ := FALSE;
            _torchIndex^ := _weldSystem.GetHeadTorchIndex();
        END_METHOD

        METHOD PUBLIC OVERRIDE Id : INT
            Id := AdaptioWeldSequenceState#Welding;
        END_METHOD
    END_CLASS

    CLASS StopTorch EXTENDS State
        VAR PRIVATE
            _torchIndex : REF_TO INT;
            _startPosition : REF_TO LREAL;
            _weldSystem : IWeldSystemOrchestrator;
            _weldAxis : REF_TO AxisObservable;
            _quickStop : REF_TO BOOL;
        END_VAR

        METHOD PUBLIC Setup
            VAR_INPUT
                torchIndex : REF_TO INT;
                startPosition : REF_TO LREAL;
                weldSystem : IWeldSystemOrchestrator;
                weldAxis : REF_TO AxisObservable;
                quickStop : REF_TO BOOL;
            END_VAR

            _torchIndex := torchIndex;
            _startPosition := startPosition;
            _weldSystem := weldSystem;
            _weldAxis := weldAxis;
            _quickStop := quickStop;
        END_METHOD

        METHOD PUBLIC OVERRIDE OnEntry
            VAR_INPUT
                fsm : IStateMachine;
            END_VAR

            _weldSystem.StopWelding(_torchIndex^);
        END_METHOD

        METHOD PUBLIC OVERRIDE OnExecute : INT
            VAR_INPUT
                fsm : IStateMachine;
            END_VAR

            OnExecute := THIS.Id();

            IF _quickStop^ THEN
                _quickStop^ := FALSE;
                OnExecute := AdaptioWeldSequenceState#QuickStop;
                RETURN;
            END_IF;

            IF NOT _weldSystem.IsWelding(_torchIndex^) THEN
                _startPosition^ := _weldAxis^.LinearPosition; // TODO: Don't use the same variable for both start and stop.
                _torchIndex^ := _weldSystem.GetNextEnabledPowerSource(_torchIndex^); // TODO: Edge cases, enabled power source that is not welding?
                IF _torchIndex^ = -1 THEN
                    OnExecute := AdaptioWeldSequenceState#InitialState;
                ELSE
                    OnExecute := AdaptioWeldSequenceState#WaitForNextTorchStop;
                END_IF;
            END_IF;
        END_METHOD

        METHOD PUBLIC OVERRIDE Id : INT
            Id := AdaptioWeldSequenceState#StopTorch;
        END_METHOD
    END_CLASS

    CLASS WaitForNextTorchStop EXTENDS State
        VAR PRIVATE
            _wireOffset : LREAL;

            _torchIndex : REF_TO INT;
            _startPosition : REF_TO LREAL;
            _weldSystem : IWeldSystemOrchestrator;
            _weldAxis : REF_TO AxisObservable;
            _quickStop : REF_TO BOOL;
        END_VAR

        METHOD PUBLIC OVERRIDE OnEntry
            VAR_INPUT
                fsm : IStateMachine;
            END_VAR

            _wireOffset := _weldSystem.WireOffset(_torchIndex^);
        END_METHOD

        METHOD PUBLIC Setup
            VAR_INPUT
                torchIndex : REF_TO INT;
                startPosition : REF_TO LREAL;
                weldSystem : IWeldSystemOrchestrator;
                weldAxis : REF_TO AxisObservable;
                quickStop : REF_TO BOOL;
            END_VAR

            _torchIndex := torchIndex;
            _startPosition := startPosition;
            _weldSystem := weldSystem;
            _weldAxis := weldAxis;
            _quickStop := quickStop;
        END_METHOD

        METHOD PUBLIC OVERRIDE OnExecute : INT
            VAR_INPUT
                fsm : IStateMachine;
            END_VAR

            OnExecute := THIS.Id();

            IF _quickStop^ THEN
                _quickStop^ := FALSE;
                OnExecute := AdaptioWeldSequenceState#QuickStop;
                RETURN;
            END_IF;

            IF Abs(_weldAxis^.LinearPosition - _startPosition^) >= _wireOffset THEN
                OnExecute := AdaptioWeldSequenceState#StopTorch;
            END_IF;
        END_METHOD

        METHOD PUBLIC OVERRIDE Id : INT
            Id := AdaptioWeldSequenceState#WaitForNextTorchStop;
        END_METHOD
    END_CLASS

    CLASS QuickStop EXTENDS State
        VAR PRIVATE
            _weldSystem : IWeldSystemOrchestrator;
        END_VAR

        METHOD PUBLIC Setup
            VAR_INPUT
                weldSystem : IWeldSystemOrchestrator;
            END_VAR

            _weldSystem := weldSystem;
        END_METHOD

        METHOD PUBLIC OVERRIDE OnEntry
            VAR_INPUT
                fsm : IStateMachine;
            END_VAR

            _weldSystem.Stop(TRUE);
        END_METHOD

        METHOD PUBLIC OVERRIDE OnExecute : INT
            VAR_INPUT
                fsm : IStateMachine;
            END_VAR

            OnExecute := THIS.Id();
            IF NOT _weldSystem.IsWelding() THEN
                OnExecute := AdaptioWeldSequenceState#InitialState;
            END_IF;
        END_METHOD

        METHOD PUBLIC OVERRIDE Id : INT
            Id := AdaptioWeldSequenceState#QuickStop;
        END_METHOD

    END_CLASS

    TYPE
        AdaptioWeldSequenceState : INT(
            InitialState            := 0,
            StartTorch              := 1,
            WaitForNextTorchStart   := 3,
            Welding                 := 4,
            StopTorch               := 5,
            QuickStop               := 6,
            WaitForNextTorchStop    := 7
        );
    END_TYPE

END_NAMESPACE