CONFIGURATION IoMapping
    {::ifndef UNLINK_P_IO}
    VAR_GLOBAL
        // -- P1 (Button box below the main HMI screen) input/output starts at %X30
        // NOTE: The actual buttons are in the reverse order compared to I/O-addressing

        // P2 (Emergency stop reset)
        DI_P_PushButton_EmergencyStop_Reset AT %I42.0 : BOOL;
        DQ_P_PushButton_EmergencyStop_Reset AT %Q42.0 : BOOL;

        // P3 (Flux release/down)
        DI_P_PushButton_FluxSystem_Release AT %I41.0 : BOOL;
        DQ_P_PushButton_FluxSystem_Release AT %Q41.0 : BOOL;

        // P4 (Flux recover/suction)
        DI_P_PushButton_FluxSystem_Recover AT %I40.0 : BOOL;
        DQ_P_PushButton_FluxSystem_Recover AT %Q40.0 : BOOL;

        // P5 (High speed selection)
        DI_P_PushButton_HighSpeed AT %I39.0 : BOOL;
        DQ_P_PushButton_HighSpeed AT %Q39.0 : BOOL;

        // P6 (Wire feed 1 + 3)
        /// NOTE: This also controls WF 3 Up through mode select
        DI_P_PushButton_WireFeed1_Up AT %I38.0 : BOOL;
        /// NOTE: This also controls WF 3 Down through mode select
        DI_P_PushButton_WireFeed1_Down AT %I38.1 : BOOL;

        // P7
        DI_P_PushButton_WireFeed2_Up AT %I37.0 : BOOL;
        DI_P_PushButton_WireFeed2_Down AT %I37.1 : BOOL;

        // P8 (Joystick) + P9 (Axis selection)
        DI_P_MotionJoystick_AxisSelection AT %I30.0 : BOOL;
        DQ_P_MotionJoystick_AxisSelection AT %Q30.0 : BOOL;
        DI_P_MotionJoystick_Up AT %I30.2 : BOOL;
        DI_P_MotionJoystick_Down AT %I30.3 : BOOL;
        DI_P_MotionJoystick_Triangle AT %I30.4 : BOOL;
        DI_P_MotionJoystick_Square AT %I30.5 : BOOL;

        // P10 (Axis selection triangle/square)
        DI_P_PushButton_AxisJog_AxisSelection AT %I36.0 : BOOL;
        DQ_P_PushButton_AxisJog_AxisSelection AT %Q36.0 : BOOL;

        // P11 (Axis triangle/square)
        DI_P_PushButton_AxisJog_Triangle AT %I35.0 : BOOL;
        DI_P_PushButton_AxisJog_Square AT %I35.1 : BOOL;

        // P12 (Start)
        DI_P_PushButton_Start AT %I34.0 : BOOL;
        DQ_P_PushButton_Start AT %Q34.0 : BOOL;

        // P13 (Stop)
        DI_P_PushButton_Stop AT %I33.0 : BOOL;
        DQ_P_PushButton_Stop AT %Q33.0 : BOOL;
    END_VAR
    {::else}
    VAR_GLOBAL
        // -- P1 (Button box below the main HMI screen) input/output starts at %X30
        // NOTE: The actual buttons are in the reverse order compared to I/O-addressing

        // P2 (Emergency stop reset)
        {S7.Extern=ReadWrite}
        DI_P_PushButton_EmergencyStop_Reset : BOOL;
        {S7.Extern=ReadWrite}
        DQ_P_PushButton_EmergencyStop_Reset : BOOL;

        // P3 (Flux release/down)
        {S7.Extern=ReadWrite}
        DI_P_PushButton_FluxSystem_Release : BOOL;
        {S7.Extern=ReadWrite}
        DQ_P_PushButton_FluxSystem_Release : BOOL;

        // P4 (Flux recover/suction)
        {S7.Extern=ReadWrite}
        DI_P_PushButton_FluxSystem_Recover : BOOL;
        {S7.Extern=ReadWrite}
        DQ_P_PushButton_FluxSystem_Recover : BOOL;

        // P5 (High speed selection)
        {S7.Extern=ReadWrite}
        DI_P_PushButton_HighSpeed : BOOL;
        {S7.Extern=ReadWrite}
        DQ_P_PushButton_HighSpeed : BOOL;

        // P6 (Wire feed 1 + 3)
        /// NOTE: This also controls WF 3 Up through mode select
        {S7.Extern=ReadWrite}
        DI_P_PushButton_WireFeed1_Up : BOOL;
        /// NOTE: This also controls WF 3 Down through mode select
        {S7.Extern=ReadWrite}
        DI_P_PushButton_WireFeed1_Down : BOOL;

        // P7
        {S7.Extern=ReadWrite}
        DI_P_PushButton_WireFeed2_Up : BOOL;
        {S7.Extern=ReadWrite}
        DI_P_PushButton_WireFeed2_Down : BOOL;

        // P8 (Joystick) + P9 (Axis selection)
        {S7.Extern=ReadWrite}
        DI_P_MotionJoystick_AxisSelection : BOOL;
        {S7.Extern=ReadWrite}
        DQ_P_MotionJoystick_AxisSelection : BOOL;
        {S7.Extern=ReadWrite}
        DI_P_MotionJoystick_Up : BOOL;
        {S7.Extern=ReadWrite}
        DI_P_MotionJoystick_Down : BOOL;
        {S7.Extern=ReadWrite}
        DI_P_MotionJoystick_Triangle : BOOL;
        {S7.Extern=ReadWrite}
        DI_P_MotionJoystick_Square : BOOL;

        // P10 (Axis selection triangle/square)
        {S7.Extern=ReadWrite}
        DI_P_PushButton_AxisJog_AxisSelection : BOOL;
        {S7.Extern=ReadWrite}
        DQ_P_PushButton_AxisJog_AxisSelection : BOOL;

        // P11 (Axis triangle/square)
        {S7.Extern=ReadWrite}
        DI_P_PushButton_AxisJog_Triangle : BOOL;
        {S7.Extern=ReadWrite}
        DI_P_PushButton_AxisJog_Square : BOOL;

        // P12 (Start)
        {S7.Extern=ReadWrite}
        DI_P_PushButton_Start : BOOL;
        {S7.Extern=ReadWrite}
        DQ_P_PushButton_Start : BOOL;

        // P13 (Stop)
        {S7.Extern=ReadWrite}
        DI_P_PushButton_Stop : BOOL;
        {S7.Extern=ReadWrite}
        DQ_P_PushButton_Stop : BOOL;
    END_VAR
    {::endif}
END_CONFIGURATION