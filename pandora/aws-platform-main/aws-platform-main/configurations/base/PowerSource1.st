USING Esab.WeldSystem.PowerSources;
USING Esab.WeldSystem;
USING Esab.Io;
USING Esab.Utils.Assets;
USING Esab.Utils.Timer;
Using Esab.Utils.Alarming;

USING Siemens.Simatic.S71500.Tasks;
USING Siemens.Simatic.S71500.Alarming;

CONFIGURATION PowerSource1Configuration

    TASK PowerSource1IoTask : ProgramCycle;

    PROGRAM PowerSource1IoProgram WITH PowerSource1IoTask: PowerSource1IoReadWrite;

    // Constants
    VAR_GLOBAL CONSTANT
        PAB1_HWID : WORD := WORD#261;
        PAB1_DEVID : WORD := WORD#262;
    END_VAR

    // Objects
    VAR_GLOBAL
        PowerSource1 : Aristo1000.PowerSource;
        Ps1HeartbeatTimer : OnDelay;
        Ps1Heartbeat : Heartbeat;
        Ps1AsyncInterface : AsyncInterface;
        Ps1AsyncReader : AsyncReader;
        Ps1AsyncWriter : AsyncWriter;
        Ps1AsyncCommands : AsyncCommands;
    END_VAR

    // Alarms
    VAR_GLOBAL
        // PS1 Alarms
        Ps1ErrorAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Power source 1: Error."}
        Ps1ErrorAlarm : ProgramAlarm;

        Ps1HeartbeatAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Power source 1: No heartbeat."}
        Ps1HeartbeatAlarm : ProgramAlarm;

        Ps1AsyncCommandReadAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Power source 1: Async command (READ) @1%u@ failed."}
        Ps1AsyncCommandReadAlarm : ProgramAlarm;

        Ps1AsyncCommandWriteAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Power source 1: Async command (WRITE) @1%u@ failed."}
        Ps1AsyncCommandWriteAlarm : ProgramAlarm;

        Ps1AsyncCommandNullAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Power source 1: Async command response is NULL."}
        Ps1AsyncCommandNullAlarm : ProgramAlarm;

        Ps1SetupAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Power source 1: Setup error."}
        Ps1SetupAlarm : ProgramAlarm;

        // Ps1 Async Interface Alarms
        Ps1InvalidCommandTypeAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Power source 1: Async Interface: Invalid command type."}
        PS1InvalidCommandTypeAlarm : ProgramAlarm;

        Ps1PoppedNullCommandAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Power source 1: Async Interface: The popped command is NULL."}
        Ps1PoppedNullCommandAlarm : ProgramAlarm;

        Ps1InvalidCommandAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Power source 1: Async Interface: The type of the popped command is not AsyncCommand."}
        Ps1InvalidCommandAlarm : ProgramAlarm;

        // PS1 Async Reader Alarms
        Ps1AsyncReaderErrorAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Power source 1: Async Reader: Error when reading async data, status: @1%u@."}
        Ps1AsyncReaderErrorAlarm : ProgramAlarm;

        // PS1 Async Writer Alarms
        Ps1AsyncWriterErrorAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Power source 1: Async Writer: Error when writing async data, status: @1%u@."}
        Ps1AsyncWriterErrorAlarm : ProgramAlarm;
    END_VAR

    // Interface
    VAR_GLOBAL
        {S7.Extern=ReadWrite}
        PS1_Data : Io;
    END_VAR

    // Retain
    VAR_GLOBAL RETAIN
        Ps1RuntimeParameters : RuntimeParameters;
        Ps1HardwareConfiguration : HardwareConfiguration;
    END_VAR
END_CONFIGURATION

FUNCTION InitializePs1
    VAR_INPUT
        assetsManager : IAssetsManager;
    END_VAR

    VAR_EXTERNAL CONSTANT
        PAB1_HWID : WORD;
        PAB1_DEVID : WORD;
    END_VAR

    VAR_EXTERNAL
        PS1_Data : Io;

        PowerSource1 : Aristo1000.PowerSource;
        Ps1HeartbeatTimer : OnDelay;
        Ps1Heartbeat : Heartbeat;
        Ps1AsyncInterface : AsyncInterface;
        Ps1AsyncReader : AsyncReader;
        Ps1AsyncWriter : AsyncWriter;
        Ps1AsyncCommands : AsyncCommands;
        Ps1RuntimeParameters : RuntimeParameters;
        Ps1HardwareConfiguration : HardwareConfiguration;

        Ps1ErrorAlarmWrapper : AlarmWrapper;
        Ps1HeartbeatAlarmWrapper : AlarmWrapper;
        Ps1AsyncCommandReadAlarmWrapper : AlarmWrapper;
        Ps1AsyncCommandWriteAlarmWrapper : AlarmWrapper;
        Ps1AsyncCommandNullAlarmWrapper : AlarmWrapper;
        Ps1SetupAlarmWrapper : AlarmWrapper;

        Ps1ErrorAlarm : ProgramAlarm;
        Ps1HeartbeatAlarm : ProgramAlarm;
        Ps1AsyncCommandReadAlarm : ProgramAlarm;
        Ps1AsyncCommandWriteAlarm : ProgramAlarm;
        Ps1AsyncCommandNullAlarm : ProgramAlarm;
        Ps1SetupAlarm : ProgramAlarm;

        Ps1InvalidCommandTypeAlarmWrapper : AlarmWrapper;
        Ps1PoppedNullCommandAlarmWrapper : AlarmWrapper;
        Ps1InvalidCommandAlarmWrapper : AlarmWrapper;

        Ps1InvalidCommandTypeAlarm : ProgramAlarm;
        Ps1PoppedNullCommandAlarm : ProgramAlarm;
        Ps1InvalidCommandAlarm : ProgramAlarm;

        Ps1AsyncReaderErrorAlarmWrapper : AlarmWrapper;
        Ps1AsyncWriterErrorAlarmWrapper : AlarmWrapper;

        Ps1AsyncReaderErrorAlarm : ProgramAlarm;
        Ps1AsyncWriterErrorAlarm : ProgramAlarm;
    END_VAR

    // Setup heartbeat
    Ps1Heartbeat.Input := PS1_Data.Pab.Input.Heartbeat;
    Ps1Heartbeat.Timer := Ps1HeartbeatTimer;

    // Setup async interface
    Ps1AsyncReader.HwId := PAB1_HWID;
    Ps1AsyncWriter.HwId := PAB1_HWID;

    // Setup alarm wrappers
    Ps1ErrorAlarmWrapper.Setup(REF(Ps1ErrorAlarm));
    Ps1HeartbeatAlarmWrapper.Setup(REF(Ps1HeartbeatAlarm));
    Ps1AsyncCommandReadAlarmWrapper.Setup(REF(Ps1AsyncCommandReadAlarm));
    Ps1AsyncCommandWriteAlarmWrapper.Setup(REF(Ps1AsyncCommandWriteAlarm));
    Ps1AsyncCommandNullAlarmWrapper.Setup(REF(Ps1AsyncCommandNullAlarm));
    Ps1SetupAlarmWrapper.Setup(REF(Ps1SetupAlarm));

    // Setup PowerSource using Setup method
    PowerSource1.Setup(
        id := UINT#1,
        ioDeviceId := PAB1_DEVID,
        heartbeat := Ps1Heartbeat,
        io := REF(PS1_Data),
        runtimeParameters := REF(Ps1RuntimeParameters),
        hardwareConfiguration := REF(Ps1HardwareConfiguration),
        asyncInterface := Ps1AsyncInterface,
        errorAlarm := Ps1ErrorAlarmWrapper,
        heartbeatAlarm := Ps1HeartbeatAlarmWrapper,
        asyncCommandReadAlarm := Ps1AsyncCommandReadAlarmWrapper,
        asyncCommandWriteAlarm := Ps1AsyncCommandWriteAlarmWrapper,
        asyncCommandNullAlarm := Ps1AsyncCommandNullAlarmWrapper,
        setupAlarm := Ps1SetupAlarmWrapper
    );

    Ps1InvalidCommandTypeAlarmWrapper.Setup(REF(Ps1InvalidCommandTypeAlarm));
    Ps1PoppedNullCommandAlarmWrapper.Setup(REF(Ps1PoppedNullCommandAlarm));
    Ps1InvalidCommandAlarmWrapper.Setup(REF(Ps1InvalidCommandAlarm));

    // Setup AsyncInterface with Setup method
    Ps1AsyncInterface.Setup(
        reader := Ps1AsyncReader,
        writer := Ps1AsyncWriter,
        invalidCommandTypeAlarm := Ps1InvalidCommandTypeAlarmWrapper,
        poppedNullCommandAlarm := Ps1PoppedNullCommandAlarmWrapper,
        invalidCommandAlarm := Ps1InvalidCommandAlarmWrapper
    );
    Ps1AsyncInterface.SetListener(PowerSource1);

    Ps1AsyncReaderErrorAlarmWrapper.Setup(REF(Ps1AsyncReaderErrorAlarm));
    Ps1AsyncWriterErrorAlarmWrapper.Setup(REF(Ps1AsyncWriterErrorAlarm));

    Ps1AsyncReader.ErrorAlarm := Ps1AsyncReaderErrorAlarmWrapper;
    Ps1AsyncWriter.ErrorAlarm := Ps1AsyncWriterErrorAlarmWrapper;

    PowerSource1.SetIdentifier(Esab.AssetIdentifier#PowerSource1);
    assetsManager.RegisterAsset(REF(PowerSource1));
END_FUNCTION

PROGRAM PowerSource1IoReadWrite
    VAR_EXTERNAL
        PowerSource1 : Aristo1000.PowerSource;

        PS1_Data : Io;
        I_Pab1 : RawPabToController;
        Q_Pab1 : RawControllerToPab;
        DQ_B_PowerSource1_RemoteStart : BOOL;
    END_VAR

    PabRead(REF(PS1_Data.Pab.Input), REF(I_Pab1));

    PabWrite(REF(PS1_Data.Pab.Output), REF(Q_Pab1));

    PS1_Data.Output.RemoteStart.Write(DQ_B_PowerSource1_RemoteStart);
END_PROGRAM