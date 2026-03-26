CONFIGURATION HIoMapping
    {::ifndef UNLINK_H_IO}
    VAR_GLOBAL
        // -- H1 (Weld head I/O) input/output starts at %X60

        // H2.1
        DI_H_SlideCrossHorizontal_LimitSwitch_Triangle AT %I60.0 : BOOL;
        DI_H_SlideCrossHorizontal_LimitSwitch_Square AT %I60.1 : BOOL;
        DI_H_SlideCrossVertical_LimitSwitch_Up AT %I60.2 : BOOL;
        DI_H_SlideCrossVertical_LimitSwitch_Down AT %I60.3 : BOOL;
        DI_H_Tilt_LimitSwitch_Left AT %I60.4 : BOOL;
        DI_H_Tilt_LimitSwitch_Right AT %I60.5 : BOOL;
        // DI_SPARE AT %I60.6 : BOOL;
        // DI_SPARE AT %I60.7 : BOOL;

        // H3.1
        AI_H_Pyrometer_Value AT %IW61 : INT;
        AI_H_HeightSensor_Value AT %IW63 : INT;
        // AI_SPARE AT %IW65 : INT;
        // AI_SPARE AT %IW67 : INT;

        // H4.1
        DQ_H_LaserPointer_Enable AT %Q69.0 : BOOL;
        DQ_H_System_Water_WarningLight AT %Q69.1 : BOOL;
        // DQ_SPARE AT %!69.2 : BOOL;
        // DQ_SPARE AT %!69.3 : BOOL;
        // DQ_SPARE AT %!69.4 : BOOL;
        // DQ_SPARE AT %!69.5 : BOOL;
        DQ_H_Scanner_LaserLine_Enable AT %Q69.6 : BOOL;
        DQ_H_Scanner_Camera_Enable AT %Q69.7 : BOOL;

        // H4.2
        DQ_H_FluxSystem_Recover AT %Q70.0 : BOOL;
        DQ_H_FluxSystem_Release AT %Q70.1 : BOOL;
        DQ_H_Scanner_AirFlow_Enable AT %Q70.2 : BOOL;
        DQ_H_FluxSystem_NozzleRotation AT %Q70.3 : BOOL;
        // DQ_SPARE AT %Q70.4 : BOOL;
        // DQ_SPARE AT %Q70.5 : BOOL;
        // DQ_SPARE AT %Q70.6 : BOOL;
        // DQ_SPARE AT %Q70.7 : BOOL;

        // H5.1
        DQ_H_Camera_Lamp1_Enable AT %Q71.0 : BOOL;
        DQ_H_Camera_Lamp2_Enable AT %Q71.1 : BOOL;
        DQ_H_FloodLight1_Enable AT %Q71.2 : BOOL;
        DQ_H_FloodLight2_Enable AT %Q71.3 : BOOL;
    END_VAR
    {::else}
    VAR_GLOBAL
        // -- H1 (Weld head I/O) input/output starts at %X60

        // H2.1
        {S7.Extern=ReadWrite}
        DI_H_SlideCrossHorizontal_LimitSwitch_Triangle : BOOL;
        {S7.Extern=ReadWrite}
        DI_H_SlideCrossHorizontal_LimitSwitch_Square : BOOL;
        {S7.Extern=ReadWrite}
        DI_H_SlideCrossVertical_LimitSwitch_Up : BOOL;
        {S7.Extern=ReadWrite}
        DI_H_SlideCrossVertical_LimitSwitch_Down : BOOL;
        {S7.Extern=ReadWrite}
        DI_H_Tilt_LimitSwitch_Left : BOOL;
        {S7.Extern=ReadWrite}
        DI_H_Tilt_LimitSwitch_Right : BOOL;
        // DI_SPARE AT %I60.6 : BOOL;
        // DI_SPARE AT %I60.7 : BOOL;

        // H3.1
        {S7.Extern=ReadWrite}
        AI_H_Pyrometer_Value : INT;
        {S7.Extern=ReadWrite}
        AI_H_HeightSensor_Value : INT;
        // AI_SPARE AT %IW65 : INT;
        // AI_SPARE AT %IW67 : INT;

        // H4.1
        {S7.Extern=ReadWrite}
        DQ_H_LaserPointer_Enable : BOOL;
        {S7.Extern=ReadWrite}
        DQ_H_System_Water_WarningLight : BOOL;
        // DQ_SPARE AT %!69.2 : BOOL;
        // DQ_SPARE AT %!69.3 : BOOL;
        // DQ_SPARE AT %!69.4 : BOOL;
        // DQ_SPARE AT %!69.5 : BOOL;
        {S7.Extern=ReadWrite}
        DQ_H_Scanner_LaserLine_Enable : BOOL;
        {S7.Extern=ReadWrite}
        DQ_H_Scanner_Camera_Enable : BOOL;

        // H4.2
        {S7.Extern=ReadWrite}
        DQ_H_FluxSystem_Recover : BOOL;
        {S7.Extern=ReadWrite}
        DQ_H_FluxSystem_Release : BOOL;
        {S7.Extern=ReadWrite}
        DQ_H_Scanner_AirFlow_Enable : BOOL;
        {S7.Extern=ReadWrite}
        DQ_H_FluxSystem_NozzleRotation : BOOL;
        // DQ_SPARE AT %Q70.4 : BOOL;
        // DQ_SPARE AT %Q70.5 : BOOL;
        // DQ_SPARE AT %Q70.6 : BOOL;
        // DQ_SPARE AT %Q70.7 : BOOL;

        // H5.1
        {S7.Extern=ReadWrite}
        DQ_H_Camera_Lamp1_Enable : BOOL;
        {S7.Extern=ReadWrite}
        DQ_H_Camera_Lamp2_Enable : BOOL;
        {S7.Extern=ReadWrite}
        DQ_H_FloodLight1_Enable : BOOL;
        {S7.Extern=ReadWrite}
        DQ_H_FloodLight2_Enable : BOOL;
    END_VAR
    {::endif}
END_CONFIGURATION