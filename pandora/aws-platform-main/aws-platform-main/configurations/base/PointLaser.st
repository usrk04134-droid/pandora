USING Esab.Peripheral;
Using Esab.Utils.Alarming;
Using Esab.Utils.Assets;

USING Siemens.Simatic.S71500.Tasks;
USING Siemens.Simatic.S71500.Alarming;

CONFIGURATION PointLaserConfiguration

    TASK PointLaserIoTask : ProgramCycle;

    PROGRAM PointLaserIoReadWrite WITH PointLaserIoTask: PointLaserIoReadWrite;

    // Constants
    VAR_GLOBAL CONSTANT
    END_VAR

    // Objects
    VAR_GLOBAL
        {S7.Extern=Read}
        PointLaser : ActivatableAsset;
    END_VAR

    // Alarms
    VAR_GLOBAL
        PointLaserSetupAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Point laser: Setup error."}
        PointLaserSetupAlarm : ProgramAlarm;
    END_VAR

    // Interface
    VAR_GLOBAL
        {S7.Extern=ReadWrite}
        PointLaserIo : Io;
    END_VAR
END_CONFIGURATION

FUNCTION InitializePointLaser
    VAR_INPUT
        Assets : IAssetsManager;
    END_VAR

    VAR_EXTERNAL
        PointLaserIo : Io;
        PointLaser : ActivatableAsset;
        PointLaserSetupAlarmWrapper : AlarmWrapper;
        PointLaserSetupAlarm : ProgramAlarm;
    END_VAR

    PointLaserSetupAlarmWrapper.Setup(REF(PointLaserSetupAlarm));
    PointLaser.Setup(REF(PointLaserIo), PointLaserSetupAlarmWrapper);

    PointLaser.SetIdentifier(Esab.AssetIdentifier#PointLaser);
    Assets.RegisterAsset(REF(PointLaser));
END_FUNCTION

PROGRAM PointLaserIoReadWrite
    VAR_EXTERNAL
        PointLaserIo : Io;
        DQ_H_LaserPointer_Enable : BOOL;
    END_VAR

    PointLaserIo.Active.Write(DQ_H_LaserPointer_Enable);
END_PROGRAM