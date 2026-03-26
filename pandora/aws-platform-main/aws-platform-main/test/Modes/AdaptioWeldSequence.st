USING Esab.Motion;
USING Esab.WeldSystem.Mock;
USING AxUnit;

NAMESPACE Esab.Modes.Test

    {TestFixture}
    CLASS AdaptioWeldSequenceTests
        VAR PRIVATE
            _fsm : AdaptioWeldSequence;
            _weldSystem : WeldSystemOrchestratorMock;
            _weldAxisObservable : AxisObservable;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            VAR_TEMP
                errorCode : INT;
            END_VAR

            errorCode := _fsm.Setup(REF(_weldAxisObservable),
                                    _weldSystem);

            Assert.Equal(errorCode, 0);
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            _weldSystem.MockReset();

            _weldAxisObservable.Busy := FALSE;
            _weldAxisObservable.Enabled := FALSE;
            _weldAxisObservable.Error := FALSE;
            _weldAxisObservable.Homed := FALSE;
            _weldAxisObservable.LinearPosition := 0.0;
            _weldAxisObservable.Standstill := TRUE;
            _weldAxisObservable.LinearVelocity := 0.0;

            _fsm.Reset();
            _fsm.Execute();
            _fsm.Execute();
        END_METHOD

        METHOD PRIVATE Execute
            _fsm.Execute();
        END_METHOD

        {Test}
        METHOD PUBLIC DualTorchWeld
            // Set initial values
            _weldSystem.ReadyToWeldMock.Value := TRUE;
            _weldSystem.WireOffsetMock.Value2 := 10.0;

            // Initial state
            Assert.Equal(_fsm.GetCurrentState(), AdaptioWeldSequenceState#InitialState);
            _weldSystem.GetHeadTorchIndexMock.Value := 1;
            _weldAxisObservable.LinearPosition := 0.0;

            THIS.Execute(); // _initialState.OnExecute
            THIS.Execute(); // _initialState.OnExecute

            // Trigger state change
            _fsm.Start();

            THIS.Execute(); // _initialState.OnExecute
            THIS.Execute(); // _initialState.OnExit

            // Start head torch
            THIS.Execute(); // _startTorch.OnEntry

            Assert.Equal(_weldSystem.StartWeldingMock.Value, 1);

            THIS.Execute(); // _startTorch.OnExecute

            Assert.Equal(_fsm.GetCurrentState(), AdaptioWeldSequenceState#StartTorch);
            Assert.Equal(_weldSystem.IsWeldingIndexedMock.Value1, 1);

            THIS.Execute(); // _startTorch.OnExecute
            THIS.Execute(); // _startTorch.OnExecute
            THIS.Execute(); // _startTorch.OnExecute

            Assert.Equal(_weldSystem.IsWeldingIndexedMock.GetCallCount(), UINT#4);
            Assert.Equal(_fsm.GetCurrentState(), AdaptioWeldSequenceState#StartTorch);
            _weldSystem.IsWeldingIndexedMock.Value2 := TRUE;
            _weldSystem.GetNextEnabledPowerSourceMock.Value1 := 1;
            _weldSystem.GetNextEnabledPowerSourceMock.Value2 := 2;

            THIS.Execute(); // _startTorch.OnExecute
            THIS.Execute(); // _startTorch.OnExit
            _weldSystem.IsWeldingIndexedMock.Value2 := FALSE;

            Assert.Equal(_weldSystem.GetNextEnabledPowerSourceMock.GetCallCount(), UINT#1);

            // Wait for next torch
            THIS.Execute(); // _waitForNextTorch.OnEntry

            Assert.Equal(_fsm.GetCurrentState(), AdaptioWeldSequenceState#WaitForNextTorchStart);
            Assert.GreaterOrEqual(_weldSystem.WireOffsetMock.GetCallCount(), UINT#1);
            Assert.Equal(_weldSystem.WireOffsetMock.Value1, 2);

            THIS.Execute(); // _waitForNextTorch.OnExecute
            THIS.Execute(); // _waitForNextTorch.OnExecute
            THIS.Execute(); // _waitForNextTorch.OnExecute

            _weldAxisObservable.LinearPosition := 11.0;

            THIS.Execute(); // _waitForNextTorch.OnExecute
            THIS.Execute(); // _waitForNextTorch.OnExit

            // Start (second) torch
            THIS.Execute(); // _startTorch.OnEntry
            THIS.Execute(); // _startTorch.OnExecute

            Assert.Equal(_fsm.GetCurrentState(), AdaptioWeldSequenceState#StartTorch);
            Assert.Equal(_weldSystem.IsWeldingIndexedMock.Value1, 2);
            _weldSystem.GetNextEnabledPowerSourceMock.Value2 := -1;

            THIS.Execute(); // _startTorch.OnExecute

            _weldSystem.IsWeldingIndexedMock.Value2 := TRUE;

            THIS.Execute(); // _startTorch.OnExecute
            THIS.Execute(); // _startTorch.OnExit

            // Welding
            THIS.Execute(); // _welding.OnEntry
            THIS.Execute(); // _welding.OnExecute

            Assert.Equal(_fsm.GetCurrentState(), AdaptioWeldSequenceState#Welding);

            THIS.Execute(); // _welding.OnExecute

            _weldAxisObservable.LinearPosition := 100.0;
            _fsm.Stop();

            THIS.Execute(); // _welding.OnExecute
            THIS.Execute(); // _welding.OnExit

            // Stop torch
            THIS.Execute(); // _stopTorch.OnEntry
            THIS.Execute(); // _stopTorch.OnExecute

            Assert.Equal(_fsm.GetCurrentState(), AdaptioWeldSequenceState#StopTorch);

            THIS.Execute(); // _stopTorch.OnExecute

            ASSERT.Equal(_weldSystem.StopWeldingMock.Value, 1);

            THIS.Execute(); // _stopTorch.OnExecute

            Assert.Equal(_weldSystem.IsWeldingIndexedMock.Value1, 1);
            _weldSystem.IsWeldingIndexedMock.Value2 := FALSE;
            _weldSystem.GetNextEnabledPowerSourceMock.Value2 := 2;

            THIS.Execute(); // _stopTorch.OnExecute
            THIS.Execute(); // _stopTorch.OnExit

            // Wait for next torch
            THIS.Execute(); // _waitForNextTorchStop.OnEntry
            _weldSystem.IsWeldingIndexedMock.Value2 := TRUE;

            Assert.Equal(_fsm.GetCurrentState(), AdaptioWeldSequenceState#WaitForNextTorchStop);
            Assert.GreaterOrEqual(_weldSystem.WireOffsetMock.GetCallCount(), UINT#1);
            Assert.Equal(_weldSystem.WireOffsetMock.Value1, 2);

            THIS.Execute(); // _waitForNextTorchStop.OnExecute
            THIS.Execute(); // _waitForNextTorchStop.OnExecute
            THIS.Execute(); // _waitForNextTorchStop.OnExecute

            _weldAxisObservable.LinearPosition := 111.0;

            THIS.Execute(); // _waitForNextTorchStop.OnExecute
            THIS.Execute(); // _waitForNextTorchStop.OnExit

            // Stop (second) torch
            THIS.Execute(); // _stopTorch.OnEntry
            THIS.Execute(); // _stopTorch.OnExecute

            Assert.Equal(_fsm.GetCurrentState(), AdaptioWeldSequenceState#StopTorch);

            THIS.Execute(); // _stopTorch.OnExecute

            ASSERT.Equal(_weldSystem.StopWeldingMock.Value, 2);

            THIS.Execute(); // _stopTorch.OnExecute

            Assert.Equal(_weldSystem.IsWeldingIndexedMock.Value1, 2);
            _weldSystem.GetNextEnabledPowerSourceMock.Value2 := -1;

            THIS.Execute(); // _stopTorch.OnExecute

            _weldSystem.IsWeldingIndexedMock.Value2 := FALSE;

            THIS.Execute(); // _stopTorch.OnExecute
            THIS.Execute(); // _stopTorch.OnExit

            // Back to initial state
            THIS.Execute(); // _initialState.OnEnter
            THIS.Execute(); // _initialState.OnExecute

            Assert.Equal(_fsm.GetCurrentState(), AdaptioWeldSequenceState#InitialState);
        END_METHOD

        {Test}
        METHOD PUBLIC TestQuickstop
            // Set initial values
            _weldSystem.ReadyToWeldMock.Value := TRUE;
            _weldSystem.WireOffsetMock.Value2 := 10.0;

            // Initial state
            Assert.Equal(_fsm.GetCurrentState(), AdaptioWeldSequenceState#InitialState);
            _weldSystem.GetHeadTorchIndexMock.Value := 1;
            _weldAxisObservable.LinearPosition := 0.0;

            THIS.Execute(); // _initialState.OnExecute
            THIS.Execute(); // _initialState.OnExecute

            // Trigger state change
            _fsm.Start();

            THIS.Execute(); // _initialState.OnExecute
            THIS.Execute(); // _initialState.OnExit

            // Start head torch
            THIS.Execute(); // _startTorch.OnEntry

            Assert.Equal(_weldSystem.StartWeldingMock.Value, 1);

            THIS.Execute(); // _startTorch.OnExecute

            Assert.Equal(_fsm.GetCurrentState(), AdaptioWeldSequenceState#StartTorch);
            Assert.Equal(_weldSystem.IsWeldingIndexedMock.Value1, 1);

            THIS.Execute(); // _startTorch.OnExecute
            THIS.Execute(); // _startTorch.OnExecute
            THIS.Execute(); // _startTorch.OnExecute

            _fsm.QuickStop();

            THIS.Execute();
            THIS.Execute();

            Assert.Equal(_fsm.GetCurrentState(), AdaptioWeldSequenceState#QuickStop);
            THIS.Execute();
            Assert.Equal(_weldSystem.StopMock.Value, TRUE);
            _weldSystem.IsWeldingMock.Value := TRUE;
            THIS.Execute();
            THIS.Execute();
            THIS.Execute();
            Assert.Equal(_fsm.GetCurrentState(), AdaptioWeldSequenceState#QuickStop);
            _weldSystem.IsWeldingMock.Value := FALSE;
            THIS.Execute(); // _quickStopState.OnExit
            THIS.Execute();
            Assert.Equal(_fsm.GetCurrentState(), AdaptioWeldSequenceState#InitialState);
        END_METHOD
    END_CLASS

END_NAMESPACE