USING Esab.Io;
USING Esab.Utils.Alarming;
USING Esab.Utils.Filters;

USING System.FastMath;

NAMESPACE Esab.Motion.MeasurementSystem

    /// Implements a speed wheel with reference sensor that uses a HSC Technology object to measure velocity and position.
    CLASS SpeedWheel EXTENDS Object IMPLEMENTS IMeasurementSystem1D, InputChangedListener
        VAR PRIVATE
            _io : REF_TO SpeedWheelIo;
            _hardwareConfiguration : REF_TO SpeedWheelHardwareConfiguration;
            _speedFilter : IFilter;
            _hsc : IHighSpeedCounter;
            _currentPositionValue : LREAL := 0.0;
            _lastCountValue : DINT := DINT#0;
            _measurementSystemListener : IMeasurementSystemListener;
        END_VAR

        METHOD PUBLIC Setup
            VAR_INPUT
                io : REF_TO SpeedWheelIo;
                hardwareConfiguration : REF_TO SpeedWheelHardwareConfiguration;
                hsc : IHighSpeedCounter;
                speedFilter : IFilter;
                setupAlarm : IAlarm;
            END_VAR

            _io := io;
            _hardwareConfiguration := hardwareConfiguration;
            _hsc := hsc;
            _speedFilter := speedFilter;
            _setupAlarm := setupAlarm;

            _isSetup := _io <> NULL AND _hardwareConfiguration <> NULL AND _hsc <> NULL AND _speedFilter <> NULL;

            IF _isSetup THEN
                _io^.ReferenceSensor.SetChangedHandler(THIS);
            END_IF;
        END_METHOD

        METHOD PUBLIC OVERRIDE Execute
            VAR_TEMP
                _currentCount : DINT;
            END_VAR

            SUPER.Execute();

            IF _setupAlarm.IsActive() THEN
                RETURN;
            END_IF;

            _hsc.Execute();

            _currentCount := _hsc.GetCountValue();
            _speedFilter.Measurement(_hsc.GetMeasuredValue() * (_hardwareConfiguration^.WheelDiameterInMm * Constants#PI / _hardwareConfiguration^.PointsPerRevolution));

            IF _lastCountValue < _currentCount AND _speedFilter.Filtered() > 0.0 THEN // Positive direction
                _currentPositionValue := _currentPositionValue + ABS(_currentCount - _lastCountValue) * (_hardwareConfiguration^.WheelDiameterInMm * Constants#PI / TO_DINT(_hardwareConfiguration^.PointsPerRevolution));
            ELSIF _lastCountValue > _currentCount AND _speedFilter.Filtered() < 0.0 THEN // Negative direction
                _currentPositionValue := _currentPositionValue - ABS(_currentCount - _lastCountValue) * (_hardwareConfiguration^.WheelDiameterInMm * Constants#PI / TO_DINT(_hardwareConfiguration^.PointsPerRevolution));
            ELSE // Possible overflow / stand-still
                IF _lastCountValue > _currentCount AND _speedFilter.Filtered() > 0.0 THEN // Positive overflow
                    _currentPositionValue := _currentPositionValue + ABS(_hsc.GetUpperCountingLimit() - _lastCountValue + _currentCount - _hsc.GetLowerCountingLimit()) * (_hardwareConfiguration^.WheelDiameterInMm * Constants#PI / TO_DINT(_hardwareConfiguration^.PointsPerRevolution));
                ELSIF _lastCountValue < _currentCount AND _speedFilter.Filtered() < 0.0 THEN // Negative overflow
                    _currentPositionValue := _currentPositionValue - ABS(_lastCountValue - _hsc.GetLowerCountingLimit() + _hsc.GetUpperCountingLimit() - _currentCount) * (_hardwareConfiguration^.WheelDiameterInMm * Constants#PI / TO_DINT(_hardwareConfiguration^.PointsPerRevolution));
                ELSE // Stand-still
                    ;
                END_IF;
            END_IF;

            _lastCountValue := _currentCount;
        END_METHOD

        METHOD PUBLIC OVERRIDE UpdateState
            IF _setupAlarm.IsActive() THEN
                _currentState := SpeedWheelState#Error;
                RETURN;
            ELSIF ABS(_speedFilter.Filtered()) > 10 THEN
                _currentState := SpeedWheelState#Monitoring;
            ELSE
                _currentState := SpeedWheelState#Idle;
            END_IF;
        END_METHOD

        METHOD PUBLIC SetListener
            VAR_INPUT
                listener : IMeasurementSystemListener;
            END_VAR

            _measurementSystemListener := listener;
        END_METHOD

        METHOD PUBLIC GetMeasuredPosition : LREAL
            GetMeasuredPosition := _currentPositionValue;
        END_METHOD

        METHOD PUBLIC GetMeasuredVelocity : LREAL
            GetMeasuredVelocity := _speedFilter.Filtered();
        END_METHOD

        METHOD PUBLIC ResetMeasuredPosition
            _currentPositionValue := 0.0;
            _lastCountValue := _hsc.GetCountValue();
        END_METHOD

        METHOD PUBLIC SetHardwareConfiguration
            VAR_INPUT
                hwConfiguration : REF_TO SpeedWheelHardwareConfiguration;
            END_VAR;

            THIS._hardwareConfiguration := hwConfiguration;
        END_METHOD

        METHOD PUBLIC SetWheelDiameterInMm
            VAR_INPUT
                diameter : LREAL;
            END_VAR;

            THIS._hardwareConfiguration^.WheelDiameterInMm := diameter;
        END_METHOD

        METHOD PUBLIC SetPointsPerRevolution
            VAR_INPUT
                ppr : UDINT;
            END_VAR;

            THIS._hardwareConfiguration^.PointsPerRevolution := ppr;
        END_METHOD

        METHOD PUBLIC InputChanged
            VAR_INPUT
                input : REF_TO Esab.Io.Input;
            END_VAR

            IF input = REF(_io^.ReferenceSensor) AND _io^.ReferenceSensor.RisingEdge() THEN
                IF _measurementSystemListener <> NULL THEN
                    _measurementSystemListener.ArrivedAtReferencePoint();
                END_IF;
            END_IF;
        END_METHOD
    END_CLASS

    TYPE
        SpeedWheelHardwareConfiguration : STRUCT
            /// The wheel diameter in millimeters.
            WheelDiameterInMm : LREAL := 150.0;
            /// Points per revolution of the encoder.
            PointsPerRevolution : UDINT := UDINT#4096;
        END_STRUCT;

        SpeedWheelIo : STRUCT
            ReferenceSensor : DigitalInput;
        END_STRUCT;

        SpeedWheelState : INT(
            Idle := 0,
            Error := 1,
            Monitoring := 2
        );
    END_TYPE

END_NAMESPACE