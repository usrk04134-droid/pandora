USING Esab.WeldSystem.PowerSources.Mock;
USING AxUnit;
USING Esab.Utils;
USING Esab.Utils.Timer.Mock;
USING Esab.Hmi.Modules;
USING Esab.Hmi;
USING Esab.Utils.Assets;
USING Esab.Motion.Mock;
USING Esab.Motion;
USING AxUnit;

NAMESPACE Esab.Hmi.Test

    {TestFixture}
    CLASS C_Hmi_JoystickTests
        VAR PRIVATE
            _hmi : C_Hmi;
            _highSpeedButton : PushButton;
            _highSpeedButtonIo : PushButtonIo;
            _joystick : DiscreteJoystick;
            _joystickIo : DiscreteJoystickIo;
            _joystickTimer : OnDelayMock;
            _globalState : GlobalState;
            _globalStateObservable : REF_TO GlobalStateObservable;
            _hAxis : ToPosAxisMock;
            _vAxis : ToPosAxisMock;

            _assets : AssetsManager;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            _joystick.Setup(REF(_joystickIo), _joystickTimer);
            _joystick.SetIdentifier(AssetIdentifier#C_Joystick_MotionJoystick);
            _assets.RegisterAsset(REF(_joystick));

            _highSpeedButton.Setup(REF(_highSpeedButtonIo));
            _highSpeedButton.SetIdentifier(AssetIdentifier#C_PushButton_System_HighSpeed);
            _assets.RegisterAsset(REF(_highSpeedButton));

            _hAxis.SetIdentifier(AssetIdentifier#HorizontalSlideAxis);
            _assets.RegisterAsset(REF(_hAxis));

            _vAxis.SetIdentifier(AssetIdentifier#VerticalSlideAxis);
            _assets.RegisterAsset(REF(_vAxis));

            _globalState.Setup(_assets);
            _globalState.SetIdentifier(AssetIdentifier#GlobalState);
            _assets.RegisterAsset(REF(_globalState));
            _globalStateObservable ?= _globalState.Observe();

            _hmi.Setup(_assets);
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            // Clear IO (twice for each to clear falling/rising)
            _joystickIo.Up.Read(FALSE);
            _joystickIo.Up.Read(FALSE);
            _joystickIo.Down.Read(FALSE);
            _joystickIo.Down.Read(FALSE);
            _joystickIo.Triangle.Read(FALSE);
            _joystickIo.Triangle.Read(FALSE);
            _joystickIo.Square.Read(FALSE);
            _joystickIo.Square.Read(FALSE);

            _highSpeedButtonIo.Pressed.Read(FALSE);
            _highSpeedButtonIo.Pressed.Read(FALSE);

            _joystickTimer.MockReset();
            _hAxis.MockReset();
            _vAxis.MockReset();

            // Execute once so the HMI Controller requests the necessary assets
            THIS.Execute();
        END_METHOD

        METHOD PRIVATE Execute
            _assets.Execute();
            _hmi.Execute();
        END_METHOD

        // {Test(position := 1)}
        // {Test(position := 2)}
        // {Test(position := 3)}
        // {Test(position := 4)}
        METHOD PUBLIC Hmi_Joystick_LongHold
            VAR_INPUT
                position : INT;
            END_VAR

            VAR_TEMP
                asset : REF_TO Asset;
                joystickPosition : JoystickPosition;
            END_VAR

            joystickPosition := position;

            // Trigger long hold callback
            CASE joystickPosition OF
                JoystickPosition#Up:
                    _joystickIo.Up.Read(TRUE);
                JoystickPosition#Down:
                    _joystickIo.Down.Read(TRUE);
                JoystickPosition#Triangle:
                    _joystickIo.Triangle.Read(TRUE);
                JoystickPosition#Square:
                    _joystickIo.Square.Read(TRUE);
            END_CASE;

            THIS.Execute();
            _joystickTimer.ExpiredMock.Value := TRUE;
            THIS.Execute();

            // The axis should be locked to the HMI now.
            CASE joystickPosition OF
                JoystickPosition#Up:
                    asset := _assets.RequestAssetHandle(NULL, Esab.AssetIdentifier#VerticalSlideAxis);
                JoystickPosition#Down:
                    asset := _assets.RequestAssetHandle(NULL, Esab.AssetIdentifier#VerticalSlideAxis);
                JoystickPosition#Triangle:
                    asset := _assets.RequestAssetHandle(NULL, Esab.AssetIdentifier#HorizontalSlideAxis);
                JoystickPosition#Square:
                    asset := _assets.RequestAssetHandle(NULL, Esab.AssetIdentifier#HorizontalSlideAxis);
            END_CASE;
            Assert.Equal(asset = NULL, TRUE);

            THIS.Execute();
            CASE joystickPosition OF
                JoystickPosition#Up:
                    Assert.Equal(_vAxis.JogPositiveMock.GetCallCount(), UINT#1);
                JoystickPosition#Down:
                    Assert.Equal(_vAxis.JogNegativeMock.GetCallCount(), UINT#1);
                JoystickPosition#Triangle:
                    Assert.Equal(_hAxis.JogNegativeMock.GetCallCount(), UINT#1);
                JoystickPosition#Square:
                    Assert.Equal(_hAxis.JogPositiveMock.GetCallCount(), UINT#1);
            END_CASE;

            THIS.Execute();
            THIS.Execute();
            THIS.Execute();
            THIS.Execute();

            CASE joystickPosition OF
                JoystickPosition#Up:
                    Assert.Equal(_vAxis.JogPositiveMock.GetCallCount(), UINT#5);
                JoystickPosition#Down:
                    Assert.Equal(_vAxis.JogNegativeMock.GetCallCount(), UINT#5);
                JoystickPosition#Triangle:
                    Assert.Equal(_hAxis.JogNegativeMock.GetCallCount(), UINT#5);
                JoystickPosition#Square:
                    Assert.Equal(_hAxis.JogPositiveMock.GetCallCount(), UINT#5);
            END_CASE;

            CASE joystickPosition OF
                JoystickPosition#Up:
                    _joystickIo.Up.Read(FALSE);
                JoystickPosition#Down:
                    _joystickIo.Down.Read(FALSE);
                JoystickPosition#Triangle:
                    _joystickIo.Triangle.Read(FALSE);
                JoystickPosition#Square:
                    _joystickIo.Square.Read(FALSE);
            END_CASE;
            _joystickTimer.MockReset();

            THIS.Execute();

            CASE joystickPosition OF
                JoystickPosition#Up:
                    Assert.Equal(_vAxis.JogPositiveMock.GetCallCount(), UINT#5);
                JoystickPosition#Down:
                    Assert.Equal(_vAxis.JogNegativeMock.GetCallCount(), UINT#5);
                JoystickPosition#Triangle:
                    Assert.Equal(_hAxis.JogNegativeMock.GetCallCount(), UINT#5);
                JoystickPosition#Square:
                    Assert.Equal(_hAxis.JogPositiveMock.GetCallCount(), UINT#5);
            END_CASE;

            // The axis should be unlocked after the joystick is released.
            CASE joystickPosition OF
                JoystickPosition#Up:
                    asset := _assets.RequestAssetHandle(NULL, Esab.AssetIdentifier#VerticalSlideAxis);
                JoystickPosition#Down:
                    asset := _assets.RequestAssetHandle(NULL, Esab.AssetIdentifier#VerticalSlideAxis);
                JoystickPosition#Triangle:
                    asset := _assets.RequestAssetHandle(NULL, Esab.AssetIdentifier#HorizontalSlideAxis);
                JoystickPosition#Square:
                    asset := _assets.RequestAssetHandle(NULL, Esab.AssetIdentifier#HorizontalSlideAxis);
            END_CASE;
            Assert.Equal(asset <> NULL, TRUE);
        END_METHOD

        {Test}
        METHOD PUBLIC HighSpeed
            VAR_TEMP
                status : BOOL;
            END_VAR

            Assert.Equal(_globalState.GetHighSpeed(), FALSE);
            Assert.Equal(_globalStateObservable^.HighSpeed, FALSE);
            _highSpeedButtonIo.Status.Write(status);
            Assert.Equal(status, FALSE);

            THIS.Execute();

            _highSpeedButtonIo.Pressed.Read(TRUE);

            THIS.Execute();

            Assert.Equal(_globalState.GetHighSpeed(), TRUE);
            THIS.Execute();
            Assert.Equal(_globalStateObservable^.HighSpeed, TRUE);
            _highSpeedButtonIo.Status.Write(status);
            Assert.Equal(status, TRUE);
        END_METHOD
    END_CLASS

    {TestFixture}
    CLASS C_Hmi_FluxSystemTests
        VAR PRIVATE
            _hmi : C_Hmi;
            _fluxSystemRelease : PushButton;
            _fluxSystemReleaseIo : PushButtonIo;
            _fluxSystemRecover : PushButton;
            _fluxSystemRecoverIo : PushButtonIo;

            _fluxSystem : FluxSystemMock;

            _assets : AssetsManager;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            _hmi.Setup(_assets);

            _fluxSystem.SetIdentifier(Esab.AssetIdentifier#FluxSystem);
            _assets.RegisterAsset(REF(_fluxSystem));

            _fluxSystemRelease.Setup(REF(_fluxSystemReleaseIo));
            _fluxSystemRelease.SetIdentifier(Esab.AssetIdentifier#C_PushButton_FluxSystem_Release);
            _assets.RegisterAsset(REF(_fluxSystemRelease));
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            _fluxSystemReleaseIo.Pressed.Read(FALSE);
            _fluxSystemReleaseIo.Pressed.Read(FALSE);

            _fluxSystem.MockReset();

            THIS.Execute();
            THIS.Execute();
        END_METHOD

        METHOD PRIVATE Execute
            _assets.Execute();
            _hmi.Execute();
        END_METHOD

        {Test}
        METHOD PUBLIC Release
            VAR_TEMP
                status : BOOL := FALSE;
            END_VAR

            _fluxSystemReleaseIo.Pressed.Read(TRUE);
            THIS.Execute();
            _fluxSystemReleaseIo.Pressed.Read(FALSE);
            THIS.Execute();

            Assert.Equal(_fluxSystem.ReleaseMock.GetCallCount(), UINT#1);
            _fluxSystem.ObservableMock.Releasing := TRUE;
            THIS.Execute();
            _fluxSystemReleaseIo.Status.Write(status);
            Assert.Equal(status, TRUE);

            _fluxSystemReleaseIo.Pressed.Read(TRUE);
            THIS.Execute();
            _fluxSystemReleaseIo.Pressed.Read(FALSE);
            THIS.Execute();

            Assert.Equal(_fluxSystem.StopReleaseMock.GetCallCount(), UINT#1);
            _fluxSystem.ObservableMock.Releasing := FALSE;
            THIS.Execute();
            _fluxSystemReleaseIo.Status.Write(status);
            Assert.Equal(status, FALSE);
        END_METHOD
    END_CLASS

    {TestFixture}
    CLASS C_Hmi_WireFeed
        VAR PRIVATE
            _hmi : C_Hmi;
            _wireFeed1 : TwinPushButton;
            _wireFeed1Io : TwinPushButtonIo;
            _wireFeed2 : TwinPushButton;
            _wireFeed2Io : TwinPushButtonIo;

            _powerSource1 : Aristo1000Mock;
            _powerSource2 : Aristo1000Mock;

            _assets : AssetsManager;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            _hmi.Setup(_assets);

            _wireFeed1.Setup(REF(_wireFeed1Io));
            _wireFeed1.SetIdentifier(AssetIdentifier#C_TwinPushButton_WireFeed1);
            _assets.RegisterAsset(REF(_wireFeed1));

            _wireFeed2.Setup(REF(_wireFeed2Io));
            _wireFeed2.SetIdentifier(AssetIdentifier#C_TwinPushButton_WireFeed2);
            _assets.RegisterAsset(REF(_wireFeed2));

            _powerSource1.SetIdentifier(AssetIdentifier#PowerSource1);
            _assets.RegisterAsset(REF(_powerSource1));

            _powerSource2.SetIdentifier(AssetIdentifier#PowerSource2);
            _assets.RegisterAsset(REF(_powerSource2));
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            _powerSource1.MockReset();
            _powerSource2.MockReset();

            THIS.Execute();
        END_METHOD

        METHOD PRIVATE Execute
            _assets.Execute();
            _hmi.Execute();
        END_METHOD

        {Test}
        METHOD PUBLIC WireFeed1
            THIS.Execute();
            _wireFeed1Io.Direction1.Read(TRUE);
            THIS.Execute();
            _wireFeed1Io.Direction1.Read(TRUE);
            THIS.Execute();
            THIS.Execute();
            THIS.Execute();

            Assert.Equal(_powerSource1.WireFeedJogNegMock.GetCallCount(), UINT#3);
            Assert.Equal(_powerSource1.WireFeedJogPosMock.GetCallCount(), UINT#0);

            _wireFeed1Io.Direction1.Read(FALSE);
            THIS.Execute();
            _wireFeed1Io.Direction1.Read(FALSE);
            THIS.Execute();
            THIS.Execute();
            THIS.Execute();

            Assert.Equal(_powerSource1.WireFeedJogNegMock.GetCallCount(), UINT#3);
            Assert.Equal(_powerSource1.WireFeedJogPosMock.GetCallCount(), UINT#0);

            _wireFeed1Io.Direction2.Read(TRUE);
            THIS.Execute();
            _wireFeed1Io.Direction2.Read(TRUE);
            THIS.Execute();
            THIS.Execute();
            THIS.Execute();

            Assert.Equal(_powerSource1.WireFeedJogNegMock.GetCallCount(), UINT#3);
            Assert.Equal(_powerSource1.WireFeedJogPosMock.GetCallCount(), UINT#3);

            _wireFeed1Io.Direction2.Read(FALSE);
            THIS.Execute();
            THIS.Execute();
            THIS.Execute();
            THIS.Execute();

            Assert.Equal(_powerSource1.WireFeedJogNegMock.GetCallCount(), UINT#3);
            Assert.Equal(_powerSource1.WireFeedJogPosMock.GetCallCount(), UINT#3);
        END_METHOD

        {Test}
        METHOD PUBLIC WireFeed2
            THIS.Execute();
            _wireFeed2Io.Direction1.Read(TRUE);
            THIS.Execute();
            _wireFeed2Io.Direction1.Read(TRUE);
            THIS.Execute();
            THIS.Execute();
            THIS.Execute();

            Assert.Equal(_powerSource2.WireFeedJogNegMock.GetCallCount(), UINT#3);
            Assert.Equal(_powerSource2.WireFeedJogPosMock.GetCallCount(), UINT#0);

            _wireFeed2Io.Direction1.Read(FALSE);
            THIS.Execute();
            _wireFeed2Io.Direction1.Read(FALSE);
            THIS.Execute();
            THIS.Execute();
            THIS.Execute();

            Assert.Equal(_powerSource2.WireFeedJogNegMock.GetCallCount(), UINT#3);
            Assert.Equal(_powerSource2.WireFeedJogPosMock.GetCallCount(), UINT#0);

            _wireFeed2Io.Direction2.Read(TRUE);
            THIS.Execute();
            _wireFeed2Io.Direction2.Read(TRUE);
            THIS.Execute();
            THIS.Execute();
            THIS.Execute();

            Assert.Equal(_powerSource2.WireFeedJogNegMock.GetCallCount(), UINT#3);
            Assert.Equal(_powerSource2.WireFeedJogPosMock.GetCallCount(), UINT#3);

            _wireFeed2Io.Direction2.Read(FALSE);
            THIS.Execute();
            _wireFeed2Io.Direction2.Read(FALSE);
            THIS.Execute();
            THIS.Execute();
            THIS.Execute();

            Assert.Equal(_powerSource2.WireFeedJogNegMock.GetCallCount(), UINT#3);
            Assert.Equal(_powerSource2.WireFeedJogPosMock.GetCallCount(), UINT#3);
        END_METHOD
    END_CLASS

END_NAMESPACE
