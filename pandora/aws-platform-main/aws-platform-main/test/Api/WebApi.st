USING Esab.Utils;
USING Esab.WeldSystem.PowerSources.Mock;
USING Esab.WeldSystem.PowerSources;
USING Esab.Motion.Mock;
USING Esab.Utils.Alarming.Mock;
USING Esab.Utils.Assets.Mock;
USING Esab.Utils.Assets;

USING AxUnit;

NAMESPACE Esab.Api.Test

    {TestFixture}
    {Category(WebApi)}
    CLASS WebApiSlideCrossTests
        VAR PRIVATE
            _api : WebApi;
            _defaultApi : WebApi;
            _webApiData : WebApiData;
            _defaultWebApiData : WebApiData;
            _horizontalSlideMock : ToPosAxisMock;
            _verticalSlideMock : ToPosAxisMock;
            _assetsManagerMock : AssetsManagerMock;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            _api := _defaultApi;
            _api.Setup(_assetsManagerMock, REF(_webApiData));
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            _webApiData := _defaultWebApiData;

            _horizontalSlideMock.MockReset();
            _verticalSlideMock.MockReset();
            _assetsManagerMock.MockReset();

            // Configure assets manager mock: by default hand out the horizontal axis when requested
            _assetsManagerMock.RequestAssetHandleMock.Qualifier := AssetIdentifier#HorizontalSlideAxis;
            _assetsManagerMock.RequestAssetHandleMock.Asset := REF(_horizontalSlideMock);
            // Observables are not required for these tests; let ObserveAsset return NULL by default
            _assetsManagerMock.ObserveAssetMock.Value := NULL;
        END_METHOD

        {Test}
        METHOD PUBLIC HorizontalSlideEnable
            _webApiData.Inputs.HorizontalSlide.Commands.Enable.Execute.Read(TRUE);

            _api.Execute();

            Assert.Equal(_horizontalSlideMock.PowerOnMock.GetCallCount(), UINT#1);
        END_METHOD

        {Test}
        METHOD PUBLIC VerticalSlideEnable
            // Reconfigure assets manager mock to return vertical axis for this test
            _assetsManagerMock.RequestAssetHandleMock.Qualifier := AssetIdentifier#VerticalSlideAxis;
            _assetsManagerMock.RequestAssetHandleMock.Asset := REF(_verticalSlideMock);

            _webApiData.Inputs.VerticalSlide.Commands.Enable.Execute.Read(TRUE);

            _api.Execute();

            Assert.Equal(_verticalSlideMock.PowerOnMock.GetCallCount(), UINT#1);
        END_METHOD

        {Test}
        METHOD PUBLIC HorizontalSlideAbsolutePositionCommand
            _webApiData.Inputs.HorizontalSlide.Commands.Positioning.CommandType.Read(PositioningCommandType#Absolute);
            _webApiData.Inputs.HorizontalSlide.Commands.Positioning.Position.Read(REAL#1.0);
            _webApiData.Inputs.HorizontalSlide.Commands.Positioning.Velocity.Read(REAL#2.0);
            _webApiData.Inputs.HorizontalSlide.Commands.Positioning.Acceleration.Read(REAL#3.0);
            _webApiData.Inputs.HorizontalSlide.Commands.Positioning.Deceleration.Read(REAL#4.0);
            _webApiData.Inputs.HorizontalSlide.Commands.Positioning.Jerk.Read(REAL#5.0);
            _webApiData.Inputs.HorizontalSlide.Commands.Positioning.Execute.Read(TRUE);

            _api.Execute();

            Assert.Equal(_horizontalSlideMock.ExecutePositioningCommandMock.GetCallCount(), UINT#1);
            //Assert.Equal(_horizontalSlideHandlerMock.ExecuteCommandMock.Command.Id, 123);
            Assert.Equal(_horizontalSlideMock.ExecutePositioningCommandMock.Command.CommandType, Esab.Motion.AxisCommandType#Absolute);
            Assert.Equal(_horizontalSlideMock.ExecutePositioningCommandMock.Command.Position, 1.0);
            Assert.Equal(_horizontalSlideMock.ExecutePositioningCommandMock.Command.Velocity, 2.0);
            Assert.Equal(_horizontalSlideMock.ExecutePositioningCommandMock.Command.Acceleration, 3.0);
            Assert.Equal(_horizontalSlideMock.ExecutePositioningCommandMock.Command.Deceleration, 4.0);
            Assert.Equal(_horizontalSlideMock.ExecutePositioningCommandMock.Command.Jerk, 5.0);
            ;
        END_METHOD

        {Test}
        METHOD PUBLIC HorizontalSlideRelativePositionCommand
            _webApiData.Inputs.HorizontalSlide.Commands.Positioning.CommandType.Read(PositioningCommandType#Relative);
            _webApiData.Inputs.HorizontalSlide.Commands.Positioning.Position.Read(REAL#1.0);
            _webApiData.Inputs.HorizontalSlide.Commands.Positioning.Velocity.Read(REAL#2.0);
            _webApiData.Inputs.HorizontalSlide.Commands.Positioning.Acceleration.Read(REAL#3.0);
            _webApiData.Inputs.HorizontalSlide.Commands.Positioning.Deceleration.Read(REAL#4.0);
            _webApiData.Inputs.HorizontalSlide.Commands.Positioning.Jerk.Read(REAL#5.0);
            _webApiData.Inputs.HorizontalSlide.Commands.Positioning.Execute.Read(TRUE);

            _api.Execute();

            Assert.Equal(_horizontalSlideMock.ExecutePositioningCommandMock.GetCallCount(), UINT#1);
            //Assert.Equal(_horizontalSlideHandlerMock.ExecuteCommandMock.Command.Id, 123);
            Assert.Equal(_horizontalSlideMock.ExecutePositioningCommandMock.Command.CommandType, Esab.Motion.AxisCommandType#Relative);
            Assert.Equal(_horizontalSlideMock.ExecutePositioningCommandMock.Command.Position, 1.0);
            Assert.Equal(_horizontalSlideMock.ExecutePositioningCommandMock.Command.Velocity, 2.0);
            Assert.Equal(_horizontalSlideMock.ExecutePositioningCommandMock.Command.Acceleration, 3.0);
            Assert.Equal(_horizontalSlideMock.ExecutePositioningCommandMock.Command.Deceleration, 4.0);
            Assert.Equal(_horizontalSlideMock.ExecutePositioningCommandMock.Command.Jerk, 5.0);
        END_METHOD

        {Test}
        METHOD PUBLIC HorizontalSlideVelocityCommand
            _webApiData.Inputs.HorizontalSlide.Commands.Positioning.CommandType.Read(PositioningCommandType#Velocity);
            _webApiData.Inputs.HorizontalSlide.Commands.Positioning.Position.Read(REAL#1.0);
            _webApiData.Inputs.HorizontalSlide.Commands.Positioning.Velocity.Read(REAL#2.0);
            _webApiData.Inputs.HorizontalSlide.Commands.Positioning.Acceleration.Read(REAL#3.0);
            _webApiData.Inputs.HorizontalSlide.Commands.Positioning.Deceleration.Read(REAL#4.0);
            _webApiData.Inputs.HorizontalSlide.Commands.Positioning.Jerk.Read(REAL#5.0);
            _webApiData.Inputs.HorizontalSlide.Commands.Positioning.Execute.Read(TRUE);

            _api.Execute();

            Assert.Equal(_horizontalSlideMock.ExecutePositioningCommandMock.GetCallCount(), UINT#1);
            //Assert.Equal(_horizontalSlideHandlerMock.ExecuteCommandMock.Command.Id, 123);
            Assert.Equal(_horizontalSlideMock.ExecutePositioningCommandMock.Command.CommandType, Esab.Motion.AxisCommandType#Velocity);
            Assert.Equal(_horizontalSlideMock.ExecutePositioningCommandMock.Command.Position, 1.0);
            Assert.Equal(_horizontalSlideMock.ExecutePositioningCommandMock.Command.Velocity, 2.0);
            Assert.Equal(_horizontalSlideMock.ExecutePositioningCommandMock.Command.Acceleration, 3.0);
            Assert.Equal(_horizontalSlideMock.ExecutePositioningCommandMock.Command.Deceleration, 4.0);
            Assert.Equal(_horizontalSlideMock.ExecutePositioningCommandMock.Command.Jerk, 5.0);
        END_METHOD

        {Test}
        METHOD PUBLIC HorizontalSlideHaltCommand
            _webApiData.Inputs.HorizontalSlide.Commands.Positioning.CommandType.Read(PositioningCommandType#Halt);
            _webApiData.Inputs.HorizontalSlide.Commands.Positioning.Position.Read(REAL#1.0);
            _webApiData.Inputs.HorizontalSlide.Commands.Positioning.Velocity.Read(REAL#2.0);
            _webApiData.Inputs.HorizontalSlide.Commands.Positioning.Acceleration.Read(REAL#3.0);
            _webApiData.Inputs.HorizontalSlide.Commands.Positioning.Deceleration.Read(REAL#4.0);
            _webApiData.Inputs.HorizontalSlide.Commands.Positioning.Jerk.Read(REAL#5.0);
            _webApiData.Inputs.HorizontalSlide.Commands.Positioning.Execute.Read(TRUE);

            _api.Execute();

            Assert.Equal(_horizontalSlideMock.ExecutePositioningCommandMock.GetCallCount(), UINT#1);
            //Assert.Equal(_horizontalSlideHandlerMock.ExecuteCommandMock.Command.Id, 123);
            Assert.Equal(_horizontalSlideMock.ExecutePositioningCommandMock.Command.CommandType, Esab.Motion.AxisCommandType#Halt);
            Assert.Equal(_horizontalSlideMock.ExecutePositioningCommandMock.Command.Position, 1.0);
            Assert.Equal(_horizontalSlideMock.ExecutePositioningCommandMock.Command.Velocity, 2.0);
            Assert.Equal(_horizontalSlideMock.ExecutePositioningCommandMock.Command.Acceleration, 3.0);
            Assert.Equal(_horizontalSlideMock.ExecutePositioningCommandMock.Command.Deceleration, 4.0);
            Assert.Equal(_horizontalSlideMock.ExecutePositioningCommandMock.Command.Jerk, 5.0);
        END_METHOD

        {Test}
        METHOD PUBLIC HorizontalSlideDirectAbsoluteHomingCommand

            _webApiData.Inputs.HorizontalSlide.Commands.Homing.HomingType.Read(HomingCommandType#DirectAbsolute);
            _webApiData.Inputs.HorizontalSlide.Commands.Homing.Position.Read(REAL#10.0);
            _webApiData.Inputs.HorizontalSlide.Commands.Homing.Execute.Read(TRUE);

            _api.Execute();

            Assert.Equal(_horizontalSlideMock.ExecuteHomingCommandMock.GetCallCount(), UINT#1);
            Assert.Equal(_horizontalSlideMock.ExecuteHomingCommandMock.Command.HomingType, Esab.Motion.AxisHomingType#DirectAbsolute);
            Assert.Equal(_horizontalSlideMock.ExecuteHomingCommandMock.Command.Position, 10.0);
        END_METHOD
    END_CLASS

    {TestFixture}
    {Category(WebApi)}
    CLASS WebApiWeldTests
        VAR PRIVATE
            _api : WebApi;
            _webApiData : WebApiData;
            _powerSourceMock : Aristo1000Mock;
            _assetsManagerMock : AssetsManagerMock;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            _api.Setup(_assetsManagerMock, REF(_webApiData));
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            THIS.ResetWebApiData();

            _powerSourceMock.MockReset();
            _assetsManagerMock.MockReset();

            _assetsManagerMock.RequestAssetHandleMock.Qualifier := AssetIdentifier#PowerSource1;
            _assetsManagerMock.RequestAssetHandleMock.Asset := REF(_powerSourceMock);
            // Observables are not required for these tests; let ObserveAsset return NULL by default
            _assetsManagerMock.ObserveAssetMock.Value := NULL;
        END_METHOD

        METHOD PRIVATE ResetWebApiData
            // Commands
            _webApiData.Inputs.PowerSource1.Commands.StartWeld.Execute.Read(FALSE);
            _webApiData.Inputs.PowerSource1.Commands.StartWeld.Execute.Read(FALSE);

            _webApiData.Inputs.PowerSource1.Commands.StopWeld.Execute.Read(FALSE);
            _webApiData.Inputs.PowerSource1.Commands.StopWeld.Execute.Read(FALSE);

            _webApiData.Inputs.PowerSource1.Commands.UpdateStatus.Execute.Read(FALSE);
            _webApiData.Inputs.PowerSource1.Commands.UpdateStatus.Execute.Read(FALSE);

            // Parameters
            _webApiData.Inputs.PowerSource1.ActiveArea.AcBalance.Read(UINT#0);
            _webApiData.Inputs.PowerSource1.ActiveArea.AcFrequency.Read(UINT#0);
            _webApiData.Inputs.PowerSource1.ActiveArea.AcOffset.Read(UINT#0);
            _webApiData.Inputs.PowerSource1.ActiveArea.AcPhaseShift.Read(UINT#0);
            _webApiData.Inputs.PowerSource1.ActiveArea.Current.Read(UINT#0);
            _webApiData.Inputs.PowerSource1.ActiveArea.IceWireSpeedPercentage.Read(UINT#0);
            _webApiData.Inputs.PowerSource1.ActiveArea.RegulationDynamics.Read(UINT#0);
            _webApiData.Inputs.PowerSource1.ActiveArea.RegulationInductance.Read(UINT#0);
            _webApiData.Inputs.PowerSource1.ActiveArea.RegulationType.Read(UINT#0);
            _webApiData.Inputs.PowerSource1.ActiveArea.StartAdjust.Read(UINT#0);
            _webApiData.Inputs.PowerSource1.ActiveArea.TravelSpeed.Read(UINT#0);
            _webApiData.Inputs.PowerSource1.ActiveArea.Voltage.Read(UINT#0);

            _webApiData.Inputs.PowerSource1.WeldDataSet.AcBalance.Read(UINT#0);
            _webApiData.Inputs.PowerSource1.WeldDataSet.AcFrequency.Read(UINT#0);
            _webApiData.Inputs.PowerSource1.WeldDataSet.AcOffset.Read(UINT#0);
            _webApiData.Inputs.PowerSource1.WeldDataSet.AcPhaseShift.Read(UINT#0);
            _webApiData.Inputs.PowerSource1.WeldDataSet.Current.Read(UINT#0);
            _webApiData.Inputs.PowerSource1.WeldDataSet.IceWireSpeedPercentage.Read(UINT#0);
            _webApiData.Inputs.PowerSource1.WeldDataSet.RegulationDynamics.Read(UINT#0);
            _webApiData.Inputs.PowerSource1.WeldDataSet.RegulationInductance.Read(UINT#0);
            _webApiData.Inputs.PowerSource1.WeldDataSet.RegulationType.Read(UINT#0);
            _webApiData.Inputs.PowerSource1.WeldDataSet.StartAdjust.Read(UINT#0);
            _webApiData.Inputs.PowerSource1.WeldDataSet.TravelSpeed.Read(UINT#0);
            _webApiData.Inputs.PowerSource1.WeldDataSet.Voltage.Read(UINT#0);
        END_METHOD

        {Test}
        METHOD PUBLIC AssetManagerMockRequestAsset
            VAR_TEMP
                asset : REF_TO Asset;
                handle : IPowerSource;
            END_VAR

            _assetsManagerMock.RequestAssetHandleMock.Qualifier := AssetIdentifier#PowerSource1;
            _assetsManagerMock.RequestAssetHandleMock.Asset := REF(_powerSourceMock);

            asset := _assetsManagerMock.RequestAssetHandle(_api, AssetIdentifier#PowerSource1);

            Assert.Equal(asset <> NULL, TRUE);

            handle ?= asset^;

            Assert.Equal(handle <> NULL, TRUE);
        END_METHOD

        {Test}
        METHOD PUBLIC PowerSource1WriteAsync
            _webApiData.Inputs.PowerSource1.Commands.WriteAsync.Index.Read(DINT#46);
            _webApiData.Inputs.PowerSource1.Commands.WriteAsync.Value.Read(UINT#2);
            _webApiData.Inputs.PowerSource1.Commands.WriteAsync.Execute.Read(TRUE);

            Assert.Equal(_powerSourceMock.WriteAsyncCmdMock.GetCallCount(), UINT#1);
            Assert.Equal(_powerSourceMock.WriteAsyncCmdMock.Command = NULL, FALSE);
            Assert.Equal(_powerSourceMock.WriteAsyncCmdMock.Command^.Index, DINT#46);
            Assert.Equal(_powerSourceMock.WriteAsyncCmdMock.Command^.Value, DINT#2);
        END_METHOD

        {Test}
        METHOD PUBLIC PowerSource1ReadAsync
            VAR_TEMP
                command : REF_TO UIntAsyncCommand := NULL;
            END_VAR
            _webApiData.Inputs.PowerSource1.Commands.ReadAsync.Index.Read(DINT#46);
            _webApiData.Inputs.PowerSource1.Commands.ReadAsync.Execute.Read(TRUE);

            Assert.Equal(_powerSourceMock.ReadAsyncCmdMock.GetCallCount(), UINT#1);
            Assert.Equal(_powerSourceMock.ReadAsyncCmdMock.Command = NULL, FALSE);
            Assert.Equal(_powerSourceMock.ReadAsyncCmdMock.Command^.Index, DINT#46);
            Assert.Equal(_webApiData.Outputs.PowerSource1.Commands.ReadAsync.Busy.Value, TRUE);
            Assert.Equal(_webApiData.Outputs.PowerSource1.Commands.ReadAsync.Executed.Value, TRUE);

            _webApiData.Inputs.PowerSource1.Commands.ReadAsync.Execute.Read(FALSE);
            Assert.Equal(_webApiData.Outputs.PowerSource1.Commands.ReadAsync.Executed.Value, FALSE);
            Assert.Equal(_webApiData.Outputs.PowerSource1.Commands.ReadAsync.Busy.Value, TRUE);

            command := _powerSourceMock.ReadAsyncCmdMock.Command;
            command^.Value := UINT#20;

            _api.AsyncCommandCallback(command, CommandStatus#Success);
            Assert.Equal(_webApiData.Outputs.PowerSource1.Commands.ReadAsync.Busy.Value, FALSE);
            Assert.Equal(_webApiData.Outputs.PowerSource1.Commands.ReadAsync.ErrorCode.Value, UINT#0);
            Assert.Equal(_webApiData.Outputs.PowerSource1.Commands.ReadAsync.Value.Value, UINT#20);
        END_METHOD

        {Test}
        METHOD PUBLIC PowerSource1ReadAsyncFailiure
            VAR_TEMP
                command : REF_TO UIntAsyncCommand := NULL;
            END_VAR
            _webApiData.Inputs.PowerSource1.Commands.ReadAsync.Index.Read(DINT#46);
            _webApiData.Inputs.PowerSource1.Commands.ReadAsync.Execute.Read(TRUE);
            _webApiData.Inputs.PowerSource1.Commands.ReadAsync.Execute.Read(FALSE);

            command := _powerSourceMock.ReadAsyncCmdMock.Command;
            command^.Value := UINT#20;

            _api.AsyncCommandCallback(command, CommandStatus#Error);
            Assert.Equal(_webApiData.Outputs.PowerSource1.Commands.ReadAsync.Busy.Value, FALSE);
            Assert.Equal(_webApiData.Outputs.PowerSource1.Commands.ReadAsync.ErrorCode.Value, UINT#2);
        END_METHOD
    END_CLASS

END_NAMESPACE