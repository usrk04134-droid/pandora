USING Esab.Modes;

CONFIGURATION AdaptioIoMapping
    {::ifndef UNLINK_ADAPTIO_IO}
    VAR_GLOBAL
        // Adaptio
        {S7.Extern=ReadOnly}
        I_Adaptio AT %IB1000 : RawFromAdaptio;
        {S7.Extern=ReadOnly}
        Q_Adaptio AT %QB1000 : RawToAdaptio;
    END_VAR
    {::else}
    VAR_GLOBAL
        // Adaptio
        {S7.Extern=ReadWrite}
        I_Adaptio : RawFromAdaptio;
        {S7.Extern=ReadWrite}
        Q_Adaptio : RawToAdaptio;
    END_VAR
    {::endif}
END_CONFIGURATION