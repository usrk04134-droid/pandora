USING Esab.Utils.Alarming;
USING Esab.Utils.Assets;
USING Esab.Utils.Timer;
USING Esab.Utils.Power;

USING Siemens.Simatic.S71500.Tasks;
USING Siemens.Simatic.S71500.Alarming;

CONFIGURATION Ups1600Configuration

    TASK Ups1600IoTask : ProgramCycle;

    PROGRAM Ups1600IoProgram WITH Ups1600IoTask: Ups1600IoReadWrite;

    // Constants
    VAR_GLOBAL CONSTANT
    END_VAR

    // Objects
    VAR_GLOBAL
        Ups : Ups1600;
    END_VAR

    // Alarms
    VAR_GLOBAL
        UpsInputVoltageOkAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "UPS: Input voltage NOT OK."}
        UpsInputVoltageOkAlarm : ProgramAlarm;

        UpsChargeInsufficientAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "UPS: Charge insufficient."}
        UpsChargeInsufficientAlarm : ProgramAlarm;

        UpsBatteryChangeAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "UPS: Battery change recommended."}
        UpsBatteryChangeAlarm : ProgramAlarm;

        UpsBatteryMaintenanceAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "UPS: Battery maintenance required."}
        UpsBatteryMaintenanceAlarm : ProgramAlarm;

        UpsUnknownBatteryAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "UPS: Unknown battery."}
        UpsUnknownBatteryAlarm : ProgramAlarm;

        UpsSetupAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "UPS: Setup error."}
        UpsSetupAlarm : ProgramAlarm;
    END_VAR

    // Interface
    VAR_GLOBAL
        UpsIo : Ups1600Io;
    END_VAR

    VAR_GLOBAL RETAIN
    END_VAR
END_CONFIGURATION

FUNCTION InitializeUps
    VAR_INPUT
        assets : IAssetsManager;
    END_VAR

    VAR_EXTERNAL
        Ups : Ups1600;
        UpsIo : Ups1600Io;

        UpsInputVoltageOkAlarmWrapper : AlarmWrapper;
        UpsInputVoltageOkAlarm : ProgramAlarm;

        UpsChargeInsufficientAlarmWrapper : AlarmWrapper;
        UpsChargeInsufficientAlarm : ProgramAlarm;

        UpsBatteryChangeAlarmWrapper : AlarmWrapper;
        UpsBatteryChangeAlarm : ProgramAlarm;

        UpsBatteryMaintenanceAlarmWrapper : AlarmWrapper;
        UpsBatteryMaintenanceAlarm : ProgramAlarm;

        UpsUnknownBatteryAlarmWrapper : AlarmWrapper;
        UpsUnknownBatteryAlarm : ProgramAlarm;

        UpsSetupAlarmWrapper : AlarmWrapper;
        UpsSetupAlarm : ProgramAlarm;
    END_VAR

    UpsInputVoltageOkAlarmWrapper.Setup(REF(UpsInputVoltageOkAlarm));
    UpsChargeInsufficientAlarmWrapper.Setup(REF(UpsChargeInsufficientAlarm));
    UpsBatteryChangeAlarmWrapper.Setup(REF(UpsBatteryChangeAlarm));
    UpsBatteryMaintenanceAlarmWrapper.Setup(REF(UpsBatteryMaintenanceAlarm));
    UpsUnknownBatteryAlarmWrapper.Setup(REF(UpsUnknownBatteryAlarm));
    UpsSetupAlarmWrapper.Setup(REF(UpsSetupAlarm));

    Ups.Setup(
        REF(UpsIo),
        UpsInputVoltageOkAlarmWrapper,
        UpsChargeInsufficientAlarmWrapper,
        UpsBatteryChangeAlarmWrapper,
        UpsBatteryMaintenanceAlarmWrapper,
        UpsUnknownBatteryAlarmWrapper,
        UpsSetupAlarmWrapper
    );

    Ups.SetIdentifier(Esab.AssetIdentifier#Ups);
    assets.RegisterAsset(REF(Ups));
END_FUNCTION

PROGRAM Ups1600IoReadWrite
    VAR_EXTERNAL
        UpsIo : Ups1600Io;
        I_Ups : RawFromUps1600;
    END_VAR

    Esab.Utils.Power.ReadUps1600Inputs(REF(UpsIo), REF(I_Ups));
END_PROGRAM