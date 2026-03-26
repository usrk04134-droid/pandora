USING Esab.Motion.MeasurementSystem;
USING Esab.Mock;

NAMESPACE Esab.Motion.MeasurementSystems.Mock

    CLASS SpeedWheelMock IMPLEMENTS IMeasurementSystem1D
        VAR PUBLIC
            IsInitializedMock : BoolMethodMock;
            ExecuteMock : MethodMock;
            GetMeasuredPositionMock : LRealMethodMock;
            GetMeasuredVelocityMock : LRealMethodMock;
            ResetMeasuredPositionMock : MethodMock;
            SetListenerMock : MethodMock;
        END_VAR

        METHOD PUBLIC MockReset
            IsInitializedMock.Reset();
            ExecuteMock.Reset();
            GetMeasuredPositionMock.Reset();
            GetMeasuredVelocityMock.Reset();
            ResetMeasuredPositionMock.Reset();
            SetListenerMock.Reset();
        END_METHOD

        METHOD PUBLIC IsInitialized : BOOL
            IsInitializedMock.IncrementCallCount();
            IsInitialized := IsInitializedMock.Value;
        END_METHOD

        METHOD PUBLIC Execute
            ExecuteMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC GetMeasuredPosition : LREAL
            GetMeasuredPositionMock.IncrementCallCount();
            GetMeasuredPosition := GetMeasuredPositionMock.Value;
        END_METHOD

        METHOD PUBLIC GetMeasuredVelocity : LREAL
            GetMeasuredVelocityMock.IncrementCallCount();
            GetMeasuredVelocity := GetMeasuredVelocityMock.Value;
        END_METHOD

        METHOD PUBLIC ResetMeasuredPosition
            ResetMeasuredPositionMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC SetListener
            VAR_INPUT
                listener : IMeasurementSystemListener;
            END_VAR

            SetListenerMock.IncrementCallCount();
        END_METHOD
    END_CLASS

END_NAMESPACE