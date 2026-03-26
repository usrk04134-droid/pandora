USING Esab.Utils.Alarming;
USING Esab.WeldSystem.Flux;
USING Esab.Motion;
USING Esab.Utils.Assets;
USING Esab.WeldSystem.PowerSources;

NAMESPACE Esab

    INTERFACE IGlobalState
        METHOD SetHighSpeed
            VAR_INPUT
                highSpeed : BOOL;
            END_VAR
        END_METHOD

        METHOD GetHighSpeed : BOOL
        END_METHOD

        METHOD SetMode
            VAR_INPUT
                mode : AwsPlatformMode;
            END_VAR
        END_METHOD

        METHOD GetMode : AwsPlatformMode
        END_METHOD
    END_INTERFACE

    CLASS GlobalState EXTENDS Asset IMPLEMENTS IGlobalState
        VAR PRIVATE
            _assets : IAssetsManager;
            _observable : GlobalStateObservable;

            _highSpeed : BOOL;
            _mode : AwsPlatformMode;

            _rollerBedObservable : REF_TO AxisObservable := NULL;
            _powerSource1Observable : REF_TO PowerSourceObservable := NULL;
            _powerSource2Observable : REF_TO PowerSourceObservable := NULL;
            _fluxSystemObservable : REF_TO FluxSystemObservable := NULL;
            _horizontalSlideAxisObservable : REF_TO AxisObservable := NULL;
            _verticalSlideAxisObservable : REF_TO AxisObservable := NULL;
        END_VAR

        METHOD PUBLIC Setup
            VAR_INPUT
                assets : IAssetsManager;
                setupAlarm : IAlarm;
            END_VAR

            _assets := assets;
            _setupAlarm := setupAlarm;

            _isSetup := _assets <> NULL;
        END_METHOD

        METHOD PUBLIC OVERRIDE Observe : IAssetObservable
            Observe := _observable;
        END_METHOD

        METHOD PUBLIC OVERRIDE Execute
            SUPER.Execute();

            IF _setupAlarm.IsActive() THEN
                RETURN;
            END_IF;
/*
            IF _rollerBedObservable = NULL THEN
                _rollerBedObservable ?= _assets.ObserveAsset(Esab.AssetIdentifier#RollerBed);
            END_IF;

            IF _powerSource1Observable = NULL THEN
                _powerSource1Observable ?= _assets.ObserveAsset(Esab.AssetIdentifier#PowerSource1);
            END_IF;

            IF _powerSource2Observable = NULL THEN
                _powerSource2Observable ?= _assets.ObserveAsset(Esab.AssetIdentifier#PowerSource2);
            END_IF;

            IF _fluxSystemObservable = NULL THEN
                _fluxSystemObservable ?= _assets.ObserveAsset(Esab.AssetIdentifier#FluxSystem);
            END_IF;

            IF _horizontalSlideAxisObservable = NULL THEN
                _horizontalSlideAxisObservable ?= _assets.ObserveAsset(Esab.AssetIdentifier#HorizontalSlideAxis);
            END_IF;

            IF _verticalSlideAxisObservable = NULL THEN
                _verticalSlideAxisObservable ?= _assets.ObserveAsset(Esab.AssetIdentifier#VerticalSlideAxis);
            END_IF;*/

            THIS.UpdateObservable();
        END_METHOD

        METHOD PUBLIC OVERRIDE UpdateState
            VAR_TEMP
                state : SystemState := SystemState#Healthy;
            END_VAR

            IF _rollerBedObservable <> NULL THEN
                IF _rollerBedObservable^.State = AxisState#Error THEN
                    state := SystemState#Error;
                END_IF;
            END_IF;

            IF _powerSource1Observable <> NULL THEN
                IF _powerSource1Observable^.State = PowerSourceState#Error THEN
                    state := SystemState#Error;
                END_IF;
            END_IF;

            IF _powerSource2Observable <> NULL THEN
                IF _powerSource2Observable^.State = PowerSourceState#Error THEN
                    state := SystemState#Error;
                END_IF;
            END_IF;

            IF _fluxSystemObservable <> NULL THEN
                IF _fluxSystemObservable^.State = FluxSystemState#Error THEN
                    state := SystemState#Error;
                END_IF;
            END_IF;

            IF _horizontalSlideAxisObservable <> NULL THEN
                IF _horizontalSlideAxisObservable^.Error THEN
                    state := SystemState#Error;
                END_IF;
            END_IF;

            IF _verticalSlideAxisObservable <> NULL THEN
                IF _verticalSlideAxisObservable^.Error THEN
                    state := SystemState#Error;
                END_IF;
            END_IF;

            _currentState := state;
        END_METHOD

        METHOD PUBLIC SetHighSpeed
            VAR_INPUT
                highSpeed : BOOL;
            END_VAR

            _highSpeed := highSpeed;
        END_METHOD

        METHOD PUBLIC GetHighSpeed : BOOL
            GetHighSpeed := _highSpeed;
        END_METHOD

        METHOD PUBLIC SetMode
            VAR_INPUT
                mode : AwsPlatformMode;
            END_VAR

            _mode := mode;
        END_METHOD

        METHOD PUBLIC GetMode : AwsPlatformMode
            GetMode := _mode;
        END_METHOD

        METHOD PRIVATE UpdateObservable
            _observable.HighSpeed := _highSpeed;
            _observable.Mode := _mode;
        END_METHOD
    END_CLASS

    CLASS GlobalStateObservable IMPLEMENTS IAssetObservable
        VAR PUBLIC
            State : SystemState;
            HighSpeed : BOOL := FALSE;
            Mode : AwsPlatformMode;
        END_VAR
    END_CLASS

    TYPE
        SystemState : INT(
            Healthy := 0,
            Error := 1
        );

        AwsPlatformMode : INT(
            Manual := 0,
            Adaptio := 1
        ) := AwsPlatformMode#Manual;
    END_TYPE

END_NAMESPACE