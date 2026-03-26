USING Esab.WeldSystem.PowerSources;
USING Esab.WeldSystem;
USING Esab.Io;
USING Esab.Utils.Assets;
USING Esab.Utils.Timer;
USING Esab.Utils.Alarming;

USING Siemens.Simatic.S71500.Tasks;
USING Siemens.Simatic.S71500.Alarming;

CONFIGURATION PowerSource2Configuration

    TASK PowerSource2IoTask : ProgramCycle;

    PROGRAM PowerSource2IoProgram WITH PowerSource2IoTask: PowerSource2IoReadWrite;

    // Constants
    VAR_GLOBAL CONSTANT
        PAB2_HWID : WORD := WORD#269;
        PAB2_DEVID : WORD := WORD#264;
    END_VAR

    // Objects
    VAR_GLOBAL
        PowerSource2 : Aristo1000.PowerSource;
        Ps2HeartbeatTimer : OnDelay;
        Ps2Heartbeat : Heartbeat;
        Ps2AsyncInterface : AsyncInterface;
        Ps2AsyncReader : AsyncReader;
        Ps2AsyncWriter : AsyncWriter;
        Ps2AsyncCommands : AsyncCommands;
    END_VAR

    // Alarms
    VAR_GLOBAL
        Ps2ErrorAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Power source 2: Error."}
        Ps2ErrorAlarm : ProgramAlarm;

        Ps2HeartbeatAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Power source 2: No heartbeat."}
        Ps2HeartbeatAlarm : ProgramAlarm;

        Ps2AsyncCommandReadAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Power source 2: Async command (READ) @1%u@ failed."}
        Ps2AsyncCommandReadAlarm : ProgramAlarm;

        Ps2AsyncCommandWriteAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Power source 2: Async command (WRITE) @1%u@ failed."}
        Ps2AsyncCommandWriteAlarm : ProgramAlarm;

        Ps2AsyncCommandNullAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Power source 2: Async command response is NULL."}
        Ps2AsyncCommandNullAlarm : ProgramAlarm;

        Ps2SetupAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Power source 2: Setup error."}
        Ps2SetupAlarm : ProgramAlarm;

        // Ps2 Async Interface Alarms
        Ps2InvalidCommandTypeAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Power source 2 - Async Interface: Invalid command type."}
        Ps2InvalidCommandTypeAlarm : ProgramAlarm;

        Ps2PoppedNullCommandAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Power source 2 - Async Interface: The popped command is NULL."}
        Ps2PoppedNullCommandAlarm : ProgramAlarm;

        Ps2InvalidCommandAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Power source 2 - Async Interface: The type of the popped command is not AsyncCommand."}
        Ps2InvalidCommandAlarm : ProgramAlarm;

        // Ps2 Async Reader Alarms
        Ps2AsyncReaderErrorAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Power source 2 - Async Reader: Error when reading async data, status: @1%u@."}
        Ps2AsyncReaderErrorAlarm : ProgramAlarm;

        // Ps2 Async Writer Alarms
        Ps2AsyncWriterErrorAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Power source 2 - Async Writer: Error when writing async data, status: @1%u@."}
        Ps2AsyncWriterErrorAlarm : ProgramAlarm;
    END_VAR

    // Interface
    VAR_GLOBAL
        {S7.Extern=ReadWrite}
        PS2_Data : Io;
    END_VAR

    // Retained
    VAR_GLOBAL RETAIN
        Ps2RuntimeParameters : RuntimeParameters;
        Ps2HardwareConfiguration : HardwareConfiguration;
    END_VAR
END_CONFIGURATION

FUNCTION InitializePs2
    VAR_INPUT
        assetsManager : IAssetsManager;
    END_VAR

    VAR_EXTERNAL CONSTANT
        PAB2_HWID : WORD;
        PAB2_DEVID : WORD;
    END_VAR

    VAR_EXTERNAL
        PS2_Data : Io;

        PowerSource2 : Aristo1000.PowerSource;
        Ps2HeartbeatTimer : OnDelay;
        Ps2Heartbeat : Heartbeat;
        Ps2AsyncInterface : AsyncInterface;
        Ps2AsyncReader : AsyncReader;
        Ps2AsyncWriter : AsyncWriter;
        Ps2AsyncCommands : AsyncCommands;
        Ps2RuntimeParameters : RuntimeParameters;
        Ps2HardwareConfiguration : HardwareConfiguration;

        Ps2ErrorAlarmWrapper : AlarmWrapper;
        Ps2HeartbeatAlarmWrapper : AlarmWrapper;
        Ps2AsyncCommandReadAlarmWrapper : AlarmWrapper;
        Ps2AsyncCommandWriteAlarmWrapper : AlarmWrapper;
        Ps2AsyncCommandNullAlarmWrapper : AlarmWrapper;
        Ps2SetupAlarmWrapper : AlarmWrapper;

        Ps2ErrorAlarm : ProgramAlarm;
        Ps2HeartbeatAlarm : ProgramAlarm;
        Ps2AsyncCommandReadAlarm : ProgramAlarm;
        Ps2AsyncCommandWriteAlarm : ProgramAlarm;
        Ps2AsyncCommandNullAlarm : ProgramAlarm;
        Ps2SetupAlarm : ProgramAlarm;

        Ps2InvalidCommandTypeAlarmWrapper : AlarmWrapper;
        Ps2PoppedNullCommandAlarmWrapper : AlarmWrapper;
        Ps2InvalidCommandAlarmWrapper : AlarmWrapper;

        Ps2InvalidCommandTypeAlarm : ProgramAlarm;
        Ps2PoppedNullCommandAlarm : ProgramAlarm;
        Ps2InvalidCommandAlarm : ProgramAlarm;

        Ps2AsyncReaderErrorAlarmWrapper : AlarmWrapper;
        Ps2AsyncWriterErrorAlarmWrapper : AlarmWrapper;

        Ps2AsyncReaderErrorAlarm : ProgramAlarm;
        Ps2AsyncWriterErrorAlarm : ProgramAlarm;
    END_VAR

    // Setup heartbeat
    Ps2Heartbeat.Input := PS2_Data.Pab.Input.Heartbeat;
    Ps2Heartbeat.Timer := Ps2HeartbeatTimer;

    // Setup async interface
    Ps2AsyncReader.HwId := PAB2_HWID;
    Ps2AsyncWriter.HwId := PAB2_HWID;

    // Setup alarm wrappers
    Ps2ErrorAlarmWrapper.Setup(REF(Ps2ErrorAlarm));
    Ps2HeartbeatAlarmWrapper.Setup(REF(Ps2HeartbeatAlarm));
    Ps2AsyncCommandReadAlarmWrapper.Setup(REF(Ps2AsyncCommandReadAlarm));
    Ps2AsyncCommandWriteAlarmWrapper.Setup(REF(Ps2AsyncCommandWriteAlarm));
    Ps2AsyncCommandNullAlarmWrapper.Setup(REF(Ps2AsyncCommandNullAlarm));
    Ps2SetupAlarmWrapper.Setup(REF(Ps2SetupAlarm));

    // Setup PowerSource using Setup method
    PowerSource2.Setup(
        id := UINT#2,
        ioDeviceId := PAB2_DEVID,
        heartbeat := Ps2Heartbeat,
        io := REF(PS2_Data),
        runtimeParameters := REF(Ps2RuntimeParameters),
        hardwareConfiguration := REF(Ps2HardwareConfiguration),
        asyncInterface := Ps2AsyncInterface,
        errorAlarm := Ps2ErrorAlarmWrapper,
        heartbeatAlarm := Ps2HeartbeatAlarmWrapper,
        asyncCommandReadAlarm := Ps2AsyncCommandReadAlarmWrapper,
        asyncCommandWriteAlarm := Ps2AsyncCommandWriteAlarmWrapper,
        asyncCommandNullAlarm := Ps2AsyncCommandNullAlarmWrapper,
        setupAlarm := Ps2SetupAlarmWrapper
    );

    Ps2InvalidCommandTypeAlarmWrapper.Setup(REF(Ps2InvalidCommandTypeAlarm));
    Ps2PoppedNullCommandAlarmWrapper.Setup(REF(Ps2PoppedNullCommandAlarm));
    Ps2InvalidCommandAlarmWrapper.Setup(REF(Ps2InvalidCommandAlarm));

    // Setup AsyncInterface with Setup method
    Ps2AsyncInterface.Setup(
        reader := Ps2AsyncReader,
        writer := Ps2AsyncWriter,
        invalidCommandTypeAlarm := Ps2InvalidCommandTypeAlarmWrapper,
        poppedNullCommandAlarm := Ps2PoppedNullCommandAlarmWrapper,
        invalidCommandAlarm := Ps2InvalidCommandAlarmWrapper
    );
    Ps2AsyncInterface.SetListener(PowerSource2);

    Ps2AsyncReaderErrorAlarmWrapper.Setup(REF(Ps2AsyncReaderErrorAlarm));
    Ps2AsyncWriterErrorAlarmWrapper.Setup(REF(Ps2AsyncWriterErrorAlarm));

    Ps2AsyncReader.ErrorAlarm := Ps2AsyncReaderErrorAlarmWrapper;
    Ps2AsyncWriter.ErrorAlarm := Ps2AsyncWriterErrorAlarmWrapper;

    PowerSource2.SetIdentifier(Esab.AssetIdentifier#PowerSource2);
    assetsManager.RegisterAsset(REF(PowerSource2));
END_FUNCTION

PROGRAM PowerSource2IoReadWrite
    VAR_EXTERNAL
        PowerSource2 : Aristo1000.PowerSource;

        PS2_Data : Io;
        I_Pab2 : RawPabToController;
        Q_Pab2 : RawControllerToPab;
        DQ_B_PowerSource2_RemoteStart : BOOL;
    END_VAR

    PabRead(REF(PS2_Data.Pab.Input), REF(I_Pab2));

    PabWrite(REF(PS2_Data.Pab.Output), REF(Q_Pab2));

    PS2_Data.Output.RemoteStart.Write(DQ_B_PowerSource2_RemoteStart);
END_PROGRAM