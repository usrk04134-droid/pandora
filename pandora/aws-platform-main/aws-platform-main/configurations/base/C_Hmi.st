USING Esab.Hmi;
USING Esab.Utils.Timer;
USING Esab.Hmi.Modules;
Using Esab.Utils.Alarming;
USING Esab.Utils.Assets;

USING Siemens.Simatic.S71500.Tasks;
USING Siemens.Simatic.S71500.Alarming;

CONFIGURATION C_Hmi_Configuration

    TASK C_Hmi_IoTask : ProgramCycle;

    PROGRAM C_Hmi_IoReadWrite WITH C_Hmi_IoTask: C_Hmi_IoReadWrite;

    // Constants
    VAR_GLOBAL CONSTANT
    END_VAR

    // Objects
    VAR_GLOBAL
        C_Hmi : C_Hmi;
        C_EmergencyStop_Reset : PushButton;
        C_FluxSystem_Release : PushButton;
        C_HighSpeed : PushButton;
        C_WireFeed1 : TwinPushButton;
        C_WireFeed2 : TwinPushButton;
        C_WireFeed3 : TwinPushButton;
        C_TrackingOff : PushButton;
        C_MotionJoystick : DiscreteJoystick;
        C_MotionJoystick_LongHoldTimer : OnDelay;
        C_Tilt : TwinPushButton;
    END_VAR

    // Alarms
    VAR_GLOBAL
        C_Hmi_SetupAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "C HMI: Setup error."}
        C_Hmi_SetupAlarm : ProgramAlarm;
    END_VAR

    // Interface
    VAR_GLOBAL
        {S7.Extern=ReadWrite}
        C_Io_EmergencyStop_Reset : PushButtonIo;
        {S7.Extern=ReadWrite}
        C_Io_FluxSystem_Release : PushButtonIo;
        {S7.Extern=ReadWrite}
        C_Io_HighSpeed : PushButtonIo;
        {S7.Extern=ReadWrite}
        C_Io_WireFeed1 : TwinPushButtonIo;
        {S7.Extern=ReadWrite}
        C_Io_WireFeed2 : TwinPushButtonIo;
        {S7.Extern=ReadWrite}
        C_Io_WireFeed3 : TwinPushButtonIo;
        {S7.Extern=ReadWrite}
        C_Io_TrackingOff : PushButtonIo;
        {S7.Extern=ReadWrite}
        C_Io_MotionJoystick : DiscreteJoystickIo;
        {S7.Extern=ReadWrite}
        C_Io_Tilt : TwinPushButtonIo;
    END_VAR
END_CONFIGURATION

FUNCTION InitializeC
    VAR_INPUT
        assetsManager : IAssetsManager;
    END_VAR

    VAR_EXTERNAL
        C_Hmi : C_Hmi;
        C_EmergencyStop_Reset : PushButton;
        C_FluxSystem_Release : PushButton;
        C_HighSpeed : PushButton;
        C_WireFeed1 : TwinPushButton;
        C_WireFeed2 : TwinPushButton;
        C_WireFeed3 : TwinPushButton;
        C_TrackingOff : PushButton;
        C_MotionJoystick : DiscreteJoystick;
        C_MotionJoystick_LongHoldTimer : OnDelay;
        C_Tilt : TwinPushButton;

        C_Io_EmergencyStop_Reset : PushButtonIo;
        C_Io_FluxSystem_Release : PushButtonIo;
        C_Io_HighSpeed : PushButtonIo;
        C_Io_WireFeed1 : TwinPushButtonIo;
        C_Io_WireFeed2 : TwinPushButtonIo;
        C_Io_WireFeed3 : TwinPushButtonIo;
        C_Io_TrackingOff : PushButtonIo;
        C_Io_MotionJoystick : DiscreteJoystickIo;
        C_Io_Tilt : TwinPushButtonIo;

        C_Hmi_SetupAlarmWrapper : AlarmWrapper;
        C_Hmi_SetupAlarm : ProgramAlarm;
    END_VAR

    C_EmergencyStop_Reset.Setup(io := REF(C_Io_EmergencyStop_Reset));
    C_EmergencyStop_Reset.SetIdentifier(Esab.AssetIdentifier#C_PushButton_EmergencyStop_Reset);
    assetsManager.RegisterAsset(REF(C_EmergencyStop_Reset));

    C_FluxSystem_Release.Setup(io := REF(C_Io_FluxSystem_Release));
    C_FluxSystem_Release.SetIdentifier(Esab.AssetIdentifier#C_PushButton_FluxSystem_Release);
    assetsManager.RegisterAsset(REF(C_FluxSystem_Release));

    C_HighSpeed.Setup(io := REF(C_Io_HighSpeed));
    C_HighSpeed.SetIdentifier(Esab.AssetIdentifier#C_PushButton_System_HighSpeed);
    assetsManager.RegisterAsset(REF(C_HighSpeed));

    C_WireFeed1.Setup(io := REF(C_Io_WireFeed1));
    C_WireFeed1.SetIdentifier(Esab.AssetIdentifier#C_TwinPushButton_WireFeed1);
    assetsManager.RegisterAsset(REF(C_WireFeed1));

    C_WireFeed2.Setup(io := REF(C_Io_WireFeed2));
    C_WireFeed2.SetIdentifier(Esab.AssetIdentifier#C_TwinPushButton_WireFeed2);
    assetsManager.RegisterAsset(REF(C_WireFeed2));

    C_WireFeed3.Setup(io := REF(C_Io_WireFeed3));
    C_WireFeed3.SetIdentifier(Esab.AssetIdentifier#C_TwinPushButton_WireFeed3);
    assetsManager.RegisterAsset(REF(C_WireFeed3));

    C_TrackingOff.Setup(io := REF(C_Io_TrackingOff));
    C_TrackingOff.SetIdentifier(Esab.AssetIdentifier#C_PushButton_TrackingOff);
    assetsManager.RegisterAsset(REF(C_TrackingOff));

    C_MotionJoystick.Setup(io := REF(C_Io_MotionJoystick), longHoldTimer := C_MotionJoystick_LongHoldTimer);
    C_MotionJoystick.SetIdentifier(Esab.AssetIdentifier#C_Joystick_MotionJoystick);
    assetsManager.RegisterAsset(REF(C_MotionJoystick));

    C_Hmi_SetupAlarmWrapper.Setup(REF(C_Hmi_SetupAlarm));

    C_Hmi.Setup(assetsManager, C_Hmi_SetupAlarmWrapper);
END_FUNCTION

PROGRAM C_Hmi_IoReadWrite
    VAR_EXTERNAL
        C_Io_EmergencyStop_Reset : PushButtonIo;
        C_Io_FluxSystem_Release : PushButtonIo;
        C_Io_HighSpeed : PushButtonIo;
        C_Io_WireFeed1 : TwinPushButtonIo;
        C_Io_WireFeed2 : TwinPushButtonIo;
        C_Io_WireFeed3 : TwinPushButtonIo;
        C_Io_TrackingOff : PushButtonIo;
        C_Io_MotionJoystick : DiscreteJoystickIo;
        C_Io_Tilt : TwinPushButtonIo;

        DI_C_PushButton_EmergencyStop_Reset : BOOL;
        DQ_C_PushButton_EmergencyStop_Reset : BOOL;

        DI_C_PushButton_FluxSystem_Release : BOOL;
        DQ_C_PushButton_FluxSystem_Release : BOOL;

        DI_C_PushButton_HighSpeed : BOOL;
        DQ_C_PushButton_HighSpeed : BOOL;

        DI_C_PushButton_WireFeed1_Up : BOOL;
        DI_C_PushButton_WireFeed1_Down : BOOL;

        DI_C_PushButton_WireFeed2_Up : BOOL;
        DI_C_PushButton_WireFeed2_Down : BOOL;

        DI_C_PushButton_WireFeed3_Up : BOOL;
        DI_C_PushButton_WireFeed3_Down : BOOL;

        DI_C_PushButton_TrackingOff : BOOL;
        DQ_C_PushButton_TrackingOff : BOOL;

        DI_C_MotionJoystick_Up : BOOL;
        DI_C_MotionJoystick_Down : BOOL;
        DI_C_MotionJoystick_Triangle : BOOL;
        DI_C_MotionJoystick_Square : BOOL;

        DI_C_PushButton_Tilt_Left : BOOL;
        DI_C_PushButton_Tilt_Right : BOOL;
    END_VAR

    C_Io_EmergencyStop_Reset.Pressed.Read(DI_C_PushButton_EmergencyStop_Reset);
    C_Io_EmergencyStop_Reset.Status.Write(DQ_C_PushButton_EmergencyStop_Reset);

    C_Io_FluxSystem_Release.Pressed.Read(DI_C_PushButton_FluxSystem_Release);
    C_Io_FluxSystem_Release.Status.Write(DQ_C_PushButton_FluxSystem_Release);

    C_Io_HighSpeed.Pressed.Read(DI_C_PushButton_HighSpeed);
    C_Io_HighSpeed.Status.Write(DQ_C_PushButton_HighSpeed);

    C_Io_WireFeed1.Direction1.Read(DI_C_PushButton_WireFeed1_Up);
    C_Io_WireFeed1.Direction2.Read(DI_C_PushButton_WireFeed1_Down);

    C_Io_WireFeed2.Direction1.Read(DI_C_PushButton_WireFeed2_Up);
    C_Io_WireFeed2.Direction2.Read(DI_C_PushButton_WireFeed2_Down);

    C_Io_WireFeed3.Direction1.Read(DI_C_PushButton_WireFeed3_Up);
    C_Io_WireFeed3.Direction2.Read(DI_C_PushButton_WireFeed3_Down);

    C_Io_TrackingOff.Pressed.Read(DI_C_PushButton_TrackingOff);
    C_Io_TrackingOff.Status.Write(DQ_C_PushButton_TrackingOff);

    C_Io_MotionJoystick.Up.Read(DI_C_MotionJoystick_Up);
    C_Io_MotionJoystick.Down.Read(DI_C_MotionJoystick_Down);
    C_Io_MotionJoystick.Triangle.Read(DI_C_MotionJoystick_Triangle);
    C_Io_MotionJoystick.Square.Read(DI_C_MotionJoystick_Square);

    C_Io_Tilt.Direction1.Read(DI_C_PushButton_Tilt_Left);
    C_Io_Tilt.Direction2.Read(DI_C_PushButton_Tilt_Right);
END_PROGRAM