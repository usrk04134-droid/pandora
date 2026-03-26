USING Esab.Api;
USING Esab.Motion;
USING Esab.Utils.Alarming;
USING Esab.WeldSystem.PowerSources;
USING Esab.Utils.Alarming;
USING Esab.Utils.Assets;

USING Siemens.Simatic.S71500.Alarming;

NAMESPACE Esab.WeldSystem

    INTERFACE IWeldSystemOrchestrator
        METHOD Execute
        END_METHOD

        /// Starts a weld according to the set configuration
        METHOD Start
            VAR_OUTPUT
                error : WeldSystemOrchestratorErrorCode;
            END_VAR
        END_METHOD

        /// Stops a weld
        METHOD Stop
            VAR_INPUT
                /// If TRUE, will issue quick stop commands to the power sources, which will make them skip the stop phase.
                /// It will also ignore all wire offsets and stop all active power sources at the same time.
                /// NOTE: The power sources will still use the crater fill and burn back parameters.
                noStopPhase : BOOL;
            END_VAR
        END_METHOD

        METHOD SwitchWeldDataSet
            VAR_INPUT
                id : INT;
            END_VAR

            VAR_OUTPUT
                error : WeldSystemOrchestratorErrorCode;
            END_VAR
        END_METHOD

        /// Returns a reference to the _active_ power source inputs for the power source number <id>
        METHOD GetPowerSourceSetPoints : REF_TO SetPoints
            VAR_INPUT
                id: INT;
                active : BOOL := TRUE;
            END_VAR

            VAR_OUTPUT
                error : WeldSystemOrchestratorErrorCode;
            END_VAR
        END_METHOD

        METHOD SetStartMode
            VAR_INPUT
                startMode : StartType;
            END_VAR
        END_METHOD

        METHOD GetHeadTorchIndex : INT
        END_METHOD

        METHOD GetNextEnabledPowerSource : INT
            VAR_INPUT
                index : INT;
            END_VAR
        END_METHOD

        METHOD StartWelding
            VAR_INPUT
                index : INT;
            END_VAR
        END_METHOD

        METHOD StopWelding
            VAR_INPUT
                index : INT;
            END_VAR
        END_METHOD

        METHOD IsWelding : BOOL
        END_METHOD

        METHOD IsWelding : BOOL
            VAR_INPUT
                index : INT;
            END_VAR
        END_METHOD

        METHOD ReadyToWeld : BOOL
        END_METHOD

        METHOD WireOffset : LREAL
            VAR_INPUT
                index : INT;
            END_VAR
        END_METHOD
    END_INTERFACE

    /// NOTE: For simplicity this class assumes that the AssetIdentifiers of the power sources are in sequential order, starting with #1.
    /// If this changes things *will* break.
    ///
    /// The max number of power sources/weld systems supported is 3. To change this, add/remove assets and set the proper number in the constant below.
    CLASS WeldSystemOrchestrator EXTENDS Asset IMPLEMENTS IAssetRequester, IWeldSystemOrchestrator, IPowerSourceListener
        VAR CONSTANT PUBLIC
            MAX_NUMBER_OF_POWER_SOURCES : INT := 3;
        END_VAR

        VAR PRIVATE
            _assetsManager : IAssetsManager;
            _runtimeParameters : REF_TO WeldSystemOrchestratorRuntimeParameters;
            _hardwareConfiguration : REF_TO WeldSystemOrchestratorHardwareConfiguration;

            _powerSources : ARRAY [1..MAX_NUMBER_OF_POWER_SOURCES] OF IPowerSource;
            _connectedPowerSources : ARRAY [1..MAX_NUMBER_OF_POWER_SOURCES] OF BOOL;
            _weldAxis : IAxis := NULL;
            _weldAxisObservable : REF_TO AxisObservable;

            _startMode : StartType := StartType#Direct;

            _lastState : WeldSystemOrchestratorState;
            _startWeld : BOOL := FALSE;
            _stopWeld : BOOL := FALSE;
            _firstTorchStartPosition : LREAL;
            _firstTorchStopPosition : LREAL;
        END_VAR

        METHOD PUBLIC Setup
            VAR_INPUT
                runtimeParameters : REF_TO WeldSystemOrchestratorRuntimeParameters;
                hardwareConfiguration : REF_TO WeldSystemOrchestratorHardwareConfiguration;
                assetsManager : IAssetsManager;
                setupAlarm : IAlarm;
            END_VAR

            _runtimeParameters := runtimeParameters;
            _hardwareConfiguration := hardwareConfiguration;
            _assetsManager := assetsManager;
            _setupAlarm := setupAlarm;

            _isSetup := _runtimeParameters <> NULL AND
                        _hardwareConfiguration <> NULL AND
                        _assetsManager <> NULL;

            _currentState := WeldSystemOrchestratorState#Idle;
            _lastState := _currentState;
        END_METHOD

        METHOD PUBLIC OVERRIDE Execute
            SUPER.Execute();

            IF _setupAlarm.IsActive() THEN
                RETURN;
            END_IF;

            IF NOT THIS.IsInControl() THEN
                THIS.RequestAndLockConnectedPowerSources();
            END_IF;

            THIS.HandleRemoteStart();
            THIS.UpdateState();
        END_METHOD

        METHOD PUBLIC OVERRIDE Observe : IAssetObservable
            Observe := NULL;
        END_METHOD

        METHOD PUBLIC PowerSourceConnected
            VAR_INPUT
                id : UINT;
            END_VAR

            _connectedPowerSources[id] := TRUE;
        END_METHOD

        METHOD PUBLIC PowerSourceDisconnected
            VAR_INPUT
                id : UINT;
            END_VAR

            _connectedPowerSources[id] := FALSE;
        END_METHOD

        METHOD PUBLIC AssetAssigned
            VAR_INPUT
                asset : REF_TO Esab.Utils.Assets.Asset;
            END_VAR

            ;
        END_METHOD

        METHOD PUBLIC AssetRemoved
            VAR_INPUT
                identifier : Esab.AssetIdentifier;
            END_VAR

            VAR_TEMP
                psIndex : INT := 0;
            END_VAR

            psIndex := identifier - Esab.AssetIdentifier#PowerSource1 + 1;

            IF psIndex > 0 AND psIndex <= MAX_NUMBER_OF_POWER_SOURCES THEN
                _powerSources[psIndex].SetListener(NULL);
                _powerSources[psIndex] := NULL;
            ELSE
                ; // Handle other assets here
            END_IF;
        END_METHOD

        METHOD PUBLIC Start
            VAR_OUTPUT
                error : WeldSystemOrchestratorErrorCode := WeldSystemOrchestratorErrorCode#NoError;
            END_VAR

            ;
        END_METHOD

        METHOD PUBLIC Stop
            VAR_INPUT
                noStopPhase : BOOL;
            END_VAR

            ;
        END_METHOD

        METHOD PUBLIC SwitchWeldDataSet
            VAR_INPUT
                id : INT;
            END_VAR

            VAR_OUTPUT
                error : WeldSystemOrchestratorErrorCode := WeldSystemOrchestratorErrorCode#NoError;
            END_VAR

            IF _powerSources[id] = NULL THEN
                error := WeldSystemOrchestratorErrorCode#PowerSourceNotAvailable;
                RETURN;
            ELSIF NOT _connectedPowerSources[id] THEN
                error := WeldSystemOrchestratorErrorCode#PowerSourceNotConnected;
                RETURN;
            END_IF;

            _powerSources[id].SwitchActivePassive();
        END_METHOD

        METHOD PUBLIC GetPowerSourceSetPoints : REF_TO SetPoints
            VAR_INPUT
                id: INT;
                active : BOOL := TRUE;
            END_VAR

            VAR_OUTPUT
                error : WeldSystemOrchestratorErrorCode := WeldSystemOrchestratorErrorCode#NoError;
            END_VAR

            GetPowerSourceSetPoints := NULL;

            IF _powerSources[id] = NULL THEN
                error := WeldSystemOrchestratorErrorCode#PowerSourceNotAvailable;
                RETURN;
            ELSIF NOT _connectedPowerSources[id] THEN
                error := WeldSystemOrchestratorErrorCode#PowerSourceNotConnected;
                RETURN;
            END_IF;

            IF active THEN
                GetPowerSourceSetPoints := _powerSources[id].ActiveArea();
            ELSE
                GetPowerSourceSetPoints := _powerSources[id].PassiveArea();
            END_IF;
        END_METHOD

        METHOD PUBLIC SetStartMode
            VAR_INPUT
                startMode : StartType;
            END_VAR

            _startMode := startMode;
        END_METHOD

        METHOD PUBLIC GetHeadTorchIndex : INT
            ;
        END_METHOD

        METHOD PUBLIC GetNextEnabledPowerSource : INT
            VAR_INPUT
                index : INT;
            END_VAR

            ;
        END_METHOD

        METHOD PUBLIC StartWelding
            VAR_INPUT
                index : INT;
            END_VAR

            IF THIS.IsConnected(index) THEN
                _powerSources[index].Start();
            END_IF;
        END_METHOD

        METHOD PUBLIC StopWelding
            VAR_INPUT
                index : INT;
            END_VAR

            IF THIS.IsConnected(index) THEN
                _powerSources[index].Stop();
            END_IF;
        END_METHOD

        METHOD PUBLIC IsWelding : BOOL
            VAR_TEMP
                index : INT := 1;
                atleastOnePowerSourcePresent : BOOL := FALSE;
            END_VAR

            FOR index := 1 TO MAX_NUMBER_OF_POWER_SOURCES DO
                IF _hardwareConfiguration^.ConnectedPowerSources[index] THEN
                    IF _powerSources[index] <> NULL AND _connectedPowerSources[index] THEN
                        IF NOT _powerSources[index].IsWelding() THEN
                            IsWelding := FALSE;
                            RETURN;
                        END_IF;
                    ELSE
                        IsWelding := FALSE;
                        RETURN;
                    END_IF;
                    atleastOnePowerSourcePresent := TRUE;
                END_IF;
            END_FOR;

            IsWelding := atleastOnePowerSourcePresent;
        END_METHOD

        METHOD PUBLIC IsWelding : BOOL
            VAR_INPUT
                index : INT;
            END_VAR

            IsWelding := FALSE;

            IF THIS.IsConnected(index) THEN
                IsWelding := _powerSources[index].IsWelding();
            END_IF;
        END_METHOD

        METHOD PUBLIC ReadyToWeld : BOOL
            VAR_TEMP
                index : INT := 1;
                atleastOnePowerSourcePresent : BOOL := FALSE;
            END_VAR

            FOR index := 1 TO MAX_NUMBER_OF_POWER_SOURCES DO
                IF _hardwareConfiguration^.ConnectedPowerSources[index] THEN
                    IF _powerSources[index] = NULL OR NOT _connectedPowerSources[index] THEN
                        IF NOT _powerSources[index].IsReadyToStart() THEN
                            ReadyToWeld := FALSE;
                            RETURN;
                        END_IF;
                    ELSE
                        ReadyToWeld := FALSE;
                        RETURN;
                    END_IF;
                    atleastOnePowerSourcePresent := TRUE;
                END_IF;
            END_FOR;

            ReadyToWeld := atleastOnePowerSourcePresent;
        END_METHOD

        METHOD PUBLIC WireOffset : LREAL
            VAR_INPUT
                index : INT;
            END_VAR

            IF index < 1 OR index > MAX_NUMBER_OF_POWER_SOURCES THEN
                WireOffset := -1.0;
                RETURN;
            END_IF;

            WireOffset := _hardwareConfiguration^.WireOffsets[index];
        END_METHOD

        METHOD PRIVATE HandleRemoteStart
            VAR_TEMP
                index : INT := 1;
            END_VAR

            FOR index := 1 TO MAX_NUMBER_OF_POWER_SOURCES DO
                IF _hardwareConfiguration^.ConnectedPowerSources[index] AND _powerSources[index] <> NULL THEN
                    IF NOT _powerSources[index].IsConnected() THEN
                        _powerSources[index].RemoteStart();
                    END_IF;
                ELSIF NOT _hardwareConfiguration^.ConnectedPowerSources[index] AND _powerSources[index] <> NULL THEN
                    IF NOT _powerSources[index].IsConnected() THEN
                        _powerSources[index].RemoteStop();
                    END_IF;
                END_IF;
            END_FOR;
        END_METHOD

        METHOD PRIVATE UpdateState
            VAR_TEMP
                nextState : WeldSystemOrchestratorState;
            END_VAR

            IF NOT THIS.PowerSourcesOk() THEN
                _currentState := WeldSystemOrchestratorState#Error;
            END_IF;

            nextState := _currentState;

            CASE _currentState OF
                WeldSystemOrchestratorState#Error:
                    ;
                WeldSystemOrchestratorState#Idle:
                    IF _startWeld THEN
                        nextState := WeldSystemOrchestratorState#Start;
                    END_IF;
                WeldSystemOrchestratorState#Start:
                    IF _stopWeld THEN
                        nextState := WeldSystemOrchestratorState#Stop;
                    END_IF;
                WeldSystemOrchestratorState#Welding:
                    IF _stopWeld THEN
                        nextState := WeldSystemOrchestratorState#Stop;
                    END_IF;
                WeldSystemOrchestratorState#Stop:
                    IF _stopWeld THEN
                        ; // Quick stop
                    END_IF;
            END_CASE;

            _startWeld := FALSE;
            _stopWeld := FALSE;

            _lastState := _currentState;
            _currentState := nextState;
        END_METHOD

        METHOD PRIVATE RequestAndLockConnectedPowerSources : BOOL
            VAR_TEMP
                index : INT := 1;
                asset : REF_TO Asset;
            END_VAR

            IF _setupAlarm.IsActive() THEN
                RETURN;
            END_IF;

            FOR index := 1 TO MAX_NUMBER_OF_POWER_SOURCES DO
                IF _powerSources[index] = NULL AND _hardwareConfiguration^.ConnectedPowerSources[index] THEN
                    asset := _assetsManager.RequestAssetHandle(THIS, Esab.AssetIdentifier#PowerSource1 - 1 + index);
                    IF asset <> NULL THEN
                        _powerSources[index] ?= asset^;
                        _powerSources[index].SetListener(THIS);
                        _powerSources[index].SetTravelMotorDrive(TravelMotorDrive#External);
                        _powerSources[index].SetStartType(StartType#Direct);
                    ELSE
                        RequestAndLockConnectedPowerSources := FALSE;
                        RETURN;
                    END_IF;
                END_IF;
            END_FOR;

            THIS.LockPowerSources();
            RequestAndLockConnectedPowerSources := TRUE;
        END_METHOD

        METHOD PRIVATE LockPowerSources
            VAR_TEMP
                index : INT := 1;
                asset : REF_TO Asset;
            END_VAR

            FOR index := 1 TO MAX_NUMBER_OF_POWER_SOURCES DO
                IF _powerSources[index] <> NULL THEN
                    asset ?= _powerSources[index];
                    asset^.Lock();
                END_IF;
            END_FOR;
        END_METHOD

        METHOD PRIVATE UnlockPowerSources
            VAR_TEMP
                index : INT := 1;
                asset : REF_TO Asset;
            END_VAR

            FOR index := 1 TO MAX_NUMBER_OF_POWER_SOURCES DO
                IF _powerSources[index] <> NULL THEN
                    asset ?= _powerSources[index];
                    asset^.Unlock();
                END_IF;
            END_FOR;
        END_METHOD

        METHOD PRIVATE IsInControl : BOOL
            VAR_TEMP
                index : INT := 1;
            END_VAR

            FOR index := 1 TO MAX_NUMBER_OF_POWER_SOURCES DO
                IF _hardwareConfiguration^.ConnectedPowerSources[index] AND _powerSources[index] = NULL THEN
                    IsInControl := FALSE;
                    RETURN;
                END_IF;
            END_FOR;
        END_METHOD

        METHOD PRIVATE ConfigurePowerSources
            VAR_TEMP
                head : BOOL := TRUE;
                index : INT := 1;
            END_VAR

            // We assume that the power sources are arranged in numerical order according to the weld direction, 1 being the first torch.
            FOR index := 1 TO MAX_NUMBER_OF_POWER_SOURCES DO
                IF _powerSources[index] <> NULL AND _runtimeParameters^.EnabledPowerSources[index] THEN
                    IF head THEN
                        _powerSources[index].SetTravelControl(TravelControl#Enabled);
                        _powerSources[index].SetTandemRole(TandemRole#Head);

                        head := FALSE;
                    ELSE
                        _powerSources[index].SetTravelControl(TravelControl#Off);
                        _powerSources[index].SetTandemRole(TandemRole#Slave);
                    END_IF;
                END_IF;
            END_FOR;
        END_METHOD

        METHOD PRIVATE ResolveAcSyncMaster
            ;
        END_METHOD

        METHOD PRIVATE PowerSourcesOk : BOOL
            VAR_TEMP
                index : INT := 1;
                atleastOnePowerSourcePresent : BOOL := FALSE;
            END_VAR

            FOR index := 1 TO MAX_NUMBER_OF_POWER_SOURCES DO
                IF _hardwareConfiguration^.ConnectedPowerSources[index] THEN
                    IF _powerSources[index] = NULL OR NOT _connectedPowerSources[index] THEN
                        PowerSourcesOk := FALSE;
                        RETURN;
                    END_IF;
                    atleastOnePowerSourcePresent := TRUE;
                END_IF;
            END_FOR;

            PowerSourcesOk := atleastOnePowerSourcePresent;
        END_METHOD

        METHOD PRIVATE IsConnected : BOOL
            VAR_INPUT
                index : INT;
            END_VAR

            IsConnected := FALSE;

            IF _hardwareConfiguration^.ConnectedPowerSources[index] THEN
                IsConnected := _connectedPowerSources[index] AND _powerSources[index] <> NULL;
            END_IF;
        END_METHOD

        METHOD PRIVATE IsConnectedAndReady : BOOL
            VAR_INPUT
                index : INT;
            END_VAR

            IsConnectedAndReady := FALSE;

            IF THIS.IsConnected(index) THEN
                IsConnectedAndReady := _powerSources[index].IsReadyToStart();
            END_IF;
        END_METHOD
    END_CLASS

    /// NOTE: The capacities of the arrays below MUST be changed accordingly if the MAX_NUMBER_OF_POWER_SOURCES of the above class is increased.
    TYPE
        WeldSystemOrchestratorRuntimeParameters : STRUCT
            EnabledPowerSources : ARRAY [1..3] OF BOOL;
            PowerSourceStartTimeout : LTIME := LT#60s;
        END_STRUCT;

        WeldSystemOrchestratorHardwareConfiguration : STRUCT
            WireOffsets : ARRAY [2..3] OF LREAL;
            ConnectedPowerSources : ARRAY [1..3] OF BOOL;
        END_STRUCT;

        WeldSystemOrchestratorErrorCode : INT(
            NoError := 0,
            PowerSourceNotAvailable := 1,
            PowerSourceNotConnected := 2,
            WeldAxisMissing := 3
        );

        WeldSystemOrchestratorState : INT(
            Error := -1,
            Idle := 0,
            Start := 1,
            Welding := 2,
            Stop := 3
        );
    END_TYPE


END_NAMESPACE
