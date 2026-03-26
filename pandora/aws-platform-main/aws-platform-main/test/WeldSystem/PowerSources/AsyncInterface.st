USING Esab.Utils.Alarming.Mock;
USING Esab.Mock;
USING Esab.WeldSystem.PowerSources;
USING Esab.WeldSystem.PowerSources.Mock;

USING AxUnit;

NAMESPACE Esab.Platform.WeldSystem.Test

    {TestFixture}
    {Category(WeldSystem)}
    CLASS AsyncInterfaceTests
        VAR PRIVATE
            __asyncInterface : AsyncInterface;
            _defaultAsync : AsyncInterface;
            _reader : AsyncReaderMock;
            _writer : AsyncWriterMock;
            _listener : ListenerMock;

            _invalidCommandTypeAlarm : AlarmMock;
            _poppedNullCommandAlarm: AlarmMock;
            _invalidCommandAlarm: AlarmMock;

            _defaultInvalidCommandTypeAlarm : AlarmMock;
            _defaultPoppedNullCommandAlarm: AlarmMock;
            _defaultInvalidCommandAlarm: AlarmMock;

            _command1 : CommandMock;
            _command2 : CommandMock;
            _command3 : CommandMock;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            __asyncInterface.Setup(_reader, _writer, _invalidCommandTypeAlarm, _poppedNullCommandAlarm, _invalidCommandAlarm);
            __asyncInterface.SetListener(_listener);
            _defaultAsync.Setup(_reader, _writer, _defaultInvalidCommandTypeAlarm, _defaultPoppedNullCommandAlarm, _defaultInvalidCommandAlarm);
            _defaultAsync.SetListener(_listener);
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            __asyncInterface := _defaultAsync;

            _reader.MockReset();
            _writer.MockReset();
            _command1.MockReset();
            _command2.MockReset();
            _command3.MockReset();

            _listener.MockReset();

            _command1.GetIndexMock.Value := DataRecord#BurnBackTime;
            _command1.GetLengthMock.Value := UINT#2;
            _command1.GetTypeMock.Value := CommandType#Read;

            _command2.GetIndexMock.Value := DataRecord#AcBalance;
            _command2.GetLengthMock.Value := UINT#2;
            _command2.GetTypeMock.Value := CommandType#Read;

            _command3.GetIndexMock.Value := DataRecord#CoupleId;
            _command3.GetLengthMock.Value := UINT#2;
            _command3.GetTypeMock.Value := CommandType#Read;
        END_METHOD

        {Test}
        METHOD PUBLIC ExecuteNoCommands
            __asyncInterface.Execute();

            Assert.Equal(_reader.ExecuteMock.GetCallCount(), UINT#1);
            Assert.Equal(_writer.ExecuteMock.GetCallCount(), UINT#1);
        END_METHOD

        {Test}
        METHOD PUBLIC ExecuteCommandSucceed
            VAR_TEMP
                command : REF_TO AsyncCommand;
            END_VAR

            __asyncInterface.Execute();

            Assert.Equal(_reader.SetCommandMock.GetCallCount(), UINT#1);
            Assert.Equal(_reader.SetCommandMock.Value = NULL, TRUE);

            __asyncInterface.ReadCommand(REF(_command1));

            __asyncInterface.Execute();

            Assert.Equal(__asyncInterface.CurrentCommand() = REF(_command1), TRUE);

            __asyncInterface.Execute();
            __asyncInterface.Execute();

            Assert.Equal(_reader.SetCommandMock.GetCallCount(), UINT#2);
            Assert.Equal(_reader.SetCommandMock.Value = REF(_command1), TRUE);
            Assert.Greater(_reader.ExecuteMock.GetCallCount(), UINT#1);

            Assert.Equal(_reader.IsDone(), FALSE);
            Assert.Equal(_reader.HasError(), FALSE);

            _reader.IsDoneMock.Value := TRUE;

            __asyncInterface.Execute();

            _reader.IsDoneMock.Value := FALSE;

            __asyncInterface.Execute();
            __asyncInterface.Execute();
            __asyncInterface.Execute();
            __asyncInterface.Execute();

            Assert.Equal(_listener.CallbackMock.GetCallCount(), UINT#1);

            command ?= _listener.CallbackMock.Command;

            Assert.Equal(command <> NULL, TRUE);

            Assert.Equal(command = REF(_command1), TRUE);
            Assert.Equal(_listener.CallbackMock.Status, CommandStatus#Success);
        END_METHOD

        {Test}
        METHOD PUBLIC ExecuteCommandFail
            VAR_TEMP
                command : REF_TO AsyncCommand;
            END_VAR

            __asyncInterface.Execute();

            Assert.Equal(_reader.SetCommandMock.GetCallCount(), UINT#1);
            Assert.Equal(_reader.SetCommandMock.Value = NULL, TRUE);

            __asyncInterface.ReadCommand(REF(_command1));

            __asyncInterface.Execute();

            Assert.Equal(__asyncInterface.CurrentCommand() = REF(_command1), TRUE);

            __asyncInterface.Execute();
            __asyncInterface.Execute();

            Assert.Equal(_reader.SetCommandMock.GetCallCount(), UINT#2);
            Assert.Equal(_reader.SetCommandMock.Value = REF(_command1), TRUE);
            Assert.Greater(_reader.ExecuteMock.GetCallCount(), UINT#1);

            Assert.Equal(_reader.IsDone(), FALSE);
            Assert.Equal(_reader.HasError(), FALSE);

            _reader.HasErrorMock.Value := TRUE;

            __asyncInterface.Execute();

            _reader.HasErrorMock.Value := FALSE;

            __asyncInterface.Execute();
            __asyncInterface.Execute();
            __asyncInterface.Execute();
            __asyncInterface.Execute();

            Assert.Equal(_listener.CallbackMock.GetCallCount(), UINT#1);

            command ?= _listener.CallbackMock.Command;

            Assert.Equal(command <> NULL, TRUE);

            Assert.Equal(command = REF(_command1), TRUE);
            Assert.Equal(_listener.CallbackMock.Status, CommandStatus#Error);
        END_METHOD

        {Test}
        METHOD PUBLIC SuccessiveCommands
            __asyncInterface.Execute();

            __asyncInterface.ReadCommand(REF(_command1));

            __asyncInterface.Execute();
            Assert.Equal(__asyncInterface.CurrentCommand() = REF(_command1), TRUE);


            __asyncInterface.Execute();
            __asyncInterface.Execute();

            _reader.IsDoneMock.Value := TRUE;
            Assert.Equal(_reader.IsBusy(), TRUE);
            Assert.Equal(__asyncInterface.CurrentCommand() = NULL, FALSE);
            __asyncInterface.Execute();
            _reader.IsDoneMock.Value := FALSE;
            Assert.Equal(_reader.IsBusy(), FALSE);
            Assert.Equal(__asyncInterface.CurrentCommand() = NULL, TRUE);
            __asyncInterface.Execute();
            __asyncInterface.Execute();

            Assert.Equal(_listener.CallbackMock.GetCallCount(), UINT#1);
            Assert.Equal(_listener.CallbackMock.Status, CommandStatus#Success);
            Assert.Equal(_listener.CallbackMock.Command = NULL, FALSE);
            Assert.Equal(_listener.CallbackMock.Command = REF(_command1), TRUE);


            __asyncInterface.Execute();

            __asyncInterface.ReadCommand(REF(_command2));

            __asyncInterface.Execute();
            Assert.Equal(__asyncInterface.CurrentCommand() = REF(_command2), TRUE);
            Assert.Equal(_reader.IsBusy(), TRUE);
            __asyncInterface.Execute();
            __asyncInterface.Execute();

            _reader.IsDoneMock.Value := TRUE;
            Assert.Equal(_reader.IsBusy(), TRUE);
            Assert.Equal(__asyncInterface.CurrentCommand() = NULL, FALSE);
            __asyncInterface.Execute();
            _reader.IsDoneMock.Value := FALSE;
            Assert.Equal(_reader.IsBusy(), FALSE);
            Assert.Equal(__asyncInterface.CurrentCommand() = NULL, TRUE);
            __asyncInterface.Execute();
            __asyncInterface.Execute();

            Assert.Equal(_listener.CallbackMock.GetCallCount(), UINT#2);
            Assert.Equal(_listener.CallbackMock.Status, CommandStatus#Success);
            Assert.Equal(_listener.CallbackMock.Command = NULL, FALSE);
            Assert.Equal(_listener.CallbackMock.Command = REF(_command2), TRUE);

        END_METHOD
    END_CLASS

    CLASS ListenerMock IMPLEMENTS IAsyncCommandListener
        VAR PUBLIC
            CallbackMock : AsyncCommandCallbackMock;
        END_VAR

        METHOD PUBLIC MockReset
            CallbackMock.Reset();
        END_METHOD

        METHOD PUBLIC AsyncCommandCallback
            VAR_INPUT
                command : REF_TO AsyncCommand;
                status : CommandStatus;
            END_VAR

            CallbackMock.IncrementCallCount();
            CallbackMock.Command := command;
            CallbackMock.Status := status;
        END_METHOD
    END_CLASS

    CLASS AsyncCommandCallbackMock EXTENDS MethodMock
        VAR PUBLIC
            Command : REF_TO AsyncCommand;
            Status : CommandStatus;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Command := NULL;
            Status := CommandStatus#Invalid;
        END_METHOD
    END_CLASS

END_NAMESPACE