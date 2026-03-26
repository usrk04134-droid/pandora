USING Esab.Utils.Timer.Mock;
USING Esab.Utils.Assets.Mock;
USING Esab.Hmi.Modules.Mock;
USING AxUnit;

NAMESPACE Esab.Hmi.Modules.Tests

    {TestFixture}
    CLASS PushButtonTests
        VAR PRIVATE
            _pushButton : PushButton;
            _pushButtonListener : PushButtonMockListener;
            _io : PushButtonIo;
            _timer : OnDelayMock;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            _pushButton.Setup(REF(_io), _timer);
            _pushButton.SetListener(_pushButtonListener);
            _pushButton.SetIdentifier(3);
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            _io.Pressed.Read(FALSE);
            _io.Pressed.Read(FALSE);
            _io.Status.SetValue(FALSE);
            _pushButtonListener.MockReset();
            _timer.MockReset();
        END_METHOD

        {Test}
        METHOD PUBLIC PressButton
            Assert.Equal(_pushButton.IsPressed(), FALSE);

            _io.Pressed.Read(TRUE);

            Assert.Equal(_pushButton.IsPressed(), TRUE);

            _io.Pressed.Read(FALSE);

            Assert.Equal(_pushButton.IsPressed(), FALSE);
        END_METHOD

        {Test}
        METHOD PUBLIC SetStatus
            VAR_TEMP
                status : BOOL := FALSE;
            END_VAR

            _io.Status.Write(status);
            Assert.Equal(status, FALSE);

            _pushButton.SetStatus(TRUE);

            _io.Status.Write(status);
            Assert.Equal(status, TRUE);
        END_METHOD

        {Test}
        METHOD PUBLIC SetBlinkingStatus
            VAR_TEMP
                status : BOOL := FALSE;
            END_VAR

            _io.Status.Write(status);
            Assert.Equal(status, FALSE);

            _pushButton.SetStatus(1.0);

            _io.Status.Write(status);
            Assert.Equal(status, TRUE);

            _pushButton.Execute();

            _io.Status.Write(status);
            Assert.Equal(status, TRUE);

            _timer.ExpiredMock.Value := TRUE;
            _pushButton.Execute();
            _timer.ExpiredMock.Value := FALSE;

            _io.Status.Write(status);
            Assert.Equal(status, FALSE);

            _timer.ExpiredMock.Value := TRUE;
            _pushButton.Execute();
            _timer.ExpiredMock.Value := FALSE;

            _io.Status.Write(status);
            Assert.Equal(status, TRUE);
        END_METHOD

        {Test}
        METHOD PUBLIC PressedReleasedCallback
            Assert.Equal(_pushButtonListener.OnPushButtonPressedMock.GetCallCount(), UINT#0);
            Assert.Equal(_pushButtonListener.OnPushButtonMock.GetCallCount(), UINT#0);
            Assert.Equal(_pushButtonListener.OnPushButtonReleasedMock.GetCallCount(), UINT#0);

            _pushButton.Execute();

            _io.Pressed.Read(TRUE);

            _pushButton.Execute();

            Assert.Equal(_pushButtonListener.OnPushButtonPressedMock.Value, 3);
            Assert.Equal(_pushButtonListener.OnPushButtonPressedMock.GetCallCount(), UINT#1);
            Assert.Equal(_pushButtonListener.OnPushButtonMock.GetCallCount(), UINT#0);
            Assert.Equal(_pushButtonListener.OnPushButtonReleasedMock.GetCallCount(), UINT#0);

            _io.Pressed.Read(TRUE);

            _pushButton.Execute();
            _pushButton.Execute();

            Assert.Equal(_pushButtonListener.OnPushButtonMock.Value, 3);
            Assert.Equal(_pushButtonListener.OnPushButtonPressedMock.GetCallCount(), UINT#1);
            Assert.Equal(_pushButtonListener.OnPushButtonMock.GetCallCount(), UINT#2);
            Assert.Equal(_pushButtonListener.OnPushButtonReleasedMock.GetCallCount(), UINT#0);

            _io.Pressed.Read(FALSE);

            _pushButton.Execute();

            Assert.Equal(_pushButtonListener.OnPushButtonReleasedMock.Value, 3);
            Assert.Equal(_pushButtonListener.OnPushButtonPressedMock.GetCallCount(), UINT#1);
            Assert.Equal(_pushButtonListener.OnPushButtonMock.GetCallCount(), UINT#2);
            Assert.Equal(_pushButtonListener.OnPushButtonReleasedMock.GetCallCount(), UINT#1);
        END_METHOD
    END_CLASS

END_NAMESPACE