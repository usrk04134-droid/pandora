CONFIGURATION CIoMapping
    {::ifndef UNLINK_C_IO}
    VAR_GLOBAL
        // -- C1 (Button box located at welding head) input/output starts at %X50
        // NOTE: The actual buttons are in the reverse order compared to I/O-addressing

        // C2
        /// Emergency stop reset button (C-cabinet)
        DI_C_PushButton_EmergencyStop_Reset AT %I59.0 : BOOL;
        /// Emergency stop reset button LED (C-cabinet)
        DQ_C_PushButton_EmergencyStop_Reset AT %Q59.0 : BOOL;

        // C3
        DI_C_PushButton_FluxSystem_Release AT %I58.0 : BOOL;
        DQ_C_PushButton_FluxSystem_Release AT %Q58.0 : BOOL;

        // C4
        DI_C_PushButton_HighSpeed AT %I57.0 : BOOL;
        DQ_C_PushButton_HighSpeed AT %Q57.0 : BOOL;

        // C5
        DI_C_PushButton_WireFeed1_Up AT %I56.0 : BOOL;
        DI_C_PushButton_WireFeed1_Down AT %I56.1 : BOOL;

        // C6
        DI_C_PushButton_WireFeed2_Up AT %I55.0 : BOOL;
        DI_C_PushButton_WireFeed2_Down AT %I55.1 : BOOL;

        // C7
        DI_C_PushButton_WireFeed3_Up AT %I54.0 : BOOL;
        DI_C_PushButton_WireFeed3_Down AT %I54.1 : BOOL;

        // C8 (Joystick) + C9 (Wired to the command module)
        DI_C_PushButton_TrackingOff AT %I50.0 : BOOL;
        DQ_C_PushButton_TrackingOff AT %Q50.0 : BOOL;
        DI_C_MotionJoystick_Up AT %I50.2 : BOOL;
        DI_C_MotionJoystick_Down AT %I50.3 : BOOL;
        DI_C_MotionJoystick_Triangle AT %I50.4 : BOOL;
        DI_C_MotionJoystick_Square AT %I50.5 : BOOL;

        // C10
        DI_C_PushButton_Tilt_Left AT %I53.0 : BOOL;
        DI_C_PushButton_Tilt_Right AT %I53.1 : BOOL;
    END_VAR
    {::else}
    VAR_GLOBAL
        // -- C1 (Button box located at welding head) input/output starts at %X50
        // NOTE: The actual buttons are in the reverse order compared to I/O-addressing

        // C2
        /// Emergency stop reset button (C-cabinet)
        {S7.Extern=ReadWrite}
        DI_C_PushButton_EmergencyStop_Reset : BOOL;
        /// Emergency stop reset button LED (C-cabinet)
        {S7.Extern=ReadWrite}
        DQ_C_PushButton_EmergencyStop_Reset : BOOL;

        // C3
        {S7.Extern=ReadWrite}
        DI_C_PushButton_FluxSystem_Release : BOOL;
        {S7.Extern=ReadWrite}
        DQ_C_PushButton_FluxSystem_Release : BOOL;

        // C4
        {S7.Extern=ReadWrite}
        DI_C_PushButton_HighSpeed : BOOL;
        {S7.Extern=ReadWrite}
        DQ_C_PushButton_HighSpeed : BOOL;

        // C5
        {S7.Extern=ReadWrite}
        DI_C_PushButton_WireFeed1_Up : BOOL;
        {S7.Extern=ReadWrite}
        DI_C_PushButton_WireFeed1_Down : BOOL;

        // C6
        {S7.Extern=ReadWrite}
        DI_C_PushButton_WireFeed2_Up : BOOL;
        {S7.Extern=ReadWrite}
        DI_C_PushButton_WireFeed2_Down : BOOL;

        // C7
        {S7.Extern=ReadWrite}
        DI_C_PushButton_WireFeed3_Up : BOOL;
        {S7.Extern=ReadWrite}
        DI_C_PushButton_WireFeed3_Down : BOOL;

        // C8 (Joystick) + C9 (Wired to the command module)
        {S7.Extern=ReadWrite}
        DI_C_PushButton_TrackingOff : BOOL;
        {S7.Extern=ReadWrite}
        DQ_C_PushButton_TrackingOff : BOOL;
        {S7.Extern=ReadWrite}
        DI_C_MotionJoystick_Up : BOOL;
        {S7.Extern=ReadWrite}
        DI_C_MotionJoystick_Down : BOOL;
        {S7.Extern=ReadWrite}
        DI_C_MotionJoystick_Triangle : BOOL;
        {S7.Extern=ReadWrite}
        DI_C_MotionJoystick_Square : BOOL;

        // C10
        {S7.Extern=ReadWrite}
        DI_C_PushButton_Tilt_Left : BOOL;
        {S7.Extern=ReadWrite}
        DI_C_PushButton_Tilt_Right : BOOL;
    END_VAR
    {::endif}
END_CONFIGURATION