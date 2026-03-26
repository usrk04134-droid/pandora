USING Esab.Utils.Alarming;
USING Esab.Utils.Assets;
USING Esab.Motion;

USING Siemens.Simatic.S71500.Tasks;
USING Siemens.Simatic.S71500.Alarming;

CONFIGURATION WeldHeadManipulatorConfiguration

    // Constants
    VAR_GLOBAL CONSTANT
    END_VAR

    // Objects
    VAR_GLOBAL
        {S7.Extern=Read}
        WeldHeadManipulator : WeldHeadManipulator;
    END_VAR

    // Alarms
    VAR_GLOBAL
        WeldHeadManipulatorSetupAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Global state: Setup error."}
        WeldHeadManipulatorSetupAlarm : ProgramAlarm;
    END_VAR

    // Interface
    VAR_GLOBAL
    END_VAR

    VAR_GLOBAL RETAIN
        WeldHeadManipulatorRuntimeParameters : WeldHeadManipulatorRuntimeParameters;
        WeldHeadManipulatorHardwareConfiguration : WeldHeadManipulatorHardwareConfiguration;
    END_VAR
END_CONFIGURATION

FUNCTION InitializeWeldHeadManipulator
    VAR_INPUT
        assetsManager : IAssetsManager;
    END_VAR

    VAR_EXTERNAL
        WeldHeadManipulator : WeldHeadManipulator;
        WeldHeadManipulatorRuntimeParameters : WeldHeadManipulatorRuntimeParameters;
        WeldHeadManipulatorHardwareConfiguration : WeldHeadManipulatorHardwareConfiguration;

        WeldHeadManipulatorSetupAlarmWrapper : AlarmWrapper;
        WeldHeadManipulatorSetupAlarm : ProgramAlarm;
    END_VAR

    WeldHeadManipulatorSetupAlarmWrapper.Setup(REF(WeldHeadManipulatorSetupAlarm));

    WeldHeadManipulator.Setup(REF(WeldHeadManipulatorRuntimeParameters),
                              REF(WeldHeadManipulatorHardwareConfiguration),
                              assetsManager,
                              WeldHeadManipulatorSetupAlarmWrapper);

    WeldHeadManipulator.SetIdentifier(Esab.AssetIdentifier#WeldHeadManipulator);
    assetsManager.RegisterAsset(REF(WeldHeadManipulator));
END_FUNCTION