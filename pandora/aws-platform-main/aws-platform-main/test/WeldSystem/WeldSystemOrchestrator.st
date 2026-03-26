USING Esab.Utils.Alarming.Mock;
USING Esab.Utils;
USING Esab.WeldSystem.PowerSources.Mock;
USING Esab.Motion;
USING Esab.Utils.Assets;

USING AxUnit;

NAMESPACE Esab.WeldSystem.Test

    {TestFixture}
    CLASS WeldSystemOrchestratorTests

        VAR PRIVATE
            _orchestrator : WeldSystemOrchestrator;
            _assetsManager : AssetsManager;
            _runtimeParameters : WeldSystemOrchestratorRuntimeParameters;
            _defaultRuntimeParameters : WeldSystemOrchestratorRuntimeParameters;
            _hardwareConfiguration : WeldSystemOrchestratorHardwareConfiguration;
            _defaultHardwareConfiguration : WeldSystemOrchestratorHardwareConfiguration;
            _setupAlarm : AlarmMock;

            _ps1 : Aristo1000Mock;
            _ps2 : Aristo1000Mock;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            _ps1.SetIdentifier(AssetIdentifier#PowerSource1);
            _ps2.SetIdentifier(AssetIdentifier#PowerSource2);
            _assetsManager.RegisterAsset(REF(_ps1));
            _assetsManager.RegisterAsset(REF(_ps2));

            _orchestrator.Setup(
                REF(_runtimeParameters),
                REF(_hardwareConfiguration),
                _assetsManager,
                _setupAlarm
            );

            _setupAlarm.IsActiveMock.Value := FALSE;

            THIS.SetupPowerSources();

            Assert.Equal(_ps1.SetListenerMock.GetCallCount(), UINT#1);
            Assert.Equal(_ps1.SetTravelMotorDriveMock.GetCallCount(), UINT#1);
            Assert.Equal(_ps1.SetStartTypeMock.GetCallCount(), UINT#1);

            Assert.Equal(_ps2.SetListenerMock.GetCallCount(), UINT#1);
            Assert.Equal(_ps2.SetTravelMotorDriveMock.GetCallCount(), UINT#1);
            Assert.Equal(_ps2.SetStartTypeMock.GetCallCount(), UINT#1);
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            _runtimeParameters := _defaultRuntimeParameters;
            _hardwareConfiguration := _defaultHardwareConfiguration;

            THIS.SetupPowerSources();
        END_METHOD

        METHOD PRIVATE SetupPowerSources
            _runtimeParameters.EnabledPowerSources[1] := TRUE;
            _runtimeParameters.EnabledPowerSources[2] := TRUE;

            _hardwareConfiguration.ConnectedPowerSources[1] := TRUE;
            _hardwareConfiguration.ConnectedPowerSources[2] := TRUE;

            _ps1.MockReset();
            _ps1.IsConnectedMock.Value := TRUE;

            _ps2.MockReset();
            _ps2.IsConnectedMock.Value := TRUE;

            _orchestrator.PowerSourceConnected(UINT#1);
            _orchestrator.PowerSourceConnected(UINT#2);

            _orchestrator.Execute();
            _orchestrator.Execute();
            _orchestrator.Execute();
            _orchestrator.Execute();
        END_METHOD

        {Test}
        METHOD PUBLIC PowerSourceSetpoints
            VAR_TEMP
                error : WeldSystemOrchestratorErrorCode;
            END_VAR

            _orchestrator.GetPowerSourceSetPoints(1, FALSE, error);
            Assert.Equal(error, WeldSystemOrchestratorErrorCode#NoError);
            Assert.Equal(_ps1.PassiveAreaMock.GetCallCount(), UINT#1);

            _orchestrator.GetPowerSourceSetPoints(1, TRUE, error);
            Assert.Equal(error, WeldSystemOrchestratorErrorCode#NoError);
            Assert.Equal(_ps1.ActiveAreaMock.GetCallCount(), UINT#1);

            _orchestrator.GetPowerSourceSetPoints(2, FALSE, error);
            Assert.Equal(error, WeldSystemOrchestratorErrorCode#NoError);
            Assert.Equal(_ps2.PassiveAreaMock.GetCallCount(), UINT#1);

            _orchestrator.GetPowerSourceSetPoints(2, TRUE, error);
            Assert.Equal(error, WeldSystemOrchestratorErrorCode#NoError);
            Assert.Equal(_ps2.ActiveAreaMock.GetCallCount(), UINT#1);

        END_METHOD

        {Test}
        METHOD PUBLIC PowerSourceSwapAreas
            VAR_TEMP
                error : WeldSystemOrchestratorErrorCode;
            END_VAR

            _orchestrator.SwitchWeldDataSet(1, error);
            Assert.Equal(error, WeldSystemOrchestratorErrorCode#NoError);
            Assert.Equal(_ps1.SwitchActivePassiveMock.GetCallCount(), UINT#1);

            _orchestrator.SwitchWeldDataSet(2, error);
            Assert.Equal(error, WeldSystemOrchestratorErrorCode#NoError);
            Assert.Equal(_ps2.SwitchActivePassiveMock.GetCallCount(), UINT#1);
        END_METHOD

        {Test}
        METHOD PUBLIC StartWelding
            _orchestrator.StartWelding(1);
            Assert.Equal(_ps1.StartMock.GetCallCount(), UINT#1);

            _orchestrator.StartWelding(2);
            Assert.Equal(_ps2.StartMock.GetCallCount(), UINT#1);
        END_METHOD

        {Test}
        METHOD PUBLIC StopWelding
            _orchestrator.StopWelding(1);
            Assert.Equal(_ps1.StopMock.GetCallCount(), UINT#1);

            _orchestrator.StopWelding(2);
            Assert.Equal(_ps2.StopMock.GetCallCount(), UINT#1);
        END_METHOD

        {Test}
        METHOD PUBLIC IsWelding
            _ps1.IsWeldingMock.Value := FALSE;
            _ps2.IsWeldingMock.Value := FALSE;
            Assert.Equal(_orchestrator.IsWelding(), FALSE);

            _ps1.IsWeldingMock.Value := TRUE;
            _ps2.IsWeldingMock.Value := TRUE;
            Assert.Equal(_orchestrator.IsWelding(), TRUE);

            _ps1.IsWeldingMock.Value := FALSE;
            _ps2.IsWeldingMock.Value := TRUE;
            Assert.Equal(_orchestrator.IsWelding(), FALSE);

            _ps1.IsWeldingMock.Value := TRUE;
            _ps2.IsWeldingMock.Value := FALSE;
            Assert.Equal(_orchestrator.IsWelding(), FALSE);
        END_METHOD

        {Test}
        METHOD PUBLIC IsWeldingNotConnected
            _ps1.IsWeldingMock.Value := TRUE;
            _ps2.IsWeldingMock.Value := TRUE;
            Assert.Equal(_orchestrator.IsWelding(), TRUE);

            _hardwareConfiguration.ConnectedPowerSources[1] := FALSE;
            _ps1.IsWeldingMock.Value := FALSE;
            _ps2.IsWeldingMock.Value := TRUE;
            Assert.Equal(_orchestrator.IsWelding(), TRUE);

            _hardwareConfiguration.ConnectedPowerSources[1] := TRUE;
            _orchestrator.PowerSourceDisconnected(UINT#1);
            _ps1.IsWeldingMock.Value := TRUE;
            _ps2.IsWeldingMock.Value := TRUE;
            Assert.Equal(_orchestrator.IsWelding(), FALSE);
        END_METHOD
    END_CLASS

END_NAMESPACE
