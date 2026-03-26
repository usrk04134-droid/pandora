USING Esab.Io;
USING Esab.WeldSystem.PowerSources;

CONFIGURATION BIoMapping
    {::ifndef UNLINK_B_IO}
    VAR_GLOBAL
        // -- B70 (Main I/O in B-cabinet) input/output starts at %X100

        // B71.1
        DI_B_System_CircuitBreaker_ServoDrives_OK AT %I100.0 : BOOL;
        DI_B_System_CircuitBreaker_ExternalConsumers_OK AT %I100.1 : BOOL;
        DI_B_System_EmergencyStop_OK AT %I100.2 : BOOL;
        DI_B_System_AirPressure_OK AT %I100.3 : BOOL;
        DI_B_RollerBed_External_Error AT %I100.4 : BOOL;
        /// Emergency stop reset button (B-cabinet)
        DI_B_PushButton_EmergencyStop_Reset AT %I100.5 : BOOL;
        // DI_SPARE AT %I100.6 : BOOL;
        // DI_SPARE AT %I100.7 : BOOL;
        DI_B_SpeedWheel_OneTurnSwitch AT %I101.0 : BOOL;
        DI_B_FluxSystem_Error AT %I101.1 : BOOL;
        DI_B_ClimateControl_Alarm AT %I101.2 : BOOL;
        // DI_SPARE AT %I101.3 : BOOL;
        // DI_SPARE AT %I101.4 : BOOL;
        // DI_SPARE AT %I101.5 : BOOL;
        // DI_SPARE AT %I101.6 : BOOL;
        // DI_SPARE AT %I101.7 : BOOL;

        // B71.2
        DI_B_PushButton_PusherRemote_WireFeed1_Down AT %I102.0 : BOOL;
        DI_B_PushButton_PusherRemote_WireFeed1_Up AT %I102.1 : BOOL;
        DI_B_PushButton_PusherRemote_WireFeed1_HighSpeed AT %I102.2 : BOOL;
        DI_B_PushButton_PusherRemote_WireFeed2_Down AT %I102.3 : BOOL;
        DI_B_PushButton_PusherRemote_WireFeed2_Up AT %I102.4 : BOOL;
        DI_B_PushButton_PusherRemote_WireFeed2_HighSpeed AT %I102.5 : BOOL;
        DI_B_PushButton_PusherRemote_WireFeed3_Down AT %I102.6 : BOOL;
        DI_B_PushButton_PusherRemote_WireFeed3_Up AT %I102.7 : BOOL;
        DI_B_PushButton_PusherRemote_WireFeed3_HighSpeed AT %I103.0 : BOOL;
        // DI_SPARE AT %I103.1 : BOOL;
        // DI_SPARE AT %I103.2 : BOOL;
        // DI_SPARE AT %I103.3 : BOOL;
        // DI_SPARE AT %I103.4 : BOOL;
        // DI_SPARE AT %I103.5 : BOOL;
        // DI_SPARE AT %I103.6 : BOOL;
        // DI_SPARE AT %I103.7 : BOOL;

        // B72.1
        DQ_B_PowerSource1_RemoteStart AT %Q100.0 : BOOL;
        DQ_B_PowerSource2_RemoteStart AT %Q100.1 : BOOL;
        DQ_B_PowerSource3_RemoteStart AT %Q100.2 : BOOL;
        DQ_B_System_RotatingWarningLight AT %Q100.3 : BOOL;
        DQ_B_FluxSystem_LowFluxWarningLight AT %Q100.4 : BOOL;
        /// This sets the reset signal to the safety relay in cabinet B.
        /// Do not use until safety investigation is complete.
        DQ_B_System_EmergencyStop_Reset AT %Q100.5 : BOOL;
        DQ_B_HighSpeed_Indicators AT %Q100.6 : BOOL;
        // DQ_SPARE AT Q100.7 : BOOL;
        // DQ_SPARE AT Q101.0 : BOOL;
        // DQ_SPARE AT Q101.1 : BOOL;
        // DQ_SPARE AT Q101.2 : BOOL;
        // DQ_SPARE AT Q101.3 : BOOL;
        // DQ_SPARE AT Q101.4 : BOOL;
        // DQ_SPARE AT Q101.5 : BOOL;
        // DQ_SPARE AT Q101.6 : BOOL;
        // DQ_SPARE AT Q101.7 : BOOL;

        // B73.1
        AI_B_EdgeSensor_Value AT %IW104 : INT;
        //AI_SPARE AT %IW106 : INT;
        //AI_SPARE AT %IW108 : INT;
        //AI_SPARE AT %IW110 : INT;

        // B74.1
        AI_B_FluxSystem_Temperature AT %IW112 : INT;
        //AI_SPARE AT %IW114 : INT;
        //AI_SPARE AT %IW116 : INT;
        //AI_SPARE AT %IW118 : INT;

        // B75.1
        AQ_B_RollerBed_SpeedReference AT %QW102 : INT;
        // AQ_SPARE AT %Q104 : INT;

        // B76.1
        DQ_B_RollerBed_Forward AT %Q106.0 : BOOL;
        DQ_B_RollerBed_Reverse AT %Q106.1 : BOOL;
        DQ_B_RollerBed_RemoteControl AT %Q106.2 : BOOL;
        // DQ_SPARE AT %Q106.3 : BOOL;

        // B77.1
        I_HighSpeedCounter AT %IB120 : RawHighSpeedCounterInputs;
        Q_HighSpeedCounter AT %QB107 : RawHighSpeedCounterOutputs;

        // B78.1
        DI_B_WireFeed1_PusherEncoder_A AT %I136.0 : BOOL;
        DI_B_WireFeed2_PusherEncoder_A AT %I136.1 : BOOL;
        DI_B_WireFeed3_PusherEncoder_A AT %I136.2 : BOOL;
        // DI_SPARE AT %I136.3 : BOOL;
        DI_B_WireFeed1_PusherEncoder_B AT %I136.4 : BOOL;
        DI_B_WireFeed2_PusherEncoder_B AT %I136.5 : BOOL;
        DI_B_WireFeed3_PusherEncoder_B AT %I136.6 : BOOL;
    END_VAR
    {::else}
    VAR_GLOBAL
        // -- B70 (Main I/O in B-cabinet) input/output starts at %X100

        // B71.1
        {S7.Extern=ReadWrite}
        DI_B_System_CircuitBreaker_ServoDrives_OK : BOOL;
        {S7.Extern=ReadWrite}
        DI_B_System_CircuitBreaker_ExternalConsumers_OK : BOOL;
        {S7.Extern=ReadWrite}
        DI_B_System_EmergencyStop_OK : BOOL;
        {S7.Extern=ReadWrite}
        DI_B_System_AirPressure_OK : BOOL;
        {S7.Extern=ReadWrite}
        DI_B_RollerBed_External_Error : BOOL;
        /// Emergency stop reset button (B-cabinet)
        {S7.Extern=ReadWrite}
        DI_B_PushButton_EmergencyStop_Reset : BOOL;
        // DI_SPARE AT %I100.6 : BOOL;
        // DI_SPARE AT %I100.7 : BOOL;
        {S7.Extern=ReadWrite}
        DI_B_SpeedWheel_OneTurnSwitch : BOOL;
        {S7.Extern=ReadWrite}
        DI_B_FluxSystem_Error : BOOL;
        {S7.Extern=ReadWrite}
        DI_B_ClimateControl_Alarm : BOOL;
        // DI_SPARE AT %I101.3 : BOOL;
        // DI_SPARE AT %I101.4 : BOOL;
        // DI_SPARE AT %I101.5 : BOOL;
        // DI_SPARE AT %I101.6 : BOOL;
        // DI_SPARE AT %I101.7 : BOOL;

        // B71.2
        {S7.Extern=ReadWrite}
        DI_B_PushButton_PusherRemote_WireFeed1_Down : BOOL;
        {S7.Extern=ReadWrite}
        DI_B_PushButton_PusherRemote_WireFeed1_Up : BOOL;
        {S7.Extern=ReadWrite}
        DI_B_PushButton_PusherRemote_WireFeed1_HighSpeed : BOOL;
        {S7.Extern=ReadWrite}
        DI_B_PushButton_PusherRemote_WireFeed2_Down : BOOL;
        {S7.Extern=ReadWrite}
        DI_B_PushButton_PusherRemote_WireFeed2_Up : BOOL;
        {S7.Extern=ReadWrite}
        DI_B_PushButton_PusherRemote_WireFeed2_HighSpeed : BOOL;
        {S7.Extern=ReadWrite}
        DI_B_PushButton_PusherRemote_WireFeed3_Down : BOOL;
        {S7.Extern=ReadWrite}
        DI_B_PushButton_PusherRemote_WireFeed3_Up : BOOL;
        {S7.Extern=ReadWrite}
        DI_B_PushButton_PusherRemote_WireFeed3_HighSpeed : BOOL;
        // DI_SPARE AT %I103.1 : BOOL;
        // DI_SPARE AT %I103.2 : BOOL;
        // DI_SPARE AT %I103.3 : BOOL;
        // DI_SPARE AT %I103.4 : BOOL;
        // DI_SPARE AT %I103.5 : BOOL;
        // DI_SPARE AT %I103.6 : BOOL;
        // DI_SPARE AT %I103.7 : BOOL;

        // B72.1
        {S7.Extern=ReadWrite}
        DQ_B_PowerSource1_RemoteStart : BOOL;
        {S7.Extern=ReadWrite}
        DQ_B_PowerSource2_RemoteStart : BOOL;
        {S7.Extern=ReadWrite}
        DQ_B_PowerSource3_RemoteStart : BOOL;
        {S7.Extern=ReadWrite}
        DQ_B_System_RotatingWarningLight : BOOL;
        {S7.Extern=ReadWrite}
        DQ_B_FluxSystem_LowFluxWarningLight : BOOL;
        /// This sets the reset signal to the safety relay in cabinet B.
        /// Do not use until safety investigation is complete.
        {S7.Extern=ReadWrite}
        DQ_B_System_EmergencyStop_Reset : BOOL;
        {S7.Extern=ReadWrite}
        DQ_B_HighSpeed_Indicators : BOOL;
        // DQ_SPARE AT Q100.7 : BOOL;
        // DQ_SPARE AT Q101.0 : BOOL;
        // DQ_SPARE AT Q101.1 : BOOL;
        // DQ_SPARE AT Q101.2 : BOOL;
        // DQ_SPARE AT Q101.3 : BOOL;
        // DQ_SPARE AT Q101.4 : BOOL;
        // DQ_SPARE AT Q101.5 : BOOL;
        // DQ_SPARE AT Q101.6 : BOOL;
        // DQ_SPARE AT Q101.7 : BOOL;

        // B73.1
        {S7.Extern=ReadWrite}
        AI_B_EdgeSensor_Value : INT;
        //AI_SPARE AT %IW106 : INT;
        //AI_SPARE AT %IW108 : INT;
        //AI_SPARE AT %IW110 : INT;

        // B74.1
        {S7.Extern=ReadWrite}
        AI_B_FluxSystem_Temperature : INT;
        //AI_SPARE AT %IW114 : INT;
        //AI_SPARE AT %IW116 : INT;
        //AI_SPARE AT %IW118 : INT;

        // B75.1
        {S7.Extern=ReadWrite}
        AQ_B_RollerBed_SpeedReference : INT;
        // AQ_SPARE AT %Q104 : INT;

        // B76.1
        {S7.Extern=ReadWrite}
        DQ_B_RollerBed_Forward : BOOL;
        {S7.Extern=ReadWrite}
        DQ_B_RollerBed_Reverse : BOOL;
        {S7.Extern=ReadWrite}
        DQ_B_RollerBed_RemoteControl : BOOL;
        // DQ_SPARE AT %Q106.3 : BOOL;

        // B77.1
        {S7.Extern=ReadWrite}
        I_HighSpeedCounter AT %MB100 : RawHighSpeedCounterInputs;
        {S7.Extern=ReadWrite}
        Q_HighSpeedCounter AT %MB150: RawHighSpeedCounterOutputs;

        // B78.1
        {S7.Extern=ReadWrite}
        DI_B_WireFeed1_PusherEncoder_A : BOOL;
        {S7.Extern=ReadWrite}
        DI_B_WireFeed2_PusherEncoder_A : BOOL;
        {S7.Extern=ReadWrite}
        DI_B_WireFeed3_PusherEncoder_A : BOOL;
        // DI_SPARE AT %I136.3 : BOOL;
        {S7.Extern=ReadWrite}
        DI_B_WireFeed1_PusherEncoder_B : BOOL;
        {S7.Extern=ReadWrite}
        DI_B_WireFeed2_PusherEncoder_B : BOOL;
        {S7.Extern=ReadWrite}
        DI_B_WireFeed3_PusherEncoder_B : BOOL;
    END_VAR
    {::endif}

END_CONFIGURATION