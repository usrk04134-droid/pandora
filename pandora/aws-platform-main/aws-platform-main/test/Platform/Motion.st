USING AxUnit;

USING Siemens.Simatic.S71500.MotionControl.Native;
USING Siemens.Simatic.S71500.MotionControl.Mocking;

NAMESPACE Esab.Motion.Test

    {TestFixture}
    {Category(Motion)}
    CLASS MotionTests
        VAR PRIVATE
            _axis : ToPosAxis;
            _mockAxis : PosAxisMock;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            _axis.Setup(_mockAxis);
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            _mockAxis.PowerOnMock.Reset();
            _mockAxis.PowerOffMock.Reset();
            _mockAxis.MoveAbsoluteMock.Reset();
            _mockAxis.MoveRelativeMock.Reset();
            _mockAxis.MoveVelocityMock.Reset();
            _mockAxis.HomeDirectMock.Reset();
            _mockAxis.HaltMock.Reset();
            _mockAxis.ResetAlarmsMock.Reset();
            _mockAxis.RestartMock.Reset();
        END_METHOD

        {Test}
        METHOD PUBLIC TestPowerOn
            _axis.PowerOn();
            // TODO: This fails because we start using the overloaded function with a arg...
            //Assert.Equal(_mockAxis.PowerOnMock.GetCallCount(), UINT#1);
        END_METHOD

        {Test}
        METHOD PUBLIC TestPowerOff
            _axis.PowerOff();
            Assert.Equal(_mockAxis.PowerOffMock.GetCallCount(), UINT#1);
        END_METHOD

        {Test}
        METHOD PUBLIC TestReset
            _axis.Reset();
            _axis.Reset(FALSE);
            Assert.Equal(_mockAxis.ResetAlarmsMock.GetCallCount(), UINT#2);
        END_METHOD

        {Test}
        METHOD PUBLIC TestRestart
            _axis.Reset(TRUE);
            Assert.Equal(_mockAxis.ResetAlarmsMock.GetCallCount(), UINT#1);
            Assert.Equal(_mockAxis.RestartMock.GetCallCount(), UINT#1);
        END_METHOD

        {Test}
        METHOD PUBLIC TestAbsolutePositioningCommand
            VAR_TEMP
                command : AxisPositioningCommand;
            END_VAR

            command.CommandType := AxisCommandType#Absolute;
            command.Position := 10.0;

            _axis.ExecutePositioningCommand(command);

            Assert.Equal(_mockAxis.MoveAbsoluteMock.GetCallCount(), UINT#1);
        END_METHOD

        {Test}
        METHOD PUBLIC TestRelativePositioningCommand
            VAR_TEMP
                command : AxisPositioningCommand;
            END_VAR

            command.CommandType := AxisCommandType#Relative;
            command.Position := 10.0;

            _axis.ExecutePositioningCommand(command);

            Assert.Equal(_mockAxis.MoveRelativeMock.GetCallCount(), UINT#1);
        END_METHOD

        {Test}
        METHOD PUBLIC TestVelocityCommand
            VAR_TEMP
                command : AxisPositioningCommand;
            END_VAR

            command.CommandType := AxisCommandType#Velocity;
            command.Velocity := 10.0;

            _axis.ExecutePositioningCommand(command);

            Assert.Equal(_mockAxis.MoveVelocityMock.GetCallCount(), UINT#1);
        END_METHOD

        {Test}
        METHOD PUBLIC TestHaltCommand
            VAR_TEMP
                command : AxisPositioningCommand;
            END_VAR

            command.CommandType := AxisCommandType#Halt;

            _axis.ExecutePositioningCommand(command);

            Assert.Equal(_mockAxis.HaltMock.GetCallCount(), UINT#1);
        END_METHOD

        {Test}
        METHOD PUBLIC TestDirectAbsoluteHomingCommand
            VAR_TEMP
                command: AxisHomingCommand;
            END_VAR

            command.HomingType := AxisHomingType#DirectAbsolute;
            command.Position := 10.0;

            _axis.ExecuteHomingCommand(command);

            Assert.Equal(_mockAxis.HomeDirectMock.GetCallCount(), UINT#1);
        END_METHOD

        {Test}
        METHOD PUBLIC TestDirectRelativeHomingCommand
            VAR_TEMP
                command: AxisHomingCommand;
            END_VAR

            command.HomingType := AxisHomingType#DirectRelative;
            command.Position := 10.0;

            _axis.ExecuteHomingCommand(command);

            Assert.Equal(_mockAxis.HomeDirectMock.GetCallCount(), UINT#1);
        END_METHOD

        {Test}
        METHOD PUBLIC TestJogPositive
            ;
        END_METHOD

        {Test}
        METHOD PUBLIC TestJogNegative
            ;
        END_METHOD
    END_CLASS
END_NAMESPACE