USING Esab.Utils.Alarming;
USING Esab.Utils.Collections;

USING Siemens.Simatic.S71500.DistributedIO;
USING Siemens.Simatic.S71500.Alarming;

NAMESPACE Esab.WeldSystem.PowerSources

    CLASS PUBLIC AsyncInterface IMPLEMENTS IAsyncInterface
        VAR PRIVATE
            _reader : IAsyncReader;
            _writer : IAsyncWriter;
            _invalidCommandTypeAlarm : IAlarm;
            _poppedNullCommandAlarm : IAlarm;
            _invalidCommandAlarm : IAlarm;

            _commandQueue : LinkedList;
            _currentCommand : REF_TO AsyncCommand := NULL;
            _listener : IAsyncCommandListener := NULL;
            _successfullyExecutedCommandsCounter : UINT;
            _executedCommandsCounter : UINT;
            _executingCommandCounter : UINT;
            _nextCommandCounter : UINT;
            _busy : BOOL;
        END_VAR

        VAR PRIVATE
            {S7.Alarm = NoAck, "Async command interface not initialized."}
            _initializationAlarm : ProgramAlarm;
        END_VAR

        METHOD PUBLIC Setup
            VAR_INPUT
                reader : IAsyncReader;
                writer : IAsyncWriter;
                invalidCommandTypeAlarm : IAlarm;
                poppedNullCommandAlarm : IAlarm;
                invalidCommandAlarm : IAlarm;
            END_VAR

            _reader := reader;
            _writer := writer;
            _invalidCommandTypeAlarm := invalidCommandTypeAlarm;
            _poppedNullCommandAlarm := poppedNullCommandAlarm;
            _invalidCommandAlarm := invalidCommandAlarm;
        END_METHOD

        METHOD PUBLIC IsInitialized : BOOL
            VAR_TEMP
                initialized : BOOL := FALSE;
            END_VAR

            initialized :=
                _reader <> NULL AND
                _writer <> NULL AND
                _invalidCommandTypeAlarm <> NULL AND
                _poppedNullCommandAlarm <> NULL AND
                _invalidCommandAlarm <> Null;

            _initializationAlarm(SIG := NOT initialized);

            IsInitialized := initialized;
        END_METHOD

        METHOD PUBLIC Execute
            VAR_TEMP
                _linkedListItem : REF_TO LinkedListItem;
            END_VAR

            IF NOT THIS.IsInitialized() THEN
                RETURN;
            END_IF;

            IF _commandQueue.Size() > 0 AND _currentCommand = NULL THEN
                    _linkedListItem := _commandQueue.PopHead();
                    _currentCommand ?= _linkedListItem;

                    _nextCommandCounter := _nextCommandCounter + UINT#1;

                    _poppedNullCommandAlarm.Execute(SIG := _linkedListItem = NULL);
                    _invalidCommandAlarm.Execute(SIG := _linkedListItem <> NULL AND _currentCommand = NULL);
                    IF _currentCommand <> NULL THEN
                        _invalidCommandTypeAlarm.Execute(SIG := NOT (_currentCommand^.GetType() = CommandType#Read OR _currentCommand^.GetType() = CommandType#Write));
                        CASE _currentCommand^.GetType() OF
                            CommandType#Read:
                                _reader.SetCommand(_currentCommand);
                            CommandType#Write:
                                _writer.SetCommand(_currentCommand);
                        ELSE
                            _currentCommand := NULL;
                        END_CASE;
                    END_IF;
            ELSIF _currentCommand = NULL AND NOT (_reader.IsBusy() OR _writer.IsBusy()) THEN
                _reader.SetCommand(NULL);
                _writer.SetCommand(NULL);
            END_IF;

            _busy := _currentCommand <> NULL;

            _reader.Execute();
            _writer.Execute();

            IF _reader.IsBusy() OR _writer.IsBusy() THEN
                _executingCommandCounter := _executingCommandCounter + UINT#1;
            END_IF;

            IF _reader.IsDone() OR _writer.IsDone() THEN
                IF _listener <> NULL THEN
                    _listener.AsyncCommandCallback(_currentCommand, CommandStatus#Success);
                END_IF;
                _currentCommand^.Callback(CommandStatus#Success);

                _executedCommandsCounter := _executedCommandsCounter + UINT#1;
                _successfullyExecutedCommandsCounter := _successfullyExecutedCommandsCounter + UINT#1;

                THIS.Reset();
            END_IF;

            IF _reader.HasError() OR _writer.HasError() THEN
                IF _listener <> NULL THEN
                    _listener.AsyncCommandCallback(_currentCommand, CommandStatus#Error);
                END_IF;
                _currentCommand^.Callback(CommandStatus#Error);
                _executedCommandsCounter := _executedCommandsCounter + UINT#1;

                THIS.Reset();
            END_IF;
        END_METHOD

        METHOD PUBLIC Reset
            _currentCommand := NULL;

            _reader.SetCommand(NULL);
            _writer.SetCommand(NULL);

            _reader.Execute();
            _writer.Execute();
        END_METHOD

        METHOD PUBLIC WriteCommand
            VAR_INPUT
                command : REF_TO AsyncCommand;
            END_VAR

            IF _commandQueue.Append(command) THEN
                command^.SetWrite();
            END_IF;
        END_METHOD

        METHOD PUBLIC ReadCommand
            VAR_INPUT
                command : REF_TO AsyncCommand;
            END_VAR

            IF _commandQueue.Append(command) THEN
                command^.SetRead();
            END_IF;
        END_METHOD

        METHOD PUBLIC FlushCommandQueue
            _commandQueue.Clear();
        END_METHOD

        METHOD PUBLIC CurrentCommand : REF_TO AsyncCommand
            CurrentCommand := _currentCommand;
        END_METHOD

        METHOD PUBLIC IsIdle : BOOL
            IsIdle := _commandQueue.Empty() AND _currentCommand = NULL AND NOT _reader.IsBusy() AND NOT _writer.IsBusy();
        END_METHOD

        METHOD PUBLIC SetListener
            VAR_INPUT
                handler : IAsyncCommandListener;
            END_VAR

            _listener := handler;
        END_METHOD
    END_CLASS

    CLASS AsyncReader IMPLEMENTS IAsyncReader
        VAR PUBLIC
            HwId : WORD;
            ErrorAlarm: IAlarm;
        END_VAR

        VAR PRIVATE
            _reader : ReadRecord;
            _command : REF_TO AsyncCommand;

            _valid : BOOL;
            _error : BOOL;
            _busy : BOOL;

            _record : ARRAY[0..10] OF BYTE;
        END_VAR

        METHOD PUBLIC Execute
            VAR_TEMP
                status : DWORD := DWORD#0;
                request : BOOL := FALSE;
                length : UINT := UINT#0;
                index : DINT := DINT#0;
                maxLength : UINT := UINT#0;
            END_VAR

            IF _command <> NULL THEN
                request := TRUE;
                index := _command^.GetIndex();
                maxLength := _command^.GetSize();
            ELSE
                request := FALSE;
            END_IF;

            _reader(
                request := request,
                id := HwId,
                index := index,
                maxLength := length,
                record := _record,
                valid => _valid,
                busy => _busy,
                error => _error,
                status => status,
                length => length
            );

            IF _command <> NULL AND _valid THEN
                _command^.ValueFromBytes(REF(_record));
            END_IF;

            ErrorAlarm.Execute(SIG := _error, SD_1 := pass(status));
        END_METHOD

        METHOD PUBLIC SetCommand
            VAR_INPUT
                command : REF_TO AsyncCommand;
            END_VAR

            _command := command;
        END_METHOD

        METHOD PUBLIC IsDone : BOOL
            IsDone := _valid;
        END_METHOD

        METHOD PUBLIC IsBusy : BOOL
            IsBusy := _busy;
        END_METHOD

        METHOD PUBLIC HasError : BOOL
            HasError := _error;
        END_METHOD
    END_CLASS

    CLASS AsyncWriter IMPLEMENTS IAsyncWriter
        VAR PUBLIC
            HwId : WORD;
            ErrorAlarm : IAlarm;
        END_VAR

        VAR PRIVATE
            _writer : WriteRecord;
            _command : REF_TO AsyncCommand;

            _valid : BOOL;
            _error : BOOL;
            _busy : BOOL;

            _record : ARRAY[0..10] OF BYTE;
        END_VAR

        METHOD PUBLIC Execute
            VAR_TEMP
                status : DWORD := DWORD#0;
                request : BOOL := FALSE;
                length : UINT := UINT#0;
                index : DINT := DINT#0;
                maxLength : UINT := UINT#0;
            END_VAR

            IF _command <> NULL THEN
                request := TRUE;
                index := _command^.GetIndex();
                maxLength := _command^.GetSize();
                _command^.ValueAsBytes(REF(_record));
            ELSE
                request := FALSE;
            END_IF;

            _writer(
                request := request,
                id := HwId,
                index := index,
                length := length,
                record := _record,
                done => _valid,
                busy => _busy,
                error => _error,
                status => status
            );

            ErrorAlarm.Execute(SIG := _error, SD_1 := pass(status));
        END_METHOD

        METHOD PUBLIC SetCommand
            VAR_INPUT
                command : REF_TO AsyncCommand;
            END_VAR

            _command := command;
        END_METHOD

        METHOD PUBLIC IsDone : BOOL
            IsDone := _valid;
        END_METHOD

        METHOD PUBLIC IsBusy : BOOL
            IsBusy := _busy;
        END_METHOD

        METHOD PUBLIC HasError : BOOL
            HasError := _error;
        END_METHOD
    END_CLASS

    INTERFACE IAsyncInterface
        /// Cyclic execute.
        METHOD Execute
        END_METHOD

        /// Resets the internal state (does NOT flush the command queue)
        METHOD Reset
        END_METHOD

        /// Adds a write command to the execution queue.
        METHOD WriteCommand
            VAR_INPUT
                command : REF_TO AsyncCommand;
            END_VAR
        END_METHOD

        /// Adds a write command to the execution queue.
        METHOD ReadCommand
            VAR_INPUT
                command : REF_TO AsyncCommand;
            END_VAR
        END_METHOD

        /// Clears the command queue (this will NOT abort any running commands).
        METHOD FlushCommandQueue
        END_METHOD

        /// Returns a reference to the current command
        METHOD CurrentCommand : REF_TO AsyncCommand
        END_METHOD

        /// Returns TRUE if this async interface is idle (i.e. no commands in queue)
        METHOD IsIdle : BOOL
        END_METHOD

        METHOD SetListener
            VAR_INPUT
                handler : IAsyncCommandListener;
            END_VAR
        END_METHOD
    END_INTERFACE

    CLASS ABSTRACT AsyncCommand EXTENDS LinkedListItem IMPLEMENTS IAsyncCommand
        VAR PUBLIC
            CommandType : CommandType := CommandType#Invalid;
            Index : DataRecord := DataRecord#Invalid;
        END_VAR

        VAR PRIVATE
            _callback_listener : IAsyncCommandListener := NULL;
        END_VAR

        METHOD PUBLIC GetIndex : DataRecord
            GetIndex := Index;
        END_METHOD

        METHOD PUBLIC ABSTRACT ValueAsBytes
            VAR_INPUT
                buffer : REF_TO ARRAY[*] OF BYTE;
            END_VAR
        END_METHOD

        METHOD PUBLIC ABSTRACT ValueFromBytes
            VAR_INPUT
                buffer : REF_TO ARRAY[*] OF BYTE;
            END_VAR
        END_METHOD

        METHOD PUBLIC ABSTRACT GetSize : UINT
        END_METHOD

        METHOD PUBLIC SetWrite
            CommandType := CommandType#Write;
        END_METHOD

        METHOD PUBLIC SetRead
            CommandType := CommandType#Read;
        END_METHOD

        METHOD PUBLIC GetType : CommandType
            GetType := CommandType;
        END_METHOD

        METHOD PUBLIC SetListener
            VAR_INPUT
                Listener : IAsyncCommandListener;
            END_VAR
            _callback_listener := Listener;
        END_METHOD

        METHOD PUBLIC Callback
            VAR_INPUT
                status : CommandStatus;
            END_VAR
            IF _callback_listener <> NULL THEN
                _callback_listener.AsyncCommandCallback(REF(THIS), status);
            END_IF;
        END_METHOD
    END_CLASS

    INTERFACE IAsyncCommand
        /// The data record to be read/written.
        METHOD GetIndex : DataRecord
        END_METHOD

        /// Writes the command data into a buffer
        METHOD ValueAsBytes
            VAR_INPUT
                buffer : REF_TO ARRAY[*] OF BYTE;
            END_VAR
        END_METHOD

        /// Reads a buffer and converts it into the command value
        METHOD ValueFromBytes
            VAR_INPUT
                buffer : REF_TO ARRAY[*] OF BYTE;
            END_VAR
        END_METHOD

        /// The expected size of the data in bytes.
        METHOD GetSize : UINT
        END_METHOD

        /// Set the type of this command to write
        METHOD SetWrite
        END_METHOD

        /// Set the type of this command to read
        METHOD SetRead
        END_METHOD

        /// The type of command (read or write).
        METHOD GetType : CommandType
        END_METHOD

        /// Listen for when the command finishes.
        METHOD SetListener
            VAR_INPUT
                Listener : IAsyncCommandListener;
            END_VAR
        END_METHOD

        /// Callback the command once finished to the listener.
        METHOD Callback
            VAR_INPUT
                status : CommandStatus;
            END_VAR
        END_METHOD
    END_INTERFACE

    INTERFACE IAsyncCommandListener
        METHOD AsyncCommandCallback
            VAR_INPUT
                command : REF_TO AsyncCommand;
                status : CommandStatus;
            END_VAR
        END_METHOD
    END_INTERFACE

    INTERFACE IAsyncWriter

        /// Cyclic execute.
        METHOD Execute
        END_METHOD

        /// Sets the command to be executed by the writer
        METHOD SetCommand
            VAR_INPUT
                command : REF_TO AsyncCommand;
            END_VAR
        END_METHOD

        /// Returns TRUE if the write operation was successful.
        METHOD IsDone : BOOL
        END_METHOD

        /// Returns TRUE if the write operation is in progress.
        METHOD IsBusy : BOOL
        END_METHOD

        /// Returns TRUE if an error occured during write.
        METHOD HasError : BOOL
        END_METHOD

    END_INTERFACE

    INTERFACE IAsyncReader

        /// Cyclic execute.
        METHOD Execute
        END_METHOD

        /// Sets the command to be executed by the reader
        METHOD SetCommand
            VAR_INPUT
                command : REF_TO AsyncCommand;
            END_VAR
        END_METHOD

        /// Returns TRUE if the read operation was successful.
        METHOD IsDone : BOOL
        END_METHOD

        /// Returns TRUE if the read operation is in progress.
        METHOD IsBusy : BOOL
        END_METHOD

        /// Returns TRUE if an error occured during read.
        METHOD HasError : BOOL
        END_METHOD

    END_INTERFACE

    TYPE
        CommandType : INT(
            Invalid := INT#-1,
            Read := INT#0,
            Write := INT#1
        ) := Invalid;

        CommandStatus : INT(
            Invalid := -1,
            Success := 0,
            Error := 1
        ) := Error;

        DataRecord : DINT(
            Invalid := DINT#-1,
            WeldProcess := DINT#1,
            WeldMethod := DINT#2,
            RegulationType := DINT#3,
            WireType := DINT#4,
            WireDimension := DINT#5,
            Voltage := DINT#6,
            Current := DINT#7,
            StartType := DINT#8,
            CraterFillTime := DINT#9,
            BurnBackTime := DINT#10,
            RegulationDynamics := DINT#11,
            RegulationInductance := DINT#12,
            AcFrequency := DINT#13,
            AcBalance := DINT#14,
            AcOffset := DINT#15,
            AcPhaseShift := DINT#16,
            StartAdjust := DINT#17,
            WireSpeed := DINT#18,
            TravelSpeed := DINT#19,
            IceWireSpeedPercentage := DINT#21,
            LwasNoOfStarts := DINT#22,
            LwasTimeout := DINT#23,
            CableArea := DINT#30,
            CableLength := DINT#31,
            GetWireDimensions := DINT#32,
            GetWireTypes := DINT#33,
            MeasureValueFrequency := DINT#34,
            MaxOcv := DINT#35,
            ParallelPowerSources := DINT#36,
            AcSyncMaster := DINT#37,
            CoupleId := DINT#38,
            PairParallelCouple := DINT#39,
            MeasureValueFilter := DINT#40,
            TandemRole := DINT#41,
            CreepStart := DINT#43,
            CreepSpeed := DINT#44,
            MaxTravelSpeed := DINT#45,
            TravelControl := DINT#46,
            TravelMotorDrive := DINT#47,
            WireMotorScaleFactor1 := DINT#48,
            WireMotorScaleFactor2 := DINT#49,
            WireJogLowSpeed := DINT#50,
            WireJogHighSpeed := DINT#51,
            IceActive := DINT#55,
            IceStartDelay := DINT#56,
            IceWireMotorScaleFactor1 := DINT#57,
            IceWireMotorScaleFactor2 := DINT#58,
            IceWireJogLowSpeed := DINT#59,
            IceWireJogHighSpeed := DINT#60,
            IceLicenseRemainingTime := DINT#61,
            MaxWireMotorCurrent := DINT#63,
            LanguageSelection := DINT#100,
            ConnectedUnits := DINT#107,
            NodeInformation := DINT#108,
            GetWeldingSystem := DINT#109,
            ErrorMessage := DINT#112,
            ErrorDeviceType := DINT#113,
            Can2NodeId := DINT#115
        ) := Invalid;

        NodeInformation : STRUCT
            Connected : BOOL := FALSE;
            Version : UINT := UINT#0;
            SubVersion : CHAR := CHAR#0;
            DeviceType : DeviceType := DeviceType#Invalid;
            MachineId : UINT := UINT#0;
        END_STRUCT;

        DeviceType : UINT(
            Invalid := UINT#99,
            WeldDataUnit := UINT#0,
            PowerSource := UINT#2,
            MotorControl := UINT#6
        ) := Invalid;

        WeldSystemType : UINT(
            LafTaf := UINT#0,
            Aristo1000 := UINT#1
        );
    END_TYPE

END_NAMESPACE