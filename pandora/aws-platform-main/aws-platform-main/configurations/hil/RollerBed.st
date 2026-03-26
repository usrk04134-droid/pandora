USING Esab.Motion;
USING Esab.Motion.MeasurementSystem;
Using Esab.Utils.Alarming;
USING Esab.Utils.Assets;
USING Esab.Io;
USING Esab.Utils.Filters;
USING Esab.Utils.Timer;

USING Siemens.Simatic.S71500.Alarming;

CONFIGURATION RollerBedConfiguration
    // Constants
    VAR_GLOBAL CONSTANT
    END_VAR

    // Objects
    VAR_GLOBAL
        RollerBed : SimulatedAnalogAxis;
        SpeedMeasurementTimer : OnDelay;
    END_VAR

    // Alarms
    VAR_GLOBAL
        RollerBedSetupAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Roller Bed: Setup error."}
        RollerBedSetupAlarm : ProgramAlarm;
    END_VAR

    // Interface
    VAR_GLOBAL
    END_VAR

    VAR_GLOBAL RETAIN
        RollerBedRuntimeParameters : AnalogAxisRuntimeParameters;
        RollerBedHardwareConfiguration : AnalogAxisHardwareConfiguration;
    END_VAR
END_CONFIGURATION

FUNCTION InitializeRollerBed
    VAR_INPUT
        assets : IAssetsManager;
    END_VAR

    VAR_EXTERNAL
        RollerBed : SimulatedAnalogAxis;
        RollerBedRuntimeParameters : AnalogAxisRuntimeParameters;
        RollerBedHardwareConfiguration : AnalogAxisHardwareConfiguration;

        RollerBedSetupAlarmWrapper : AlarmWrapper;
        RollerBedSetupAlarm : ProgramAlarm;
    END_VAR

    RollerBedSetupAlarmWrapper.Setup(REF(RollerBedSetupAlarm));

    RollerBed.Setup(REF(RollerBedRuntimeParameters),
                    REF(RollerBedHardwareConfiguration),
                    RollerBedSetupAlarmWrapper);

    RollerBed.SetIdentifier(Esab.AssetIdentifier#RollerBed);
    assets.RegisterAsset(REF(RollerBed));
END_FUNCTION
