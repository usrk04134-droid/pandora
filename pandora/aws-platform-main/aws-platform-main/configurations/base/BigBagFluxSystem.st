USING Esab.WeldSystem.Flux;
Using Esab.Utils.Alarming;
Using Esab.Utils.Assets;

USING Siemens.Simatic.S71500.Tasks;
USING Siemens.Simatic.S71500.Alarming;

CONFIGURATION BigBagFluxSystemConfiguration

    TASK BigBagFluxSystemIoTask : ProgramCycle;

    PROGRAM BigBagFluxSystemIoReadWrite WITH BigBagFluxSystemIoTask: BigBagFluxSystemIoReadWrite;

    // Constants
    VAR_GLOBAL CONSTANT
    END_VAR

    // Objects
    VAR_GLOBAL
        {S7.Extern=Read}
        FluxSystem : BigBag.FluxSystem;
    END_VAR

    // Alarms
    VAR_GLOBAL
        BigBagErrorAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Flux system (Big Bag): General error."}
        BigBagErrorAlarm : ProgramAlarm;

        BigBagSetupAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Flux system (Big Bag): Setup error."}
        BigBagSetupAlarm : ProgramAlarm;
    END_VAR

    // Interface
    VAR_GLOBAL
        {S7.Extern=ReadWrite}
        FluxSystemIo : BigBag.Io;
    END_VAR
END_CONFIGURATION

FUNCTION InitializeBigBagFluxSystem
    VAR_INPUT
        Assets : IAssetsManager;
    END_VAR

    VAR_EXTERNAL
        FluxSystemIo : BigBag.Io;

        FluxSystem : BigBag.FluxSystem;

        BigBagErrorAlarmWrapper : AlarmWrapper;
        BigBagErrorAlarm : ProgramAlarm;
        BigBagSetupAlarmWrapper : AlarmWrapper;
        BigBagSetupAlarm : ProgramAlarm;
    END_VAR

    FluxSystemIo.Input.Temperature.Scale := REAL#0.1;

    BigBagErrorAlarmWrapper.Setup(REF(BigBagErrorAlarm));
    BigBagSetupAlarmWrapper.Setup(REF(BigBagSetupAlarm));
    FluxSystem.Setup(REF(FluxSystemIo), BigBagErrorAlarmWrapper, BigBagSetupAlarmWrapper);

    FluxSystem.SetIdentifier(Esab.AssetIdentifier#FluxSystem);
    Assets.RegisterAsset(REF(FluxSystem));
END_FUNCTION

PROGRAM BigBagFluxSystemIoReadWrite
    VAR_EXTERNAL
        FluxSystemIo : BigBag.Io;
        DI_B_FluxSystem_Error : BOOL;

        DQ_H_FluxSystem_Recover : BOOL;
        DQ_H_FluxSystem_Release : BOOL;
        AI_B_FluxSystem_Temperature : INT;
    END_VAR

    FluxSystemIo.Input.BigBagError.Read(DI_B_FluxSystem_Error);
    FluxSystemIo.Input.Temperature.Read(AI_B_FluxSystem_Temperature);

    FluxSystemIo.Output.Release.Write(DQ_H_FluxSystem_Release);
    FluxSystemIo.Output.Recover.Write(DQ_H_FluxSystem_Recover);
END_PROGRAM