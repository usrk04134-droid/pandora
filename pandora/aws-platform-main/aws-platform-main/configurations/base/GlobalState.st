USING Esab.WeldSystem.Flux;
USING Esab.Utils.Alarming;
USING Esab.Utils.Assets;
USING Esab.Modes;

USING Siemens.Simatic.S71500.Tasks;
USING Siemens.Simatic.S71500.Alarming;

CONFIGURATION GlobalStateConfiguration

    // Constants
    VAR_GLOBAL CONSTANT
    END_VAR

    // Objects
    VAR_GLOBAL
        {S7.Extern=Read}
        GlobalState : Esab.GlobalState;
    END_VAR

    // Alarms
    VAR_GLOBAL
        GlobalStateSetupAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Global state: Setup error."}
        GlobalStateSetupAlarm : ProgramAlarm;
    END_VAR

    // Interface
    VAR_GLOBAL
    END_VAR
END_CONFIGURATION

FUNCTION InitializeGlobalState
    VAR_INPUT
        assetsManager : IAssetsManager;
    END_VAR

    VAR_EXTERNAL
        GlobalState : Esab.GlobalState;

        GlobalStateSetupAlarmWrapper : AlarmWrapper;
        GlobalStateSetupAlarm : ProgramAlarm;
    END_VAR

    GlobalStateSetupAlarmWrapper.Setup(REF(GlobalStateSetupAlarm));

    GlobalState.Setup(assetsManager, GlobalStateSetupAlarmWrapper);

    GlobalState.SetIdentifier(Esab.AssetIdentifier#GlobalState);
    assetsManager.RegisterAsset(REF(GlobalState));

    // By default we set the GlobalState mode to be Adaptio
    GlobalState.SetMode(Esab.AwsPlatformMode#Adaptio);
END_FUNCTION