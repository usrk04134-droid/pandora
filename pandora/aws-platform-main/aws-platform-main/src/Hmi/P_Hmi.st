USING Esab.WeldSystem.PowerSources;
USING Esab.Hmi.Modules;
USING Esab.WeldSystem.Flux;
USING Esab.Hmi.Modules;
USING Esab.Motion;
USING Esab.Utils;
USING Esab.Utils.Alarming;
USING Esab.Utils.Assets;
USING Esab.Utils.EmergencyStop;

NAMESPACE Esab.Hmi

    CLASS P_Hmi EXTENDS Object IMPLEMENTS IButtonBox, IAssetRequester, IClickListener, ILongHoldListener, IPushButtonListener
        VAR PRIVATE
            _assetsManager : IAssetsManager := NULL;

            _fluxSystem : IFluxSystem := NULL;
            _emergencyStopCircuitObservable : REF_TO EmergencyStopCircuitObservable := NULL;
            _emergencyStopReset : IPushButton := NULL;
            _fluxSystemRelease : IPushButton := NULL;
            _fluxSystemRecover : IPushButton := NULL;
            _fluxSystemObservable : REF_TO FluxSystemObservable;
            _highSpeed : IPushButton := NULL;
            _wireFeed1 : ITwinPushButton := NULL;
            _wireFeed2 : ITwinPushButton := NULL;
            _motionJoystickAxisSelection : IPushButton := NULL;
            _motionJoystick : IJoystick := NULL;
            _axisJogAxisSelection : IPushButton := NULL;
            _axisJog : ITwinPushButton := NULL;
            _start : IPushButton := NULL;
            _stop : IPushButton := NULL;

            _horizontalSlideAxis : IAxis := NULL;
            _verticalSlideAxis : IAxis := NULL;
            _powerSource1 : IPowerSource := NULL;
            _powerSource2 : IPowerSource := NULL;
            _rollerBed : IAxis := NULL;

            _globalState : IGlobalState := NULL;
            _globalStateObservable : REF_TO GlobalStateObservable;
        END_VAR

        METHOD PUBLIC Setup : BOOL
            VAR_INPUT
                assetsManager : IAssetsManager;
                setupAlarm : IAlarm;
            END_VAR

            _assetsManager := assetsManager;
            _setupAlarm := setupAlarm;

            _isSetup := _assetsManager <> NULL;
        END_METHOD

        METHOD PUBLIC OVERRIDE Execute
            SUPER.Execute();

            IF _setupAlarm.IsActive() THEN
                RETURN;
            END_IF;

            THIS.RequestGlobalStateObservable();
            THIS.RequestEmergencyStopCircuitObservable();
            THIS.RequestFluxSystemHmiAssets();
            THIS.RequestWireFeedButtons();
            THIS.RequestAxisJogButtons();
            THIS.RequestStartStopButtons();
            THIS.RequestHighSpeedButton();
            // THIS.RequestMotionJoystick();

            IF _fluxSystemObservable <> NULL THEN
                IF _fluxSystemRelease <> NULL THEN
                    _fluxSystemRelease.SetStatus(_fluxSystemObservable^.Releasing);
                END_IF;

                IF _fluxSystemRecover <> NULL THEN
                    _fluxSystemRecover.SetStatus(_fluxSystemObservable^.Recovering);
                END_IF;
            END_IF;

            IF _globalStateObservable <> NULL THEN
                IF _highSpeed <> NULL THEN
                    _highSpeed.SetStatus(_globalStateObservable^.HighSpeed);
                END_IF;
            END_IF;
        END_METHOD

        METHOD PUBLIC AssetAssigned
            VAR_INPUT
                asset : REF_TO Asset;
            END_VAR

            ;
        END_METHOD

        METHOD PUBLIC AssetRemoved
            VAR_INPUT
                identifier : INT;
            END_VAR

            CASE identifier OF
                Esab.AssetIdentifier#P_PushButton_FluxSystem_Release:
                    _fluxSystemRelease.SetListener(NULL);
                    _fluxSystemRelease := NULL;
                Esab.AssetIdentifier#P_PushButton_FluxSystem_Recover:
                    _fluxSystemRecover.SetListener(NULL);
                    _fluxSystemRecover := NULL;
                Esab.AssetIdentifier#P_PushButton_System_HighSpeed:
                    _highSpeed.SetListener(NULL);
                    _highSpeed := NULL;
                Esab.AssetIdentifier#P_PushButton_MotionJoystick_AxisSelection:
                    _motionJoystickAxisSelection.SetListener(NULL);
                    _motionJoystickAxisSelection := NULL;
                Esab.AssetIdentifier#P_Joystick_MotionJoystick:
                    _motionJoystick.SetClickListener(NULL);
                    _motionJoystick.SetLongHoldListener(NULL);
                    _motionJoystick := NULL;
                Esab.AssetIdentifier#P_TwinPushButton_WireFeed1:
                    _wireFeed1.SetListener(NULL);
                    _wireFeed1 := NULL;
                Esab.AssetIdentifier#P_TwinPushButton_WireFeed2:
                    _wireFeed2.SetListener(NULL);
                    _wireFeed2 := NULL;
                Esab.AssetIdentifier#P_PushButton_AxisJog_AxisSelection:
                    _axisJogAxisSelection.SetListener(NULL);
                    _axisJogAxisSelection := NULL;
                Esab.AssetIdentifier#P_TwinPushButton_AxisJog:
                    _axisJog.SetListener(NULL);
                    _axisJog := NULL;
                Esab.AssetIdentifier#P_PushButton_Start:
                    _start.SetListener(NULL);
                    _start := NULL;
                Esab.AssetIdentifier#P_PushButton_Stop:
                    _stop.SetListener(NULL);
                    _stop := NULL;
                Esab.AssetIdentifier#HorizontalSlideAxis:
                    _horizontalSlideAxis := NULL;
                Esab.AssetIdentifier#VerticalSlideAxis:
                    _verticalSlideAxis := NULL;
                Esab.AssetIdentifier#PowerSource1:
                    _powerSource1 := NULL;
                Esab.AssetIdentifier#PowerSource2:
                    _powerSource2 := NULL;
                Esab.AssetIdentifier#RollerBed:
                    _rollerBed := NULL;
            END_CASE;
        END_METHOD

        METHOD PUBLIC OnClick
            VAR_INPUT
                direction : JoystickPosition;
            END_VAR

            ;
        END_METHOD

        METHOD PUBLIC OnLongHoldDetected
            VAR_INPUT
                direction : JoystickPosition;
            END_VAR

            VAR_TEMP
                asset : IAsset;
            END_VAR

            asset ?= _motionJoystick;
            asset.Lock();

            IF direction = JoystickPosition#Up OR direction = JoystickPosition#Down THEN
                THIS.RequestVerticalAxis();
                IF _verticalSlideAxis <> NULL THEN
                    asset ?= _verticalSlideAxis;
                    asset.Lock();
                END_IF;
            END_IF;

            IF direction = JoystickPosition#Triangle OR direction = JoystickPosition#Square THEN
                THIS.RequestHorizontalAxis();
                IF _horizontalSlideAxis <> NULL THEN
                    asset ?= _horizontalSlideAxis;
                    asset.Lock();
                END_IF;
            END_IF;
        END_METHOD

        METHOD PUBLIC OnLongHold
            VAR_INPUT
                direction : JoystickPosition;
            END_VAR

            VAR_TEMP
                highSpeed : BOOL := FALSE;
            END_VAR

            IF _globalStateObservable <> NULL THEN
                highSpeed := _globalStateObservable^.HighSpeed;
            END_IF;

            CASE direction OF
                JoystickPosition#Up:
                    IF _verticalSlideAxis <> NULL THEN
                        _verticalSlideAxis.JogPositive(highSpeed);
                    END_IF;
                JoystickPosition#Down:
                    IF _verticalSlideAxis <> NULL THEN
                        _verticalSlideAxis.JogNegative(highSpeed);
                    END_IF;
                JoystickPosition#Triangle:
                    IF _horizontalSlideAxis <> NULL THEN
                        _horizontalSlideAxis.JogNegative(highSpeed);
                    END_IF;
                JoystickPosition#Square:
                    IF _horizontalSlideAxis <> NULL THEN
                        _horizontalSlideAxis.JogPositive(highSpeed);
                    END_IF;
            END_CASE;
        END_METHOD

        METHOD PUBLIC OnLongHoldReleased
            VAR_INPUT
                direction : JoystickPosition;
            END_VAR

            VAR_TEMP
                asset : IAsset;
            END_VAR

            IF direction = JoystickPosition#Up OR direction = JoystickPosition#Down THEN
                IF _verticalSlideAxis <> NULL THEN
                    asset ?= _verticalSlideAxis;
                    asset.Unlock();
                END_IF;
            END_IF;

            IF direction = JoystickPosition#Triangle OR direction = JoystickPosition#Square THEN
                IF _horizontalSlideAxis <> NULL THEN
                    asset ?= _horizontalSlideAxis;
                    asset.Unlock();
                END_IF;
            END_IF;

            asset ?= _motionJoystick;
            asset.Unlock();
        END_METHOD

        METHOD PUBLIC OnPushButtonPressed
            VAR_INPUT
                id : AssetIdentifier;
            END_VAR

            VAR_TEMP
                asset : IAsset;
            END_VAR

            CASE id OF
                Esab.AssetIdentifier#P_PushButton_FluxSystem_Release:
                    THIS.RequestFluxSystem();

                    IF _fluxSystem <> NULL AND _fluxSystemObservable <> NULL THEN
                        IF _fluxSystemObservable^.Releasing THEN
                            _fluxSystem.StopRelease();
                        ELSE
                            _fluxSystem.Release();
                        END_IF;
                    END_IF;
                Esab.AssetIdentifier#P_PushButton_FluxSystem_Recover:
                    THIS.RequestFluxSystem();

                    IF _fluxSystem <> NULL THEN
                        IF _fluxSystemObservable^.Recovering THEN
                            _fluxSystem.StopRecover();
                        ELSE
                            _fluxSystem.Recover();
                        END_IF;
                    END_IF;
                Esab.AssetIdentifier#P_PushButton_System_HighSpeed:
                    THIS.RequestGlobalState();

                    IF _globalState <> NULL THEN
                        _globalState.SetHighSpeed(NOT _globalState.GetHighSpeed());
                    END_IF;
                Esab.AssetIdentifier#P_TwinPushButton_WireFeed1:
                    THIS.RequestWeldSystem1();

                    IF _powerSource1 <> NULL THEN
                        asset ?= _powerSource1;
                        asset.Lock();
                    END_IF;
                Esab.AssetIdentifier#P_TwinPushButton_WireFeed2:
                    THIS.RequestWeldSystem2();

                    IF _powerSource2 <> NULL THEN
                        asset ?= _powerSource2;
                        asset.Lock();
                    END_IF;
                Esab.AssetIdentifier#P_PushButton_MotionJoystick_AxisSelection:
                    ;
                Esab.AssetIdentifier#P_PushButton_AxisJog_AxisSelection:
                    ;
                Esab.AssetIdentifier#P_TwinPushButton_AxisJog:
                    THIS.RequestRollerBed();

                    IF _rollerBed <> NULL THEN
                        _rollerBed.PowerOn();
                        asset ?= _rollerBed;
                        asset.Lock();
                    END_IF;
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

            VAR_TEMP
                highSpeed : BOOL := FALSE;
            END_VAR

            IF _globalStateObservable <> NULL THEN
                highSpeed := _globalStateObservable^.HighSpeed;
            END_IF;

            CASE id OF
                Esab.AssetIdentifier#P_PushButton_FluxSystem_Release:
                    ;
                Esab.AssetIdentifier#P_PushButton_FluxSystem_Recover:
                    ;
                Esab.AssetIdentifier#P_PushButton_System_HighSpeed:
                    ;
                Esab.AssetIdentifier#P_TwinPushButton_WireFeed1:
                    IF _powerSource1 <> NULL THEN
                        IF _wireFeed1.IsInDirection1() THEN
                            _powerSource1.WireFeedJogNeg(highSpeed);
                        ELSIF _wireFeed1.IsInDirection2() THEN
                            _powerSource1.WireFeedJogPos(highSpeed);
                        END_IF;
                    END_IF;
                Esab.AssetIdentifier#P_TwinPushButton_WireFeed2:
                    IF _powerSource2 <> NULL THEN
                        IF _wireFeed2.IsInDirection1() THEN
                            _powerSource2.WireFeedJogNeg(highSpeed);
                        ELSIF _wireFeed2.IsInDirection2() THEN
                            _powerSource2.WireFeedJogPos(highSpeed);
                        END_IF;
                    END_IF;
                Esab.AssetIdentifier#P_PushButton_MotionJoystick_AxisSelection:
                    ;
                Esab.AssetIdentifier#P_PushButton_AxisJog_AxisSelection:
                    ;
                Esab.AssetIdentifier#P_TwinPushButton_AxisJog:
                    IF _rollerBed <> NULL THEN
                        IF _axisJog.IsInDirection1() THEN
                            _rollerBed.JogNegative(highSpeed);
                        ELSIF _axisJog.IsInDirection2() THEN
                            _rollerBed.JogPositive(highSpeed);
                        END_IF;
                    END_IF;
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

            VAR_TEMP
                asset : IAsset;
            END_VAR

            CASE id OF
                Esab.AssetIdentifier#P_PushButton_FluxSystem_Release:
                    ;
                Esab.AssetIdentifier#P_PushButton_FluxSystem_Recover:
                    ;
                Esab.AssetIdentifier#P_PushButton_System_HighSpeed:
                    ;
                Esab.AssetIdentifier#P_TwinPushButton_WireFeed1:
                    IF _powerSource1 <> NULL THEN
                        asset ?= _powerSource1;
                        asset.Unlock();
                    END_IF;
                Esab.AssetIdentifier#P_TwinPushButton_WireFeed2:
                    IF _powerSource1 <> NULL THEN
                        asset ?= _powerSource2;
                        asset.Unlock();
                    END_IF;
                Esab.AssetIdentifier#P_PushButton_MotionJoystick_AxisSelection:
                    ;
                Esab.AssetIdentifier#P_PushButton_AxisJog_AxisSelection:
                    ;
                Esab.AssetIdentifier#P_TwinPushButton_AxisJog:
                    IF _rollerBed <> NULL THEN
                        _rollerBed.PowerOff();
                        asset ?= _rollerBed;
                        asset.Unlock();
                    END_IF;
                Esab.AssetIdentifier#P_PushButton_Start:
                    ;
                Esab.AssetIdentifier#P_PushButton_Stop:
                    ;
            END_CASE;
        END_METHOD

        METHOD PRIVATE RequestMotionJoystick
            VAR_TEMP
                assetHandle : REF_TO Asset;
            END_VAR

            IF _motionJoystickAxisSelection = NULL THEN
                assetHandle := THIS._assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#P_PushButton_MotionJoystick_AxisSelection);

                IF assetHandle <> NULL THEN
                    _motionJoystickAxisSelection ?= assetHandle^;
                    IF _motionJoystickAxisSelection <> NULL THEN
                        _motionJoystickAxisSelection.SetListener(THIS);
                    END_IF;
                END_IF;
            END_IF;

            IF _motionJoystick = NULL THEN
                assetHandle := THIS._assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#P_Joystick_MotionJoystick);

                IF assetHandle <> NULL THEN
                    _motionJoystick ?= assetHandle^;
                    IF _motionJoystick <> NULL THEN
                        _motionJoystick.SetClickListener(THIS);
                        _motionJoystick.SetLongHoldListener(THIS);
                    END_IF;
                END_IF;
            END_IF;
        END_METHOD

        METHOD PRIVATE RequestHorizontalAxis
            VAR_TEMP
                assetHandle : REF_TO Asset;
            END_VAR

            IF _horizontalSlideAxis = NULL THEN
                assetHandle := THIS._assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#HorizontalSlideAxis);

                IF assetHandle <> NULL THEN
                    _horizontalSlideAxis ?= assetHandle^;
                END_IF;
            END_IF;
        END_METHOD

        METHOD PRIVATE RequestVerticalAxis
            VAR_TEMP
                assetHandle : REF_TO Asset;
            END_VAR

            IF _verticalSlideAxis = NULL THEN
                assetHandle := THIS._assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#VerticalSlideAxis);

                IF assetHandle <> NULL THEN
                    _verticalSlideAxis ?= assetHandle^;
                END_IF;
            END_IF;
        END_METHOD

        METHOD PRIVATE RequestHighSpeedButton
            VAR_TEMP
                assetHandle : REF_TO Asset;
            END_VAR

            IF _highSpeed = NULL THEN
                assetHandle := THIS._assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#P_PushButton_System_HighSpeed);

                IF assetHandle <> NULL THEN
                    _highSpeed ?= assetHandle^;
                    IF _highSpeed <> NULL THEN
                        _highSpeed.SetListener(THIS);
                    END_IF;
                END_IF;
            END_IF;
        END_METHOD

        METHOD PRIVATE RequestGlobalState
            VAR_TEMP
                assetHandle : REF_TO Asset;
            END_VAR

            IF _globalState = NULL THEN
                assetHandle := THIS._assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#GlobalState);

                IF assetHandle <> NULL THEN
                    _globalState ?= assetHandle^;
                END_IF;
            END_IF;
        END_METHOD

        METHOD PRIVATE RequestGlobalStateObservable
            VAR_TEMP
                observable : IAssetObservable;
            END_VAR

            IF _globalStateObservable = NULL THEN
                observable := THIS._assetsManager.ObserveAsset(Esab.AssetIdentifier#GlobalState);

                IF observable <> NULL THEN
                    _globalStateObservable ?= observable;
                END_IF;
            END_IF;
        END_METHOD

        METHOD PRIVATE RequestEmergencyStopCircuitObservable
            VAR_TEMP
                observable : IAssetObservable;
            END_VAR

            IF _emergencyStopCircuitObservable = NULL THEN
                observable := THIS._assetsManager.ObserveAsset(Esab.AssetIdentifier#EmergencyStopCircuit);

                IF observable <> NULL THEN
                    _emergencyStopCircuitObservable ?= observable;
                END_IF;
            END_IF;
        END_METHOD

        METHOD PRIVATE RequestFluxSystemHmiAssets
            VAR_TEMP
                assetHandle : REF_TO Asset;
                observable : IAssetObservable;
            END_VAR

            IF _fluxSystemRelease = NULL THEN
                assetHandle := THIS._assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#P_PushButton_FluxSystem_Release);

                IF assetHandle <> NULL THEN
                    _fluxSystemRelease ?= assetHandle^;
                    IF _fluxSystemRelease <> NULL THEN
                        _fluxSystemRelease.SetListener(THIS);
                    END_IF;
                END_IF;
            END_IF;

            IF _fluxSystemRecover = NULL THEN
                assetHandle := THIS._assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#P_PushButton_FluxSystem_Recover);

                IF assetHandle <> NULL THEN
                    _fluxSystemRecover ?= assetHandle^;
                    IF _fluxSystemRecover <> NULL THEN
                        _fluxSystemRecover.SetListener(THIS);
                    END_IF;
                END_IF;
            END_IF;

            IF _fluxSystemObservable = NULL THEN
                observable := THIS._assetsManager.ObserveAsset(Esab.AssetIdentifier#FluxSystem);

                IF observable <> NULL THEN
                    _fluxSystemObservable ?= observable;
                END_IF;
            END_IF;
        END_METHOD

        METHOD PRIVATE RequestFluxSystem
            VAR_TEMP
                assetHandle : REF_TO Asset;
            END_VAR

            IF _fluxSystem = NULL THEN
                assetHandle := THIS._assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#FluxSystem);

                IF assetHandle <> NULL THEN
                    _fluxSystem ?= assetHandle^;
                END_IF;
            END_IF;
        END_METHOD

        METHOD PRIVATE RequestWireFeedButtons
            VAR_TEMP
                assetHandle : REF_TO Asset;
            END_VAR

            IF _wireFeed1 = NULL THEN
                assetHandle := THIS._assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#P_TwinPushButton_WireFeed1);

                IF assetHandle <> NULL THEN
                    _wireFeed1 ?= assetHandle^;
                    IF _wireFeed1 <> NULL THEN
                        _wireFeed1.SetListener(THIS);
                    END_IF;
                END_IF;
            END_IF;

            IF _wireFeed2 = NULL THEN
                assetHandle := THIS._assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#P_TwinPushButton_WireFeed2);

                IF assetHandle <> NULL THEN
                    _wireFeed2 ?= assetHandle^;
                    IF _wireFeed2 <> NULL THEN
                        _wireFeed2.SetListener(THIS);
                    END_IF;
                END_IF;
            END_IF;
        END_METHOD

        METHOD PRIVATE RequestWeldSystem1
            VAR_TEMP
                assetHandle : REF_TO Asset;
            END_VAR

            IF _powerSource1 = NULL THEN
                assetHandle := THIS._assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#PowerSource1);

                IF assetHandle <> NULL THEN
                    _powerSource1 ?= assetHandle^;
                END_IF;
            END_IF;
        END_METHOD

        METHOD PRIVATE RequestWeldSystem2
            VAR_TEMP
                assetHandle : REF_TO Asset;
            END_VAR

            IF _powerSource2 = NULL THEN
                assetHandle := THIS._assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#PowerSource2);

                IF assetHandle <> NULL THEN
                    _powerSource2 ?= assetHandle^;
                END_IF;
            END_IF;
        END_METHOD

        METHOD PRIVATE RequestAxisJogButtons
            VAR_TEMP
                assetHandle : REF_TO Asset;
            END_VAR

            IF _axisJogAxisSelection = NULL THEN
                assetHandle := THIS._assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#P_PushButton_AxisJog_AxisSelection);

                IF assetHandle <> NULL THEN
                    _axisJogAxisSelection ?= assetHandle^;

                    IF _axisJogAxisSelection <> NULL THEN
                        _axisJogAxisSelection.SetListener(THIS);
                    END_IF;
                END_IF;
            END_IF;

            IF _axisJog = NULL THEN
                assetHandle := THIS._assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#P_TwinPushButton_AxisJog);

                IF assetHandle <> NULL THEN
                    _axisJog ?= assetHandle^;
                    IF _axisJog <> NULL THEN
                        _axisJog.SetListener(THIS);
                    END_IF;
                END_IF;
            END_IF;
        END_METHOD

        METHOD PRIVATE RequestStartStopButtons
            VAR_TEMP
                assetHandle : REF_TO Asset;
            END_VAR

            IF _start = NULL THEN
                assetHandle := THIS._assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#P_PushButton_Start);

                IF assetHandle <> NULL THEN
                    _start ?= assetHandle^;
                    IF _start <> NULL THEN
                        _start.SetListener(THIS);
                    END_IF;
                END_IF;
            END_IF;

            IF _stop = NULL THEN
                assetHandle := THIS._assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#P_PushButton_Stop);

                IF assetHandle <> NULL THEN
                    _stop ?= assetHandle^;
                    IF _stop <> NULL THEN
                        _stop.SetListener(THIS);
                    END_IF;
                END_IF;
            END_IF;
        END_METHOD

        METHOD PRIVATE RequestRollerBed
            VAR_TEMP
                assetHandle : REF_TO Asset;
            END_VAR

            IF _rollerBed = NULL THEN
                assetHandle := THIS._assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#RollerBed);

                IF assetHandle <> NULL THEN
                    _rollerBed ?= assetHandle^;
                END_IF;
            END_IF;
        END_METHOD
    END_CLASS

END_NAMESPACE