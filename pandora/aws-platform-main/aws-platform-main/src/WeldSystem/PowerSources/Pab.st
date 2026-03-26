USING Esab.Io;

NAMESPACE Esab.WeldSystem.PowerSources
    TYPE
        {S7.Extern=ReadWrite}
        PabData : STRUCT
            Input : PabToController;
            Output : ControllerToPab;
        END_STRUCT;

        // --- Interface struct declarations
        {S7.Extern=ReadWrite}
        PabToController : STRUCT
            /// Indicates that the Weld On command has been received.
            WeldStarted : DigitalInput;
            /// Set as soon as the welding requirements are met.
            Welding : DigitalInput;
            /// Indicates that the weld is finished. Only applicable for LAF/TAF.
            WeldingFinished : DigitalInput;
            /// TRUE when there is an error present that prohibits start.
            Error : DigitalInput;
            /// TRUE when it is possible to start a weld.
            ReadyToStart : DigitalInput;
            /// Indicates the currently selected weld method. TRUE = AC, FALSE = DC. Aristo 1000 only.
            WeldMethod : DigitalInput;
            /// Set when event information is available. Only set for ~5 seconds and then reset.
            Event : DigitalInput;
            /// Set when import or export function is active.
            FileBusy : DigitalInput;
            /// FALSE = Not coupled, TRUE = Coupled. If this is set the power source is master and has found its parallel slave(s).
            ParallelCoupleStatus : DigitalInput;
            /// The total number of errors or events detected. This equals the number of the last post in the error/event log.
            NumberOfErrors : UIntInput := (Endianness := Endianness#Big);
            /// Requested travel speed (cm/min).
            RequestedTravelSpeed : IntInput := (Endianness := Endianness#Little);
            /// The measured welding voltage.
            MeasuredVoltage : RealInput := (Endianness := Endianness#Little, Scale := REAL#0.1);
            /// The measured welding current.
            MeasuredCurrent : UIntInput := (Endianness := Endianness#Little);
            /// Measured wire speed (cm/min).
            MeasuredWireSpeed : IntInput := (Endianness := Endianness#Little);
            /// Measured travel speed (cm/min).
            MeasuredTravelSpeed : IntInput := (Endianness := Endianness#Little);
            /// The measured heat input.
            MeasuredHeatInput : RealInput := (Endianness := Endianness#Little, Scale := REAL#0.1);
            /// The currently set weld method. Aristo 1000 only.
            SetWeldMethod : UIntInput := (Endianness := Endianness#Big);
            /// The currently set regulation type. Aristo 1000 only.
            SetRegulationType : UIntInput := (Endianness := Endianness#Big);
            /// The AC frequency setpoint. Aristo 1000 only.
            SetAcFrequency : UIntInput := (Endianness := Endianness#Little);
            /// The AC balance setpoint. Aristo 1000 only.
            SetAcBalance : UIntInput := (Endianness := Endianness#Little);
            /// The voltage setpoint.
            SetVoltage : RealInput := (Endianness := Endianness#Little, Scale := REAL#0.1);
            /// The current setpoint.
            SetCurrent : UIntInput := (Endianness := Endianness#Little);
            /// Current wire speed setpoint (cm/min).
            SetWireSpeed : UIntInput := (Endianness := Endianness#Little);
            /// Current travel speed setpoint (cm/min).
            SetTravelSpeed : UIntInput := (Endianness := Endianness#Little);
            /// The current AC offset value.
            SetAcOffset : RealInput := (Endianness := Endianness#Little, Scale := REAL#0.1);
            /// The current AC phase shift value.
            SetAcPhaseShift : UIntInput := (Endianness := Endianness#Little);
            /// Requested wire speed (cm/min).
            RequestedWireSpeed : IntInput := (Endianness := Endianness#Little);
            /// Current weld data set
            SetWeldDataSet : UIntInput := (Endianness := Endianness#Little);
            ErrorEvent : ErrorEvent;
            /// Incremented at 2 Hz, when this value is incrementing the PAB can be considered alive and ready for communication.
            Heartbeat : UIntInput := (Endianness := Endianness#Little);
            /// The current start adjust value in %.
            SetStartAdjust : UIntInput := (Endianness := Endianness#Little);
            /// The current regulation dynamics value.
            SetRegulationDynamics : UIntInput := (Endianness := Endianness#Little);
            /// The current regulation inductance value.
            SetRegulationInductance : UIntInput := (Endianness := Endianness#Little);
        END_STRUCT;

        {S7.Extern=ReadWrite}
        ErrorEvent : STRUCT
            Code : WordInput := (Endianness := Endianness#Little);
            SubCode : UIntInput := (Endianness := Endianness#Big);
            NodeId : UIntInput := (Endianness := Endianness#Big);
            DeviceType : UIntInput := (Endianness := Endianness#Big);
            SubUnit : UIntInput := (Endianness := Endianness#Big);
        END_STRUCT;

        {S7.Extern=ReadWrite}
        ControllerToPab : STRUCT
            Common : PabInputCommon;
            InputArea : ARRAY[1..2] OF PabInputArea;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        PabInputCommon : STRUCT
            /// Starts the weld when set to TRUE, to stop welding set this to FALSE.
            WeldOn : DigitalOutput;
            /// When this is set to TRUE the weld system will perform a quick stop (stopping without doing crater fill).
            QuickStop : DigitalOutput;
            /// Set to TRUE to jog the wire feed in the positive direction (down)
            WireFeedJogPos : DigitalOutput;
            /// Set to TRUE to jog the wire feed in the negative direction (up)
            WireFeedJogNeg : DigitalOutput;
            /// Set to TRUE to jog the travel axis in the positive direction
            TravelAxisJogPos : DigitalOutput;
            /// Set to TRUE to jog the travel axis in the negative direction
            TravelAxisJogNeg : DigitalOutput;
            /// Set to TRUE to jog the ICE wire feed in the positive direction (down)
            IceWireFeedJogPos : DigitalOutput;
            /// Set to TRUE to jog the ICE wire feed in the negative direction (up)
            IceWireFeedJogNeg : DigitalOutput;
            /// High speed (jogging)
            HighSpeed : DigitalOutput;
            /// Switches the active input area (0 = Input area #1, 1 = Input area #2)
            InputAreaSwitch : DigitalOutput;
            /// OPTIONAL! A heartbeat used to tell the PAB that the Controller is alive and well.
            Heartbeat : UIntOutput := (Endianness := Endianness#Big);
        END_STRUCT;

        {S7.Extern=ReadWrite}
        PabInputArea : STRUCT
            /// The weld method.
            WeldMethod : UIntOutput := (Endianness := Endianness#Big);
            /// The regulation type.
            RegulationType : UIntOutput := (Endianness := Endianness#Big);
            /// Weld voltage setpoint.
            Voltage : RealOutput := (Endianness := Endianness#Little, Scale := REAL#0.1);
            /// Wire speed setpoint (cm/min)
            WireSpeed : UIntOutput := (Endianness := Endianness#Little);
            /// Weld current setpoint
            Current : UIntOutput := (Endianness := Endianness#Little);
            /// Travel speed setpoint (cm/min)
            TravelSpeed : UIntOutput := (Endianness := Endianness#Little);
            /// AC frequency setpoint. Aristo 1000 only.
            AcFrequency : UIntOutput := (Endianness := Endianness#Little);
            /// AC balance setpoint. Aristo 1000 only
            AcBalance : UIntOutput := (Endianness := Endianness#Little);
            /// AC offset setpoint. Aristo 1000 only.
            AcOffset : RealOutput := (Endianness := Endianness#Little, Scale := REAL#0.1);
            /// AC phase shift setpoint. Aristo 1000 only
            AcPhaseShift : UIntOutput := (Endianness := Endianness#Little);
            /// Start adjust setpoint in %.
            StartAdjust : UIntOutput := (Endianness := Endianness#Little);
            /// Regulation dynamics setpoint.
            RegulationDynamics : UIntOutput := (Endianness := Endianness#Little);
            /// Regulation inductance setpoint.
            RegulationInductance : UIntOutput := (Endianness := Endianness#Little);
            /// ICE wire speed percentage.
            IceWireSpeedPercentage : UIntOutput := (Endianness := Endianness#Little);
        END_STRUCT;

        /// An enum representing the weld method
        WeldMethod : BYTE (
            DCp := BYTE#0,
            AC := BYTE#1,
            DCn := BYTE#2
        );

        RegulationType : BYTE (
            ConstantAmperage := BYTE#0,
            ConstantWire := BYTE#1,
            ConstantCurrent := BYTE#2
        );

        // --- I/O struct declarations
        {S7.Extern=ReadWrite}
        RawPabToController : STRUCT
            WeldStarted AT %X0.0 : BOOL;
            Welding AT %X0.1 : BOOL;
            WeldingFinished AT %X0.2 : BOOL;
            Error AT %X0.3 : BOOL;
            ReadyToStart AT %X1.3 : BOOL;
            WeldMethod AT %X2.2 : BOOL;
            Event AT %X2.4 : BOOL;
            FileBusy AT %X2.5 : BOOL;
            ParallelCoupleStatus AT %X2.7 : BOOL;
            NumberOfErrors AT %B4 : BYTE;
            RequestedTravelSpeed AT %B6 : INT;
            MeasuredVoltage AT %B8 : INT;
            MeasuredCurrent AT %B10 : UINT;
            MeasuredHeatInput AT %B12 : INT;
            MeasuredWireSpeed AT %B14 : INT;
            MeasuredTravelSpeed AT %B16 : INT;
            SetWeldMethod AT %B18 : BYTE;
            SetRegulationType AT %B19 : BYTE;
            SetAcFrequency AT %B20 : UINT;
            SetAcBalance AT %B22 : UINT;
            SetVoltage AT %B24 : UINT;
            SetCurrent AT %B26 : UINT;
            SetWireSpeed AT %B28 : UINT;
            SetTravelSpeed AT %B30 : UINT;
            SetAcOffset AT %B32 : INT;
            SetWeldDataSet AT %B34 : BYTE;
            SetAcPhaseShift AT %B36 : UINT;
            RequestedWireSpeed AT %B38 : INT;
            ErrorEvent AT %B40 : RawErrorEvent;
            Heartbeat AT %B46 : UINT;
            SetStartAdjust AT %B48 : UINT;
            SetRegulationDynamics AT %B50 : UINT;
            SetRegulationInductance AT %B52 : UINT;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        RawErrorEvent : STRUCT
            Code AT %B0 : WORD;
            SubCode AT %B2 : BYTE;
            NodeId AT %B3 : BYTE;
            DeviceType AT %B4 : BYTE;
            SubUnit AT %B5 : BYTE;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        RawControllerToPab : STRUCT
            Common AT %B0 : RawPabInputCommon;
            Area1 AT %B8 : RawPabInputArea;
            Area2 AT %B36 : RawPabInputArea;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        RawPabInputCommon : STRUCT
            WeldOn AT %X0.0 : BOOL;
            QuickStop AT %X0.1 : BOOL;
            WireFeedJogPos AT %X0.4 : BOOL;
            WireFeedJogNeg AT %X0.5 : BOOL;
            TravelAxisJogPos AT %X0.6 : BOOL;
            TravelAxisJogNeg AT %X0.7 : BOOL;
            IceWireFeedJogPos AT %X1.0 : BOOL;
            IceWireFeedJogNeg AT %X1.1 : BOOL;
            HighSpeed AT %X1.2 : BOOL;
            InputAreaSwitch AT %X3.2 : BOOL;
            Heartbeat AT %B7 : BYTE;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        RawPabInputArea : STRUCT
            WeldMethod AT %B0 : BYTE;
            RegulationType AT %B1 : BYTE;
            Voltage AT %B2 : UINT;
            WireSpeed AT %B4 : UINT;
            Current AT %B6 : UINT;
            TravelSpeed AT %B8 : UINT;
            AcFrequency AT %B10 : UINT;
            AcBalance AT %B12 : UINT;
            AcOffset AT %B14 : INT;
            AcPhaseShift AT %B16 : UINT;
            StartAdjust AT %B18 : UINT;
            RegulationDynamics AT %B20 : UINT;
            RegulationInductance AT %B22 : UINT;
            IceWireSpeedPercentage AT %B26 : UINT;
        END_STRUCT;
    END_TYPE

    FUNCTION PabRead
        VAR_INPUT
            Processed : REF_TO PabToController;
            Raw : REF_TO RawPabToController;
        END_VAR

        Processed^.WeldStarted.Read             (Raw^.WeldStarted);
        Processed^.Welding.Read                 (Raw^.Welding);
        Processed^.WeldingFinished.Read         (Raw^.WeldingFinished);
        Processed^.Error.Read                   (Raw^.Error);
        Processed^.ReadyToStart.Read            (Raw^.ReadyToStart);
        Processed^.WeldMethod.Read              (Raw^.WeldMethod);
        Processed^.Event.Read                   (Raw^.Event);
        Processed^.FileBusy.Read                (Raw^.FileBusy);
        Processed^.ParallelCoupleStatus.Read    (Raw^.ParallelCoupleStatus);
        Processed^.NumberOfErrors.Read          (Raw^.NumberOfErrors);
        Processed^.RequestedTravelSpeed.Read    (Raw^.RequestedTravelSpeed);
        Processed^.MeasuredVoltage.Read         (Raw^.MeasuredVoltage);
        Processed^.MeasuredCurrent.Read         (Raw^.MeasuredCurrent);
        Processed^.MeasuredHeatInput.Read       (Raw^.MeasuredHeatInput);
        Processed^.MeasuredWireSpeed.Read       (Raw^.MeasuredWireSpeed);
        Processed^.MeasuredTravelSpeed.Read     (Raw^.MeasuredTravelSpeed);
        Processed^.SetWeldMethod.Read           (Raw^.SetWeldMethod);
        Processed^.SetRegulationType.Read       (Raw^.SetRegulationType);
        Processed^.SetAcFrequency.Read          (Raw^.SetAcFrequency);
        Processed^.SetAcBalance.Read            (Raw^.SetAcBalance);
        Processed^.SetVoltage.Read              (Raw^.SetVoltage);
        Processed^.SetCurrent.Read              (Raw^.SetCurrent);
        Processed^.SetWireSpeed.Read            (Raw^.SetWireSpeed);
        Processed^.SetTravelSpeed.Read          (Raw^.SetTravelSpeed);
        Processed^.SetAcOffset.Read             (Raw^.SetAcOffset);
        Processed^.SetWeldDataSet.Read          (Raw^.SetWeldDataSet);
        Processed^.SetAcPhaseShift.Read         (Raw^.SetAcPhaseShift);
        Processed^.RequestedWireSpeed.Read      (Raw^.RequestedWireSpeed);
        Processed^.ErrorEvent.Code.Read         (Raw^.ErrorEvent.Code);
        Processed^.ErrorEvent.SubCode.Read      (Raw^.ErrorEvent.SubCode);
        Processed^.ErrorEvent.NodeId.Read       (Raw^.ErrorEvent.NodeId);
        Processed^.ErrorEvent.DeviceType.Read   (Raw^.ErrorEvent.DeviceType);
        Processed^.ErrorEvent.SubUnit.Read      (Raw^.ErrorEvent.SubUnit);
        Processed^.Heartbeat.Read               (Raw^.Heartbeat);
        Processed^.SetStartAdjust.Read          (Raw^.SetStartAdjust);
        Processed^.SetRegulationDynamics.Read   (Raw^.SetRegulationDynamics);
        Processed^.SetRegulationInductance.Read (Raw^.SetRegulationInductance);
    END_FUNCTION

    FUNCTION PabWrite
        VAR_INPUT
            Processed : REF_TO ControllerToPab;
            Raw : REF_TO RawControllerToPab;
        END_VAR

        Processed^.Common.WeldOn.Write              (Raw^.Common.WeldOn);
        Processed^.Common.QuickStop.Write           (Raw^.Common.QuickStop);
        Processed^.Common.Heartbeat.Write           (Raw^.Common.Heartbeat);
        Processed^.Common.WireFeedJogPos.Write      (Raw^.Common.WireFeedJogPos);
        Processed^.Common.WireFeedJogNeg.Write      (Raw^.Common.WireFeedJogNeg);
        Processed^.Common.TravelAxisJogPos.Write    (Raw^.Common.TravelAxisJogPos);
        Processed^.Common.TravelAxisJogNeg.Write    (Raw^.Common.TravelAxisJogNeg);
        Processed^.Common.IceWireFeedJogPos.Write   (Raw^.Common.IceWireFeedJogPos);
        Processed^.Common.IceWireFeedJogNeg.Write   (Raw^.Common.IceWireFeedJogNeg);
        Processed^.Common.HighSpeed.Write           (Raw^.Common.HighSpeed);
        Processed^.Common.InputAreaSwitch.Write     (Raw^.Common.InputAreaSwitch);

        Processed^.InputArea[1].WeldMethod.Write               (Raw^.Area1.WeldMethod);
        Processed^.InputArea[1].RegulationType.Write           (Raw^.Area1.RegulationType);
        Processed^.InputArea[1].Voltage.Write                  (Raw^.Area1.Voltage);
        Processed^.InputArea[1].WireSpeed.Write                (Raw^.Area1.WireSpeed);
        Processed^.InputArea[1].Current.Write                  (Raw^.Area1.Current);
        Processed^.InputArea[1].TravelSpeed.Write              (Raw^.Area1.TravelSpeed);
        Processed^.InputArea[1].AcFrequency.Write              (Raw^.Area1.AcFrequency);
        Processed^.InputArea[1].AcBalance.Write                (Raw^.Area1.AcBalance);
        Processed^.InputArea[1].AcOffset.Write                 (Raw^.Area1.AcOffset);
        Processed^.InputArea[1].AcPhaseShift.Write             (Raw^.Area1.AcPhaseShift);
        Processed^.InputArea[1].StartAdjust.Write              (Raw^.Area1.StartAdjust);
        Processed^.InputArea[1].RegulationDynamics.Write       (Raw^.Area1.RegulationDynamics);
        Processed^.InputArea[1].RegulationInductance.Write     (Raw^.Area1.RegulationInductance);
        Processed^.InputArea[1].IceWireSpeedPercentage.Write   (Raw^.Area1.IceWireSpeedPercentage);

        Processed^.InputArea[2].WeldMethod.Write               (Raw^.Area2.WeldMethod);
        Processed^.InputArea[2].RegulationType.Write           (Raw^.Area2.RegulationType);
        Processed^.InputArea[2].Voltage.Write                  (Raw^.Area2.Voltage);
        Processed^.InputArea[2].WireSpeed.Write                (Raw^.Area2.WireSpeed);
        Processed^.InputArea[2].Current.Write                  (Raw^.Area2.Current);
        Processed^.InputArea[2].TravelSpeed.Write              (Raw^.Area2.TravelSpeed);
        Processed^.InputArea[2].AcFrequency.Write              (Raw^.Area2.AcFrequency);
        Processed^.InputArea[2].AcBalance.Write                (Raw^.Area2.AcBalance);
        Processed^.InputArea[2].AcOffset.Write                 (Raw^.Area2.AcOffset);
        Processed^.InputArea[2].AcPhaseShift.Write             (Raw^.Area2.AcPhaseShift);
        Processed^.InputArea[2].StartAdjust.Write              (Raw^.Area2.StartAdjust);
        Processed^.InputArea[2].RegulationDynamics.Write       (Raw^.Area2.RegulationDynamics);
        Processed^.InputArea[2].RegulationInductance.Write     (Raw^.Area2.RegulationInductance);
        Processed^.InputArea[2].IceWireSpeedPercentage.Write   (Raw^.Area2.IceWireSpeedPercentage);
    END_FUNCTION

END_NAMESPACE