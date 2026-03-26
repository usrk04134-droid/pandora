USING Esab.Utils.Collections;

NAMESPACE Esab.Utils.Assets

    INTERFACE IAssetsManager
        /// Registers an asset to be managed.
        /// Returns TRUE if the asset was successfully registered.
        METHOD RegisterAsset : BOOL
            VAR_INPUT
                asset : REF_TO Asset;
            END_VAR
        END_METHOD

        /// Requests an asset from this manager.
        /// If the asset is not found or not available, NULL will be returned.
        METHOD RequestAssetHandle : REF_TO Asset
            VAR_INPUT
                caller : IAssetRequester;
                identifier : INT;
            END_VAR
        END_METHOD

        /// Returns a struct class with data, exact type depends in implementer.
        METHOD ObserveAsset : IAssetObservable
            VAR_INPUT
                identifier : INT;
            END_VAR
        END_METHOD

        /// Returns TRUE if the asset is managed by this manager.
        METHOD IsManaged : BOOL
            VAR_INPUT
                identifier : INT;
            END_VAR
        END_METHOD

        /// Execute this manager cyclically.
        /// This will in turn execute all controller assets.
        /// NOTE: This will execute all assets in turn, take care to not
        /// do anything time consuming when the assets execute themselves.
        METHOD Execute
        END_METHOD
    END_INTERFACE

    INTERFACE IAssetRequester
        /// This method will be called when an asses is assigned.
        METHOD AssetAssigned
            VAR_INPUT
                asset : REF_TO Asset;
            END_VAR
        END_METHOD

        /// This method will be called when an asset is removed.
        METHOD AssetRemoved
            VAR_INPUT
                identifier : INT;
            END_VAR
        END_METHOD
    END_INTERFACE

    CLASS AssetsManager IMPLEMENTS IAssetsManager
        VAR CONSTANT PUBLIC
            MAX_ASSETS : INT := 100;
        END_VAR

        VAR PRIVATE
            _assets : ARRAY [0..MAX_ASSETS-1] OF REF_TO Asset;
        END_VAR

        METHOD PUBLIC RegisterAsset : BOOL
            VAR_INPUT
                asset : REF_TO Asset;
            END_VAR

            IF asset = NULL THEN
                RETURN;
            END_IF;

            IF NOT THIS.IsManaged(asset^.GetIdentifier()) THEN
                RegisterAsset := THIS.InsertAsset(asset);
            ELSE
                RegisterAsset := FALSE;
            END_IF;
        END_METHOD

        METHOD PUBLIC RequestAssetHandle : REF_TO Asset
            VAR_INPUT
                caller : IAssetRequester;
                identifier : INT;
            END_VAR

            VAR_TEMP
                asset : REF_TO Asset := NULL;
            END_VAR

            asset := THIS.FindAsset(identifier);

            RequestAssetHandle := NULL;

            IF asset <> NULL THEN
                IF NOT asset^.IsLocked() THEN
                    IF asset^.GetUser() <> NULL THEN
                        asset^.GetUser().AssetRemoved(asset^.GetIdentifier());
                    END_IF;

                    asset^.SetUser(caller);

                    IF caller <> NULL THEN
                        caller.AssetAssigned(asset);
                    END_IF;

                    RequestAssetHandle := asset;
                END_IF;
            END_IF;
        END_METHOD

        METHOD PUBLIC ObserveAsset : IAssetObservable
            VAR_INPUT
                identifier : INT;
            END_VAR

            VAR_TEMP
                asset : REF_TO Asset;
            END_VAR

            asset := THIS.FindAsset(identifier);

            IF asset <> NULL THEN
                ObserveAsset := asset^.Observe();
            ELSE
                ObserveAsset := NULL;
            END_IF;
        END_METHOD

        METHOD PUBLIC IsManaged : BOOL
            VAR_INPUT
                identifier : INT;
            END_VAR

            IsManaged := THIS.FindAsset(identifier) <> NULL;
        END_METHOD

        METHOD PUBLIC Execute
            VAR_TEMP
                assetIndex : INT := 0;
            END_VAR

            FOR assetIndex := 0 TO MAX_ASSETS-1 DO
                IF _assets[assetIndex] <> NULL THEN
                    _assets[assetIndex]^.Execute();
                END_IF;
            END_FOR;
        END_METHOD

        METHOD PRIVATE FindAsset : REF_TO Asset
            VAR_INPUT
                identifier : INT;
            END_VAR

            IF identifier < 0 OR identifier > MAX_ASSETS-1 THEN
                FindAsset := NULL;
                RETURN;
            END_IF;

            FindAsset := _assets[identifier];
        END_METHOD

        METHOD PRIVATE InsertAsset : BOOL
            VAR_INPUT
                asset : REF_TO Asset;
            END_VAR

            VAR_TEMP
                index : INT;
            END_VAR

            index := asset^.GetIdentifier();

            IF index < 0 OR index > MAX_ASSETS-1 THEN
                InsertAsset := FALSE;
                RETURN;
            END_IF;

            IF _assets[index] <> NULL THEN
                InsertAsset := FALSE;
                RETURN;
            END_IF;

            _assets[index] := asset;

            InsertAsset := TRUE;
        END_METHOD
    END_CLASS
END_NAMESPACE
