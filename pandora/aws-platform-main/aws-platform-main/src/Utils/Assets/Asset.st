USING Esab.Utils.Collections;

NAMESPACE Esab.Utils.Assets

    INTERFACE IAsset
        /// Locks this resource so it will not be reassigned by the manager.
        METHOD Lock
        END_METHOD

        /// Unlocks this resource so it may be reassigned by the manager.
        METHOD Unlock
        END_METHOD

        /// Returns TRUE if this asset is currently locked.
        METHOD IsLocked : BOOL
        END_METHOD

        /// Returns a struct class with data, exact class depends on implementer.
        /// Returns NULL if the asset does not exist.
        METHOD Observe : IAssetObservable
        END_METHOD
    END_INTERFACE

    /// Used to mark Assets.
    CLASS PUBLIC ABSTRACT Asset EXTENDS Object IMPLEMENTS IAsset

        VAR PRIVATE
            _locked : BOOL := FALSE;
            _identifier : INT := -1;
            _user : IAssetRequester;
            _status : AssetStatus := AssetStatus#Unknown;
        END_VAR

        /// Execute this asset.
        /// THis will be called when the manager is executed.
        METHOD PUBLIC OVERRIDE Execute
            SUPER.Execute();
        END_METHOD

        METHOD PUBLIC SetUser
            VAR_INPUT
                user : IAssetRequester;
            END_VAR

            _user := user;
        END_METHOD

        METHOD PUBLIC GetUser : IAssetRequester;
            GetUser := _user;
        END_METHOD

        /// Sets the identifier of this asset.
        /// This should ONLY be called during system initialization.
        METHOD PUBLIC SetIdentifier
            VAR_INPUT
                identifier : INT;
            END_VAR

            IF _identifier = -1 THEN
                _identifier := identifier;
            END_IF;
        END_METHOD

        /// Fetches the ID of this asset.
        METHOD PUBLIC GetIdentifier : INT
            GetIdentifier := _identifier;
        END_METHOD

        /// Locks this resource so it will not be reassigned by the manager.
        METHOD PUBLIC Lock
            _locked := TRUE;
        END_METHOD

        /// Unlocks this resource so it may be reassigned by the manager.
        METHOD PUBLIC Unlock
            _locked := FALSE;
        END_METHOD

        /// Returns TRUE if this asset is currently locked.
        METHOD PUBLIC IsLocked : BOOL
            IsLocked := _locked;
        END_METHOD

        /// Returns the current status of this asset
        METHOD PUBLIC Status : AssetStatus
            Status := _status;
        END_METHOD

        /// Sets the current status of this asset
        METHOD PROTECTED Status
            VAR_INPUT
                value : AssetStatus;
            END_VAR

            _status := value;
        END_METHOD

        /// Returns a struct class with data, exact class depends on implementer.
        /// Returns NULL if the asset does not exist.
        METHOD PUBLIC ABSTRACT Observe : IAssetObservable
        END_METHOD
    END_CLASS

    /// Used to mark the observable part of an Asset.
    INTERFACE IAssetObservable
    END_INTERFACE

    TYPE
        AssetStatus : INT(
            Unknown := -1,
            NotConnected := 0,
            ConfigurationError := 1,
            StartupError := 2,
            Healthy := 99
        );
    END_TYPE

END_NAMESPACE