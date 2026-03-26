USING Esab.Mock;
USING Esab.Utils.Assets;
USING Esab.Utils.Assets.Mock;

USING Esab.WeldSystem;

NAMESPACE Esab.WeldSystem.PowerSources.Mock

    CLASS Aristo1000Mock EXTENDS Asset IMPLEMENTS IPowerSource
        VAR PUBLIC
            SetListenerMock : PowerSourceListenerMethodMock;
            StartMock : MethodMock;
            StopMock : MethodMock;
            QuickStopMock : MethodMock;
            RemoteStartMock : MethodMock;
            RemoteStopMock : MethodMock;
            ActiveAreaMock : SetPointsRefMethodMock;
            PassiveAreaMock : SetPointsRefMethodMock;
            SwitchActivePassiveMock : MethodMock;
            SetTravelControlMock : TravelControlMethodMock;
            SetTravelMotorDriveMock : TravelMotorDriveMethodMock;
            SetTandemRoleMock : TandemRoleMethodMock;
            SetStartTypeMock : StartTypeMethodMock;
            SetWireFeedJogSpeedMock : UIntMethodMock;
            SetWireFeedJogHighSpeedMock : UIntMethodMock;
            ApplyWireMotorConfigurationMock : MethodMock;
            GetIdMock : UIntMethodMock;
            GetNodeIdMock : UIntMethodMock;
            GetWeldSystemTypeMock : WeldSystemTypeMethodMock;
            GetTravelControlMock : TravelControlMethodMock;
            GetTravelMotorDriveMock : TravelMotorDriveMethodMock;
            GetTandemRoleMock : TandemRoleMethodMock;
            IsWeldingMock : BoolMethodMock;
            IsConnectedMock : BoolMethodMock;
            IsReadyToStartMock : BoolMethodMock;
            HasErrorMock : BoolMethodMock;
            GetMeasuredVoltageMock : RealMethodMock;
            GetMeasuredWireSpeedMock : IntMethodMock;
            GetMeasuredTravelSpeedMock : IntMethodMock;
            GetMeasuredHeatInputMock : RealMethodMock;
            GetWeldDataSetMock : UIntMethodMock;
            GetRequestedTravelSpeedMock : IntMethodMock;
            GetRequestedWireSpeedMock : IntMethodMock;
            NodeIsConnectedMock : NodeIsConnectedMethodMock;
            GetNodeInformationMock : NodeInformationMethodMock;
            WireFeedJogPosMock : BoolMethodMock;
            WireFeedJogNegMock : BoolMethodMock;
            TravelAxisJogPosMock : BoolMethodMock;
            TravelAxisJogNegMock : BoolMethodMock;
            ReadNodesMock : MethodMock;
            WriteAsyncMock : WriteAsyncMock;
            WriteAsyncCmdMock : WriteAsyncCmdMock;
            ReadAsyncMock : ReadAsyncMock;
            ReadAsyncCmdMock : ReadAsyncCmdMock;
        END_VAR

        METHOD PUBLIC MockReset
            SetListenerMock.Reset();
            StartMock.Reset();
            StopMock.Reset();
            QuickStopMock.Reset();
            RemoteStartMock.Reset();
            RemoteStopMock.Reset();
            ActiveAreaMock.Reset();
            PassiveAreaMock.Reset();
            SwitchActivePassiveMock.Reset();
            SetTravelControlMock.Reset();
            SetTravelMotorDriveMock.Reset();
            SetTandemRoleMock.Reset();
            SetStartTypeMock.Reset();
            SetWireFeedJogSpeedMock.Reset();
            SetWireFeedJogHighSpeedMock.Reset();
            ApplyWireMotorConfigurationMock.Reset();
            GetIdMock.Reset();
            GetNodeIdMock.Reset();
            GetWeldSystemTypeMock.Reset();
            GetTravelControlMock.Reset();
            GetTravelMotorDriveMock.Reset();
            GetTandemRoleMock.Reset();
            IsWeldingMock.Reset();
            IsConnectedMock.Reset();
            IsReadyToStartMock.Reset();
            HasErrorMock.Reset();
            GetMeasuredVoltageMock.Reset();
            GetMeasuredWireSpeedMock.Reset();
            GetMeasuredTravelSpeedMock.Reset();
            GetMeasuredHeatInputMock.Reset();
            GetWeldDataSetMock.Reset();
            GetRequestedTravelSpeedMock.Reset();
            GetRequestedWireSpeedMock.Reset();
            NodeIsConnectedMock.Reset();
            GetNodeInformationMock.Reset();
            WireFeedJogPosMock.Reset();
            WireFeedJogNegMock.Reset();
            TravelAxisJogPosMock.Reset();
            TravelAxisJogNegMock.Reset();
            ReadNodesMock.Reset();
            WriteAsyncMock.Reset();
            WriteAsyncCmdMock.Reset();
            ReadAsyncMock.Reset();
            ReadAsyncCmdMock.Reset();
        END_METHOD

        METHOD PUBLIC SetListener
            VAR_INPUT
                listener : IPowerSourceListener;
            END_VAR

            SetListenerMock.IncrementCallCount();
            SetListenerMock.Value := listener;
        END_METHOD

        METHOD PUBLIC Start
            StartMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC Stop
            StopMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC QuickStop
            QuickStopMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC RemoteStart
            RemoteStartMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC RemoteStop
            RemoteStopMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC ActiveArea : REF_TO Esab.WeldSystem.PowerSources.SetPoints
            ActiveAreaMock.IncrementCallCount();
            ActiveArea := ActiveAreaMock.Value;
        END_METHOD

        METHOD PUBLIC PassiveArea : REF_TO Esab.WeldSystem.PowerSources.SetPoints
            PassiveAreaMock.IncrementCallCount();
            PassiveArea := PassiveAreaMock.Value;
        END_METHOD

        METHOD PUBLIC SwitchActivePassive
            SwitchActivePassiveMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC SetTravelControl
            VAR_INPUT
                control : TravelControl;
            END_VAR

            SetTravelControlMock.IncrementCallCount();
            SetTravelControlMock.Value := control;
        END_METHOD

        METHOD PUBLIC SetTravelMotorDrive
            VAR_INPUT
                drive : TravelMotorDrive;
            END_VAR

            SetTravelMotorDriveMock.IncrementCallCount();
            SetTravelMotorDriveMock.Value := drive;
        END_METHOD

        METHOD PUBLIC SetTandemRole
            VAR_INPUT
                role : TandemRole;
            END_VAR

            SetTandemRoleMock.IncrementCallCount();
            SetTandemRoleMock.Value := role;
        END_METHOD

        METHOD PUBLIC SetStartType
            VAR_INPUT
                startType : StartType;
            END_VAR

            SetStartTypeMock.IncrementCallCount();
            SetStartTypeMock.Value := startType;
        END_METHOD

        METHOD PUBLIC SetWireFeedJogSpeed
            VAR_INPUT
                speed : UINT;
            END_VAR

            SetWireFeedJogSpeedMock.IncrementCallCount();
            SetWireFeedJogSpeedMock.Value := speed;
        END_METHOD

        METHOD PUBLIC SetWireFeedJogHighSpeed
            VAR_INPUT
                speed : UINT;
            END_VAR

            SetWireFeedJogHighSpeedMock.IncrementCallCount();
            SetWireFeedJogHighSpeedMock.Value := speed;
        END_METHOD

        METHOD PUBLIC ApplyWireMotorConfiguration : BOOL
            VAR_INPUT
                motorConfiguration : REF_TO Esab.WeldSystem.PowerSources.MotorConfiguration;
            END_VAR

            ApplyWireMotorConfigurationMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC GetId : UINT
            GetIdMock.IncrementCallCount();
            GetId := GetIdMock.Value;
        END_METHOD

        METHOD PUBLIC GetNodeId : UINT
            GetNodeIdMock.IncrementCallCount();
            GetNodeId := GetNodeIdMock.Value;
        END_METHOD

        METHOD PUBLIC GetWeldSystemType : WeldSystemType
            GetWeldSystemTypeMock.IncrementCallCount();
            GetWeldSystemType := GetWeldSystemTypeMock.Value;
        END_METHOD

        METHOD PUBLIC GetTravelControl : TravelControl
            GetTravelControlMock.IncrementCallCount();
            GetTravelControl := GetTravelControlMock.Value;
        END_METHOD

        METHOD PUBLIC GetTravelMotorDrive : TravelMotorDrive
            GetTravelMotorDriveMock.IncrementCallCount();
            GetTravelMotorDrive := GetTravelMotorDriveMock.Value;
        END_METHOD

        METHOD PUBLIC GetTandemRole : TandemRole
            GetTandemRoleMock.IncrementCallCount();
            GetTandemRole := GetTravelControlMock.Value;
        END_METHOD

        METHOD PUBLIC IsWelding : BOOL
            IsWeldingMock.IncrementCallCount();
            IsWelding := IsWeldingMock.Value;
        END_METHOD

        METHOD PUBLIC IsConnected : BOOL
            IsConnectedMock.IncrementCallCount();
            IsConnected := IsConnectedMock.Value;
        END_METHOD

        METHOD PUBLIC IsReadyToStart : BOOL
            IsReadyToStartMock.IncrementCallCount();
            IsReadyToStart := IsReadyToStartMock.Value;
        END_METHOD

        METHOD PUBLIC HasError : BOOL
            HasErrorMock.IncrementCallCount();
            HasError := HasErrorMock.Value;
        END_METHOD

        METHOD PUBLIC GetMeasuredVoltage : REAL
            GetMeasuredVoltageMock.IncrementCallCount();
            GetMeasuredVoltage := GetMeasuredVoltageMock.Value;
        END_METHOD

        METHOD PUBLIC GetMeasuredWireSpeed : INT
            GetMeasuredWireSpeedMock.IncrementCallCount();
            GetMeasuredWireSpeed := GetMeasuredWireSpeedMock.Value;
        END_METHOD

        METHOD PUBLIC GetMeasuredTravelSpeed : INT
            GetMeasuredTravelSpeedMock.IncrementCallCount();
            GetMeasuredTravelSpeed := GetMeasuredTravelSpeedMock.Value;
        END_METHOD

        METHOD PUBLIC GetMeasuredHeatInput : REAL
            GetMeasuredHeatInputMock.IncrementCallCount();
            GetMeasuredHeatInput := GetMeasuredHeatInputMock.Value;
        END_METHOD

        METHOD PUBLIC GetWeldDataSet : UINT
            GetWeldDataSetMock.IncrementCallCount();
            GetWeldDataSet := GetWeldDataSetMock.Value;
        END_METHOD

        METHOD PUBLIC GetRequestedTravelSpeed : INT
            GetRequestedTravelSpeedMock.IncrementCallCount();
            GetRequestedTravelSpeed := GetRequestedTravelSpeedMock.Value;
        END_METHOD

        METHOD PUBLIC GetRequestedWireSpeed : INT
            GetRequestedWireSpeedMock.IncrementCallCount();
            GetRequestedWireSpeed := GetRequestedWireSpeedMock.Value;
        END_METHOD

        METHOD PUBLIC NodeIsConnected : BOOL
            VAR_INPUT
                nodeId : UINT;
            END_VAR

            NodeIsConnectedMock.IncrementCallCount();
            NodeIsConnectedMock.NodeId := nodeId;
            NodeIsConnected := NodeIsConnectedMock.Value;
        END_METHOD

        METHOD PUBLIC GetNodeInformation : NodeInformation
            VAR_INPUT
                nodeId : UINT;
            END_VAR

            GetNodeInformationMock.IncrementCallCount();
            GetNodeInformationMock.NodeId := nodeId;
            GetNodeInformation := GetNodeInformationMock.NodeInformation;
        END_METHOD

        METHOD PUBLIC WireFeedJogPos
            VAR_INPUT
                highSpeed : BOOL;
            END_VAR

            WireFeedJogPosMock.IncrementCallCount();
            WireFeedJogPosMock.Value := highSpeed;
        END_METHOD

        METHOD PUBLIC WireFeedJogNeg
            VAR_INPUT
                highSpeed : BOOL;
            END_VAR

            WireFeedJogNegMock.IncrementCallCount();
            WireFeedJogNegMock.Value := highSpeed;
        END_METHOD

        METHOD PUBLIC TravelAxisJogPos
            VAR_INPUT
                highSpeed : BOOL;
            END_VAR

            TravelAxisJogPosMock.IncrementCallCount();
            TravelAxisJogPosMock.Value := highSpeed;
        END_METHOD

        METHOD PUBLIC TravelAxisJogNeg
            VAR_INPUT
                highSpeed : BOOL;
            END_VAR

            TravelAxisJogNegMock.IncrementCallCount();
            TravelAxisJogNegMock.Value := highSpeed;
        END_METHOD

        METHOD PUBLIC ReadNodes
            ReadNodesMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC WriteAsync
            VAR_INPUT
                record : DataRecord;
                value : UINT;
            END_VAR

            WriteAsyncMock.IncrementCallCount();
            WriteAsyncMock.Index := record;
            WriteAsyncMock.Value := value;
        END_METHOD

        METHOD PUBLIC WriteAsync
            VAR_INPUT
                command : REF_TO Esab.WeldSystem.PowerSources.UIntAsyncCommand;
            END_VAR

            WriteAsyncCmdMock.IncrementCallCount();
            WriteAsyncCmdMock.Command := command;
        END_METHOD

        METHOD PUBLIC ReadAsync
            VAR_INPUT
                record : DataRecord;
            END_VAR

            ReadAsyncMock.IncrementCallCount();
            ReadAsyncMock.Index := record;
        END_METHOD

        METHOD PUBLIC ReadAsync
            VAR_INPUT
                command : REF_TO Esab.WeldSystem.PowerSources.UIntAsyncCommand;
            END_VAR

            ReadAsyncCmdMock.IncrementCallCount();
            ReadAsyncCmdMock.Command := command;
        END_METHOD

        METHOD PUBLIC OVERRIDE Observe : IAssetObservable
            Observe := NULL;
        END_METHOD
    END_CLASS

    CLASS WriteAsyncMock EXTENDS MethodMock
        VAR PUBLIC
            Index : DataRecord;
            Value : UINT;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Index := DataRecord#Invalid;
            Value := UINT#0;
        END_METHOD
    END_CLASS

    CLASS WriteAsyncCmdMock EXTENDS MethodMock
        VAR PUBLIC
            Command: REF_TO UIntAsyncCommand;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Command := NULL;
        END_METHOD
    END_CLASS

    CLASS ReadAsyncMock EXTENDS MethodMock
        VAR PUBLIC
            Index : DataRecord;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Index := DataRecord#Invalid;
        END_METHOD
    END_CLASS

    CLASS ReadAsyncCmdMock EXTENDS MethodMock
        VAR PUBLIC
            Command: REF_TO UIntAsyncCommand;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Command := NULL;
        END_METHOD
    END_CLASS

    CLASS NodeInformationMethodMock EXTENDS MethodMock
        VAR PUBLIC
            NodeId : UINT;
            NodeInformation : NodeInformation;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            NodeId := UINT#0;
            NodeInformation.Version := UINT#0;
            NodeInformation.SubVersion := 'Z';
            NodeInformation.DeviceType := UINT#0;
            NodeInformation.MachineId := UINT#0;
        END_METHOD
    END_CLASS

    CLASS NodeIsConnectedMethodMock EXTENDS BoolMethodMock
        VAR PUBLIC
            NodeId : UINT;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            NodeId := UINT#0;
            Value := FALSE;
        END_METHOD
    END_CLASS

    CLASS TravelControlMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value : TravelControl;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Value := -1;
        END_METHOD
    END_CLASS

    CLASS TravelMotorDriveMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value : TravelMotorDrive;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Value := -1;
        END_METHOD
    END_CLASS

    CLASS TandemRoleMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value : TandemRole;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Value := -1;
        END_METHOD
    END_CLASS

    CLASS PowerSourceListenerMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value : IPowerSourceListener;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Value := NULL;
        END_METHOD
    END_CLASS

    CLASS WeldSystemTypeMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value : WeldSystemType;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Value := WeldSystemType#Aristo1000;
        END_METHOD
    END_CLASS

    CLASS SetPointsRefMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value : REF_TO SetPoints;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Value := NULL;
        END_METHOD
    END_CLASS

    CLASS StartTypeMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value : StartType;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Value := StartType#Direct;
        END_METHOD
    END_CLASS

END_NAMESPACE