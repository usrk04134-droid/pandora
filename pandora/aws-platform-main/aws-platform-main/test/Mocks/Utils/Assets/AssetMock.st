USING Esab.Mock;
USING Esab.Utils.Collections;

NAMESPACE Esab.Utils.Assets.Mock

    CLASS AssetMock EXTENDS Asset
        VAR PUBLIC
            SetUserMock : AssetAssignmentListenerMethodMock;
            GetUserMock : AssetAssignmentListenerMethodMock;
            SetIdentifierMock : IntMethodMock;
            GetIdentifierMock : IntMethodMock;
            LockMock : MethodMock;
            UnlockMock : MethodMock;
            IsLockedMock : BoolMethodMock;
            ObserveMock : MethodMock;
            ExecuteMock : MethodMock;
        END_VAR

        METHOD PUBLIC MockReset
            SetUserMock.Reset();
            GetUserMock.Reset();
            SetIdentifierMock.Reset();
            GetIdentifierMock.Reset();
            LockMock.Reset();
            UnlockMock.Reset();
            IsLockedMock.Reset();
            ObserveMock.Reset();
        END_METHOD

        METHOD PUBLIC OVERRIDE SetUser
            VAR_INPUT
                user : IAssetRequester;
            END_VAR

            SetUserMock.IncrementCallCount();
            SetUserMock.Value := user;
        END_METHOD

        METHOD PUBLIC OVERRIDE GetUser : IAssetRequester
            GetUserMock.IncrementCallCount();
            GetUser := GetUserMock.Value;
        END_METHOD

        METHOD PUBLIC OVERRIDE SetIdentifier
            VAR_INPUT
                identifier : INT;
            END_VAR

            SetIdentifierMock.IncrementCallCount();
            SetIdentifierMock.Value := identifier;
        END_METHOD

        METHOD PUBLIC OVERRIDE GetIdentifier : INT
            GetIdentifierMock.IncrementCallCount();
            GetIdentifier := GetIdentifierMock.Value;
        END_METHOD

        METHOD PUBLIC OVERRIDE Lock
            LockMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC OVERRIDE Unlock
            UnlockMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC OVERRIDE IsLocked : BOOL
            IsLockedMock.IncrementCallCount();
            IsLocked := IsLockedMock.Value;
        END_METHOD

        METHOD PUBLIC OVERRIDE Observe : IAssetObservable
            ObserveMock.IncrementCallCount();
            Observe := NULL;
        END_METHOD

        METHOD PUBLIC OVERRIDE Execute
            ExecuteMock.IncrementCallCount();
        END_METHOD
    END_CLASS

    CLASS AssetAssignmentListenerMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value : IAssetRequester;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Value := NULL;
        END_METHOD
    END_CLASS

    CLASS StartupMethodMock EXTENDS BoolMethodMock
        VAR PUBLIC
            Status : AssetStatus;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Value := FALSE;
            Status := AssetStatus#Unknown;
        END_METHOD
    END_CLASS

END_NAMESPACE