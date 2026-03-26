NAMESPACE Esab.Motion.MeasurementSystem

    INTERFACE IMeasurementSystem1D
        /// Cyclic execute.
        METHOD Execute
        END_METHOD

        /// Returns the measured position in mm.
        METHOD GetMeasuredPosition : LREAL
        END_METHOD

        /// Returns the measured velocity in mm/s.
        METHOD GetMeasuredVelocity : LREAL
        END_METHOD

        /// Resets the measured position to 0.0.
        METHOD ResetMeasuredPosition
        END_METHOD

        METHOD SetListener
            VAR_INPUT
                listener : IMeasurementSystemListener;
            END_VAR
        END_METHOD
    END_INTERFACE

    INTERFACE IMeasurementSystemListener
        METHOD ArrivedAtReferencePoint
        END_METHOD
    END_INTERFACE

END_NAMESPACE