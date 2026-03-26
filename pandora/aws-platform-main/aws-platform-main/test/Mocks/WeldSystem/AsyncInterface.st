USING Esab.Mock;

NAMESPACE Esab.WeldSystem.PowerSources.Mock

    /// This mock-up contains some logic/state so that it behaves as the actual implementation
    CLASS AsyncWriterMock IMPLEMENTS IAsyncWriter
        VAR PUBLIC
            ExecuteMock : MethodMock;
            SetCommandMock : RefCommandMethodMock;
            IsDoneMock : BoolMethodMock;
            IsBusyMock : MethodMock;
            HasErrorMock : BoolMethodMock;
        END_VAR

        VAR PRIVATE
            _currentCommand : REF_TO AsyncCommand;
            _busy : BOOL;
        END_VAR

        METHOD PUBLIC MockReset
            ExecuteMock.Reset();
            SetCommandMock.Reset();
            IsDoneMock.Reset();
            IsBusyMock.Reset();
            HasErrorMock.Reset();
        END_METHOD

        METHOD PUBLIC Execute
            ExecuteMock.IncrementCallCount();
            _busy := _currentCommand <> NULL;
        END_METHOD

        METHOD PUBLIC SetCommand
            VAR_INPUT
                command : REF_TO AsyncCommand;
            END_VAR

            SetCommandMock.IncrementCallCount();
            SetCommandMock.Value := command;
            _currentCommand := command;
        END_METHOD

        METHOD PUBLIC IsDone : BOOL
            IsDoneMock.IncrementCallCount();
            IsDone := IsDoneMock.Value;
        END_METHOD

        METHOD PUBLIC IsBusy : BOOL
            IsBusyMock.IncrementCallCount();
            IsBusy := _busy;
        END_METHOD

        METHOD PUBLIC HasError : BOOL
            HasErrorMock.IncrementCallCount();
            HasError := HasErrorMock.Value;
        END_METHOD
    END_CLASS

    /// This mock-up contains some logic/state so that it behaves as the actual implementation
    CLASS AsyncReaderMock IMPLEMENTS IAsyncReader
        VAR PUBLIC
            ExecuteMock : MethodMock;
            SetCommandMock : RefCommandMethodMock;
            IsDoneMock : BoolMethodMock;
            IsBusyMock : MethodMock;
            HasErrorMock : BoolMethodMock;
        END_VAR

        VAR PRIVATE
            _currentCommand : REF_TO AsyncCommand;
            _busy : BOOL;
        END_VAR

        METHOD PUBLIC MockReset
            ExecuteMock.Reset();
            SetCommandMock.Reset();
            IsDoneMock.Reset();
            IsBusyMock.Reset();
            HasErrorMock.Reset();
        END_METHOD

        METHOD PUBLIC Execute
            ExecuteMock.IncrementCallCount();
            _busy := _currentCommand <> NULL;
        END_METHOD

        METHOD PUBLIC SetCommand
            VAR_INPUT
                command : REF_TO AsyncCommand;
            END_VAR

            SetCommandMock.IncrementCallCount();
            SetCommandMock.Value := command;
            _currentCommand := command;
        END_METHOD

        METHOD PUBLIC IsDone : BOOL
            IsDoneMock.IncrementCallCount();
            IsDone := IsDoneMock.Value;
        END_METHOD

        METHOD PUBLIC IsBusy : BOOL
            IsBusyMock.IncrementCallCount();
            IsBusy := _busy;
        END_METHOD

        METHOD PUBLIC HasError : BOOL
            HasErrorMock.IncrementCallCount();
            HasError := HasErrorMock.Value;
        END_METHOD
    END_CLASS

    CLASS CommandMock EXTENDS AsyncCommand
        VAR PUBLIC
            GetIndexMock : DataRecordMethodMock;
            ValueAsBytesMock : RefByteArrayMethodMock;
            ValueFromBytesMock : RefByteArrayMethodMock;
            GetLengthMock : UIntMethodMock;
            SetWriteMock : MethodMock;
            SetReadMock : MethodMock;
            GetTypeMock : CommandTypeMethodMock;
        END_VAR

        METHOD PUBLIC MockReset
            GetIndexMock.Reset();
            ValueAsBytesMock.Reset();
            ValueFromBytesMock.Reset();
            GetLengthMock.Reset();
            SetWriteMock.Reset();
            SetReadMock.Reset();
            GetTypeMock.Reset();
        END_METHOD

        METHOD PUBLIC OVERRIDE GetIndex : DataRecord
            GetIndexMock.IncrementCallCount();
            GetIndex := GetIndexMock.Value;
        END_METHOD

        METHOD PUBLIC OVERRIDE ValueAsBytes
            VAR_INPUT
                buffer : REF_TO ARRAY[*] OF BYTE;
            END_VAR

            ValueAsBytesMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC OVERRIDE ValueFromBytes
            VAR_INPUT
                buffer : REF_TO ARRAY[*] OF BYTE;
            END_VAR

            ValueFromBytesMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC OVERRIDE GetSize : UINT
            GetLengthMock.IncrementCallCount();
            GetSize := GetLengthMock.Value;
        END_METHOD

        METHOD PUBLIC OVERRIDE SetWrite
            SetWriteMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC OVERRIDE SetRead
            SetReadMock.IncrementCallCount();
        END_METHOD

        METHOD PUBLIC OVERRIDE GetType : CommandType
            GetTypeMock.IncrementCallCount();
            GetType := GetTypeMock.Value;
        END_METHOD
    END_CLASS

    CLASS CommandMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value : IAsyncCommand;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            Value := NULL;
            SUPER.Reset();
        END_METHOD
    END_CLASS

    CLASS RefCommandMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value : REF_TO AsyncCommand;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            Value := NULL;
            SUPER.Reset();
        END_METHOD
    END_CLASS

    CLASS CommandTypeMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value : CommandType;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            Value := CommandType#Invalid;
            SUPER.Reset();
        END_METHOD
    END_CLASS

    CLASS DataRecordMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value : DataRecord;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            Value := DataRecord#Invalid;
            SUPER.Reset();
        END_METHOD
    END_CLASS

    CLASS RefByteArrayMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value : ARRAY[0..10] OF BYTE;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            VAR_TEMP
                i : INT := 0;
            END_VAR

            FOR i := 0 TO 10 DO
                Value[i] := BYTE#0;
            END_FOR;

            SUPER.Reset();
        END_METHOD
    END_CLASS

END_NAMESPACE