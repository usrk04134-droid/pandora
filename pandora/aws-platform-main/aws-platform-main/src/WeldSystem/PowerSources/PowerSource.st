USING Esab.Utils.Assets;
USING Esab.Utils.Timer;
USING Esab.Utils.Io;

USING Esab.WeldSystem;

USING System.FastMath;

NAMESPACE Esab.WeldSystem.PowerSources

    INTERFACE IPowerSource
        /// Intended for cyclic execution
        METHOD Execute
        END_METHOD

        /// Sets a listener to this power source
        METHOD SetListener
            VAR_INPUT
                listener : IPowerSourceListener;
            END_VAR
        END_METHOD

        /// Initiates the welding sequence
        METHOD Start
        END_METHOD

        /// Stops the welding sequence in a controlled manner
        METHOD Stop
        END_METHOD

        /// Stops the welding sequence faster, skips the stop phase
        METHOD QuickStop
        END_METHOD

        /// Sets remote start towards the power source
        METHOD RemoteStart
        END_METHOD

        /// Sets remote stop towards the power source
        METHOD RemoteStop
        END_METHOD

        /// Returns a reference to the currently active input area
        METHOD ActiveArea : REF_TO SetPoints
        END_METHOD

        /// Returns a reference to the currently passive input area
        METHOD PassiveArea : REF_TO SetPoints
        END_METHOD

        /// Switch the active and passive areas
        METHOD SwitchActivePassive
        END_METHOD

        /// Sets the travel control (NOTE: Async)
        METHOD SetTravelControl
            VAR_INPUT
                control : TravelControl;
            END_VAR
        END_METHOD

        /// Sets the travel motor drive (NOTE: Async)
        METHOD SetTravelMotorDrive
            VAR_INPUT
                drive : TravelMotorDrive;
            END_VAR
        END_METHOD

        /// Sets the tandem role of this power source (NOTE: Async)
        METHOD SetTandemRole
            VAR_INPUT
                role : TandemRole;
            END_VAR
        END_METHOD

        /// Sets the start type (NOTE: Async)
        METHOD SetStartType
            VAR_INPUT
                startType : StartType;
            END_VAR
        END_METHOD

        /// Sets normal wire feed jog speed (NOTE: Async)
        METHOD SetWireFeedJogSpeed
            VAR_INPUT
                speed : UINT;
            END_VAR
        END_METHOD

        /// Sets wire feed jog high speed (NOTE: Async)
        METHOD SetWireFeedJogHighSpeed
            VAR_INPUT
                speed : UINT;
            END_VAR
        END_METHOD

        /// Applies a configuration to the wire motor
        /// Returns FALSE if it is not currently possible to set configuration
        METHOD ApplyWireMotorConfiguration : BOOL
            VAR_INPUT
                motorConfiguration : REF_TO MotorConfiguration;
            END_VAR
        END_METHOD

        /// ID of the power source
        METHOD GetId : UINT
        END_METHOD

        /// Node ID used by this power source
        METHOD GetNodeId : UINT
        END_METHOD

        /// The actual weld system type that is connected
        METHOD GetWeldSystemType : WeldSystemType
        END_METHOD

        /// Travel control (Off/Enabled)
        METHOD GetTravelControl : TravelControl
        END_METHOD

        /// Travel motor drive (Faa/External)
        METHOD GetTravelMotorDrive : TravelMotorDrive
        END_METHOD

        /// Tandem role (Head/Tail)
        METHOD GetTandemRole : TandemRole
        END_METHOD

        /// Returns TRUE if the welding system is welding
        METHOD IsWelding : BOOL
        END_METHOD

        /// Returns TRUE if the PLC has active communication with the PAB
        METHOD IsConnected : BOOL
        END_METHOD

        /// Returns TRUE if the power source reports as ready to start
        METHOD IsReadyToStart : BOOL
        END_METHOD

        /// Returns TRUE if the power source reports it has an error
        METHOD HasError : BOOL
        END_METHOD

        /// Returns the measured welding voltage.
        METHOD GetMeasuredVoltage : REAL
        END_METHOD

        /// Returns the measured wire speed (cm/min)
        METHOD GetMeasuredWireSpeed : INT
        END_METHOD

        /// Returns the measured travel speed (cm/min)
        METHOD GetMeasuredTravelSpeed : INT
        END_METHOD

        /// Returns the measured heat input (kJ/cm)
        METHOD GetMeasuredHeatInput : REAL
        END_METHOD

        /// Returns the currently set weld data set
        METHOD GetWeldDataSet : UINT
        END_METHOD

        /// Returns the requested (by the power source) travel speed
        METHOD GetRequestedTravelSpeed : INT
        END_METHOD

        /// Returns the requested (by the power source) wire speed
        METHOD GetRequestedWireSpeed : INT
        END_METHOD

        /// Returns TRUE if the node with the given ID is connected
        METHOD NodeIsConnected : BOOL
            VAR_INPUT
                nodeId : UINT;
            END_VAR
        END_METHOD

        /// Returns the information of the given node
        METHOD GetNodeInformation : NodeInformation
            VAR_INPUT
                nodeId : UINT;
            END_VAR
        END_METHOD

        METHOD WireFeedJogPos
            VAR_INPUT
                highSpeed : BOOL;
            END_VAR
        END_METHOD

        METHOD WireFeedJogNeg
            VAR_INPUT
                highSpeed : BOOL;
            END_VAR
        END_METHOD

        METHOD TravelAxisJogPos
            VAR_INPUT
                highSpeed : BOOL;
            END_VAR
        END_METHOD

        METHOD TravelAxisJogNeg
            VAR_INPUT
                highSpeed : BOOL;
            END_VAR
        END_METHOD

        /// Initiates a read of all connected nodes (unless already reading)
        METHOD ReadNodes
        END_METHOD

        METHOD WriteAsync
            VAR_INPUT
                record : DataRecord;
                value : UINT;
            END_VAR
        END_METHOD

        METHOD WriteAsync
            VAR_INPUT
                command: REF_TO UIntAsyncCommand;
            END_VAR
        END_METHOD

        METHOD ReadAsync
            VAR_INPUT
                record : DataRecord;
            END_VAR
        END_METHOD

        METHOD ReadAsync
            VAR_INPUT
                command: REF_TO UIntAsyncCommand;
            END_VAR
        END_METHOD
    END_INTERFACE

    INTERFACE IHeartBeat
        /// Returns TRUE if this object is initialized
        METHOD IsInitialized : BOOL
        END_METHOD

        /// Cyclic execution to evaluate heartbeat
        METHOD Execute
        END_METHOD

        /// Returns TRUE if a heartbeat is detected
        METHOD Alive : BOOL
        END_METHOD

        /// Returns TRUE if no heartbeat is detected
        METHOD Dead : BOOL
        END_METHOD
    END_INTERFACE

    CLASS Heartbeat IMPLEMENTS IHeartbeat
        VAR PUBLIC
            Input : IUIntInput;
            Timer: ITimer;
        END_VAR

        VAR PRIVATE
            _value : UINT;
            _lastValue : UINT;
            _alive : BOOL;
        END_VAR

        METHOD PUBLIC IsInitialized : BOOL
            IsInitialized := Input <> NULL AND Timer <> NULL;
        END_METHOD

        METHOD PUBLIC Execute
            IF NOT THIS.IsInitialized() THEN
                _alive := FALSE;
                RETURN;
            END_IF;

            _lastValue := _value;
            _value := Input.GetValue();

            Timer.Execute(_value = _lastValue, LT#10s);
            _alive := NOT Timer.Expired();
        END_METHOD

        METHOD PUBLIC Alive : BOOL
            Alive := _alive;
        END_METHOD

        METHOD PUBLIC Dead : BOOL
            Dead := NOT _alive;
        END_METHOD
    END_CLASS

    INTERFACE IPowerSourceListener
        /// Called when a power source becomes connected
        METHOD PowerSourceConnected
            VAR_INPUT
                /// The id (enumeration) of the power source
                id : UINT;
            END_VAR
        END_METHOD

        /// Called when a power source disconnects
        METHOD PowerSourceDisconnected
            VAR_INPUT
                /// The id (enumeration) of the power source
                id : UINT;
            END_VAR
        END_METHOD
    END_INTERFACE

    TYPE
        WeldProcess : INT(
            Saw := 0,
            Gmaw := 1,
            Gouging := 2
        );

        WireType : INT(
            FeSolidSingle := 0,
            FeSolidTwin := 1,
            FeTubeSingle := 2,
            FeTubeTwin := 3,
            SsSolidSingle := 4,
            SsSolidTwin := 5,
            SsTubeSingle := 6,
            SsTubeTwin := 7,
            AlSolidSingle := 8,
            AlSolidTwin := 9,
            StripSingle := 10,
            Gouging := 11
        );

        StartType : INT(
            Direct := 0,
            Scratch := 1,
            Lwas := 2,
            LwasMan := 3
        );

        TravelControl : INT(
            Off := 0,
            Enabled := 1
        );

        TravelMotorDrive : INT(
            Faa := 0,
            External := 1
        );

        TandemRole : INT(
            Head := 0,
            Slave := 1
        );

        /// Container for values read from async commands
        StatusBuffer : STRUCT
            /// Node ID used by this power source
            NodeId : UINT;
            /// The actual weld system type that is connected
            WeldSystemType : WeldSystemType;
            /// Travel control (Off/Enabled)
            TravelControl : TravelControl;
            /// Travel motor drive (Faa/External)
            TravelMotorDrive : TravelMotorDrive;
            /// Tandem role (Head/Tail)
            TandemRole : TandemRole;
        END_STRUCT;
    END_TYPE

    CLASS PowerSourceObservable IMPLEMENTS IAssetObservable
        VAR PUBLIC
            State : PowerSourceState;
            ReadyToStart : BOOL;
            Welding : BOOL;
            Error : BOOL;
            Connected : BOOL;
            WeldMethod : WeldMethod;
            MeasuredVoltage : REAL;
            MeasuredCurrent : UINT;
            MeasuredHeatInput : REAL;
            MeasuredWireSpeed : INT;
            MeasuredTravelSpeed : INT;
            RequestedWireSpeed : INT;
            RequestedTravelSpeed : INT;
            SetPoints : SetPoints;
        END_VAR
    END_CLASS

    FUNCTION CalculateMotorScaleFactors
        VAR_INPUT
            motorConfiguration : REF_TO MotorConfiguration;
        END_VAR

        VAR_OUTPUT
            nominator : UINT;
            denominator : UINT;
        END_VAR

        nominator := TO_UINT(TO_LREAL(motorConfiguration^.Gear.N2) / motorConfiguration^.Gear.N1 * motorConfiguration^.Rpm * motorConfiguration^.FeedRollDiameter * Constants#PI);
        denominator := TO_UINT(TO_UDINT(motorConfiguration^.Rpm) * motorConfiguration^.EncoderPpr / UINT#60);
    END_FUNCTION

    TYPE
        {S7.Extern=ReadWrite}
        RuntimeParameters : STRUCT
            WireFeedJogSpeed : UINT;
            WireFeedJogHighSpeed : UINT;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        HardwareConfiguration : STRUCT
            WireMotor : MotorConfiguration;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        MotorConfiguration : STRUCT
            Gear : Gear;
            Rpm : UINT;
            FeedRollDiameter : UINT;
            EncoderPpr : UINT;
            MaxCurrent : UINT;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        Gear : STRUCT
            N1 : UINT;
            N2 : UINT;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        Io : STRUCT
            Pab : PabData;
            Output : Output;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        Output : STRUCT
            RemoteStart : DigitalOutput;
        END_STRUCT;

        PowerSourceState : INT(
            Idle := 0,
            NotConnected := 1,
            Error := 2,
            Welding := 3
        );

        SetPoints : STRUCT
            Voltage : REAL;
            Current : UINT;
            WireSpeed : UINT;
            TravelSpeed : UINT;
            AcFrequency : UINT;
            AcBalance : UINT;
            AcOffset : REAL;
            AcPhaseShift : UINT;
            WeldMethod : WeldMethod;
            RegulationType : RegulationType;
            StartAdjust : UINT;
            RegulationDynamics : UINT;
            RegulationInductance : UINT;
            IceWireSpeedPercentage : UINT;
        END_STRUCT;
    END_TYPE

END_NAMESPACE