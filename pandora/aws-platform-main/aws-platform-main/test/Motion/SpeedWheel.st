USING Esab.Utils.Filters;
USING Esab.Io;
USING Esab.Io.Mock;
USING Esab.Motion.Mock;

USING AxUnit;
USING System.FastMath;

NAMESPACE Esab.Motion.MeasurementSystem.Test

    {TestFixture}
    CLASS SpeedWheelTests
        VAR PRIVATE
            _speedWheel : SpeedWheel;
            _hsc : HighSpeedCounterMock;
            _referenceSensor : DigitalInput;
            _hardwareConfiguration : SpeedWheelHardwareConfiguration;
            _io : SpeedWheelIo;
            _circumference : LREAL;
            _speedFilter : NoFilter;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            _hardwareConfiguration.WheelDiameterInMm := LREAL#150.0;
            _hardwareConfiguration.PointsPerRevolution := UDINT#100;
            _io.ReferenceSensor := _referenceSensor;
            _speedWheel.Setup(REF(_io), REF(_hardwareConfiguration), _hsc, _speedFilter);
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            _io.ReferenceSensor.Read(FALSE);
            _io.ReferenceSensor.Read(FALSE);

            _hsc.MockReset();
            _speedWheel.ResetMeasuredPosition();
            _circumference := Constants#PI * _hardwareConfiguration.WheelDiameterInMm;
        END_METHOD

        {Test}
        METHOD PUBLIC PositionCalculationPositiveDirection
            // One rotation of the wheel should give a full circumference worth of length units (mm).
            _hsc.GetMeasuredValueMock.Value := DINT#10;
            _hsc.GetCountValueMock.Value := DINT#0;
            _speedWheel.Execute();
            _hsc.GetCountValueMock.Value := TO_DINT(_hardwareConfiguration.PointsPerRevolution);
            _speedWheel.Execute();

            Assert.InRange(_speedWheel.GetMeasuredPosition(), _circumference, LREAL#0.0001);
        END_METHOD

        {Test}
        METHOD PUBLIC PositionCalculationNegativeDirection
            // One rotation of the wheel should give a full circumference worth of length units (mm).
            _hsc.GetMeasuredValueMock.Value := DINT#-10;
            _hsc.GetCountValueMock.Value := DINT#0;
            _speedWheel.Execute();
            _hsc.GetCountValueMock.Value := -TO_DINT(_hardwareConfiguration.PointsPerRevolution);
            _speedWheel.Execute();

            Assert.InRange(_speedWheel.GetMeasuredPosition(), -_circumference, LREAL#0.0001);
        END_METHOD

        {Test}
        METHOD PUBLIC CounterRolloverPositive
            _hsc.GetUpperCountingLimitMock.Value := 200;
            _hsc.GetLowerCountingLimitMock.Value := -200;

            // Rolling over should still increase the measured position
            _hsc.GetCountValueMock.Value := DINT#150;
            _speedWheel.ResetMeasuredPosition();
            _hsc.GetMeasuredValueMock.Value := DINT#10;
            _speedWheel.Execute();
            _hsc.GetCountValueMock.Value := DINT#-150;
            _speedWheel.Execute();

            Assert.InRange(_speedWheel.GetMeasuredPosition(), _circumference, LREAL#0.0001);
        END_METHOD

        {Test}
        METHOD PUBLIC CounterRolloverNegative
            _hsc.GetUpperCountingLimitMock.Value := 200;
            _hsc.GetLowerCountingLimitMock.Value := -200;

            // Rolling over should still increase the measured position
            _hsc.GetCountValueMock.Value := DINT#-150;
            _speedWheel.ResetMeasuredPosition();
            _hsc.GetMeasuredValueMock.Value := DINT#-10;
            _speedWheel.Execute();
            _hsc.GetCountValueMock.Value := DINT#150;
            _speedWheel.Execute();

            Assert.InRange(_speedWheel.GetMeasuredPosition(), -_circumference, LREAL#0.0001);
        END_METHOD

        {Test}
        METHOD PUBLIC Speed
            _hsc.GetMeasuredValueMock.Value := DINT#100;

            _speedWheel.Execute();

            Assert.Equal(_speedWheel.GetMeasuredVelocity(), 100.0 * (150.0 * Constants#PI / 100));
        END_METHOD
    END_CLASS

END_NAMESPACE