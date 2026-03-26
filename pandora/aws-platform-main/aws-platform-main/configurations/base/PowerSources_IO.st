USING Esab.WeldSystem.PowerSources;

CONFIGURATION PowerSourcesIoMapping
    {::ifndef UNLINK_POWERSOURCES_IO}
    VAR_GLOBAL
        // Power sources
        I_Pab1 AT %IB500 : RawPabToController;
        Q_Pab1 AT %QB500 : RawControllerToPab;
        I_Pab2 AT %IB600 : RawPabToController;
        Q_Pab2 AT %QB600 : RawControllerToPab;
    END_VAR
    {::else}
    VAR_GLOBAL
        // Power sources
        {S7.Extern=ReadWrite}
        I_Pab1 : RawPabToController;
        {S7.Extern=ReadWrite}
        Q_Pab1 : RawControllerToPab;
        {S7.Extern=ReadWrite}
        I_Pab2 : RawPabToController;
        {S7.Extern=ReadWrite}
        Q_Pab2 : RawControllerToPab;
    END_VAR
    {::endif}
END_CONFIGURATION