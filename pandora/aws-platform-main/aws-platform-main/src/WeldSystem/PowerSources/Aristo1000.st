USING Esab.Api;
USING Esab.Utils.Alarming;
USING Esab.Utils;
USING Esab.Utils.Assets;
USING Esab.WeldSystem.PowerSources;
USING Esab.Utils.Alarming;
USING Siemens.Simatic.S71500.Alarming;
USING Siemens.Simatic.S71500.DistributedIO;

NAMESPACE Esab.WeldSystem.PowerSources.Aristo1000

    /// This class implements an Aristo 1000 power source
    CLASS PowerSource EXTENDS Asset IMPLEMENTS IPowerSource, IAsyncCommandListener
        VAR PRIVATE
            _id : UINT;
            _ioDeviceId : WORD;
            _heartbeat: IHeartBeat;
            _io : REF_TO Io;
            _runtimeParameters : REF_TO RuntimeParameters;
            _hardwareConfiguration : REF_TO HardwareConfiguration;
            _asyncInterface : IAsyncInterface;
            _asyncCommands : AsyncCommands;
            _errorAlarm : IAlarm;
            _heartbeatAlarm : IAlarm;
            _asyncCommandReadAlarm : IAlarm;
            _asyncCommandWriteAlarm : IAlarm;
            _asyncCommandNullAlarm : IAlarm;

            _readingNodes : BOOL := FALSE;
            _currentlyReadingNodeId : UINT := UINT#0;
            _nodeInformation : ARRAY [1..31] OF NodeInformation;
            _observable : PowerSourceObservable;
            _listener : IPowerSourceListener := NULL;
            _isConnected : BOOL := FALSE;

            _nodeId : UINT := UINT#0;
            _weldSystemType : WeldSystemType;
            _travelControl : TravelControl;
            _travelMotorDrive : TravelMotorDrive;
            _tandemRole : TandemRole;
            _inputAreaSwitch : BOOL := FALSE; // Area 2 is active if True
            _inputArea : ARRAY [1..2] OF SetPoints;

            // Commands used when reading/writing custom records
            _writeUIntAsyncCommand : UIntAsyncCommand;
            _readUIntAsyncCommand : UIntAsyncCommand;

            _highSpeed : BOOL := FALSE;
            _wireFeedJogPos : BOOL := FALSE;
            _wireFeedJogNeg : BOOL := FALSE;
            _travelAxisJogPos : BOOL := FALSE;
            _travelAxisJogNeg : BOOL := FALSE;
        END_VAR

        METHOD PUBLIC Setup
            VAR_INPUT
                id : UINT;
                ioDeviceId : WORD;
                heartbeat: IHeartBeat;
                io : REF_TO Io;
                runtimeParameters : REF_TO RuntimeParameters;
                hardwareConfiguration : REF_TO HardwareConfiguration;
                asyncInterface : IAsyncInterface;
                errorAlarm : IAlarm;
                heartbeatAlarm : IAlarm;
                asyncCommandReadAlarm : IAlarm;
                asyncCommandWriteAlarm : IAlarm;
                asyncCommandNullAlarm : IAlarm;
                setupAlarm : IAlarm;
            END_VAR

            _id := id;
            _ioDeviceId := ioDeviceId;
            _heartbeat := heartbeat;
            _io := io;
            _runtimeParameters := runtimeParameters;
            _hardwareConfiguration := hardwareConfiguration;
            _asyncInterface := asyncInterface;
            _asyncInterface.SetListener(THIS);
            _errorAlarm := errorAlarm;
            _heartbeatAlarm := heartbeatAlarm;
            _asyncCommandReadAlarm := asyncCommandReadAlarm;
            _asyncCommandWriteAlarm := asyncCommandWriteAlarm;
            _asyncCommandNullAlarm := asyncCommandNullAlarm;
            _setupAlarm := setupAlarm;

            _isSetup := _io <> NULL AND
                        _heartbeat <> NULL AND
                        _runtimeParameters <> NULL AND
                        _hardwareConfiguration <> NULL AND
                        _errorAlarm <> NULL AND
                        _heartbeatAlarm <> NULL AND
                        _asyncCommandReadAlarm <> NULL AND
                        _asyncCommandWriteAlarm <> NULL AND
                        _asyncCommandNullAlarm <> NULL;

            IF _isSetup THEN
                THIS.WriteAsync(DataRecord#WireJogLowSpeed, _runtimeParameters^.WireFeedJogSpeed);
                THIS.WriteAsync(DataRecord#WireJogHighSpeed, _runtimeParameters^.WireFeedJogHighSpeed);
            END_IF;
        END_METHOD

        METHOD PUBLIC OVERRIDE Execute
            SUPER.Execute();

            IF _setupAlarm.IsActive() THEN
                RETURN;
            END_IF;

            _heartbeat.Execute();

            _heartbeatAlarm.Execute(SIG := _heartbeat.Dead());

            IF _heartbeat.Dead() THEN
                IF _isConnected AND _listener <> NULL THEN
                    _listener.PowerSourceDisconnected(THIS.GetId());
                END_IF;

                RETURN;
            ELSIF NOT _isConnected AND _listener <> NULL THEN
                THIS.ReadNodes();
                _listener.PowerSourceConnected(THIS.GetId());
            END_IF;

            _isConnected := _heartbeat.Alive();

            THIS.SetHeartbeat(THIS.GetHeartbeat());

            _errorAlarm.Execute(SIG := _io^.Pab.Input.Error.GetValue());

            _io^.Pab.Output.Common.HighSpeed.SetValue(_highSpeed);
            _io^.Pab.Output.Common.WireFeedJogPos.SetValue(_wireFeedJogPos);
            _io^.Pab.Output.Common.WireFeedJogNeg.SetValue(_wireFeedJogNeg);
            _io^.Pab.Output.Common.TravelAxisJogPos.SetValue(_travelAxisJogPos);
            _io^.Pab.Output.Common.TravelAxisJogNeg.SetValue(_travelAxisJogNeg);

            _highSpeed := FALSE;
            _wireFeedJogPos := FALSE;
            _wireFeedJogNeg := FALSE;
            _travelAxisJogPos := FALSE;
            _travelAxisJogNeg := FALSE;

            IF _io^.Pab.Input.Welding.FallingEdge() THEN
                THIS.Stop();
            END_IF;

            _asyncInterface.Execute();

            THIS.UpdateObservable();
            THIS.UpdateSetpoints();
        END_METHOD

        METHOD PUBLIC OVERRIDE UpdateState
            IF _setupAlarm.IsActive() THEN
                _currentState := PowerSourceState#Error;
            ELSIF NOT THIS.IsConnected() THEN
                _currentState := PowerSourceState#NotConnected;
            ELSIF THIS.IsWelding() THEN
                _currentState := PowerSourceState#Welding;
            ELSIF _errorAlarm.IsActive() OR _asyncCommandReadAlarm.IsActive() OR _asyncCommandWriteAlarm.IsActive() OR _asyncCommandNullAlarm.IsActive() THEN
                _currentState := PowerSourceState#Error;
            ELSE
                _currentState := PowerSourceState#Idle;
            END_IF;
        END_METHOD

        METHOD PUBLIC SetListener
            VAR_INPUT
                listener : IPowerSourceListener;
            END_VAR

            _listener := listener;
        END_METHOD

        METHOD PUBLIC Start
            _io^.Pab.Output.Common.WeldOn.SetValue(TRUE);
        END_METHOD

        METHOD PUBLIC Stop
            _io^.Pab.Output.Common.WeldOn.SetValue(FALSE);
        END_METHOD

        METHOD PUBLIC QuickStop
            _io^.Pab.Output.Common.WeldOn.SetValue(FALSE);
            _io^.Pab.Output.Common.QuickStop.SetValue(TRUE);
        END_METHOD

        METHOD PUBLIC RemoteStart
            _io^.Output.RemoteStart.SetValue(TRUE);
        END_METHOD

        METHOD PUBLIC RemoteStop
            _io^.Output.RemoteStart.SetValue(FALSE);
        END_METHOD

        METHOD PUBLIC ActiveArea : REF_TO SetPoints
            IF NOT _inputAreaSwitch THEN
                ActiveArea := REF(_inputArea[1]);
            ELSE
                ActiveArea := REF(_inputArea[2]);
            END_IF;
        END_METHOD

        METHOD PUBLIC PassiveArea : REF_TO SetPoints
            IF NOT _inputAreaSwitch THEN
                PassiveArea := REF(_inputArea[2]);
            ELSE
                PassiveArea := REF(_inputArea[1]);
            END_IF;
        END_METHOD

        METHOD PUBLIC SwitchActivePassive
            _inputAreaSwitch := NOT _inputAreaSwitch;
            _io^.Pab.Output.Common.InputAreaSwitch.SetValue(_inputAreaSwitch);
        END_METHOD

        METHOD PUBLIC IsWelding : BOOL
            IsWelding := _io^.Pab.Input.Welding.GetValue() OR _io^.Pab.Input.WeldStarted.GetValue();
        END_METHOD

        METHOD PUBLIC IsConnected : BOOL
            IsConnected := _heartbeat.Alive();
        END_METHOD

        METHOD PUBLIC IsReadyToStart : BOOL
            IsReadyToStart := _io^.Pab.Input.ReadyToStart.GetValue();
        END_METHOD

        METHOD PUBLIC HasError : BOOL
            HasError := _io^.Pab.Input.Error.GetValue();
        END_METHOD

        METHOD PUBLIC SetTravelControl
            VAR_INPUT
                control : TravelControl;
            END_VAR

            _travelControl := control;
            _asyncCommands.TravelControl.Value := TO_UINT(control);

            _asyncInterface.WriteCommand(REF(_asyncCommands.TravelControl));
        END_METHOD

        METHOD PUBLIC SetTravelMotorDrive
            VAR_INPUT
                drive : TravelMotorDrive;
            END_VAR

            _travelMotorDrive := drive;
            _asyncCommands.TravelMotorDrive.Value := TO_UINT(drive);

            _asyncInterface.WriteCommand(REF(_asyncCommands.TravelMotorDrive));
        END_METHOD

        METHOD PUBLIC SetTandemRole
            VAR_INPUT
                role : TandemRole;
            END_VAR

            _tandemRole := role;
            _asyncCommands.TandemRole.Value := TO_UINT(role);

            _asyncInterface.WriteCommand(REF(_asyncCommands.TandemRole));
        END_METHOD

        METHOD PUBLIC SetStartType
            VAR_INPUT
                startType : StartType;
            END_VAR

            _asyncCommands.StartType.Value := TO_UINT(startType);

            _asyncInterface.WriteCommand(REF(_asyncCommands.StartType));
        END_METHOD

        METHOD PUBLIC SetWireFeedJogSpeed
            VAR_INPUT
                speed : UINT;
            END_VAR

            _asyncCommands.JogWireFeedSpeed.Value := speed;
            _asyncInterface.WriteCommand(REF(_asyncCommands.JogWireFeedSpeed));
        END_METHOD

        METHOD PUBLIC SetWireFeedJogHighSpeed
            VAR_INPUT
                speed : UINT;
            END_VAR

            _asyncCommands.JogWireFeedHighSpeed.Value := speed;
            _asyncInterface.WriteCommand(REF(_asyncCommands.JogWireFeedHighSpeed));
        END_METHOD

        METHOD PUBLIC GetId : UINT
            GetId := _id;
        END_METHOD

        METHOD PUBLIC GetNodeId : UINT
            GetNodeId := _nodeId;
        END_METHOD

        METHOD PUBLIC GetWeldSystemType : WeldSystemType
            GetWeldSystemType := _weldSystemType;
        END_METHOD

        METHOD PUBLIC GetTravelControl : TravelControl
            GetTravelControl := _travelControl;
        END_METHOD

        METHOD PUBLIC GetTravelMotorDrive : TravelMotorDrive
            GetTravelMotorDrive := _travelMotorDrive;
        END_METHOD

        METHOD PUBLIC GetTandemRole : TandemRole
            GetTandemRole := _tandemRole;
        END_METHOD

        METHOD PUBLIC GetMeasuredVoltage : REAL
            GetMeasuredVoltage := _io^.Pab.Input.MeasuredVoltage.GetValue();
        END_METHOD

        METHOD PUBLIC GetMeasuredCurrent : UINT
            GetMeasuredCurrent := _io^.Pab.Input.MeasuredCurrent.GetValue();
        END_METHOD

        METHOD PUBLIC GetMeasuredWireSpeed : INT
            GetMeasuredWireSpeed := _io^.Pab.Input.MeasuredWireSpeed.GetValue();
        END_METHOD

        METHOD PUBLIC GetMeasuredTravelSpeed : INT
            GetMeasuredTravelSpeed := _io^.Pab.Input.MeasuredTravelSpeed.GetValue();
        END_METHOD

        METHOD PUBLIC GetMeasuredHeatInput : REAL
            GetMeasuredHeatInput := _io^.Pab.Input.MeasuredHeatInput.GetValue();
        END_METHOD

        METHOD PUBLIC GetWeldDataSet : UINT
            GetWeldDataSet := _io^.Pab.Input.SetWeldDataSet.GetValue();
        END_METHOD

        METHOD PUBLIC GetRequestedTravelSpeed : INT
            GetRequestedTravelSpeed := _io^.Pab.Input.RequestedTravelSpeed.GetValue();
        END_METHOD

        METHOD PUBLIC GetRequestedWireSpeed : INT
            GetRequestedWireSpeed := _io^.Pab.Input.RequestedWireSpeed.GetValue();
        END_METHOD

        METHOD PUBLIC WireFeedJogPos
            VAR_INPUT
                highSpeed : BOOL;
            END_VAR

            _highSpeed := highSpeed;
            _wireFeedJogPos := TRUE;
        END_METHOD

        METHOD PUBLIC WireFeedJogNeg
            VAR_INPUT
                highSpeed : BOOL;
            END_VAR

            _highSpeed := highSpeed;
            _wireFeedJogNeg := TRUE;
        END_METHOD

        METHOD PUBLIC TravelAxisJogPos
            VAR_INPUT
                highSpeed : BOOL;
            END_VAR

            _highSpeed := highSpeed;
            _travelAxisJogPos := TRUE;
        END_METHOD

        METHOD PUBLIC TravelAxisJogNeg
            VAR_INPUT
                highSpeed : BOOL;
            END_VAR

            _highSpeed := highSpeed;
            _travelAxisJogNeg := TRUE;
        END_METHOD

        METHOD PUBLIC ReadNodes
            IF _readingNodes = FALSE THEN
                _readingNodes := TRUE;
                _asyncInterface.ReadCommand(REF(_asyncCommands.ConnectedUnits));
            END_IF;
        END_METHOD

        METHOD PUBLIC NodeIsConnected : BOOL
            VAR_INPUT
                nodeId : UINT;
            END_VAR

            NodeIsConnected := _nodeInformation[nodeId].Connected;
        END_METHOD

        METHOD PUBLIC GetNodeInformation : NodeInformation
            VAR_INPUT
                nodeId : UINT;
            END_VAR

            GetNodeInformation := _nodeInformation[nodeId];
        END_METHOD

        METHOD PUBLIC ApplyWireMotorConfiguration : BOOL
            VAR_INPUT
                motorConfiguration : REF_TO MotorConfiguration;
            END_VAR

            VAR_TEMP
                _scaleFactor1 : UINT;
                _scaleFactor2 : UINT;
            END_VAR

            IF motorConfiguration = NULL THEN
                ApplyWireMotorConfiguration := FALSE;
                RETURN;
            END_IF;

            IF NOT THIS.IsWelding() THEN
                CalculateMotorScaleFactors(motorConfiguration, _scaleFactor1, _scaleFactor2);

                _asyncCommands.WireMotorScaleFactor1.Value := _scaleFactor1;
                _asyncInterface.WriteCommand(REF(_asyncCommands.WireMotorScaleFactor1));

                _asyncCommands.WireMotorScaleFactor2.Value := _scaleFactor2;
                _asyncInterface.WriteCommand(REF(_asyncCommands.WireMotorScaleFactor2));

                _asyncCommands.MaxWireMotorCurrent.Value := motorConfiguration^.MaxCurrent;
                _asyncInterface.WriteCommand(REF(_asyncCommands.MaxWireMotorCurrent));
            ELSE
                ApplyWireMotorConfiguration := FALSE;
                RETURN;
            END_IF;

            ApplyWireMotorConfiguration := TRUE;
        END_METHOD

        METHOD PUBLIC WriteAsync
            VAR_INPUT
                record : DataRecord;
                value : UINT;
            END_VAR

            _writeUIntAsyncCommand.Index := record;
            _writeUIntAsyncCommand.Value := value;
            _asyncInterface.WriteCommand(REF(_writeUIntAsyncCommand));
        END_METHOD

        METHOD PUBLIC WriteAsync
            VAR_INPUT
                command: REF_TO UIntAsyncCommand;
            END_VAR

            _asyncInterface.WriteCommand(command);
        END_METHOD

        METHOD PUBLIC ReadAsync
            VAR_INPUT
                record : DataRecord;
            END_VAR

            _readUIntAsyncCommand.Index := record;
            _asyncInterface.ReadCommand(REF(_readUIntAsyncCommand));
        END_METHOD

        // For extrernal callers
        METHOD PUBLIC ReadAsync
            VAR_INPUT
                command: REF_TO UIntAsyncCommand;
            END_VAR
            _asyncInterface.ReadCommand(command);
        END_METHOD

        METHOD PUBLIC AsyncCommandCallback
            VAR_INPUT
                command : REF_TO AsyncCommand;
                status : CommandStatus;
            END_VAR

            VAR_TEMP
                _uintCommand : REF_TO UIntAsyncCommand;
                _udintCommand : REF_TO UDIntAsyncCommand;
                _nodeInfoCommand : REF_TO NodeInformationAsyncCommand;

                _index : UINT := UINT#0;
            END_VAR

            _asyncCommandNullAlarm.Execute(SIG := command = NULL);

            IF command = NULL THEN
                RETURN;
            END_IF;

            _asyncCommandReadAlarm.Execute(SIG := command^.GetType() = CommandType#Read && status = CommandStatus#Error, SD_1 := pass(command^.GetIndex()));
            _asyncCommandWriteAlarm.Execute(SIG := command^.GetType() = CommandType#Write && status = CommandStatus#Error, SD_1 := pass(command^.GetIndex()));

            IF command^.GetType() = CommandType#Write AND status = CommandStatus#Success THEN
                _asyncInterface.ReadCommand(command);
            ELSIF command^.GetType() = CommandType#Read THEN
                _uintCommand ?= command;
                _udintCommand ?= command;
                _nodeInfoCommand ?= command;

                CASE command^.Index OF
                    DataRecord#TravelControl:
                        IF _uintCommand <> NULL AND status = CommandStatus#Success THEN
                            _travelControl := TO_INT(_uintCommand^.Value);
                        END_IF;
                    DataRecord#TravelMotorDrive:
                        IF _uintCommand <> NULL AND status = CommandStatus#Success THEN
                            _travelMotorDrive := TO_INT(_uintCommand^.Value);
                        END_IF;
                    DataRecord#TandemRole:
                        IF _uintCommand <> NULL AND status = CommandStatus#Success THEN
                            _tandemRole := TO_INT(_uintCommand^.Value);
                        END_IF;
                    DataRecord#ConnectedUnits:
                        IF _udintCommand <> NULL AND status = CommandStatus#Success THEN
                            FOR _index := 1 TO UINT#31 DO
                                _nodeInformation[_index].Connected := ((SHR(TO_DWORD(_udintCommand^.Value), _index) & DWORD#1) <> DWORD#0);
                            END_FOR;

                            // This will kick off the reading of all nodes information
                            THIS.ReadNextConnectedNode();
                        END_IF;
                    DataRecord#NodeInformation:
                        IF _nodeInfoCommand <> NULL AND status = CommandStatus#Success THEN
                            _nodeInformation[_nodeInfoCommand^.Id].Version := _nodeInfoCommand^.Value.Version;
                            _nodeInformation[_nodeInfoCommand^.Id].SubVersion := _nodeInfoCommand^.Value.SubVersion;
                            _nodeInformation[_nodeInfoCommand^.Id].DeviceType := _nodeInfoCommand^.Value.DeviceType;
                            _nodeInformation[_nodeInfoCommand^.Id].MachineId := _nodeInfoCommand^.Value.MachineId;
                            IF _readingNodes THEN
                                THIS.ReadNextConnectedNode();
                            END_IF;
                        ELSE
                            THIS.CancelNodeReading();
                        END_IF;
                    DataRecord#Can2NodeId:
                        IF _uintCommand <> NULL THEN
                            _nodeId := _uintCommand^.Value;
                        END_IF;
                    DataRecord#GetWeldingSystem:
                        IF _uintCommand <> NULL THEN
                            _weldSystemType := _uintCommand^.Value;
                        END_IF;
                    DataRecord#WireJogLowSpeed:
                        if _uintCommand <> NULL THEN
                            IF _runtimeParameters <> NULL THEN
                                _runtimeParameters^.WireFeedJogSpeed := _uintCommand^.Value;
                            END_IF;
                        END_IF;
                    DataRecord#WireJogHighSpeed:
                        if _uintCommand <> NULL THEN
                            IF _runtimeParameters <> NULL THEN
                                _runtimeParameters^.WireFeedJogHighSpeed := _uintCommand^.Value;
                            END_IF;
                        END_IF;
                END_CASE;
            END_IF;
        END_METHOD

        METHOD PUBLIC OVERRIDE Observe : IAssetObservable
            Observe := _observable;
        END_METHOD

        METHOD PRIVATE SetHeartbeat
            VAR_INPUT
                value : UINT;
            END_VAR

            _io^.Pab.Output.Common.Heartbeat.SetValue(value);
        END_METHOD

        METHOD PRIVATE GetHeartbeat : UINT
            GetHeartbeat := _io^.Pab.Input.Heartbeat.GetValue();
        END_METHOD

        METHOD PRIVATE ReadNextConnectedNode
            VAR_TEMP
                isConnected : BOOL := FALSE;
            END_VAR

            _currentlyReadingNodeId := _currentlyReadingNodeId + UINT#1;

            WHILE _currentlyReadingNodeId <= UINT#31 AND NOT isConnected DO
                isConnected := _nodeInformation[_currentlyReadingNodeId].Connected;
                IF NOT isConnected THEN
                    _currentlyReadingNodeId := _currentlyReadingNodeId + UINT#1;
                END_IF;
            END_WHILE;

            IF _currentlyReadingNodeId <= UINT#31 THEN
                _asyncCommands.NodeInformation.Id := _currentlyReadingNodeId;
                _asyncInterface.WriteCommand(REF(_asyncCommands.NodeInformation));
            ELSE
                THIS.CancelNodeReading();
            END_IF;
        END_METHOD

        METHOD PRIVATE CancelNodeReading
            _currentlyReadingNodeId := UINT#0;
            _readingNodes := FALSE;
        END_METHOD

        METHOD PRIVATE UpdateObservable
            _observable.State := _currentState;
            _observable.ReadyToStart := THIS.IsReadyToStart();
            _observable.Error := THIS.HasError();
            _observable.Welding := THIS.IsWelding();
            _observable.Connected := THIS.IsConnected();
            _observable.MeasuredVoltage := THIS.GetMeasuredVoltage();
            _observable.MeasuredCurrent := THIS.GetMeasuredCurrent();
            _observable.MeasuredWireSpeed := THIS.GetMeasuredWireSpeed();
            _observable.MeasuredTravelSpeed := THIS.GetMeasuredTravelSpeed();
            _observable.MeasuredHeatInput := THIS.GetMeasuredHeatInput();
            _observable.RequestedWireSpeed := THIS.GetRequestedWireSpeed();
            _observable.RequestedTravelSpeed := THIS.GetRequestedTravelSpeed();
            _observable.SetPoints.Voltage := _io^.Pab.Input.SetVoltage.GetValue();
            _observable.SetPoints.Current := _io^.Pab.Input.SetCurrent.GetValue();
            _observable.SetPoints.WireSpeed := _io^.Pab.Input.SetWireSpeed.GetValue();
            _observable.SetPoints.TravelSpeed := _io^.Pab.Input.SetTravelSpeed.GetValue();
            _observable.SetPoints.AcFrequency := _io^.Pab.Input.SetAcFrequency.GetValue();
            _observable.SetPoints.AcBalance := _io^.Pab.Input.SetAcBalance.GetValue();
            _observable.SetPoints.AcOffset := _io^.Pab.Input.SetAcOffset.GetValue();
            _observable.SetPoints.AcPhaseShift := _io^.Pab.Input.SetAcPhaseShift.GetValue();
            _observable.SetPoints.WeldMethod := TO_BYTE(_io^.Pab.Input.SetWeldMethod.GetValue());
            _observable.SetPoints.RegulationType := TO_BYTE(_io^.Pab.Input.SetRegulationType.GetValue());
            _observable.SetPoints.StartAdjust := _io^.Pab.Input.SetStartAdjust.GetValue();
            _observable.SetPoints.RegulationDynamics := _io^.Pab.Input.SetRegulationDynamics.GetValue();
            _observable.SetPoints.RegulationInductance := _io^.Pab.Input.SetRegulationInductance.GetValue();
            // _observable.SetPoints.IceWireSpeedPercentage := _io^.Pab.Input.SetIceWireSpeedPercentage.GetValue(); // Not available
        END_METHOD

        METHOD PRIVATE UpdateSetpoints
            VAR_TEMP
                area1 : REF_TO SetPoints;
                area2 : REF_TO SetPoints;
            END_VAR

            IF NOT _inputAreaSwitch THEN
                area1 := THIS.ActiveArea();
                area2 := THIS.PassiveArea();
            ELSE
                area1 := THIS.PassiveArea();
                area2 := THIS.ActiveArea();
            END_IF;

            _io^.Pab.Output.InputArea[1].Voltage.SetValue(area1^.Voltage);
            _io^.Pab.Output.InputArea[1].Current.SetValue(area1^.Current);
            _io^.Pab.Output.InputArea[1].WireSpeed.SetValue(area1^.WireSpeed);
            _io^.Pab.Output.InputArea[1].TravelSpeed.SetValue(area1^.TravelSpeed);
            _io^.Pab.Output.InputArea[1].AcFrequency.SetValue(area1^.AcFrequency);
            _io^.Pab.Output.InputArea[1].AcBalance.SetValue(area1^.AcBalance);
            _io^.Pab.Output.InputArea[1].AcOffset.SetValue(area1^.AcOffset);
            _io^.Pab.Output.InputArea[1].AcPhaseShift.SetValue(area1^.AcPhaseShift);
            _io^.Pab.Output.InputArea[1].WeldMethod.SetValue(area1^.WeldMethod);
            _io^.Pab.Output.InputArea[1].RegulationType.SetValue(area1^.RegulationType);
            _io^.Pab.Output.InputArea[1].StartAdjust.SetValue(area1^.StartAdjust);
            _io^.Pab.Output.InputArea[1].RegulationDynamics.SetValue(area1^.RegulationDynamics);
            _io^.Pab.Output.InputArea[1].RegulationInductance.SetValue(area1^.RegulationInductance);
            _io^.Pab.Output.InputArea[1].IceWireSpeedPercentage.SetValue(area1^.IceWireSpeedPercentage);

            _io^.Pab.Output.InputArea[2].Voltage.SetValue(area2^.Voltage);
            _io^.Pab.Output.InputArea[2].Current.SetValue(area2^.Current);
            _io^.Pab.Output.InputArea[2].WireSpeed.SetValue(area2^.WireSpeed);
            _io^.Pab.Output.InputArea[2].TravelSpeed.SetValue(area2^.TravelSpeed);
            _io^.Pab.Output.InputArea[2].AcFrequency.SetValue(area2^.AcFrequency);
            _io^.Pab.Output.InputArea[2].AcBalance.SetValue(area2^.AcBalance);
            _io^.Pab.Output.InputArea[2].AcOffset.SetValue(area2^.AcOffset);
            _io^.Pab.Output.InputArea[2].AcPhaseShift.SetValue(area2^.AcPhaseShift);
            _io^.Pab.Output.InputArea[2].WeldMethod.SetValue(area2^.WeldMethod);
            _io^.Pab.Output.InputArea[2].RegulationType.SetValue(area2^.RegulationType);
            _io^.Pab.Output.InputArea[2].StartAdjust.SetValue(area2^.StartAdjust);
            _io^.Pab.Output.InputArea[2].RegulationDynamics.SetValue(area2^.RegulationDynamics);
            _io^.Pab.Output.InputArea[2].RegulationInductance.SetValue(area2^.RegulationInductance);
            _io^.Pab.Output.InputArea[2].IceWireSpeedPercentage.SetValue(area2^.IceWireSpeedPercentage);
        END_METHOD
    END_CLASS

END_NAMESPACE