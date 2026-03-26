USING Esab.Utils.Assets;

USING AxUnit;

NAMESPACE Esab.Tests

    {TestFixture}
    CLASS GlobalStateTests
        VAR PRIVATE
            _assetsManager : AssetsManager;
            _globalState : GlobalState;
            _globalStateObservable : REF_TO GlobalStateObservable;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            _globalState.SetIdentifier(AssetIdentifier#GlobalState);
            _assetsManager.RegisterAsset(REF(_globalState));

            _globalState.Setup(_assetsManager, NULL);

            _globalStateObservable ?= _globalState.Observe();
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            ;
        END_METHOD

        METHOD PRIVATE Execute
            _assetsManager.Execute();
        END_METHOD

        {Test}
        METHOD PUBLIC HighSpeed
            _globalState.SetHighSpeed(TRUE);
            THIS.Execute();
            Assert.Equal(_globalStateObservable^.HighSpeed, TRUE);

            _globalState.SetHighSpeed(FALSE);
            THIS.Execute();
            Assert.Equal(_globalStateObservable^.HighSpeed, FALSE);
        END_METHOD
    END_CLASS

END_NAMESPACE