USING Esab.Api;
USING Esab.Utils.Assets;
USING Esab.Motion.Mock;
USING Esab.Motion;
USING AxUnit;

NAMESPACE Esab.Api.BlockTests

    {TestFixture}
    {Category(Blocks)}
    CLASS WebApiBlockTests
        VAR PRIVATE
            _api : WebApi;
            _image : WebApiData; // Simulated IO image with Inputs/Outputs
            _assets : AssetsManager;
            _hAxis : ToPosAxisMock;
            _hAxisObservable : REF_TO AxisObservable;
        END_VAR

        {TestSetup}
        METHOD PUBLIC Setup
            // Reset and bind API
            _hAxis.MockReset();
            _hAxisObservable ?= _hAxis.Observe();

            // Clear image values
            _image.Inputs.HorizontalSlide.Commands.Enable.Execute.Value := FALSE;
            _image.Inputs.HorizontalSlide.Commands.Disable.Execute.Value := FALSE;
            _image.Inputs.HorizontalSlide.Commands.Halt.Execute.Value := FALSE;
            _image.Inputs.HorizontalSlide.Commands.JogPositive.Execute.Value := FALSE;
            _image.Inputs.HorizontalSlide.Commands.JogNegative.Execute.Value := FALSE;
            _image.Inputs.HorizontalSlide.Commands.Positioning.Execute.Value := FALSE;
            _image.Inputs.HorizontalSlide.Commands.Positioning.CommandType.Value := UINT#0;
            _image.Inputs.HorizontalSlide.Commands.Positioning.Position.Value := REAL#0.0;
            _image.Inputs.HorizontalSlide.Commands.Positioning.Velocity.Value := REAL#0.0;
            _image.Inputs.HorizontalSlide.Commands.Positioning.Acceleration.Value := REAL#0.0;
            _image.Inputs.HorizontalSlide.Commands.Positioning.Deceleration.Value := REAL#0.0;
            _image.Inputs.HorizontalSlide.Commands.Positioning.Jerk.Value := REAL#0.0;
            _image.Inputs.HorizontalSlide.Commands.Homing.Execute.Value := FALSE;
            _image.Inputs.HorizontalSlide.Commands.Homing.HomingType.Value := UINT#0;
            _image.Inputs.HorizontalSlide.Commands.Homing.Position.Value := REAL#0.0;

            // Bind API to image and asset manager
            _api.Setup(_assets, REF(_image));

            // Register axis mocks as managed assets (block-level intent)
            // Assign identifiers so the real AssetsManager can index them
            _hAxis.SetIdentifier(AssetIdentifier#HorizontalSlideAxis);
            _assets.RegisterAsset(REF(_hAxis));
        END_METHOD

        // Helper: propagate input image values into IO classes (produce edges when toggled)
        METHOD PRIVATE PropagateInputsHorizontal
            _image.Inputs.HorizontalSlide.Commands.Enable.Execute.Read();
            _image.Inputs.HorizontalSlide.Commands.Disable.Execute.Read();
            _image.Inputs.HorizontalSlide.Commands.Halt.Execute.Read();
            _image.Inputs.HorizontalSlide.Commands.JogPositive.Execute.Read();
            _image.Inputs.HorizontalSlide.Commands.JogNegative.Execute.Read();

            _image.Inputs.HorizontalSlide.Commands.Positioning.CommandType.Read();
            _image.Inputs.HorizontalSlide.Commands.Positioning.Position.Read();
            _image.Inputs.HorizontalSlide.Commands.Positioning.Velocity.Read();
            _image.Inputs.HorizontalSlide.Commands.Positioning.Acceleration.Read();
            _image.Inputs.HorizontalSlide.Commands.Positioning.Deceleration.Read();
            _image.Inputs.HorizontalSlide.Commands.Positioning.Jerk.Read();
            _image.Inputs.HorizontalSlide.Commands.Positioning.Execute.Read();

            _image.Inputs.HorizontalSlide.Commands.Homing.HomingType.Read();
            _image.Inputs.HorizontalSlide.Commands.Homing.Position.Read();
            _image.Inputs.HorizontalSlide.Commands.Homing.Execute.Read();
        END_METHOD

        METHOD PRIVATE Execute
            THIS.PropagateInputsHorizontal();
            _api.Execute();
            THIS.PropagateOutputsHorizontal();
        END_METHOD

        METHOD PRIVATE PropagateOutputsHorizontal
            _image.Outputs.HorizontalSlide.Valid.Write();
            _image.Outputs.HorizontalSlide.Status.Enabled.Write();
            _image.Outputs.HorizontalSlide.Status.Homed.Write();
            _image.Outputs.HorizontalSlide.Status.Error.Write();
            _image.Outputs.HorizontalSlide.Status.Busy.Write();
            _image.Outputs.HorizontalSlide.Status.Position.Write();
            _image.Outputs.HorizontalSlide.Status.Velocity.Write();
        END_METHOD

        // Test: Positioning command absolute on horizontal axis via IO image and observable mapping
        {Test}
        METHOD PUBLIC Horizontal_PositionAbsolute_UpdatesAxisAndOutputs
            // 1) Prime edges low
            _image.Inputs.HorizontalSlide.Commands.Positioning.Execute.Value := FALSE;
            THIS.Execute();

            // 2) Set up parameters and rising edge for execute
            _image.Inputs.HorizontalSlide.Commands.Positioning.CommandType.Value := PositioningCommandType#Absolute;
            _image.Inputs.HorizontalSlide.Commands.Positioning.Position.Value := REAL#12.5;
            _image.Inputs.HorizontalSlide.Commands.Positioning.Velocity.Value := REAL#2.5;
            _image.Inputs.HorizontalSlide.Commands.Positioning.Acceleration.Value := REAL#3.5;
            _image.Inputs.HorizontalSlide.Commands.Positioning.Deceleration.Value := REAL#4.5;
            _image.Inputs.HorizontalSlide.Commands.Positioning.Jerk.Value := REAL#5.5;
            _image.Inputs.HorizontalSlide.Commands.Positioning.Execute.Value := TRUE; // Rising

            // Drive to test outputs mapping
            _hAxis.IsEnabledMock.Value := TRUE;
            _hAxis.IsHomedMock.Value := TRUE;
            _hAxis.HasErrorMock.Value := FALSE;
            _hAxis.IsBusyMock.Value := TRUE;
            _hAxis.ActualLinearPositionMock.Value := LREAL#12.5;
            _hAxis.ActualLinearVelocityMock.Value := LREAL#2.5;

            THIS.Execute();

            // Verify command reached axis (through observable mock’s recorded command)
            Assert.Equal(_hAxis.ExecutePositioningCommandMock.GetCallCount(), UINT#1);

            Assert.Equal(_hAxis.ExecutePositioningCommandMock.Command.CommandType, Esab.Motion.AxisCommandType#Absolute);
            Assert.Equal(_hAxis.ExecutePositioningCommandMock.Command.Position, 12.5);
            Assert.Equal(_hAxis.ExecutePositioningCommandMock.Command.Velocity, 2.5);
        END_METHOD

        // Test: Homing command on Horizontal axis
        {Test}
        METHOD PUBLIC Horizontal_HomingDirectAbsolute_UpdatesAxis
            // AssetsManager is real; horizontal axis is already registered with correct ID.

            // Prime low then rise
            _image.Inputs.HorizontalSlide.Commands.Homing.Execute.Value := FALSE;
            THIS.Execute();

            _image.Inputs.HorizontalSlide.Commands.Homing.HomingType.Value := HomingCommandType#DirectAbsolute;
            _image.Inputs.HorizontalSlide.Commands.Homing.Position.Value := REAL#10.0;
            _image.Inputs.HorizontalSlide.Commands.Homing.Execute.Value := TRUE;

            THIS.Execute();

            Assert.Equal(_hAxis.ExecuteHomingCommandMock.GetCallCount(), UINT#1);
            Assert.Equal(_hAxis.ExecuteHomingCommandMock.Command.HomingType, Esab.Motion.AxisHomingType#DirectAbsolute);
            Assert.Equal(_hAxis.ExecuteHomingCommandMock.Command.Position, 10.0);
        END_METHOD

        // Test: Enable command on horizontal axis using Value+Read propagation toggling
        {Test}
        METHOD PUBLIC Horizontal_Enable_TogglesOnce
            // Use horizontal axis (mock with PowerOnMock) to verify enable edge behavior
            // Prime low
            _image.Inputs.HorizontalSlide.Commands.Enable.Execute.Value := FALSE;
            THIS.Execute();
            Assert.Equal(_hAxis.PowerOnMock.GetCallCount(), UINT#0);

            // Set high and propagate
            _image.Inputs.HorizontalSlide.Commands.Enable.Execute.Value := TRUE;
            THIS.Execute();
            Assert.Equal(_image.Inputs.HorizontalSlide.Commands.Enable.Execute.Value, FALSE);

            Assert.Equal(_hAxis.PowerOnMock.GetCallCount(), UINT#1);
        END_METHOD

        // Test: Axis remains locked while Busy across cycles
        {Test}
        METHOD PUBLIC Horizontal_PositionCommand_KeepsLockWhileBusy
            VAR_TEMP
                handleAttempt : REF_TO Asset;
                cycles : UINT;
            END_VAR

            // Prime low, execute once
            _image.Inputs.HorizontalSlide.Commands.Positioning.Execute.Value := FALSE;
            THIS.Execute();

            // Issue absolute move on rising edge
            _image.Inputs.HorizontalSlide.Commands.Positioning.CommandType.Value := PositioningCommandType#Absolute;
            _image.Inputs.HorizontalSlide.Commands.Positioning.Position.Value := REAL#5.0;
            _image.Inputs.HorizontalSlide.Commands.Positioning.Velocity.Value := REAL#1.0;
            _image.Inputs.HorizontalSlide.Commands.Positioning.Acceleration.Value := REAL#2.0;
            _image.Inputs.HorizontalSlide.Commands.Positioning.Deceleration.Value := REAL#3.0;
            _image.Inputs.HorizontalSlide.Commands.Positioning.Jerk.Value := REAL#4.0;
            _image.Inputs.HorizontalSlide.Commands.Positioning.Execute.Value := TRUE;

            // Simulate multi-cycle busy
            _hAxis.IsBusyMock.Value := TRUE;

            THIS.Execute();

            // For several cycles, the asset should remain locked so that RequestAssetHandle returns NULL
            FOR cycles := UINT#0 TO UINT#2 DO
                THIS.Execute();
                handleAttempt := _assets.RequestAssetHandle(_api, AssetIdentifier#HorizontalSlideAxis);
                Assert.Equal(handleAttempt = NULL, TRUE);
            END_FOR;

            // Now mark command done/busy false and execute once to allow unlock
            _hAxis.IsBusyMock.Value := FALSE;
            THIS.Execute();

            // After Busy clears, asset should be unlocked and available
            handleAttempt := _assets.RequestAssetHandle(_api, AssetIdentifier#HorizontalSlideAxis);
            Assert.Equal(handleAttempt <> NULL, TRUE);
        END_METHOD
    END_CLASS
END_NAMESPACE
