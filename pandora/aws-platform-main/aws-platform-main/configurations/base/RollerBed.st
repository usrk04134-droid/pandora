USING Esab.Motion;
USING Esab.Motion.MeasurementSystem;
Using Esab.Utils.Alarming;
USING Esab.Utils.Assets;
USING Esab.Io;
USING Esab.Utils.Filters;
USING Esab.Utils.Timer;

USING Siemens.Simatic.S71500.Tasks;
USING Siemens.Simatic.S71500.Alarming;

CONFIGURATION RollerBedConfiguration

    TASK RollerBedIoTask : ProgramCycle;

    PROGRAM RollerBedIoProgram WITH RollerBedIoTask: RollerBedIoReadWrite;

    // Constants
    VAR_GLOBAL CONSTANT
    END_VAR

    // Objects
    VAR_GLOBAL
        RollerBed : AnalogAxis;
        SpeedFilter : NoFilter;
        SpeedWheel : SpeedWheel;
        HighSpeedCounter : HighSpeedCounter;
        Hsc : HighSpeedCounter;
        SpeedMeasurementTimer : OnDelay;
    END_VAR

    // Alarms
    VAR_GLOBAL
        RollerBedSetupAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Roller Bed: Setup error."}
        RollerBedSetupAlarm : ProgramAlarm;

        RollerBedSpeedMonitoringAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Roller Bed: Set speed not reached."}
        RollerBedSpeedMonitoringAlarm : ProgramAlarm;

        SpeedWheelSetupAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Speed wheel: Setup error."}
        SpeedWheelSetupAlarm : ProgramAlarm;

        HighSpeedCounterLoadErrorAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "High speed counter: Load value error."}
        HighSpeedCounterLoadErrorAlarm : ProgramAlarm;

        HighSpeedCounterEncoderErrorAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "High speed counter: Encoder error."}
        HighSpeedCounterEncoderErrorAlarm : ProgramAlarm;

        HighSpeedCounterPowerSupplyErrorAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "High speed counter: Power supply error."}
        HighSpeedCounterPowerSupplyErrorAlarm : ProgramAlarm;

        HighSpeedCounterSetupAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "High speed counter: Setup error."}
        HighSpeedCounterSetupAlarm : ProgramAlarm;
    END_VAR

    // Interface
    VAR_GLOBAL
        RollerBedIo : AnalogAxisIo;
        SpeedWheelIo : SpeedWheelIo;
        HighSpeedCounterIo : HighSpeedCounterIo;
    END_VAR

    VAR_GLOBAL RETAIN
        RollerBedRuntimeParameters : AnalogAxisRuntimeParameters;
        RollerBedHardwareConfiguration : AnalogAxisHardwareConfiguration;
        SpeedWheelHardwareConfiguration : SpeedWheelHardwareConfiguration;
        HighSpeedCounterHardwareConfiguration : HighSpeedCounterHardwareConfiguration;
    END_VAR
END_CONFIGURATION

FUNCTION InitializeRollerBed
    VAR_INPUT
        assets : IAssetsManager;
    END_VAR

    VAR_EXTERNAL
        RollerBed : AnalogAxis;
        RollerBedIo : AnalogAxisIo;
        SpeedFilter : NoFilter;
        SpeedWheel : SpeedWheel;
        SpeedWheelIo : SpeedWheelIo;
        HighSpeedCounter : HighSpeedCounter;
        HighSpeedCounterIo : HighSpeedCounterIo;
        SpeedMeasurementTimer : OnDelay;

        RollerBedRuntimeParameters : AnalogAxisRuntimeParameters;

        RollerBedHardwareConfiguration : AnalogAxisHardwareConfiguration;
        SpeedWheelHardwareConfiguration : SpeedWheelHardwareConfiguration;
        HighSpeedCounterHardwareConfiguration : HighSpeedCounterHardwareConfiguration;

        RollerBedSetupAlarmWrapper : AlarmWrapper;
        RollerBedSetupAlarm : ProgramAlarm;

        RollerBedSpeedMonitoringAlarmWrapper : AlarmWrapper;
        RollerBedSpeedMonitoringAlarm : ProgramAlarm;

        SpeedWheelSetupAlarmWrapper : AlarmWrapper;
        SpeedWheelSetupAlarm : ProgramAlarm;

        HighSpeedCounterLoadErrorAlarmWrapper : AlarmWrapper;
        HighSpeedCounterLoadErrorAlarm : ProgramAlarm;
        HighSpeedCounterEncoderErrorAlarmWrapper : AlarmWrapper;
        HighSpeedCounterEncoderErrorAlarm : ProgramAlarm;
        HighSpeedCounterPowerSupplyErrorAlarmWrapper : AlarmWrapper;
        HighSpeedCounterPowerSupplyErrorAlarm : ProgramAlarm;
        HighSpeedCounterSetupAlarmWrapper : AlarmWrapper;
        HighSpeedCounterSetupAlarm : ProgramAlarm;
    END_VAR

    HighSpeedCounterLoadErrorAlarmWrapper.Setup(REF(HighSpeedCounterLoadErrorAlarm));
    HighSpeedCounterEncoderErrorAlarmWrapper.Setup(REF(HighSpeedCounterEncoderErrorAlarm));
    HighSpeedCounterPowerSupplyErrorAlarmWrapper.Setup(REF(HighSpeedCounterPowerSupplyErrorAlarm));
    HighSpeedCounterSetupAlarmWrapper.Setup(REF(HighSpeedCounterSetupAlarm));

    HighSpeedCounter.Setup(REF(HighSpeedCounterIo),
                           REF(HighSpeedCounterHardwareConfiguration),
                           HighSpeedCounterLoadErrorAlarmWrapper,
                           HighSpeedCounterEncoderErrorAlarmWrapper,
                           HighSpeedCounterPowerSupplyErrorAlarmWrapper,
                           HighSpeedCounterSetupAlarmWrapper);

    SpeedWheelSetupAlarmWrapper.Setup(REF(SpeedWheelSetupAlarm));

    SpeedWheel.Setup(io := REF(SpeedWheelIo),
                     hardwareConfiguration := REF(SpeedWheelHardwareConfiguration),
                     hsc := HighSpeedCounter,
                     speedFilter := SpeedFilter,
                     setupAlarm := SpeedWheelSetupAlarmWrapper);

    RollerBedSpeedMonitoringAlarmWrapper.Setup(REF(RollerBedSpeedMonitoringAlarm));
    RollerBedSetupAlarmWrapper.Setup(REF(RollerBedSetupAlarm));

    RollerBed.Setup(REF(RollerBedIo),
                    REF(RollerBedRuntimeParameters),
                    REF(RollerBedHardwareConfiguration),
                    SpeedWheel,
                    SpeedMeasurementTimer,
                    RollerBedSpeedMonitoringAlarmWrapper,
                    RollerBedSetupAlarmWrapper);

    RollerBed.SetIdentifier(Esab.AssetIdentifier#RollerBed);
    assets.RegisterAsset(REF(RollerBed));
END_FUNCTION

PROGRAM RollerBedIoReadWrite
    VAR_EXTERNAL
        RollerBedIo : AnalogAxisIo;
        SpeedWheelIo : SpeedWheelIo;
        HighSpeedCounterIo : HighSpeedCounterIo;

        I_HighSpeedCounter : RawHighSpeedCounterInputs;
        Q_HighSpeedCounter : RawHighSpeedCounterOutputs;
        DI_B_SpeedWheel_OneTurnSwitch : BOOL;
        DI_B_RollerBed_External_Error : BOOL;
        DQ_B_RollerBed_Forward : BOOL;
        DQ_B_RollerBed_Reverse : BOOL;
        DQ_B_RollerBed_RemoteControl : BOOL;
        AQ_B_RollerBed_SpeedReference : INT;
    END_VAR

    HighSpeedCounterIo.Inputs.CountValue.Read(I_HighSpeedCounter.CountValue);
    HighSpeedCounterIo.Inputs.CapturedValue.Read(I_HighSpeedCounter.CapturedValue);
    HighSpeedCounterIo.Inputs.MeasuredValue.Read(I_HighSpeedCounter.MeasuredValue);
    HighSpeedCounterIo.Inputs.LoadError.Read(I_HighSpeedCounter.LoadError);
    HighSpeedCounterIo.Inputs.EncoderError.Read(I_HighSpeedCounter.EncoderError);
    HighSpeedCounterIo.Inputs.PowerSupplyError.Read(I_HighSpeedCounter.PowerSupplyError);
    HighSpeedCounterIo.Inputs.SoftwareGate.Read(I_HighSpeedCounter.SoftwareGate);
    HighSpeedCounterIo.Inputs.Ready.Read(I_HighSpeedCounter.Ready);
    HighSpeedCounterIo.Inputs.Slot1Loaded.Read(I_HighSpeedCounter.Slot1Loaded);
    HighSpeedCounterIo.Inputs.Slot0Loaded.Read(I_HighSpeedCounter.Slot0Loaded);
    HighSpeedCounterIo.Inputs.ResetEventsAcknowledge.Read(I_HighSpeedCounter.ResetEventsAcknowledge);
    HighSpeedCounterIo.Inputs.Di2.Read(I_HighSpeedCounter.Di2);
    HighSpeedCounterIo.Inputs.Di1.Read(I_HighSpeedCounter.Di1);
    HighSpeedCounterIo.Inputs.Di0.Read(I_HighSpeedCounter.Di0);
    HighSpeedCounterIo.Inputs.Dq1.Read(I_HighSpeedCounter.Dq1);
    HighSpeedCounterIo.Inputs.Dq0.Read(I_HighSpeedCounter.Dq0);
    HighSpeedCounterIo.Inputs.InternalGate.Read(I_HighSpeedCounter.InternalGate);
    HighSpeedCounterIo.Inputs.Counting.Read(I_HighSpeedCounter.Counting);
    HighSpeedCounterIo.Inputs.Direction.Read(I_HighSpeedCounter.Direction);
    HighSpeedCounterIo.Inputs.MeasurementPulseDetected.Read(I_HighSpeedCounter.MeasurementPulseDetected);
    HighSpeedCounterIo.Inputs.CaptureEvent.Read(I_HighSpeedCounter.CaptureEvent);
    HighSpeedCounterIo.Inputs.SynchronizationEvent.Read(I_HighSpeedCounter.SynchronizationEvent);
    HighSpeedCounterIo.Inputs.ComparisonEvent1.Read(I_HighSpeedCounter.ComparisonEvent1);
    HighSpeedCounterIo.Inputs.ComparisonEvent0.Read(I_HighSpeedCounter.ComparisonEvent0);
    HighSpeedCounterIo.Inputs.OverflowEvent.Read(I_HighSpeedCounter.OverflowEvent);
    HighSpeedCounterIo.Inputs.UnderflowEvent.Read(I_HighSpeedCounter.UnderflowEvent);
    HighSpeedCounterIo.Inputs.ZeroPassEvent.Read(I_HighSpeedCounter.ZeroPassEvent);

    HighSpeedCounterIo.Outputs.Slot0.Write(Q_HighSpeedCounter.Slot0);
    HighSpeedCounterIo.Outputs.Slot1.Write(Q_HighSpeedCounter.Slot1);
    HighSpeedCounterIo.Outputs.LoadSlotX.Write(Q_HighSpeedCounter.LoadSlotX);
    HighSpeedCounterIo.Outputs.EnableCapture.Write(Q_HighSpeedCounter.EnableCapture);
    HighSpeedCounterIo.Outputs.EnableSynchronizationDown.Write(Q_HighSpeedCounter.EnableSynchronizationDown);
    HighSpeedCounterIo.Outputs.EnableSynchronizationUp.Write(Q_HighSpeedCounter.EnableSynchronizationUp);
    HighSpeedCounterIo.Outputs.SetDq1.Write(Q_HighSpeedCounter.SetDq1);
    HighSpeedCounterIo.Outputs.SetDq0.Write(Q_HighSpeedCounter.SetDq0);
    HighSpeedCounterIo.Outputs.TmCtrlDq1.Write(Q_HighSpeedCounter.TmCtrlDq1);
    HighSpeedCounterIo.Outputs.TmCtrlDq0.Write(Q_HighSpeedCounter.TmCtrlDq0);
    HighSpeedCounterIo.Outputs.SoftwareGate.Write(Q_HighSpeedCounter.SoftwareGate);
    HighSpeedCounterIo.Outputs.CountDirection.Write(Q_HighSpeedCounter.CountDirection);
    HighSpeedCounterIo.Outputs.ResetEvents.Write(Q_HighSpeedCounter.ResetEvents);
    HighSpeedCounterIo.Outputs.ResetErrors.Write(Q_HighSpeedCounter.ResetErrors);

    SpeedWheelIo.ReferenceSensor.Read(DI_B_SpeedWheel_OneTurnSwitch);

    RollerBedIo.Inputs.Error.Read(DI_B_RollerBed_External_Error);
    RollerBedIo.Outputs.Forward.Write(DQ_B_RollerBed_Forward);
    RollerBedIo.Outputs.Reverse.Write(DQ_B_RollerBed_Reverse);
    RollerBedIo.Outputs.RemoteControl.Write(DQ_B_RollerBed_RemoteControl);
    RollerBedIo.Outputs.SpeedReference.Write(AQ_B_RollerBed_SpeedReference);
END_PROGRAM