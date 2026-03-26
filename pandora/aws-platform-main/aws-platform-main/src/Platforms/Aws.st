USING Esab.Api;
USING Esab.Hmi;
USING Esab.Motion;
USING Esab.Utils;
USING Esab.Utils.Assets;
USING Esab.WeldSystem;
USING Esab.WeldSystem.PowerSources;

USING Siemens.Simatic.S71500.Alarming;

NAMESPACE Esab.Platforms.Aws

    CLASS Platform EXTENDS Object
        VAR PRIVATE
            _assetsManager : IAssetsManager;

            _webApi : IWebApi;

            _pHmi : IButtonBox;
            _cHmi : IButtonBox;

            _weldSystem : IWeldSystemOrchestrator;
            _assetsStarted : BOOL := FALSE;
        END_VAR

        METHOD PUBLIC Setup
            VAR_INPUT
                assetsManager : IAssetsManager;
                webApi : IWebApi;
                pHmi : IButtonBox;
                cHmi : IButtonBox;
                weldSystem : IWeldSystemOrchestrator;
            END_VAR

            _assetsManager := assetsManager;
            _webApi := webApi;
            _pHmi := pHmi;
            _cHmi := cHmi;
            _weldSystem := weldSystem;

            _isSetup := _assetsManager <> NULL AND _webApi <> NULL AND _pHmi <> NULL AND _cHmi <> NULL AND _weldSystem <> NULL;
        END_METHOD

        METHOD PUBLIC OVERRIDE Execute
            VAR
                assetsStartupStatus : BOOL := FALSE;
            END_VAR

            SUPER.Execute();

            IF _setupAlarm.IsActive() THEN
                RETURN;
            END_IF;

            _assetsManager.Execute();

            _webApi.Execute();
            _pHmi.Execute();
            _cHmi.Execute();

            _weldSystem.Execute();
        END_METHOD
    END_CLASS

END_NAMESPACE