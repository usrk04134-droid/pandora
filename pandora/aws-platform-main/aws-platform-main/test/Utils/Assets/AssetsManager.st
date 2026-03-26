USING Esab.Utils.Assets.Mock;
USING Esab.Utils.Collections;

USING AxUnit;

NAMESPACE Esab.Utils.Assets.Test

    {TestFixture}
    {Category(Assets)}
    CLASS AssetsManagerTests
        VAR PRIVATE
            _manager : AssetsManager;
            _defaultManager : AssetsManager;
            _user1 : IAssetRequester;
            _asset1 : REF_TO Asset;
            _asset2 : REF_TO Asset;

            _actualUser1 : AssetUserMock;
            _actualAsset1 : AssetMock;
            _actualAsset2 : AssetMock;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            ;
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            _manager := _defaultManager;
            _actualUser1.MockReset();
            _actualAsset1.MockReset();
            _actualAsset2.MockReset();
            _user1 := _actualUser1;
            _asset1 := REF(_actualAsset1);
            _asset2 := REF(_actualAsset2);

            _actualAsset1.GetIdentifierMock.Value := AssetIdentifier#Asset1;
            _actualAsset2.GetIdentifierMock.Value := AssetIdentifier#Asset2;
        END_METHOD

        {Test}
        METHOD PUBLIC RegisterNullAsset
            Assert.Equal(_manager.RegisterAsset(NULL), FALSE);
        END_METHOD

        {Test}
        METHOD PUBLIC RegisterAsset
            Assert.Equal(_manager.RegisterAsset(_asset1), TRUE);
            Assert.Equal(_manager.RegisterAsset(_asset2), TRUE);
        END_METHOD

        {Test}
        METHOD PUBLIC RegisterAssetMultipleTimes
            Assert.Equal(_manager.RegisterAsset(_asset1), TRUE);
            Assert.Equal(_manager.RegisterAsset(_asset1), FALSE);
            Assert.Equal(_manager.RegisterAsset(_asset1), FALSE);
            Assert.Equal(_manager.RegisterAsset(_asset1), FALSE);
            Assert.Equal(_manager.RegisterAsset(_asset1), FALSE);
        END_METHOD

        {Test}
        METHOD PUBLIC RegisterAssetMultipleTimesWithSameId
            _actualAsset1.GetIdentifierMock.Value := AssetIdentifier#Asset1;
            _actualAsset2.GetIdentifierMock.Value := AssetIdentifier#Asset1;
            Assert.Equal(_manager.RegisterAsset(_asset1), TRUE);
            Assert.Equal(_manager.RegisterAsset(_asset2), FALSE);
        END_METHOD

        {Test}
        METHOD PUBLIC RequestFreeAsset
            VAR_TEMP
                asset : REF_TO Asset;
            END_VAR

            _manager.RegisterAsset(_asset1);

            _actualAsset1.GetUserMock.Value := NULL;

            asset := _manager.RequestAssetHandle(_user1, AssetIdentifier#Asset1);

            Assert.Equal(_actualAsset1.GetUserMock.GetCallCount(), UINT#1);
            Assert.Equal(asset = _asset1, TRUE);
        END_METHOD

        {Test}
        METHOD PUBLIC RequestUnexistingAsset
            VAR_TEMP
                asset : REF_TO Asset;
            END_VAR

            _actualAsset1.GetUserMock.Value := NULL;

            asset := _manager.RequestAssetHandle(_user1, AssetIdentifier#Asset1);

            Assert.Equal(asset = NULL, TRUE);
        END_METHOD

        {Test}
        METHOD PUBLIC RequestOccupiedAssetSuccessfully
            VAR_TEMP
                asset : REF_TO Asset;
            END_VAR

            _manager.RegisterAsset(_asset1);

            _actualAsset1.GetUserMock.Value := _user1;
            _actualAsset1.IsLockedMock.Value := FALSE;

            asset := _manager.RequestAssetHandle(_user1, AssetIdentifier#Asset1);

            Assert.Equal(_actualAsset1.IsLockedMock.GetCallCount(), UINT#1);
            Assert.Equal(_actualAsset1.GetUserMock.GetCallCount(), UINT#2);
            Assert.Equal(asset = _asset1, TRUE);
        END_METHOD

        {Test}
        METHOD PUBLIC RequestOccupiedAssetFail
            VAR_TEMP
                asset : REF_TO Asset;
            END_VAR

            _manager.RegisterAsset(_asset1);

            _actualAsset1.GetUserMock.Value := _user1;
            _actualAsset1.IsLockedMock.Value := TRUE;

            asset := _manager.RequestAssetHandle(_user1, AssetIdentifier#Asset1);

            Assert.Equal(_actualAsset1.IsLockedMock.GetCallCount(), UINT#1);
            Assert.Equal(asset = NULL, TRUE);
        END_METHOD

        {Test}
        METHOD PUBLIC Execute
            _manager.RegisterAsset(_asset1);
            _manager.RegisterAsset(_asset2);

            _manager.Execute();

            Assert.Equal(_actualAsset1.ExecuteMock.GetCallCount(), UINT#1);
            Assert.Equal(_actualAsset2.ExecuteMock.GetCallCount(), UINT#1);
        END_METHOD
    END_CLASS

    TYPE
        AssetIdentifier : INT (
            Asset1 := 1,
            Asset2 := 2
        );
    END_TYPE

END_NAMESPACE