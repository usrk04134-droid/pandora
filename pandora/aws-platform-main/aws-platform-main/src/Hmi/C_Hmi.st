USING Esab.Hmi.Modules;
USING Esab.WeldSystem.Flux;
USING Esab.Hmi.Modules;
USING Esab.Motion;
USING Esab.Utils;
USING Esab.Utils.Alarming;
USING Esab.Utils.Assets;
USING Esab.Utils.EmergencyStop;
USING Esab.WeldSystem.PowerSources;

NAMESPACE Esab.Hmi

    CLASS C_Hmi EXTENDS Object IMPLEMENTS IButtonBox, IAssetRequester, IClickListener, ILongHoldListener, IPushButtonListener
        VAR PRIVATE
            _assetsManager : IAssetsManager := NULL;

            _fluxSystem : IFluxSystem := NULL;
            _emergencyStopCircuitObservable : REF_TO EmergencyStopCircuitObservable := NULL;
            _emergencyStopReset : IPushButton := NULL;
            _fluxSystemRelease : IPushButton := NULL;
            _fluxSystemObservable : REF_TO FluxSystemObservable;
            _highSpeed : IPushButton := NULL;
            _wireFeed1 : ITwinPushButton := NULL;
            _wireFeed2 : ITwinPushButton := NULL;
            _wireFeed3 : ITwinPushButton := NULL;
            _trackingOff : IPushButton := NULL;
            _motionJoystick : IJoystick := NULL;
            _tilt : ITwinPushButton := NULL;

            _horizontalSlideAxis : IAxis := NULL;
            _verticalSlideAxis : IAxis := NULL;
            _powerSource1 : IPowerSource := NULL;
            _powerSource2 : IPowerSource := NULL;
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
            THIS.RequestHighSpeedButton();
            THIS.RequestWireFeedButtons();
            // THIS.RequestMotionJoystick();

            IF _fluxSystemObservable <> NULL THEN
                IF _fluxSystemRelease <> NULL THEN
                    _fluxSystemRelease.SetStatus(_fluxSystemObservable^.Releasing);
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
                Esab.AssetIdentifier#C_PushButton_FluxSystem_Release:
                    _fluxSystemRelease.SetListener(NULL);
                    _fluxSystemRelease := NULL;
                Esab.AssetIdentifier#C_PushButton_System_HighSpeed:
                    _highSpeed.SetListener(NULL);
                    _highSpeed := NULL;
                Esab.AssetIdentifier#C_TwinPushButton_WireFeed1:
                    _wireFeed1.SetListener(NULL);
                    _wireFeed1 := NULL;
                Esab.AssetIdentifier#C_TwinPushButton_WireFeed2:
                    _wireFeed2.SetListener(NULL);
                    _wireFeed2 := NULL;
                Esab.AssetIdentifier#C_TwinPushButton_WireFeed3:
                    _wireFeed3.SetListener(NULL);
                    _wireFeed3 := NULL;
                Esab.AssetIdentifier#C_PushButton_TrackingOff:
                    _trackingOff.SetListener(NULL);
                    _trackingOff := NULL;
                Esab.AssetIdentifier#C_Joystick_MotionJoystick:
                    _motionJoystick.SetClickListener(NULL);
                    _motionJoystick.SetLongHoldListener(NULL);
                    _motionJoystick := NULL;
                Esab.AssetIdentifier#C_TwinPushButton_Tilt:
                    _tilt.SetListener(NULL);
                    _tilt := NULL;
                Esab.AssetIdentifier#HorizontalSlideAxis:
                    _horizontalSlideAxis := NULL;
                Esab.AssetIdentifier#VerticalSlideAxis:
                    _verticalSlideAxis := NULL;
                Esab.AssetIdentifier#PowerSource1:
                    _powerSource1 := NULL;
                Esab.AssetIdentifier#PowerSource2:
                    _powerSource2 := NULL;
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
                fluxSystem : IFluxSystem;
            END_VAR

            CASE id OF
                Esab.AssetIdentifier#C_PushButton_FluxSystem_Release:
                    THIS.RequestFluxSystem();

                    IF _fluxSystem <> NULL AND _fluxSystemObservable <> NULL THEN
                        IF _fluxSystemObservable^.Releasing THEN
                            _fluxSystem.StopRelease();
                        ELSE
                            _fluxSystem.Release();
                        END_IF;
                    END_IF;
                Esab.AssetIdentifier#C_PushButton_System_HighSpeed:
                    THIS.RequestGlobalState();

                    IF _globalState <> NULL THEN
                        asset ?= _globalState;
                        _globalState.SetHighSpeed(NOT _globalState.GetHighSpeed());
                    END_IF;
                Esab.AssetIdentifier#C_TwinPushButton_WireFeed1:
                    THIS.RequestPowerSource1();

                    IF _powerSource1 <> NULL THEN
                        asset ?= _powerSource1;
                        asset.Lock();
                    END_IF;
                Esab.AssetIdentifier#C_TwinPushButton_WireFeed2:
                    THIS.RequestPowerSource2();

                    IF _powerSource2 <> NULL THEN
                        asset ?= _powerSource2;
                        asset.Lock();
                    END_IF;
                Esab.AssetIdentifier#C_TwinPushButton_WireFeed3:
                    ;
                Esab.AssetIdentifier#C_PushButton_TrackingOff:
                    ;
                Esab.AssetIdentifier#C_TwinPushButton_Tilt:
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
                Esab.AssetIdentifier#C_PushButton_FluxSystem_Release:
                    ;
                Esab.AssetIdentifier#C_PushButton_System_HighSpeed:
                    ;
                Esab.AssetIdentifier#C_TwinPushButton_WireFeed1:
                    IF _powerSource1 <> NULL THEN
                        IF _wireFeed1.IsInDirection1() THEN
                            _powerSource1.WireFeedJogNeg(highSpeed);
                        ELSIF _wireFeed1.IsInDirection2() THEN
                            _powerSource1.WireFeedJogPos(highSpeed);
                        END_IF;
                    END_IF;
                Esab.AssetIdentifier#C_TwinPushButton_WireFeed2:
                    IF _powerSource2 <> NULL THEN
                        IF _wireFeed2.IsInDirection1() THEN
                            _powerSource2.WireFeedJogNeg(highSpeed);
                        ELSIF _wireFeed2.IsInDirection2() THEN
                            _powerSource2.WireFeedJogPos(highSpeed);
                        END_IF;
                    END_IF;
                Esab.AssetIdentifier#C_TwinPushButton_WireFeed3:
                    ;
                Esab.AssetIdentifier#C_PushButton_TrackingOff:
                    ;
                Esab.AssetIdentifier#C_TwinPushButton_Tilt:
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
                Esab.AssetIdentifier#C_PushButton_FluxSystem_Release:
                    ;
                Esab.AssetIdentifier#C_PushButton_System_HighSpeed:
                    ;
                Esab.AssetIdentifier#C_TwinPushButton_WireFeed1:
                    IF _powerSource1 <> NULL THEN
                        asset ?= _powerSource1;
                        asset.Unlock();
                    END_IF;
                Esab.AssetIdentifier#C_TwinPushButton_WireFeed2:
                    IF _powerSource1 <> NULL THEN
                        asset ?= _powerSource2;
                        asset.Unlock();
                    END_IF;
                Esab.AssetIdentifier#C_TwinPushButton_WireFeed3:
                    ;
                Esab.AssetIdentifier#C_PushButton_TrackingOff:
                    ;
                Esab.AssetIdentifier#C_TwinPushButton_Tilt:
                    ;
            END_CASE;
        END_METHOD

        METHOD PRIVATE RequestMotionJoystick
            VAR_TEMP
                assetHandle : REF_TO Asset;
            END_VAR

            IF _motionJoystick = NULL THEN
                assetHandle := THIS._assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#C_Joystick_MotionJoystick);

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
                assetHandle := THIS._assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#C_PushButton_System_HighSpeed);

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
                assetHandle := THIS._assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#C_PushButton_FluxSystem_Release);

                IF assetHandle <> NULL THEN
                    _fluxSystemRelease ?= assetHandle^;
                    IF _fluxSystemRelease <> NULL THEN
                        _fluxSystemRelease.SetListener(THIS);
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
                assetHandle := THIS._assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#C_TwinPushButton_WireFeed1);

                IF assetHandle <> NULL THEN
                    _wireFeed1 ?= assetHandle^;
                    IF _wireFeed1 <> NULL THEN
                        _wireFeed1.SetListener(THIS);
                    END_IF;
                END_IF;
            END_IF;

            IF _wireFeed2 = NULL THEN
                assetHandle := THIS._assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#C_TwinPushButton_WireFeed2);

                IF assetHandle <> NULL THEN
                    _wireFeed2 ?= assetHandle^;
                    IF _wireFeed2 <> NULL THEN
                        _wireFeed2.SetListener(THIS);
                    END_IF;
                END_IF;
            END_IF;

            IF _wireFeed3 = NULL THEN
                assetHandle := THIS._assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#C_TwinPushButton_WireFeed3);

                IF assetHandle <> NULL THEN
                    _wireFeed3 ?= assetHandle^;
                    IF _wireFeed3 <> NULL THEN
                        _wireFeed3.SetListener(THIS);
                    END_IF;
                END_IF;
            END_IF;
        END_METHOD

        METHOD PRIVATE RequestPowerSource1
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

        METHOD PRIVATE RequestPowerSource2
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
    END_CLASS

END_NAMESPACE