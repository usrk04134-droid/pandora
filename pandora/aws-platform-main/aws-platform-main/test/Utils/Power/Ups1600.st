USING Esab.Utils.Alarming.Mock;

USING AxUnit;

NAMESPACE Esab.Utils.Power.Test

    {TestFixture}
    CLASS Ups1600Tests
        VAR PRIVATE
            _ups : Ups1600;
            _io : Ups1600Io;

            _inputVoltageOkAlarm        : AlarmMock;
            _chargeInsufficientAlarm    : AlarmMock;
            _batteryChangeAlarm         : AlarmMock;
            _batteryMaintenanceAlarm    : AlarmMock;
            _unknownBatteryAlarm        : AlarmMock;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            _ups.Setup(REF(_io),
                      _inputVoltageOkAlarm,
                      _chargeInsufficientAlarm,
                      _batteryChangeAlarm,
                      _batteryMaintenanceAlarm,
                      _unknownBatteryAlarm);
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            // Read all inputs twice to untrigger HasChanged
            _io.Inputs.InputVoltageOk.Read(TRUE);
            _io.Inputs.InputVoltageOk.Read(TRUE);
            _io.Inputs.BufferModeActive.Read(FALSE);
            _io.Inputs.BufferModeActive.Read(FALSE);
            _io.Inputs.ReadyForBuffering.Read(TRUE);
            _io.Inputs.ReadyForBuffering.Read(TRUE);
            _io.Inputs.ChargeSufficient.Read(TRUE);
            _io.Inputs.ChargeSufficient.Read(TRUE);
            _io.Inputs.BatteryChangeRecommended.Read(FALSE);
            _io.Inputs.BatteryChangeRecommended.Read(FALSE);
            _io.Inputs.NewAlarmsPending.Read(FALSE);
            _io.Inputs.NewAlarmsPending.Read(FALSE);
            _io.Inputs.BatteryChargeLevel.Read(BYTE#100);
            _io.Inputs.BatteryChargeLevel.Read(BYTE#100);
            _io.Inputs.UnknownBattery.Read(FALSE);
            _io.Inputs.UnknownBattery.Read(FALSE);
            _io.Inputs.BatteryMaintenanceRequired.Read(FALSE);
            _io.Inputs.BatteryMaintenanceRequired.Read(FALSE);

            _inputVoltageOkAlarm.MockReset();
            _chargeInsufficientAlarm.MockReset();
            _batteryChangeAlarm.MockReset();
            _batteryMaintenanceAlarm.MockReset();
            _unknownBatteryAlarm.MockReset();

            THIS.Execute();
            THIS.Execute();
        END_METHOD

        METHOD PRIVATE Execute
            _ups.Execute();
        END_METHOD

        {Test}
        METHOD PUBLIC InputVoltageOkAlarm
            _io.Inputs.InputVoltageOk.Read(FALSE);

            THIS.Execute();

            Assert.Greater(_inputVoltageOkAlarm.ExecuteMock.GetCallCount(), UINT#0);
            Assert.Equal(_inputVoltageOkAlarm.ExecuteMock.SIG, TRUE);
        END_METHOD

        {Test}
        METHOD PUBLIC ChargeInsufficientAlarm
            _io.Inputs.ChargeSufficient.Read(FALSE);

            THIS.Execute();

            Assert.Greater(_chargeInsufficientAlarm.ExecuteMock.GetCallCount(), UINT#0);
            Assert.Equal(_chargeInsufficientAlarm.ExecuteMock.SIG, TRUE);
        END_METHOD

        {Test}
        METHOD PUBLIC BatteryChangeAlarm
            _io.Inputs.BatteryChangeRecommended.Read(TRUE);

            THIS.Execute();

            Assert.Greater(_batteryChangeAlarm.ExecuteMock.GetCallCount(), UINT#0);
            Assert.Equal(_batteryChangeAlarm.ExecuteMock.SIG, TRUE);
        END_METHOD

        {Test}
        METHOD PUBLIC BatteryMaintenanceAlarm
            _io.Inputs.BatteryChangeRecommended.Read(TRUE);

            THIS.Execute();

            Assert.Greater(_batteryChangeAlarm.ExecuteMock.GetCallCount(), UINT#0);
            Assert.Equal(_batteryChangeAlarm.ExecuteMock.SIG, TRUE);
        END_METHOD

        {Test}
        METHOD PUBLIC UnknownBatteryAlarm
            _io.Inputs.UnknownBattery.Read(TRUE);

            THIS.Execute();

            Assert.Greater(_unknownBatteryAlarm.ExecuteMock.GetCallCount(), UINT#0);
            Assert.Equal(_unknownBatteryAlarm.ExecuteMock.SIG, TRUE);
        END_METHOD

        {Test}
        METHOD PUBLIC Observable
            VAR_TEMP
                obs : REF_TO Ups1600Observable;
            END_VAR

            obs ?= _ups.Observe();

            _io.Inputs.InputVoltageOk.Read(FALSE);
            _io.Inputs.BufferModeActive.Read(TRUE);
            _io.Inputs.ReadyForBuffering.Read(FALSE);
            _io.Inputs.ChargeSufficient.Read(FALSE);
            _io.Inputs.BatteryChangeRecommended.Read(TRUE);
            _io.Inputs.NewAlarmsPending.Read(TRUE);
            _io.Inputs.BatteryChargeLevel.Read(BYTE#50);
            _io.Inputs.UnknownBattery.Read(TRUE);
            _io.Inputs.BatteryMaintenanceRequired.Read(TRUE);

            THIS.Execute();

            Assert.Equal(obs^.InputVoltageOk, FALSE);
            Assert.Equal(obs^.BufferModeActive, TRUE);
            Assert.Equal(obs^.ReadyForBuffering, FALSE);
            Assert.Equal(obs^.ChargeSufficient, FALSE);
            Assert.Equal(obs^.BatteryChangeRecommended, TRUE);
            Assert.Equal(obs^.NewAlarmsPending, TRUE);
            Assert.Equal(obs^.BatteryChargeLevel, UINT#50);
            Assert.Equal(obs^.UnknownBattery, TRUE);
            Assert.Equal(obs^.BatteryMaintenanceRequired, TRUE);
        END_METHOD
    END_CLASS

END_NAMESPACE