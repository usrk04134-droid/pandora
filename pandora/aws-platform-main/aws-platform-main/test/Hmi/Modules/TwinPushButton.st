USING Esab.Utils.Assets.Mock;
USING Esab.Hmi.Modules.Mock;
USING AxUnit;

USING Esab.Utils.Assets.Mock;

NAMESPACE Esab.Hmi.Modules.Tests

    {TestFixture}
    CLASS TwinPushButtonTests
        VAR PRIVATE
            _pushButton : TwinPushButton;
            _pushButtonListener : PushButtonMockListener;
            _io : TwinPushButtonIo;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            _pushButton.Setup(REF(_io));
            _pushButton.SetListener(_pushButtonListener);
            _pushButton.SetIdentifier(3);
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            _io.Direction1.Read(FALSE);
            _io.Direction1.Read(FALSE);
            _io.Direction2.Read(FALSE);
            _io.Direction2.Read(FALSE);
            _io.Status.SetValue(FALSE);
            _pushButtonListener.MockReset();
        END_METHOD

        {Test}
        METHOD PUBLIC ActivateDirection1
            Assert.Equal(_pushButton.IsPressed(), FALSE);

            _io.Direction1.Read(TRUE);

            Assert.Equal(_pushButton.IsPressed(), TRUE);
            Assert.Equal(_pushButton.IsInDirection1(), TRUE);
            Assert.Equal(_pushButton.IsInDirection2(), FALSE);

            _io.Direction1.Read(FALSE);

            Assert.Equal(_pushButton.IsPressed(), FALSE);
            Assert.Equal(_pushButton.IsInDirection1(), FALSE);
            Assert.Equal(_pushButton.IsInDirection2(), FALSE);
        END_METHOD

        {Test}
        METHOD PUBLIC ActivateDirection2
            Assert.Equal(_pushButton.IsPressed(), FALSE);

            _io.Direction2.Read(TRUE);

            Assert.Equal(_pushButton.IsPressed(), TRUE);
            Assert.Equal(_pushButton.IsInDirection1(), FALSE);
            Assert.Equal(_pushButton.IsInDirection2(), TRUE);

            _io.Direction2.Read(FALSE);

            Assert.Equal(_pushButton.IsPressed(), FALSE);
            Assert.Equal(_pushButton.IsInDirection1(), FALSE);
            Assert.Equal(_pushButton.IsInDirection2(), FALSE);
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
        METHOD PUBLIC Direction1ReleasedCallback
            Assert.Equal(_pushButtonListener.OnPushButtonPressedMock.GetCallCount(), UINT#0);
            Assert.Equal(_pushButtonListener.OnPushButtonMock.GetCallCount(), UINT#0);
            Assert.Equal(_pushButtonListener.OnPushButtonReleasedMock.GetCallCount(), UINT#0);

            _pushButton.Execute();

            _io.Direction1.Read(TRUE);

            _pushButton.Execute();

            Assert.Equal(_pushButtonListener.OnPushButtonPressedMock.Value, 3);
            Assert.Equal(_pushButtonListener.OnPushButtonPressedMock.GetCallCount(), UINT#1);
            Assert.Equal(_pushButtonListener.OnPushButtonMock.GetCallCount(), UINT#0);
            Assert.Equal(_pushButtonListener.OnPushButtonReleasedMock.GetCallCount(), UINT#0);

            _io.Direction1.Read(TRUE);

            _pushButton.Execute();
            _pushButton.Execute();

            Assert.Equal(_pushButtonListener.OnPushButtonMock.Value, 3);
            Assert.Equal(_pushButtonListener.OnPushButtonPressedMock.GetCallCount(), UINT#1);
            Assert.Equal(_pushButtonListener.OnPushButtonMock.GetCallCount(), UINT#2);
            Assert.Equal(_pushButtonListener.OnPushButtonReleasedMock.GetCallCount(), UINT#0);

            _io.Direction1.Read(FALSE);

            _pushButton.Execute();

            Assert.Equal(_pushButtonListener.OnPushButtonReleasedMock.Value, 3);
            Assert.Equal(_pushButtonListener.OnPushButtonPressedMock.GetCallCount(), UINT#1);
            Assert.Equal(_pushButtonListener.OnPushButtonMock.GetCallCount(), UINT#2);
            Assert.Equal(_pushButtonListener.OnPushButtonReleasedMock.GetCallCount(), UINT#1);
        END_METHOD

        {Test}
        METHOD PUBLIC OnPushButtonCallback
            _io.Direction1.Read(TRUE);
            _io.Direction1.Read(TRUE);
            _pushButton.Execute();
            Assert.Equal(_pushButtonListener.OnPushButtonMock.GetCallCount(), UINT#1);
        END_METHOD

        {Test}
        METHOD PUBLIC Direction2ReleasedCallback
            Assert.Equal(_pushButtonListener.OnPushButtonPressedMock.GetCallCount(), UINT#0);
            Assert.Equal(_pushButtonListener.OnPushButtonMock.GetCallCount(), UINT#0);
            Assert.Equal(_pushButtonListener.OnPushButtonReleasedMock.GetCallCount(), UINT#0);

            _pushButton.Execute();

            _io.Direction2.Read(TRUE);

            _pushButton.Execute();

            Assert.Equal(_pushButtonListener.OnPushButtonPressedMock.Value, 3);
            Assert.Equal(_pushButtonListener.OnPushButtonPressedMock.GetCallCount(), UINT#1);
            Assert.Equal(_pushButtonListener.OnPushButtonMock.GetCallCount(), UINT#0);
            Assert.Equal(_pushButtonListener.OnPushButtonReleasedMock.GetCallCount(), UINT#0);

            _io.Direction2.Read(TRUE);

            _pushButton.Execute();
            _pushButton.Execute();

            Assert.Equal(_pushButtonListener.OnPushButtonMock.Value, 3);
            Assert.Equal(_pushButtonListener.OnPushButtonPressedMock.GetCallCount(), UINT#1);
            Assert.Equal(_pushButtonListener.OnPushButtonMock.GetCallCount(), UINT#2);
            Assert.Equal(_pushButtonListener.OnPushButtonReleasedMock.GetCallCount(), UINT#0);

            _io.Direction2.Read(FALSE);

            _pushButton.Execute();

            Assert.Equal(_pushButtonListener.OnPushButtonReleasedMock.Value, 3);
            Assert.Equal(_pushButtonListener.OnPushButtonPressedMock.GetCallCount(), UINT#1);
            Assert.Equal(_pushButtonListener.OnPushButtonMock.GetCallCount(), UINT#2);
            Assert.Equal(_pushButtonListener.OnPushButtonReleasedMock.GetCallCount(), UINT#1);
        END_METHOD
    END_CLASS

END_NAMESPACE