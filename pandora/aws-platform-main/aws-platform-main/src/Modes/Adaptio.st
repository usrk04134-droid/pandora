USING Esab.Api;
USING Esab.Io;
USING Esab.WeldSystem.PowerSources;
USING Esab.WeldSystem;
USING Esab.Hmi.Modules;
USING Esab.Motion;
USING Esab;
USING Esab.Utils.Alarming;
USING Esab.Utils.Assets;
USING Esab.Utils.Heartbeat;
USING Esab.Utils.Timer;
USING Esab.Utils.Fsm;

NAMESPACE Esab.Modes

    INTERFACE IAdaptio
    END_INTERFACE

    CLASS PUBLIC Adaptio EXTENDS Object IMPLEMENTS IAdaptio, IAssetRequester, IPushButtonListener
        VAR PRIVATE
            _io : REF_TO AdaptioIo;
            _runtimeParameters : REF_TO AdaptioRuntimeParameters := NULL;
            _assetsManager : IAssetsManager := NULL;
            _weldSequence : IWeldSequence := NULL;
            _heartbeat : Esab.Utils.Heartbeat.IHeartbeat := NULL;
            _requestTimer : ITimer := NULL;
            _joystickClickTimer : ITimer := NULL;
            _heartbeatAlarm : IAlarm := NULL;

            _weldHeadManipulator : IWeldHeadManipulator := NULL;
            _rollerBed : IAxis := NULL;
            _weldSystem : IWeldSystemOrchestrator := NULL;
            _p_joystick : IJoystick := NULL;
            _c_joystick : IJoystick := NULL;
            _startButton : IPushButton := NULL;
            _stopButton : IPushButton := NULL;

            _globalStateObservable : REF_TO GlobalStateObservable := NULL;
            _rollerBedObservable : REF_TO AxisObservable := NULL;
            _internalState : AdaptioInternalState := AdaptioInternalState#Inactive;

            _currentRequest : AdaptioRequest;
        END_VAR

        METHOD PUBLIC Setup
            VAR_INPUT
                io : REF_TO AdaptioIo;
                runtimeParameters : REF_TO AdaptioRuntimeParameters;
                assetsManager : IAssetsManager;
                weldSequence : IWeldSequence;
                heartbeat : Esab.Utils.Heartbeat.IHeartbeat;
                requestTimer : ITimer;
                joystickClickTimer : ITimer;
                setupAlarm : IAlarm;
            END_VAR

            VAR_EXTERNAL CONSTANT
                PlatformVersionMajor : UINT;
                PlatformVersionMinor : UINT;
                PlatformVersionPatch : UINT;
            END_VAR

            _io := io;
            _runtimeParameters := runtimeParameters;
            _assetsManager := assetsManager;
            _weldSequence := weldSequence;
            _heartbeat := heartbeat;
            _requestTimer := requestTimer;
            _joystickClickTimer := joystickClickTimer;
            _setupAlarm := setupAlarm;

            _isSetup := _io <> NULL AND
                        _runtimeParameters <> NULL AND
                        _assetsManager <> NULL AND
                        _heartbeat <> NULL AND
                        _requestTimer <> NULL AND
                        _joystickClickTimer <> NULL;

            IF _isSetup THEN
                _io^.ToAdaptio.SystemVersions.Major.SetValue(PlatformVersionMajor);
                _io^.ToAdaptio.SystemVersions.Minor.SetValue(PlatformVersionMinor);
                _io^.ToAdaptio.SystemVersions.Patch.SetValue(PlatformVersionPatch);
            END_IF;
        END_METHOD

        METHOD PUBLIC OVERRIDE Execute
            VAR_TEMP
                asset : REF_TO Asset;
            END_VAR

            SUPER.Execute();

            IF _setupAlarm.IsActive() THEN
                RETURN;
            END_IF;

            _heartbeat.Execute();

            IF _globalStateObservable = NULL THEN
                _globalStateObservable ?= _assetsManager.ObserveAsset(Esab.AssetIdentifier#GlobalState);
            END_IF;

            IF _rollerBedObservable = NULL THEN
                _rollerBedObservable ?= _assetsManager.ObserveAsset(Esab.AssetIdentifier#RollerBed);
            END_IF;

            THIS.UpdateRequest();
            THIS.UpdateInternalState();
            THIS.UpdateObservable();
            THIS.UpdatePowerSourceSetPoints();
            THIS.HandleWeldHeadManipulator();
            THIS.HandleWeldControl();
            THIS.HandleWeldAxis();
        END_METHOD

        METHOD PRIVATE HandleWeldAxis
            VAR_TEMP
                command : AxisPositioningCommand;
            END_VAR

            IF _rollerBedObservable <> NULL THEN
                ;
            END_IF;

            IF _rollerBed = NULL THEN
                RETURN;
            END_IF;

            IF _io^.FromAdaptio.WeldAxis.EnableMotion.RisingEdge() THEN
                _rollerBed.PowerOn();
            END_IF;

            IF _io^.FromAdaptio.WeldAxis.EnableMotion.FallingEdge() THEN
                _rollerBed.PowerOff();
            END_IF;

            IF _rollerBed.IsEnabled() THEN
                IF _io^.FromAdaptio.WeldAxis.InvalidateReference.RisingEdge() THEN
                    _rollerBed.Halt();
                    _rollerBed.InvalidateHoming();
                ELSIF _io^.FromAdaptio.WeldAxis.Radius.HasChanged() THEN
                    _rollerBed.SetObjectRadius(_io^.FromAdaptio.WeldAxis.Radius.GetValue());
                ELSIF _io^.FromAdaptio.WeldAxis.ResetLinearObjectDistance.RisingEdge() THEN
                    ; // TODO
                ELSIF THIS.WeldAxisInputHasChanged() THEN
                    command.Acceleration := -1;
                    command.Deceleration := -1;
                    command.Jerk := -1;
                    command.Position := _io^.FromAdaptio.WeldAxis.Position.GetValue();
                    command.Velocity := _io^.FromAdaptio.WeldAxis.Velocity.GetValue();
                    _rollerBed.ExecutePositioningCommand(command);
                END_IF;
            END_IF;
        END_METHOD

        METHOD PRIVATE WeldAxisInputHasChanged : BOOL
            WeldAxisInputHasChanged :=
                _io^.FromAdaptio.WeldAxis.MovementMode.HasChanged() OR
                _io^.FromAdaptio.WeldAxis.MovementType.HasChanged() OR
                _io^.FromAdaptio.WeldAxis.Position.HasChanged() OR
                _io^.FromAdaptio.WeldAxis.Velocity.HasChanged();
        END_METHOD

        METHOD PRIVATE HandleWeldControl
            IF _internalState <> AdaptioInternalState#ActiveAndLocked THEN
                RETURN;
            END_IF;

            IF _io^.FromAdaptio.WeldControl.Start.RisingEdge() THEN
                _weldSequence.Start();
            END_IF;

            IF _io^.FromAdaptio.WeldControl.Stop.RisingEdge() THEN
                _weldSequence.Stop();
            END_IF;

            IF _io^.FromAdaptio.WeldControl.QuickStop.RisingEdge() THEN
                _weldSequence.QuickStop();
            END_IF;
        END_METHOD

        METHOD PRIVATE HandleWeldHeadManipulator
            VAR_TEMP
                interpolatedSpeed : LREAL;
                speed : ARRAY [0..1] OF LREAL;
                position : ARRAY [0..1] OF LREAL;
                actualPosition : Array[0..1] OF LREAL;
                actualVelocity : Array[0..1] OF LREAL;
            END_VAR

            IF _weldHeadManipulator = NULL THEN
                RETURN;
            END_IF;

            IF _internalState <> AdaptioInternalState#ActiveAndLocked THEN
                IF _weldHeadManipulator.IsEnabled() THEN
                    _weldHeadManipulator.Disable();
                END_IF;
                RETURN;
            END_IF;

            IF _io^.FromAdaptio.WeldHeadManipulator.EnableMotion.GetValue() AND NOT _weldHeadManipulator.IsEnabled() THEN
                _weldHeadManipulator.Enable();
            ELSIF NOT _io^.FromAdaptio.WeldHeadManipulator.EnableMotion.GetValue() AND _weldHeadManipulator.IsEnabled() THEN
                _weldHeadManipulator.Disable();
            END_IF;

            IF _weldHeadManipulator.IsEnabled() AND
               (_io^.FromAdaptio.WeldHeadManipulator.Interpolate.HasChanged() OR
                _io^.FromAdaptio.WeldHeadManipulator.InterpolatedSpeed.HasChanged() OR
                _io^.FromAdaptio.WeldHeadManipulator.XPosition.HasChanged() OR
                _io^.FromAdaptio.WeldHeadManipulator.YPosition.HasChanged()) THEN

                IF _io^.FromAdaptio.WeldHeadManipulator.Interpolate.GetValue() THEN
                    interpolatedSpeed := _io^.FromAdaptio.WeldHeadManipulator.InterpolatedSpeed.GetValue();
                    position[0] := _io^.FromAdaptio.WeldHeadManipulator.XPosition.GetValue();
                    position[1] := _io^.FromAdaptio.WeldHeadManipulator.YPosition.GetValue();

                    _weldHeadManipulator.Move(position, interpolatedSpeed);
                ELSE
                    speed[0] := _io^.FromAdaptio.WeldHeadManipulator.XSpeed.GetValue();
                    speed[1] := _io^.FromAdaptio.WeldHeadManipulator.YSpeed.GetValue();
                    position[0] := _io^.FromAdaptio.WeldHeadManipulator.XPosition.GetValue();
                    position[1] := _io^.FromAdaptio.WeldHeadManipulator.YPosition.GetValue();

                    _weldHeadManipulator.Move(position, speed);
                END_IF;
            END_IF;

            _io^.ToAdaptio.WeldHeadManipulator.InterpolatedSpeed.SetValue(TO_REAL(_weldHeadManipulator.GetSpeed()));
            actualVelocity := _weldHeadManipulator.GetVelocity();
            _io^.ToAdaptio.WeldHeadManipulator.XVelocity.SetValue(TO_REAL(actualVelocity[0]));
            _io^.ToAdaptio.WeldHeadManipulator.YVelocity.SetValue(TO_REAL(actualVelocity[1]));
            actualPosition := _weldHeadManipulator.GetPosition();
            _io^.ToAdaptio.WeldHeadManipulator.XPosition.SetValue(TO_REAL(actualPosition[0]));
            _io^.ToAdaptio.WeldHeadManipulator.YPosition.SetValue(TO_REAL(actualPosition[1]));
        END_METHOD


        METHOD PRIVATE UpdateRequest
            IF _currentState <> AdaptioRequest#None THEN
                _requestTimer.Execute(TRUE, _runtimeParameters^.RequestTimeout);

                IF _requestTimer.Expired() THEN
                    _currentRequest := AdaptioRequest#None;
                END_IF;
            END_IF;

            _io^.ToAdaptio.SystemControl.StartRequest.Reset();
            _io^.ToAdaptio.SystemControl.StopRequest.Reset();
            _io^.ToAdaptio.SystemControl.QuickStopRequest.Reset();
            _io^.ToAdaptio.SystemControl.ShutdownRequest.Reset();

            CASE _currentRequest OF
                AdaptioRequest#Start:
                    _io^.ToAdaptio.SystemControl.StartRequest.Set();
                AdaptioRequest#Stop:
                    _io^.ToAdaptio.SystemControl.StopRequest.Set();
                AdaptioRequest#QuickStop:
                    _io^.ToAdaptio.SystemControl.QuickStopRequest.Set();
                AdaptioRequest#Shutdown:
                    _io^.ToAdaptio.SystemControl.ShutdownRequest.Set();
            ELSE
                _requestTimer.Execute(FALSE);
            END_CASE;
        END_METHOD

        METHOD PRIVATE UpdateInternalState
            IF _globalStateObservable <> NULL THEN
                IF _globalStateObservable^.Mode <> AwsPlatformMode#Adaptio THEN
                    _internalState := AdaptioInternalState#Inactive;
                END_IF;
            END_IF;

            CASE _internalState OF
                AdaptioInternalState#Error:
                    ;
                AdaptioInternalState#Inactive:
                    IF _globalStateObservable <> NULL THEN
                        IF _globalStateObservable^.Mode = AwsPlatformMode#Adaptio THEN
                            _internalState := AdaptioInternalState#Setup;
                        END_IF;
                    END_IF;

                    THIS.UnlockAssets();
                    THIS.UnlockStartStopButtons();
                AdaptioInternalState#Setup:
                    IF _startButton = NULL OR _stopButton = NULL THEN
                        IF THIS.RequestAndLockStartStopButtons() THEN
                            _internalState := AdaptioInternalState#Active;
                        END_IF;
                    END_IF;
                AdaptioInternalState#Active:
                    IF THIS.RequestAndLockAssets() THEN
                        IF _weldSequence.Setup(_rollerBedObservable,
                                                  _weldSystem) = StateMachineErrorCode#NoError THEN
                            _weldSequence.Reset();
                            _internalState := AdaptioInternalState#ActiveAndLocked;
                        END_IF;
                    END_IF;
                AdaptioInternalState#ActiveAndLocked:
                    ; // Do nothing
            END_CASE;
        END_METHOD

        METHOD PRIVATE UpdateObservable
            ;
        END_METHOD

        METHOD PRIVATE UpdatePowerSourceSetPoints
            VAR_TEMP
                ps1 : REF_TO SetPoints;
                ps2 : REF_TO SetPoints;
            END_VAR

            IF _internalState = AdaptioInternalState#ActiveAndLocked THEN

                ps1 := _weldSystem.GetPowerSourceSetPoints(1, _io^.FromAdaptio.PowerSource1.ActiveAreaSelect.GetValue());
                ps2 := _weldSystem.GetPowerSourceSetPoints(2, _io^.FromAdaptio.PowerSource2.ActiveAreaSelect.GetValue());

                IF ps1 <> NULL THEN
                    ps1^.Voltage := _io^.FromAdaptio.PowerSource1.Voltage.GetValue();
                    ps1^.Current := TO_UINT(_io^.FromAdaptio.PowerSource1.Current.GetValue());
                    ps1^.WireSpeed := TO_UINT(_io^.FromAdaptio.PowerSource1.WireSpeed.GetValue());
                 // ps1^.TravelSpeed := _io^.FromAdaptio.PowerSource1.TravelSpeed.GetValue(); // NOT USED
                    ps1^.AcFrequency := TO_UINT(_io^.FromAdaptio.PowerSource1.AcFrequency.GetValue());
                    ps1^.AcBalance := TO_UINT(_io^.FromAdaptio.PowerSource1.AcBalance.GetValue());
                    ps1^.AcOffset := _io^.FromAdaptio.PowerSource1.AcOffset.GetValue();
                    ps1^.AcPhaseShift := TO_UINT(_io^.FromAdaptio.PowerSource1.AcPhaseShift.GetValue());
                    ps1^.WeldMethod := TO_BYTE(_io^.FromAdaptio.PowerSource1.WeldMethod.GetValue());
                    ps1^.RegulationType := TO_BYTE(_io^.FromAdaptio.PowerSource1.RegulationType.GetValue());
                    ps1^.StartAdjust := TO_UINT(_io^.FromAdaptio.PowerSource1.StartAdjust.GetValue());
                    ps1^.RegulationDynamics := TO_UINT(_io^.FromAdaptio.PowerSource1.RegulationDynamics.GetValue());
                    ps1^.RegulationInductance := TO_UINT(_io^.FromAdaptio.PowerSource1.RegulationInductance.GetValue());
                    ps1^.IceWireSpeedPercentage := TO_UINT(_io^.FromAdaptio.PowerSource1.IceWireSpeed.GetValue());
                END_IF;

                IF ps2 <> NULL THEN
                    ps2^.Voltage := _io^.FromAdaptio.PowerSource2.Voltage.GetValue();
                    ps2^.Current := TO_UINT(_io^.FromAdaptio.PowerSource2.Current.GetValue());
                    ps2^.WireSpeed := TO_UINT(_io^.FromAdaptio.PowerSource2.WireSpeed.GetValue());
                 // ps2^.TravelSpeed := _io^.FromAdaptio.PowerSource2.TravelSpeed.GetValue(); // NOT USED
                    ps2^.AcFrequency := TO_UINT(_io^.FromAdaptio.PowerSource2.AcFrequency.GetValue());
                    ps2^.AcBalance := TO_UINT(_io^.FromAdaptio.PowerSource2.AcBalance.GetValue());
                    ps2^.AcOffset := _io^.FromAdaptio.PowerSource2.AcOffset.GetValue();
                    ps2^.AcPhaseShift := TO_UINT(_io^.FromAdaptio.PowerSource2.AcPhaseShift.GetValue());
                    ps2^.WeldMethod := TO_BYTE(_io^.FromAdaptio.PowerSource2.WeldMethod.GetValue());
                    ps2^.RegulationType := TO_BYTE(_io^.FromAdaptio.PowerSource2.RegulationType.GetValue());
                    ps2^.StartAdjust := TO_UINT(_io^.FromAdaptio.PowerSource2.StartAdjust.GetValue());
                    ps2^.RegulationDynamics := TO_UINT(_io^.FromAdaptio.PowerSource2.RegulationDynamics.GetValue());
                    ps2^.RegulationInductance := TO_UINT(_io^.FromAdaptio.PowerSource2.RegulationInductance.GetValue());
                    ps2^.IceWireSpeedPercentage := TO_UINT(_io^.FromAdaptio.PowerSource2.IceWireSpeed.GetValue());
                END_IF;
            END_IF;
        END_METHOD

        METHOD PRIVATE RequestAndLockAssets : BOOL
            VAR_TEMP
                asset : REF_TO Asset;
                requestSuccess : BOOL := TRUE;
            END_VAR

            IF _weldHeadManipulator = NULL THEN
                asset := _assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#WeldHeadManipulator);
                IF asset <> NULL THEN
                    _weldHeadManipulator ?= asset^;
                ELSE
                    requestSuccess := FALSE;
                END_IF;
            END_IF;

            IF _rollerBed = NULL THEN
                asset := _assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#RollerBed);
                IF asset <> NULL THEN
                    _rollerBed ?= asset^;
                ELSE
                    requestSuccess := FALSE;
                END_IF;
            END_IF;

            IF _weldSystem = NULL THEN
                asset := _assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#WeldSystemOrchestrator);
                IF asset <> NULL THEN
                    _weldSystem ?= asset^;
                ELSE
                    requestSuccess := FALSE;
                END_IF;
            END_IF;

            IF _p_joystick = NULL THEN
                asset := _assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#P_Joystick_MotionJoystick);
                IF asset <> NULL THEN
                    _p_joystick ?= asset^;
                ELSE
                    requestSuccess := FALSE;
                END_IF;
            END_IF;

            IF _c_joystick = NULL THEN
                asset := _assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#C_Joystick_MotionJoystick);
                IF asset <> NULL THEN
                    _c_joystick ?= asset^;
                ELSE
                    requestSuccess := FALSE;
                END_IF;
            END_IF;

            IF requestSuccess THEN
                THIS.LockAssets();
            END_IF;

            RequestAndLockAssets := requestSuccess;
        END_METHOD

        METHOD PRIVATE RequestAndLockStartStopButtons : BOOL
            VAR_TEMP
                asset : REF_TO Asset;
                requestSuccess : BOOL := TRUE;
            END_VAR

            IF _startButton = NULL THEN
                asset := _assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#P_PushButton_Start);
                IF asset <> NULL THEN
                    _startButton ?= asset^;
                    _startButton.SetListener(THIS);
                ELSE
                    requestSuccess := FALSE;
                END_IF;
            END_IF;

            IF _stopButton = NULL THEN
                asset := _assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#P_PushButton_Stop);
                IF asset <> NULL THEN
                    _stopButton ?= asset^;
                    _stopButton.SetListener(THIS);
                ELSE
                    requestSuccess := FALSE;
                END_IF;
            END_IF;

            IF requestSuccess THEN
                THIS.LockStartStopButtons();
            END_IF;

            RequestAndLockStartStopButtons := requestSuccess;
        END_METHOD

        METHOD PRIVATE IsInControl : BOOL
            VAR_TEMP
                asset : IAsset;
                in_control : BOOL := TRUE;
            END_VAR;

            asset ?= _weldHeadManipulator;
            IF asset <> NULL THEN
                IF NOT asset.IsLocked() THEN
                    in_control := FALSE;
                END_IF;
            ELSE
                in_control := FALSE;
            END_IF;

            asset ?= _rollerBed;
            IF asset <> NULL THEN
                IF NOT asset.IsLocked() THEN
                    in_control := FALSE;
                END_IF;
            ELSE
                in_control := FALSE;
            END_IF;

            asset ?= _weldSystem;
            IF asset <> NULL THEN
                IF NOT asset.IsLocked() THEN
                    in_control := FALSE;
                END_IF;
            ELSE
                in_control := FALSE;
            END_IF;

            asset ?= _p_joystick;
            IF asset <> NULL THEN
                IF NOT asset.IsLocked() THEN
                    in_control := FALSE;
                END_IF;
            ELSE
                in_control := FALSE;
            END_IF;

            asset ?= _c_joystick;
            IF asset <> NULL THEN
                IF NOT asset.IsLocked() THEN
                    in_control := FALSE;
                END_IF;
            ELSE
                in_control := FALSE;
            END_IF;

            asset ?= _startButton;
            IF asset <> NULL THEN
                IF NOT asset.IsLocked() THEN
                    in_control := FALSE;
                END_IF;
            ELSE
                in_control := FALSE;
            END_IF;

            asset ?= _stopButton;
            IF asset <> NULL THEN
                IF NOT asset.IsLocked() THEN
                    in_control := FALSE;
                END_IF;
            ELSE
                in_control := FALSE;
            END_IF;

            IsInControl := in_control;
        END_METHOD

        METHOD PRIVATE LockAssets
            VAR_TEMP
                asset : IAsset;
            END_VAR

            IF _weldHeadManipulator <> NULL THEN
                asset ?= _weldHeadManipulator;
                asset.Lock();
            END_IF;

            IF _rollerBed <> NULL THEN
                asset ?= _rollerBed;
                asset.Lock();
            END_IF;

            IF _weldSystem <> NULL THEN
                asset ?= _weldSystem;
                asset.Lock();
            END_IF;

            IF _p_joystick <> NULL THEN
                asset ?= _p_joystick;
                asset.Lock();
            END_IF;

            IF _c_joystick <> NULL THEN
                asset ?= _c_joystick;
                asset.Lock();
            END_IF;
        END_METHOD

        METHOD PRIVATE UnlockAssets
            VAR_TEMP
                asset : IAsset;
            END_VAR

            IF _weldHeadManipulator <> NULL THEN
                asset ?= _weldHeadManipulator;
                asset.Unlock();
            END_IF;

            IF _rollerBed <> NULL THEN
                asset ?= _rollerBed;
                asset.Unlock();
            END_IF;

            IF _weldSystem <> NULL THEN
                asset ?= _weldSystem;
                asset.Unlock();
            END_IF;

            IF _p_joystick <> NULL THEN
                asset ?= _p_joystick;
                asset.Unlock();
            END_IF;

            IF _c_joystick <> NULL THEN
                asset ?= _c_joystick;
                asset.Unlock();
            END_IF;
        END_METHOD

        METHOD PRIVATE LockStartStopButtons
            VAR_TEMP
                asset : IAsset;
            END_VAR

            IF _startButton <> NULL THEN
                asset ?= _startButton;
                asset.Lock();
            END_IF;

            IF _stopButton <> NULL THEN
                asset ?= _stopButton;
                asset.Lock();
            END_IF;
        END_METHOD

        METHOD PRIVATE UnlockStartStopButtons
            VAR_TEMP
                asset : IAsset;
            END_VAR

            IF _startButton <> NULL THEN
                asset ?= _startButton;
                asset.Unlock();
            END_IF;

            IF _stopButton <> NULL THEN
                asset ?= _stopButton;
                asset.Unlock();
            END_IF;
        END_METHOD

        METHOD PUBLIC AssetAssigned
            VAR_INPUT
                asset : REF_TO Esab.Utils.Assets.Asset;
            END_VAR

            ;
        END_METHOD

        METHOD PUBLIC AssetRemoved
            VAR_INPUT
                identifier : INT;
            END_VAR

            CASE identifier OF
                Esab.AssetIdentifier#WeldHeadManipulator:
                    _weldHeadManipulator := NULL;
                Esab.AssetIdentifier#RollerBed:
                    _rollerBed := NULL;
                Esab.AssetIdentifier#WeldSystemOrchestrator:
                    _weldSystem := NULL;
                Esab.AssetIdentifier#P_Joystick_MotionJoystick:
                    _p_joystick := NULL;
                Esab.AssetIdentifier#C_Joystick_MotionJoystick:
                    _c_joystick := NULL;
                Esab.AssetIdentifier#P_PushButton_Start:
                    _startButton.SetListener(NULL);
                    _startButton := NULL;
                Esab.AssetIdentifier#P_PushButton_Stop:
                    _stopButton.SetListener(NULL);
                    _stopButton := NULL;
            END_CASE;
        END_METHOD

        METHOD PUBLIC OnPushButtonPressed
            VAR_INPUT
                id : AssetIdentifier;
            END_VAR

            CASE id OF
                Esab.AssetIdentifier#P_PushButton_Start:
                    ;
                Esab.AssetIdentifier#P_PushButton_Stop:
                    ;
            END_CASE;
        END_METHOD

        METHOD PUBLIC OnPushButton
            VAR_INPUT
                id : AssetIdentifier;
            END_VAR

            CASE id OF
                Esab.AssetIdentifier#P_PushButton_Start:
                    ;
                Esab.AssetIdentifier#P_PushButton_Stop:
                    ;
            END_CASE;
        END_METHOD

        METHOD PUBLIC OnPushButtonReleased
            VAR_INPUT
                id : AssetIdentifier;
            END_VAR

            CASE id OF
                Esab.AssetIdentifier#P_PushButton_Start:
                    _requestTimer.Execute(FALSE);
                    _currentRequest := AdaptioRequest#Start;
                Esab.AssetIdentifier#P_PushButton_Stop:
                    IF _currentRequest = AdaptioRequest#Stop THEN
                        _requestTimer.Execute(FALSE);
                        _currentRequest := AdaptioRequest#QuickStop;
                    ELSE
                        _requestTimer.Execute(FALSE);
                        _currentRequest := AdaptioRequest#Stop;
                    END_IF;
            END_CASE;
        END_METHOD
    END_CLASS

    TYPE
        AdaptioIo : STRUCT
            FromAdaptio : AdaptioInputs;
            ToAdaptio : AdaptioOutputs;
        END_STRUCT;

        AdaptioInputs : STRUCT
            SystemControl : AdaptioSystemControl_AdaptioToPlc;
            WeldControl : AdaptioWeldControl_AdaptioToPlc;
            PowerSource1 : AdaptioWeldSystem_AdaptioToPlc;
            PowerSource2 : AdaptioWeldSystem_AdaptioToPlc;
            WeldAxis : AdaptioWeldAxis_AdaptioToPlc;
            WeldHeadManipulator : AdaptioWeldHeadManipulator_AdaptioToPlc;
        END_STRUCT;

        AdaptioOutputs : STRUCT
            SystemVersions : AdaptioSystemVersions_PlcToAdaptio;
            SystemControl : AdaptioSystemControl_PlcToAdaptio;
            Joystick : AdaptioJoystick_PlcToAdaptio;
            FluxSystem : AdaptioFluxSystem_PlcToAdaptio;
            WeldControl : AdaptioWeldControl_PlcToAdaptio;
            PowerSource1 : AdaptioWeldSystem_PlcToAdaptio;
            PowerSource2 : AdaptioWeldSystem_PlcToAdaptio;
            WeldAxis : AdaptioWeldAxis_PlcToAdaptio;
            WeldHeadManipulator : AdaptioWeldHeadManipulator_PlcToAdaptio;
        END_STRUCT;

        AdaptioSystemVersions_PlcToAdaptio : STRUCT
            Major : DIntOutput;
            Minor : DIntOutput;
            Patch : DIntOutput;
        END_STRUCT;

        AdaptioSystemControl_AdaptioToPlc : STRUCT
            Heartbeat : DIntInput;
        END_STRUCT;

        AdaptioSystemControl_PlcToAdaptio : STRUCT
            StartRequest : DigitalOutput;
            StopRequest : DigitalOutput;
            QuickStopRequest : DigitalOutput;
            ShutdownRequest : DigitalOutput;
            Heartbeat : DIntOutput;
        END_STRUCT;

        AdaptioJoystick_PlcToAdaptio : STRUCT
            State : DIntOutput;
        END_STRUCT;

        AdaptioWeldControl_AdaptioToPlc : STRUCT
            Start : DigitalInput;
            Stop : DigitalInput;
            QuickStop : DigitalInput;
        END_STRUCT;

        AdaptioWeldControl_PlcToAdaptio : STRUCT
            State : DIntOutput;
        END_STRUCT;

        AdaptioFluxSystem_PlcToAdaptio : STRUCT
            State : DIntOutput;
        END_STRUCT;

        AdaptioWeldSystem_AdaptioToPlc : STRUCT
            Enable : DigitalInput;
            ActiveAreaSelect : DigitalInput;
            SwitchAreas : DigitalInput;
            Voltage : RealInput;
            Current : DIntInput;
            WireSpeed : DIntInput;
            RegulationType : DIntInput;
            WeldMethod : DIntInput;
            AcFrequency : DIntInput;
            AcBalance : DIntInput;
            AcOffset : RealInput;
            AcPhaseShift : DIntInput;
            StartAdjust : DIntInput;
            RegulationDynamics : DIntInput;
            RegulationInductance : DIntInput;
            IceWireSpeed : DIntInput;
        END_STRUCT;

        AdaptioWeldSystem_PlcToAdaptio : STRUCT
            Enabled : DigitalOutput;
            State : DIntOutput;
            ActiveVoltage : RealOutput;
            ActiveCurrent : DIntOutput;
            ActiveWireSpeed : DIntOutput;
            ActiveRegulationType : DIntOutput;
            ActiveWeldMethod : DIntOutput;
            ActiveAcFrequency : DIntOutput;
            ActiveAcBalance : DIntOutput;
            ActiveAcOffset : RealOutput;
            ActiveAcPhaseShift : DIntOutput;
            ActiveStartAdjust : DIntOutput;
            ActiveRegulationDynamics : DIntOutput;
            ActiveRegulationInductance : DIntOutput;
            ActiveIceWireSpeed : DIntOutput;
            MeasuredVoltage : RealOutput;
            MeasuredCurrent : DIntOutput;
            MeasuredWireSpeed : DIntOutput;
            MeasuredIceWireSpeed : DIntOutput;
            CalculatedHeatInput : RealOutput;
            CalculatedDepositionRate : RealOutput;
        END_STRUCT;

        AdaptioWeldAxis_AdaptioToPlc : STRUCT
            EnableMotion : DigitalInput;
            Reset : DigitalInput;
            InvalidateReference : DigitalInput;
            ResetLinearObjectDistance : DigitalInput;
            MovementType : DIntInput;
            MovementMode : DIntInput;
            Radius : RealInput;
            Position : RealInput;
            Velocity : RealInput;
        END_STRUCT;

        AdaptioWeldAxis_PlcToAdaptio : STRUCT
            InPosition : DigitalOutput;
            ReferenceValid : DigitalOutput;
            State : DIntOutput;
            ErrorCode : DIntOutput;
            AxisType : DIntOutput;
            Radius : RealOutput;
            Position : RealOutput;
            LinearObjectDistance : RealOutput;
            Velocity : RealOutput;
        END_STRUCT;

        AdaptioWeldHeadManipulator_AdaptioToPlc : STRUCT
            EnableMotion : DigitalInput;
            Interpolate : DigitalInput;
            XPosition : RealInput;
            YPosition : RealInput;
            InterpolatedSpeed : RealInput;
            XSpeed : RealInput;
            YSpeed : RealInput;
        END_STRUCT;

        AdaptioWeldHeadManipulator_PlcToAdaptio : STRUCT
            InPosition : DigitalOutput;
            State : DIntOutput;
            XPosition : RealOutput;
            YPosition : RealOutput;
            InterpolatedSpeed : RealOutput;
            XVelocity : RealOutput;
            YVelocity : RealOutput;
        END_STRUCT;

        AdaptioRuntimeParameters : STRUCT
            JoystickLongHoldTime : LTIME := LT#1s;
            JoystickClickTimeout : LTIME := LT#500ms;
            RequestTimeout : LTIME := LT#500ms;
        END_STRUCT;

        /// Represents the internal state of the Adaptio implementation in the PLC
        AdaptioInternalState : INT(
            Error := -1,
            Inactive := 0,
            Setup := 1,
            Active := 2,
            ActiveAndLocked := 3
        );

        AdaptioRequest : INT(
            None := -1,
            Start := 1,
            Stop := 2,
            QuickStop := 3,
            Shutdown := 4
        ) := AdaptioRequest#None;

        AdaptioJoystickState : INT(
            Idle            := 0,
            ClickedUp       := 1,
            ClickedDown     := 2,
            ClickedSquare   := 3,
            ClickedTriangle := 4,
            HeldUp          := 5,
            HeldDown        := 6,
            HeldSquare      := 7,
            HeldTriangle    := 8
        );
    END_TYPE

    {::ifndef UNLINK_ADAPTIO_IO}
    TYPE
        {S7.Extern=ReadOnly}
        RawFromAdaptio : STRUCT
            SystemControl       AT %B0 : RawAdaptioSystemControl_AdaptioToPlc;
            WeldControl         AT %B20 : RawAdaptioWeldControl_AdaptioToPlc;
            PowerSource1        AT %B36: RawAdaptioWeldSystem_AdaptioToPlc;
            PowerSource2        AT %B104: RawAdaptioWeldSystem_AdaptioToPlc;
            WeldAxis            AT %B172 : RawAdaptioWeldAxis_AdaptioToPlc;
            WeldHeadManipulator AT %B208 : RawAdaptioWeldHeadManipulator_AdaptioToPlc;
        END_STRUCT;

        {S7.Extern=ReadOnly}
        RawToAdaptio : STRUCT
            SystemVersions      AT %B0 : RawAdaptioSystemVersions_PlcToAdaptio;
            SystemControl       AT %B12 : RawAdaptioSystemControl_PlcToAdaptio;
            Joystick            AT %B36 : RawAdaptioJoystick_PlcToAdaptio;
            FluxSystem          AT %B52 : RawAdaptioFluxSystem_PlcToAdaptio;
            WeldControl         AT %B68 : RawAdaptioWeldControl_PlcToAdaptio;
            PowerSource1        AT %B84 : RawAdaptioWeldSystem_PlcToAdaptio;
            PowerSource2        AT %B180 : RawAdaptioWeldSystem_PlcToAdaptio;
            WeldAxis            AT %B276 : RawAdaptioWeldAxis_PlcToAdaptio;
            WeldHeadManipulator AT %B320 : RawAdaptioWeldHeadManipulator_PlcToAdaptio;
        END_STRUCT;

        {S7.Extern=ReadOnly}
        RawAdaptioSystemVersions_PlcToAdaptio : STRUCT
            Major AT %B0 : DINT;
            Minor AT %B4 : DINT;
            Patch AT %B8 : DINT;
        END_STRUCT;

        {S7.Extern=ReadOnly}
        RawAdaptioSystemControl_AdaptioToPlc : STRUCT
            Heartbeat      AT %B0 : DINT;
            Reserved1      AT %B4 : DINT;
            Reserved2      AT %B8 : DINT;
            Reserved3      AT %B12 : DINT;
        END_STRUCT;

        {S7.Extern=ReadOnly}
        RawAdaptioSystemControl_PlcToAdaptio : STRUCT
            StartRequest     AT %X3.0 : BOOL;
            StopRequest      AT %X3.1 : BOOL;
            QuickStopRequest AT %X3.2 : BOOL;
            ShutdownRequest  AT %X3.3 : BOOL;
            Heartbeat        AT %B4 : DINT;
            Reserved1        AT %B8 : DINT;
            Reserved2        AT %B12 : DINT;
            Reserved3        AT %B16 : DINT;
        END_STRUCT;

        {S7.Extern=ReadOnly}
        RawAdaptioJoystick_PlcToAdaptio : STRUCT
            State     AT %B0 : DINT;
            Reserved1 AT %B4 : DINT;
            Reserved2 AT %B8 : DINT;
            Reserved3 AT %B12 : DINT;
        END_STRUCT;

        {S7.Extern=ReadOnly}
        RawAdaptioWeldControl_AdaptioToPlc : STRUCT
            Start     AT %X3.0 : BOOL;
            Stop      AT %X3.1 : BOOL;
            QuickStop AT %X3.2 : BOOL;
            Reserved1 AT %B4 : DINT;
            Reserved2 AT %B8 : DINT;
            Reserved3 AT %B12 : DINT;
        END_STRUCT;

        {S7.Extern=ReadOnly}
        RawAdaptioWeldControl_PlcToAdaptio : STRUCT
            State     AT %B0 : DINT;
            Reserved1 AT %B4 : DINT;
            Reserved2 AT %B8 : DINT;
            Reserved3 AT %B12 : DINT;
        END_STRUCT;

        {S7.Extern=ReadOnly}
        RawAdaptioFluxSystem_PlcToAdaptio : STRUCT
            State     AT %B0 : DINT;
            Reserved1 AT %B4 : DINT;
            Reserved2 AT %B8 : DINT;
            Reserved3 AT %B12 : DINT;
        END_STRUCT;

        {S7.Extern=ReadOnly}
        RawAdaptioWeldSystem_AdaptioToPlc : STRUCT
            Enable               AT %X3.0 : BOOL;
            ActiveAreaSelect     AT %X3.1 : BOOL;
            SwitchAreas          AT %X3.2 : BOOL;
            Voltage              AT %B4 : REAL;
            Current              AT %B8 : DINT;
            WireSpeed            AT %B12 : DINT;
            RegulationType       AT %B16 : DINT;
            WeldMethod           AT %B20 : DINT;
            AcFrequency          AT %B24 : DINT;
            AcBalance            AT %B28 : DINT;
            AcOffset             AT %B32 : REAL;
            AcPhaseShift         AT %B36 : DINT;
            StartAdjust          AT %B40 : DINT;
            RegulationDynamics   AT %B44 : DINT;
            RegulationInductance AT %B48 : DINT;
            IceWireSpeed         AT %B52 : DINT;
            Reserved1            AT %B56 : DINT;
            Reserved2            AT %B60 : DINT;
            Reserved3            AT %B64 : DINT;
        END_STRUCT;

        {S7.Extern=ReadOnly}
        RawAdaptioWeldSystem_PlcToAdaptio : STRUCT
            Enabled                    AT %X3.0 : BOOL;
            State                      AT %B4 : DINT;
            ActiveVoltage              AT %B8 : REAL;
            ActiveCurrent              AT %B12 : DINT;
            ActiveWireSpeed            AT %B16 : DINT;
            ActiveRegulationType       AT %B20 : DINT;
            ActiveWeldMethod           AT %B24 : DINT;
            ActiveAcFrequency          AT %B28 : DINT;
            ActiveAcBalance            AT %B32 : DINT;
            ActiveAcOffset             AT %B36 : REAL;
            ActiveAcPhaseShift         AT %B40 : DINT;
            ActiveStartAdjust          AT %B44 : DINT;
            ActiveRegulationDynamics   AT %B48 : DINT;
            ActiveRegulationInductance AT %B52 : DINT;
            ActiveIceWireSpeed         AT %B56 : DINT;
            MeasuredVoltage            AT %B60 : REAL;
            MeasuredCurrent            AT %B64 : DINT;
            MeasuredWireSpeed          AT %B68 : DINT;
            MeasuredIceWireSpeed       AT %B72 : DINT;
            CalculatedHeatInput        AT %B76 : REAL;
            CalculatedDepositionRate   AT %B80 : REAL;
            Reserved1                  AT %B84 : DINT;
            Reserved2                  AT %B88 : DINT;
            Reserved3                  AT %B92 : DINT;
        END_STRUCT;

        {S7.Extern=ReadOnly}
        RawAdaptioWeldAxis_AdaptioToPlc : STRUCT
            EnableMotion              AT %X3.0 : BOOL;
            Reset                     AT %X3.1 : BOOL;
            InvalidateReference       AT %X3.2 : BOOL;
            ResetLinearObjectDistance AT %X3.3 : BOOL;
            MovementType              AT %B4 : DINT;
            MovementMode              AT %B8 : DINT;
            Radius                    AT %B12 : REAL;
            Position                  AT %B16 : REAL;
            Velocity                  AT %B20 : REAL;
            Reserved1                 AT %B24 : DINT;
            Reserved2                 AT %B28 : DINT;
            Reserved3                 AT %B32 : DINT;
        END_STRUCT;

        {S7.Extern=ReadOnly}
        RawAdaptioWeldAxis_PlcToAdaptio : STRUCT
            InPosition           AT %X3.0 : BOOL;
            ReferenceValid       AT %X3.1 : BOOL;
            State                AT %B4 : DINT;
            ErrorCode            AT %B8 : DINT;
            AxisType             AT %B12 : DINT;
            Radius               AT %B16 : REAL;
            Position             AT %B20 : REAL;
            LinearObjectDistance AT %B24 : REAL;
            Velocity             AT %B28 : REAL;
            Reserved1            AT %B32 : DINT;
            Reserved2            AT %B36 : DINT;
            Reserved3            AT %B40 : DINT;
        END_STRUCT;

        {S7.Extern=ReadOnly}
        RawAdaptioWeldHeadManipulator_AdaptioToPlc : STRUCT
            EnableMotion        AT %X3.0 : BOOL;
            Interpolate         AT %X3.1 : BOOL;
            XPosition           AT %B4 : REAL;
            YPosition           AT %B8 : REAL;
            Reserved1           AT %B12 : DINT;
            Reserved2           AT %B16 : DINT;
            Reserved3           AT %B20 : DINT;
            InterpolatedSpeed   AT %B24 : REAL;
            XSpeed              AT %B28 : REAL;
            YSpeed              AT %B32 : REAL;
            Reserved4           AT %B36 : DINT;
            Reserved5           AT %B40 : DINT;
            Reserved6           AT %B44 : DINT;
            Reserved7           AT %B48 : DINT;
            Reserved8           AT %B52 : DINT;
            Reserved9           AT %B56 : DINT;
        END_STRUCT;

        {S7.Extern=ReadOnly}
        RawAdaptioWeldHeadManipulator_PlcToAdaptio : STRUCT
            InPosition          AT %X3.0 : BOOL;
            State               AT %B4 : DINT;
            XPosition           AT %B8 : REAL;
            YPosition           AT %B12 : REAL;
            Reserved1           AT %B16 : DINT;
            Reserved2           AT %B20 : DINT;
            Reserved3           AT %B24 : DINT;
            InterpolatedSpeed   AT %B28 : REAL;
            XVelocity           AT %B32 : REAL;
            YVelocity           AT %B36 : REAL;
            Reserved4           AT %B40 : DINT;
            Reserved5           AT %B44 : DINT;
            Reserved6           AT %B48 : DINT;
            Reserved7           AT %B52 : DINT;
            Reserved8           AT %B56 : DINT;
            Reserved9           AT %B60 : DINT;
        END_STRUCT;
    END_TYPE
    {::else}
    TYPE
        {S7.Extern=ReadWrite}
        RawFromAdaptio : STRUCT
            SystemControl       : RawAdaptioSystemControl_AdaptioToPlc;
            WeldControl         : RawAdaptioWeldControl_AdaptioToPlc;
            PowerSource1        : RawAdaptioWeldSystem_AdaptioToPlc;
            PowerSource2        : RawAdaptioWeldSystem_AdaptioToPlc;
            WeldAxis            : RawAdaptioWeldAxis_AdaptioToPlc;
            WeldHeadManipulator : RawAdaptioWeldHeadManipulator_AdaptioToPlc;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        RawToAdaptio : STRUCT
            SystemVersions      : RawAdaptioSystemVersions_PlcToAdaptio;
            SystemControl       : RawAdaptioSystemControl_PlcToAdaptio;
            Joystick            : RawAdaptioJoystick_PlcToAdaptio;
            FluxSystem          : RawAdaptioFluxSystem_PlcToAdaptio;
            WeldControl         : RawAdaptioWeldControl_PlcToAdaptio;
            PowerSource1        : RawAdaptioWeldSystem_PlcToAdaptio;
            PowerSource2        : RawAdaptioWeldSystem_PlcToAdaptio;
            WeldAxis            : RawAdaptioWeldAxis_PlcToAdaptio;
            WeldHeadManipulator : RawAdaptioWeldHeadManipulator_PlcToAdaptio;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        RawAdaptioSystemVersions_PlcToAdaptio : STRUCT
            Major : DINT;
            Minor : DINT;
            Patch : DINT;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        RawAdaptioSystemControl_AdaptioToPlc : STRUCT
            Heartbeat      : DINT;
            Reserved1      : DINT;
            Reserved2      : DINT;
            Reserved3      : DINT;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        RawAdaptioSystemControl_PlcToAdaptio : STRUCT
            StartRequest     : BOOL;
            StopRequest      : BOOL;
            QuickStopRequest : BOOL;
            ShutdownRequest  : BOOL;
            Heartbeat        : DINT;
            Reserved1        : DINT;
            Reserved2        : DINT;
            Reserved3        : DINT;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        RawAdaptioJoystick_PlcToAdaptio : STRUCT
            State     : DINT;
            Reserved1 : DINT;
            Reserved2 : DINT;
            Reserved3 : DINT;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        RawAdaptioWeldControl_AdaptioToPlc : STRUCT
            Start     : BOOL;
            Stop      : BOOL;
            QuickStop : BOOL;
            Reserved1 : DINT;
            Reserved2 : DINT;
            Reserved3 : DINT;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        RawAdaptioWeldControl_PlcToAdaptio : STRUCT
            State     : DINT;
            Reserved1 : DINT;
            Reserved2 : DINT;
            Reserved3 : DINT;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        RawAdaptioFluxSystem_PlcToAdaptio : STRUCT
            State     : DINT;
            Reserved1 : DINT;
            Reserved2 : DINT;
            Reserved3 : DINT;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        RawAdaptioWeldSystem_AdaptioToPlc : STRUCT
            Enable               : BOOL;
            ActiveAreaSelect     : BOOL;
            SwitchAreas          : BOOL;
            Voltage              : REAL;
            Current              : DINT;
            WireSpeed            : DINT;
            RegulationType       : DINT;
            WeldMethod           : DINT;
            AcFrequency          : DINT;
            AcBalance            : DINT;
            AcOffset             : REAL;
            AcPhaseShift         : DINT;
            StartAdjust          : DINT;
            RegulationDynamics   : DINT;
            RegulationInductance : DINT;
            IceWireSpeed         : DINT;
            Reserved1            : DINT;
            Reserved2            : DINT;
            Reserved3            : DINT;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        RawAdaptioWeldSystem_PlcToAdaptio : STRUCT
            Enabled                    : BOOL;
            State                      : DINT;
            ActiveVoltage              : REAL;
            ActiveCurrent              : DINT;
            ActiveWireSpeed            : DINT;
            ActiveRegulationType       : DINT;
            ActiveWeldMethod           : DINT;
            ActiveAcFrequency          : DINT;
            ActiveAcBalance            : DINT;
            ActiveAcOffset             : REAL;
            ActiveAcPhaseShift         : DINT;
            ActiveStartAdjust          : DINT;
            ActiveRegulationDynamics   : DINT;
            ActiveRegulationInductance : DINT;
            ActiveIceWireSpeed         : DINT;
            MeasuredVoltage            : REAL;
            MeasuredCurrent            : DINT;
            MeasuredWireSpeed          : DINT;
            MeasuredIceWireSpeed       : DINT;
            CalculatedHeatInput        : REAL;
            CalculatedDepositionRate   : REAL;
            Reserved1                  : DINT;
            Reserved2                  : DINT;
            Reserved3                  : DINT;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        RawAdaptioWeldAxis_AdaptioToPlc : STRUCT
            EnableMotion              : BOOL;
            Reset                     : BOOL;
            InvalidateReference       : BOOL;
            ResetLinearObjectDistance : BOOL;
            MovementType              : DINT;
            MovementMode              : DINT;
            Radius                    : REAL;
            Position                  : REAL;
            Velocity                  : REAL;
            Reserved1                 : DINT;
            Reserved2                 : DINT;
            Reserved3                 : DINT;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        RawAdaptioWeldAxis_PlcToAdaptio : STRUCT
            InPosition           : BOOL;
            ReferenceValid       : BOOL;
            State                : DINT;
            ErrorCode            : DINT;
            AxisType             : DINT;
            Radius               : REAL;
            Position             : REAL;
            LinearObjectDistance : REAL;
            Velocity             : REAL;
            Reserved1            : DINT;
            Reserved2            : DINT;
            Reserved3            : DINT;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        RawAdaptioWeldHeadManipulator_AdaptioToPlc : STRUCT
            EnableMotion        : BOOL;
            Interpolate         : BOOL;
            XPosition           : REAL;
            YPosition           : REAL;
            Reserved1           : DINT;
            Reserved2           : DINT;
            Reserved3           : DINT;
            InterpolatedSpeed   : REAL;
            XSpeed              : REAL;
            YSpeed              : REAL;
            Reserved4           : DINT;
            Reserved5           : DINT;
            Reserved6           : DINT;
            Reserved7           : DINT;
            Reserved8           : DINT;
            Reserved9           : DINT;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        RawAdaptioWeldHeadManipulator_PlcToAdaptio : STRUCT
            InPosition        : BOOL;
            State             : DINT;
            XPosition         : REAL;
            YPosition         : REAL;
            Reserved1         : DINT;
            Reserved2         : DINT;
            Reserved3         : DINT;
            InterpolatedSpeed : REAL;
            XVelocity         : REAL;
            YVelocity         : REAL;
            Reserved4         : DINT;
            Reserved5         : DINT;
            Reserved6         : DINT;
            Reserved7         : DINT;
            Reserved8         : DINT;
            Reserved9         : DINT;
        END_STRUCT;
    END_TYPE
    {::endif}
END_NAMESPACE