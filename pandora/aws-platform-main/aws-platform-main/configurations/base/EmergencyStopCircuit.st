USING Esab.Hmi;
USING Esab.Utils.Timer;
USING Esab.Hmi.Modules;
USING Esab.Utils.Assets;
USING Esab.Utils.EmergencyStop;

USING Siemens.Simatic.S71500.Tasks;

CONFIGURATION EmergencyStopCircuit_Configuration

    TASK EmergencyStopCircuit_IoTask : ProgramCycle;

    PROGRAM EmergencyStopCircuit_IoReadWrite WITH EmergencyStopCircuit_IoTask: EmergencyStopCircuit_IoReadWrite;

    // Constants
    VAR_GLOBAL CONSTANT
    END_VAR

    // Objects
    VAR_GLOBAL
        EmergencyStopCircuit : EmergencyStopCircuit;
    END_VAR

    // Interface
    VAR_GLOBAL
        {S7.Extern=ReadWrite}
        EmergencyStopCircuitIo : EmergencyStopCircuitIo;
    END_VAR
END_CONFIGURATION

FUNCTION InitializeEmergencyStopCircuit
    VAR_INPUT
        Assets : IAssetsManager;
    END_VAR

    VAR_EXTERNAL
        EmergencyStopCircuit : EmergencyStopCircuit;
        EmergencyStopCircuitIo : EmergencyStopCircuitIo;
    END_VAR

    EmergencyStopCircuit.Io := REF(EmergencyStopCircuitIo);
    EmergencyStopCircuit.SetIdentifier(Esab.AssetIdentifier#EmergencyStopCircuit);
    Assets.RegisterAsset(REF(EmergencyStopCircuit));
END_FUNCTION

PROGRAM EmergencyStopCircuit_IoReadWrite
    VAR_EXTERNAL
        EmergencyStopCircuitIo : EmergencyStopCircuitIo;

        DI_B_System_EmergencyStop_OK : BOOL;
    END_VAR

    EmergencyStopCircuitIo.LoopClosed.Read(DI_B_System_EmergencyStop_OK);
END_PROGRAM