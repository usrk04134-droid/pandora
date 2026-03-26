USING Esab.Utils.Power;

CONFIGURATION Ups1600IoMapping

    {::ifndef UNLINK_UPS_IO}
    VAR_GLOBAL
        {S7.Extern=ReadOnly}
        I_Ups AT %IB0 : RawFromUps1600;
    END_VAR
    {::else}
    VAR_GLOBAL
        {S7.Extern=ReadWrite}
        I_Ups : RawFromUps1600;
    END_VAR
    {::endif}

END_CONFIGURATION