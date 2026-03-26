NAMESPACE Esab

    TYPE
        /// A complete list of possible assets
        AssetIdentifier : INT (
            Invalid := -1,

            GlobalState := 1,
            EmergencyStopCircuit := 2,
            Ups := 3,
            WeldSystemOrchestrator := 5,
            PowerSource1 := 6,
            PowerSource2 := 7,
            PowerSource3 := 8,
            FluxSystem := 10,
            RollerBed := 20,
            WeldHeadManipulator := 30,
            HorizontalSlideAxis := 31,
            VerticalSlideAxis := 32,

            PointLaser := 33,

            // P-HMI
            P_PushButton_EmergencyStop_Reset := 40,
            P_PushButton_FluxSystem_Release := 41,
            P_PushButton_FluxSystem_Recover := 42,
            P_PushButton_System_HighSpeed := 43,
            P_TwinPushButton_WireFeed1 := 44,
            P_TwinPushButton_WireFeed2 := 45,
            P_PushButton_MotionJoystick_AxisSelection := 46,
            P_Joystick_MotionJoystick := 47,
            P_PushButton_AxisJog_AxisSelection := 48,
            P_TwinPushButton_AxisJog := 49,
            P_PushButton_Start := 50,
            P_PushButton_Stop := 51,

            // C-HMI
            C_PushButton_EmergencyStop_Reset := 55,
            C_PushButton_FluxSystem_Release := 56,
            C_PushButton_System_HighSpeed := 57,
            C_TwinPushButton_WireFeed1 := 58,
            C_TwinPushButton_WireFeed2 := 59,
            C_TwinPushButton_WireFeed3 := 60,
            C_PushButton_TrackingOff := 61,
            C_Joystick_MotionJoystick := 62,
            C_TwinPushButton_Tilt := 63
        ) := AssetIdentifier#Invalid;
    END_TYPE

END_NAMESPACE