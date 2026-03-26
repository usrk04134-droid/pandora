USING Esab.Utils.Timer;
USING Esab.Mock;

NAMESPACE Esab.Utils.Timer.Mock

    CLASS OnDelayMock IMPLEMENTS ITimer
        VAR PUBLIC
            ResetMock : MethodMock;
            ExecuteMock : TimerExecuteMethodMock;
            ExpiredMock : BoolMethodMock;
            ElapsedTimeMock : ElapsedTimeMock;
        END_VAR

        VAR PRIVATE
            _onDelayMock : System.Timer.OnDelay;
            _currentTimeMock : LTIME;
            _qMock : BOOL;
        END_VAR

        METHOD PUBLIC MockReset
            ResetMock.Reset();
            ExecuteMock.Reset();
            ExpiredMock.Reset();
            ElapsedTimeMock.Reset();
        END_METHOD

        METHOD PUBLIC Execute
            VAR_INPUT
                signal : BOOL;
                duration : LTIME;
            END_VAR

            ExecuteMock.IncrementCallCount();
            ExecuteMock.Value := signal;
            ExecuteMOck.Duration := duration;
        END_METHOD

        METHOD PUBLIC Expired : BOOL
            ExpiredMock.IncrementCallCount();
            Expired := ExpiredMock.Value;
        END_METHOD

        METHOD PUBLIC ElapsedTime : LTIME
            ElapsedTimeMock.IncrementCallCount();
            ElapsedTime := ElapsedTimeMock.Value;
        END_METHOD
    END_CLASS

    CLASS ElapsedTimeMock EXTENDS MethodMock
        VAR PUBLIC
            Value : LTIME;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            Value := LT#0s;
            SUPER.Reset();
        END_METHOD
    END_CLASS

    CLASS TimerExecuteMethodMock EXTENDS BoolMethodMock
        VAR PUBLIC
            Duration : LTIME;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Duration := LTIME#0s;
        END_METHOD
    END_CLASS

END_NAMESPACE
