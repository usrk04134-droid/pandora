USING Esab.Utils.Alarming;
USING Esab.Utils.Assets;
USING Esab.WeldSystem;

USING Siemens.Simatic.S71500.Alarming;

CONFIGURATION WeldSystemOrchestratorConfiguration

    // Constants
    VAR_GLOBAL CONSTANT
    END_VAR

    // Objects
    VAR_GLOBAL
        WeldSystemOrchestrator : WeldSystemOrchestrator;
    END_VAR

    // Alarms
    VAR_GLOBAL
        WeldSystemOrchestratorSetupAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Weld system: Setup error."}
        WeldSystemOrchestratorSetupAlarm : ProgramAlarm;
    END_VAR

    // Interface
    VAR_GLOBAL
    END_VAR

    VAR_GLOBAL RETAIN
        WeldSystemOrchestratorRuntimeParameters : WeldSystemOrchestratorRuntimeParameters;
        WeldSystemOrchestratorHardwareConfiguration : WeldSystemOrchestratorHardwareConfiguration;
    END_VAR
END_CONFIGURATION

FUNCTION InitializeMultiWeldSystem
    VAR_INPUT
        assetsManager : IAssetsManager;
    END_VAR

    VAR_EXTERNAL
        WeldSystemOrchestrator : WeldSystemOrchestrator;
        WeldSystemOrchestratorRuntimeParameters : WeldSystemOrchestratorRuntimeParameters;
        WeldSystemOrchestratorHardwareConfiguration : WeldSystemOrchestratorHardwareConfiguration;
        WeldSystemOrchestratorSetupAlarmWrapper : AlarmWrapper;
        WeldSystemOrchestratorSetupAlarm : ProgramAlarm;
    END_VAR

    WeldSystemOrchestratorSetupAlarmWrapper.Setup(REF(WeldSystemOrchestratorSetupAlarm));

    WeldSystemOrchestrator.Setup(REF(WeldSystemOrchestratorRuntimeParameters),
                                 REF(WeldSystemOrchestratorHardwareConfiguration),
                                 assetsManager,
                                 WeldSystemOrchestratorSetupAlarmWrapper);

    WeldSystemOrchestrator.SetIdentifier(Esab.AssetIdentifier#WeldSystemOrchestrator);
    assetsManager.RegisterAsset(REF(WeldSystemOrchestrator));
END_FUNCTION
