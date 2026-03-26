USING Esab.Utils.Assets;
NAMESPACE Esab.WeldSystem.Flux

    INTERFACE IFluxSystem
        METHOD Execute
        END_METHOD

        METHOD Release
        END_METHOD

        METHOD Recover
        END_METHOD

        METHOD StopRelease
        END_METHOD

        METHOD StopRecover
        END_METHOD

        METHOD IsReleasing : BOOL
        END_METHOD

        METHOD IsRecovering : BOOL
        END_METHOD
    END_INTERFACE

    CLASS FluxSystemObservable IMPLEMENTS IAssetObservable
        VAR PUBLIC
            State : FluxSystemState;
            Releasing : BOOL;
            Recovering : BOOL;
            Temperature : REAL;
        END_VAR
    END_CLASS

    TYPE
        FluxSystemState : INT(
            Idle := 0,
            Error := 1,
            /// Releasing and/or recovering
            Active := 2
        );
    END_TYPE
END_NAMESPACE