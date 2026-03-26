USING Esab.Utils.Assets;
NAMESPACE Esab.Peripheral
    /// Represents a simple asset with a single digital output.
    INTERFACE IActivatableAsset
        METHOD Activate
        END_METHOD

        METHOD Deactivate
        END_METHOD

        METHOD IsActive : BOOL
        END_METHOD
    END_INTERFACE
    
    CLASS ActivatableObservable IMPLEMENTS IAssetObservable
        VAR PUBLIC
            Active : BOOL;
        END_VAR
    END_CLASS
END_NAMESPACE
