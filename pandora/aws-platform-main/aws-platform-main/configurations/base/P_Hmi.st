USING Esab.Hmi;
USING Esab.Utils.Timer;
USING Esab.Hmi.Modules;
Using Esab.Utils.Alarming;
USING Esab.Utils.Assets;

USING Siemens.Simatic.S71500.Tasks;
USING Siemens.Simatic.S71500.Alarming;

CONFIGURATION P_Hmi_Configuration

    TASK P_Hmi_IoTask : ProgramCycle;

    PROGRAM P_Hmi_IoReadWrite WITH P_Hmi_IoTask: P_Hmi_IoReadWrite;

    // Constants
    VAR_GLOBAL CONSTANT
    END_VAR

    // Objects
    VAR_GLOBAL
        P_Hmi : P_Hmi;
        P_EmergencyStop_Reset : PushButton;
        P_FluxSystem_Release : PushButton;
        P_FluxSystem_Recover : PushButton;
        P_HighSpeedButton : PushButton;
        P_WireFeed1 : TwinPushButton;
        P_WireFeed2 : TwinPushButton;
        P_MotionJoystick_AxisSelection : PushButton;
        P_MotionJoystick : DiscreteJoystick;
        P_MotionJoystick_LongHoldTimer : OnDelay;
        P_AxisJog_AxisSelection : PushButton;
        P_AxisJog : TwinPushButton;
        P_Start : PushButton;
        P_Stop : PushButton;
    END_VAR

    // Alarms
    VAR_GLOBAL
        P_Hmi_SetupAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "P HMI: Setup error."}
        P_Hmi_SetupAlarm : ProgramAlarm;
    END_VAR

    // Interface
    VAR_GLOBAL
        {S7.Extern=ReadWrite}
        P_Io_EmergencyStop_Reset : PushButtonIo;
        {S7.Extern=ReadWrite}
        P_Io_FluxSystem_Release : PushButtonIo;
        {S7.Extern=ReadWrite}
        P_Io_FluxSystem_Recover : PushButtonIo;
        {S7.Extern=ReadWrite}
        P_Io_WireFeed1 : TwinPushButtonIo;
        {S7.Extern=ReadWrite}
        P_Io_WireFeed2 : TwinPushButtonIo;
        {S7.Extern=ReadWrite}
        P_Io_HighSpeedButton : PushButtonIo;
        {S7.Extern=ReadWrite}
        P_Io_MotionJoystick_AxisSelection : PushButtonIo;
        {S7.Extern=ReadWrite}
        P_Io_MotionJoystick : DiscreteJoystickIo;
        {S7.Extern=ReadWrite}
        P_Io_AxisJog_AxisSelection : PushButtonIo;
        {S7.Extern=ReadWrite}
        P_Io_AxisJog : TwinPushButtonIo;
        {S7.Extern=ReadWrite}
        P_Io_Start : PushButtonIo;
        {S7.Extern=ReadWrite}
        P_Io_Stop : PushButtonIo;
    END_VAR
END_CONFIGURATION

FUNCTION InitializeP
    VAR_INPUT
        assetsManager : IAssetsManager;
    END_VAR

    VAR_EXTERNAL
        P_Hmi : P_Hmi;
        P_EmergencyStop_Reset : PushButton;
        P_FluxSystem_Release : PushButton;
        P_FluxSystem_Recover : PushButton;
        P_HighSpeedButton : PushButton;
        P_WireFeed1 : TwinPushButton;
        P_WireFeed2 : TwinPushButton;
        P_MotionJoystick_AxisSelection : PushButton;
        P_MotionJoystick : DiscreteJoystick;
        P_MotionJoystick_LongHoldTimer : OnDelay;
        P_AxisJog_AxisSelection : PushButton;
        P_AxisJog : TwinPushButton;
        P_Start : PushButton;
        P_Stop : PushButton;

        P_Io_EmergencyStop_Reset : PushButtonIo;
        P_Io_FluxSystem_Release : PushButtonIo;
        P_Io_FluxSystem_Recover : PushButtonIo;
        P_Io_WireFeed1 : TwinPushButtonIo;
        P_Io_WireFeed2 : TwinPushButtonIo;
        P_Io_HighSpeedButton : PushButtonIo;
        P_Io_MotionJoystick_AxisSelection : PushButtonIo;
        P_Io_MotionJoystick : DiscreteJoystickIo;
        P_Io_AxisJog_AxisSelection : PushButtonIo;
        P_Io_AxisJog : TwinPushButtonIo;
        P_Io_Start : PushButtonIo;
        P_Io_Stop : PushButtonIo;

        P_Hmi_SetupAlarmWrapper : AlarmWrapper;
        P_Hmi_SetupAlarm : ProgramAlarm;
    END_VAR

    P_EmergencyStop_Reset.Setup(io := REF(P_Io_EmergencyStop_Reset));
    P_EmergencyStop_Reset.SetIdentifier(Esab.AssetIdentifier#P_PushButton_EmergencyStop_Reset);
    assetsManager.RegisterAsset(REF(P_EmergencyStop_Reset));

    P_FluxSystem_Release.Setup(io := REF(P_Io_FluxSystem_Release));
    P_FluxSystem_Release.SetIdentifier(Esab.AssetIdentifier#P_PushButton_FluxSystem_Release);
    assetsManager.RegisterAsset(REF(P_FluxSystem_Release));

    P_FluxSystem_Recover.Setup(io := REF(P_Io_FluxSystem_Recover));
    P_FluxSystem_Recover.SetIdentifier(Esab.AssetIdentifier#P_PushButton_FluxSystem_Recover);
    assetsManager.RegisterAsset(REF(P_FluxSystem_Recover));

    P_HighSpeedButton.Setup(io := REF(P_Io_HighSpeedButton));
    P_HighSpeedButton.SetIdentifier(Esab.AssetIdentifier#P_PushButton_System_HighSpeed);
    assetsManager.RegisterAsset(REF(P_HighSpeedButton));

    P_WireFeed1.Setup(io := REF(P_Io_WireFeed1));
    P_WireFeed1.SetIdentifier(Esab.AssetIdentifier#P_TwinPushButton_WireFeed1);
    assetsManager.RegisterAsset(REF(P_WireFeed1));

    P_WireFeed2.Setup(io := REF(P_Io_WireFeed2));
    P_WireFeed2.SetIdentifier(Esab.AssetIdentifier#P_TwinPushButton_WireFeed2);
    assetsManager.RegisterAsset(REF(P_WireFeed2));

    P_MotionJoystick_AxisSelection.Setup(io := REF(P_Io_MotionJoystick_AxisSelection));
    P_MotionJoystick_AxisSelection.SetIdentifier(Esab.AssetIdentifier#P_PushButton_MotionJoystick_AxisSelection);
    assetsManager.RegisterAsset(REF(P_MotionJoystick_AxisSelection));

    P_MotionJoystick.Setup(io := REF(P_Io_MotionJoystick), longHoldTimer := P_MotionJoystick_LongHoldTimer);
    P_MotionJoystick.SetIdentifier(Esab.AssetIdentifier#P_Joystick_MotionJoystick);
    assetsManager.RegisterAsset(REF(P_MotionJoystick));

    P_AxisJog_AxisSelection.Setup(io := REF(P_Io_AxisJog_AxisSelection));
    P_AxisJog_AxisSelection.SetIdentifier(Esab.AssetIdentifier#P_PushButton_AxisJog_AxisSelection);
    assetsManager.RegisterAsset(REF(P_AxisJog_AxisSelection));

    P_AxisJog.Setup(io := REF(P_Io_AxisJog));
    P_AxisJog.SetIdentifier(Esab.AssetIdentifier#P_TwinPushButton_AxisJog);
    assetsManager.RegisterAsset(REF(P_AxisJog));

    P_Start.Setup(io := REF(P_Io_Start));
    P_Start.SetIdentifier(Esab.AssetIdentifier#P_PushButton_Start);
    assetsManager.RegisterAsset(REF(P_Start));

    P_Stop.Setup(io := REF(P_Io_Stop));
    P_Stop.SetIdentifier(Esab.AssetIdentifier#P_PushButton_Stop);
    assetsManager.RegisterAsset(REF(P_Stop));

    P_Hmi_SetupAlarmWrapper.Setup(REF(P_Hmi_SetupAlarm));

    P_Hmi.Setup(assetsManager, P_Hmi_SetupAlarmWrapper);
END_FUNCTION

PROGRAM P_Hmi_IoReadWrite
    VAR_EXTERNAL
        P_Io_EmergencyStop_Reset : PushButtonIo;
        P_Io_FluxSystem_Release : PushButtonIo;
        P_Io_FluxSystem_Recover : PushButtonIo;
        P_Io_WireFeed1 : TwinPushButtonIo;
        P_Io_WireFeed2 : TwinPushButtonIo;
        P_Io_HighSpeedButton : PushButtonIo;
        P_Io_MotionJoystick_AxisSelection : PushButtonIo;
        P_Io_MotionJoystick : DiscreteJoystickIo;
        P_Io_AxisJog_AxisSelection : PushButtonIo;
        P_Io_AxisJog : TwinPushButtonIo;
        P_Io_Start : PushButtonIo;
        P_Io_Stop : PushButtonIo;

        DI_P_PushButton_EmergencyStop_Reset : BOOL;
        DQ_P_PushButton_EmergencyStop_Reset : BOOL;

        DI_P_PushButton_FluxSystem_Release : BOOL;
        DQ_P_PushButton_FluxSystem_Release : BOOL;

        DI_P_PushButton_FluxSystem_Recover : BOOL;
        DQ_P_PushButton_FluxSystem_Recover : BOOL;

        DI_P_PushButton_HighSpeed : BOOL;
        DQ_P_PushButton_HighSpeed : BOOL;

        DI_P_PushButton_WireFeed1_Up : BOOL;
        DI_P_PushButton_WireFeed1_Down : BOOL;

        DI_P_PushButton_WireFeed2_Up : BOOL;
        DI_P_PushButton_WireFeed2_Down : BOOL;

        DI_P_MotionJoystick_AxisSelection : BOOL;
        DQ_P_MotionJoystick_AxisSelection : BOOL;
        DI_P_MotionJoystick_Up : BOOL;
        DI_P_MotionJoystick_Down : BOOL;
        DI_P_MotionJoystick_Triangle : BOOL;
        DI_P_MotionJoystick_Square : BOOL;

        DI_P_PushButton_AxisJog_AxisSelection : BOOL;
        DQ_P_PushButton_AxisJog_AxisSelection : BOOL;

        DI_P_PushButton_AxisJog_Triangle : BOOL;
        DI_P_PushButton_AxisJog_Square : BOOL;

        DI_P_PushButton_Start : BOOL;
        DQ_P_PushButton_Start : BOOL;

        DI_P_PushButton_Stop : BOOL;
        DQ_P_PushButton_Stop : BOOL;
    END_VAR

    P_Io_EmergencyStop_Reset.Pressed.Read(DI_P_PushButton_EmergencyStop_Reset);
    P_Io_EmergencyStop_Reset.Status.Write(DQ_P_PushButton_EmergencyStop_Reset);

    P_Io_FluxSystem_Release.Pressed.Read(DI_P_PushButton_FluxSystem_Release);
    P_Io_FluxSystem_Release.Status.Write(DQ_P_PushButton_FluxSystem_Release);

    P_Io_FluxSystem_Recover.Pressed.Read(DI_P_PushButton_FluxSystem_Recover);
    P_Io_FluxSystem_Recover.Status.Write(DQ_P_PushButton_FluxSystem_Recover);

    P_Io_HighSpeedButton.Pressed.Read(DI_P_PushButton_HighSpeed);
    P_Io_HighSpeedButton.Status.Write(DQ_P_PushButton_HighSpeed);

    P_Io_WireFeed1.Direction1.Read(DI_P_PushButton_WireFeed1_Up);
    P_Io_WireFeed1.Direction2.Read(DI_P_PushButton_WireFeed1_Down);

    P_Io_WireFeed2.Direction1.Read(DI_P_PushButton_WireFeed2_Up);
    P_Io_WireFeed2.Direction2.Read(DI_P_PushButton_WireFeed2_Down);

    P_Io_MotionJoystick_AxisSelection.Pressed.Read(DI_P_MotionJoystick_AxisSelection);
    P_Io_MotionJoystick_AxisSelection.Status.Write(DQ_P_MotionJoystick_AxisSelection);

    P_Io_MotionJoystick.Up.Read(DI_P_MotionJoystick_Up);
    P_Io_MotionJoystick.Down.Read(DI_P_MotionJoystick_Down);
    P_Io_MotionJoystick.Triangle.Read(DI_P_MotionJoystick_Triangle);
    P_Io_MotionJoystick.Square.Read(DI_P_MotionJoystick_Square);

    P_Io_AxisJog_AxisSelection.Pressed.Read(DI_P_MotionJoystick_AxisSelection);
    P_Io_AxisJog_AxisSelection.Status.Write(DQ_P_MotionJoystick_AxisSelection);

    P_Io_AxisJog.Direction1.Read(DI_P_PushButton_AxisJog_Triangle);
    P_Io_AxisJog.Direction2.Read(DI_P_PushButton_AxisJog_Square);

    P_Io_Start.Pressed.Read(DI_P_PushButton_Start);
    P_Io_Start.Status.Write(DQ_P_PushButton_Start);

    P_Io_Stop.Pressed.Read(DI_P_PushButton_Stop);
    P_Io_Stop.Status.Write(DQ_P_PushButton_Stop);
END_PROGRAM