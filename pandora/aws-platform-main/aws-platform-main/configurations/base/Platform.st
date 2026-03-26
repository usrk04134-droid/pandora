USING Esab.Hmi;
USING Esab.Utils;
USING Esab.Utils.Assets;
USING Esab.Io;
USING Esab.Utils.Timer;
USING Esab.Platforms;
USING Esab.Hmi.Modules;

USING Siemens.Simatic.S71500.Tasks;

CONFIGURATION Platform
    TASK MainTask : ProgramCycle;
    TASK AwsStartup : Startup;

    PROGRAM MainProgram WITH MainTask: MainProgram;
    PROGRAM StartupProgram WITH AwsStartup : InitializeConfiguration;

    VAR_GLOBAL
        AssetsManager : AssetsManager;
    END_VAR

END_CONFIGURATION

/// This program is used to wire up I/O and other initialization to all the different objects.
PROGRAM InitializeConfiguration

    VAR_EXTERNAL
        AssetsManager : Esab.Utils.Assets.AssetsManager;
    END_VAR

    InitializeGlobalState(AssetsManager);
    InitializeWebApi(AssetsManager);
    InitializeP(AssetsManager);
    InitializeC(AssetsManager);
    InitializeEmergencyStopCircuit(AssetsManager);
    InitializeRollerBed(AssetsManager);
    InitializeBigBagFluxSystem(AssetsManager);
    InitializePs1(AssetsManager);
    InitializePs2(AssetsManager);
    InitializeSlideCrossAxis(AssetsManager);
    InitializeMultiWeldSystem(AssetsManager);
    InitializeAdaptio(AssetsManager);
    InitializeWeldHeadManipulator(AssetsManager);
    InitializeUps(AssetsManager);
END_PROGRAM

PROGRAM MainProgram
    VAR_EXTERNAL
        AssetsManager : AssetsManager;
        WebApi : Esab.Api.WebApi;
        P_Hmi : Esab.Hmi.P_Hmi;
        C_Hmi : Esab.Hmi.C_Hmi;
        Adaptio : Esab.Modes.Adaptio;
    END_VAR

    AssetsManager.Execute();

    Adaptio.Execute();
    WebApi.Execute();
    P_Hmi.Execute();
    C_Hmi.Execute();
END_PROGRAM