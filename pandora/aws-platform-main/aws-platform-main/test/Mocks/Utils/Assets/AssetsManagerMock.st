USING Esab.Mock;
USING Esab.Mock;
USING Esab.Mock;

NAMESPACE Esab.Utils.Assets.Mock

    CLASS AssetsManagerMock IMPLEMENTS IAssetsManager
        VAR PUBLIC
            ExecuteMock : MethodMock;
            RegisterAssetMock : RegisterAssetMethodMock;
            ObserveAssetMock : AssetObservableMethodMock;
            RequestAssetHandleMock : RequestAssetHandleMethodMock;
            IsManagedMock : IsManagedMethodMock;
            StartupAssetsMock : StartupAssetsMethodMock;
        END_VAR

        METHOD PUBLIC MockReset
            ExecuteMock.Reset();
            RegisterAssetMock.Reset();
            RequestAssetHandleMock.Reset();
            IsManagedMock.Reset();
        END_METHOD

        METHOD PUBLIC Execute
            ExecuteMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC RegisterAsset : BOOL
            VAR_INPUT
                asset : REF_TO Asset;
            END_VAR

            RegisterAssetMock.IncrementCallCount();
            RegisterAssetMock.Asset := asset;
            RegisterAsset := RegisterAssetMock.Value;
        END_METHOD

        METHOD PUBLIC RequestAssetHandle : REF_TO Asset
            VAR_INPUT
                caller : IAssetRequester;
                identifier : INT;
            END_VAR

            RequestAssetHandleMock.IncrementCallCount();
            RequestAssetHandleMock.User := caller;
            RequestAssetHandleMock.Identifier := identifier;

            IF identifier = RequestAssetHandleMock.Qualifier THEN
                RequestAssetHandle := RequestAssetHandleMock.Asset;
            ELSE
                RequestAssetHandle := NULL;
            END_IF;
        END_METHOD

        METHOD PUBLIC ObserveAsset : IAssetObservable
            VAR_INPUT
                identifier : INT;
            END_VAR

            ObserveAssetMock.IncrementCallCount();
            ObserveAsset := ObserveAssetMock.Value;
        END_METHOD

        METHOD PUBLIC StartupAssets : BOOL
            VAR_OUTPUT
                status : BOOL;
            END_VAR

            StartupAssetsMock.IncrementCallCount();
            status := StartupAssetsMock.Outputs;
            StartupAssets := StartupAssetsMock.Returns;
        END_METHOD

        METHOD PUBLIC IsManaged : BOOL
            VAR_INPUT
                identifier : INT;
            END_VAR

            IsManagedMock.IncrementCallCount();
            IsManagedMock.Identifier := identifier;
            IsManaged := IsManagedMock.Value;
        END_METHOD
    END_CLASS

    CLASS RegisterAssetMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Asset : REF_TO Asset;
            Value : BOOL;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Asset := NULL;
            Value := FALSE;
        END_METHOD
    END_CLASS

    CLASS AssetObservableMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value : IAssetObservable;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Value := NULL;
        END_METHOD
    END_CLASS

    CLASS RequestAssetHandleMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Asset : REF_TO Asset;
            User : IAssetRequester;
            Identifier : AssetIdentifier;
            Qualifier : AssetIdentifier;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Asset := NULL;
            User := NULL;
            Identifier := -1;
            Qualifier := -1;
        END_METHOD
    END_CLASS

    CLASS IsManagedMethodMock EXTENDS BoolMethodMock
        VAR PUBLIC
            Identifier : AssetIdentifier;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Identifier := -1;
        END_METHOD
    END_CLASS

    CLASS StartupAssetsMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Outputs : BOOL;
            Returns : BOOL;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Outputs := FALSE;
            Returns := FALSE;
        END_METHOD
    END_CLASS

    CLASS AssetIdentifierMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value : AssetIdentifier := -1;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Value := -1;
        END_METHOD
    END_CLASS

END_NAMESPACE