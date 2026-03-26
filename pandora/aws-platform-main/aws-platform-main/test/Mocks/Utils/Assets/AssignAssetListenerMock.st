USING Esab.Mock;

NAMESPACE Esab.Utils.Assets.Mock

    CLASS AssetUserMock IMPLEMENTS IAssetRequester
        VAR PUBLIC
            AssetRemovedMock : IntMethodMock;
            AssetAssignedMock : MethodMock;
        END_VAR

        METHOD PUBLIC MockReset
            AssetRemovedMock.Reset();
            AssetAssignedMock.Reset();
        END_METHOD

        METHOD PUBLIC AssetAssigned
            VAR_INPUT
                asset : REF_TO Asset;
            END_VAR

            AssetAssignedMock.IncrementCallCount();
            // Note: MethodMock doesn't have a Value property for complex types like IAsset
        END_METHOD

        METHOD PUBLIC AssetRemoved
            VAR_INPUT
                identifier : INT;
            END_VAR

            AssetRemovedMock.IncrementCallCount();
            AssetRemovedMock.Value := identifier;
        END_METHOD
    END_CLASS

END_NAMESPACE