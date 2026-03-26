USING AxUnit;
USING Esab.Utils.Alarming.Mock;
USING Esab.WeldSystem;
USING Esab.Utils.Assets;
USING Esab.WeldSystem.PowerSources;
USING Esab.WeldSystem.PowerSources.Mock;

USING Siemens.Simatic.S71500.DistributedIO;

USING AxUnit;

NAMESPACE Esab.WeldSystem.Test

    {TestFixture}
    {Category(WeldSystem)}
    CLASS Aristo1000Tests

        VAR PRIVATE
            _ps : Aristo1000.PowerSource;
            _defaultPs : Aristo1000.PowerSource;
            _data : Io;
            _defaultData : Io;
            _heartbeat : HeartbeatMock;
            _runtimeParameters : RuntimeParameters;
            _hardwareConfiguration : HardwareConfiguration;
            _asyncInterface : AsyncInterface;
            _defaultAsyncInterface : AsyncInterface;
            _reader : AsyncReaderMock;
            _writer : AsyncWriterMock;
            _errorAlarm : AlarmMock;
            _heartbeatAlarm : AlarmMock;
            _asyncCommandReadAlarm : AlarmMock;
            _asyncCommandWriteAlarm : AlarmMock;
            _asyncCommandNullAlarm : AlarmMock;
            _startupErrorAlarm : AlarmMock;

            _defaultInvalidCommandTypeAlarm : AlarmMock;
            _defaultPoppedNullCommandAlarm: AlarmMock;
            _defaultInvalidCommandAlarm: AlarmMock;

            _invalidCommandTypeAlarm : AlarmMock;
            _poppedNullCommandAlarm: AlarmMock;
            _invalidCommandAlarm: AlarmMock;

            _setDeviceStatePayload : SetDeviceStatePayload;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            _defaultAsyncInterface.Setup(_reader, _writer, _defaultInvalidCommandTypeAlarm, _defaultPoppedNullCommandAlarm, _defaultInvalidCommandAlarm);
            _asyncInterface.Setup(_reader, _writer, _invalidCommandTypeAlarm, _poppedNullCommandAlarm, _invalidCommandAlarm);
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            _data := _defaultData;


            _heartbeat.MockReset();
            _heartbeat.IsInitializedMock.Value := TRUE;
            _heartbeat.AliveMock.Value := TRUE;

            _reader.MockReset();
            _writer.MockReset();
            _asyncInterface := _defaultAsyncInterface;
            _asyncInterface.Setup(_reader, _writer, _invalidCommandTypeAlarm, _poppedNullCommandAlarm, _invalidCommandAlarm);

            _ps := _defaultPs;
            _ps.Setup(UINT#255, WORD#0, _heartbeat, REF(_data), REF(_runtimeParameters), REF(_hardwareConfiguration), _asyncInterface, _errorAlarm, _heartbeatAlarm, _asyncCommandReadAlarm, _asyncCommandWriteAlarm, _asyncCommandNullAlarm, _startupErrorAlarm);
        END_METHOD

        {Test}
        METHOD PUBLIC HeartbeatIsInitialized
            Assert.Equal(_heartbeat.IsInitialized(), TRUE);
        END_METHOD

        {Test}
        METHOD PUBLIC Start
            VAR_TEMP
                _start : BOOL;
            END_VAR;

            _ps.Start();
            _data.Pab.Output.Common.WeldOn.Write(_start);
            Assert.Equal(_start, TRUE);
        END_METHOD

        {Test}
        METHOD PUBLIC Stop
            VAR_TEMP
                _out : BOOL;
            END_VAR;

            _ps.Start();
            _data.Pab.Output.Common.WeldOn.Write(_out);
            Assert.Equal(_out, TRUE);

            _ps.Stop();
            _data.Pab.Output.Common.WeldOn.Write(_out);
            Assert.Equal(_out, FALSE);
        END_METHOD

        {Test}
        METHOD PUBLIC QuickStop
            VAR_TEMP
                _start : BOOL;
                _quickStop : BOOL;
            END_VAR;

            _ps.Start();
            _data.Pab.Output.Common.WeldOn.Write(_start);
            Assert.Equal(_start, TRUE);

            _ps.QuickStop();
            _data.Pab.Output.Common.WeldOn.Write(_start);
            _data.Pab.Output.Common.QuickStop.Write(_quickStop);
            Assert.Equal(_start, FALSE);
            Assert.Equal(_quickStop, TRUE);
        END_METHOD

        {Test}
        METHOD PUBLIC ActiveSetPoints
            VAR_TEMP
                Voltage : UINT;
                Current : UINT;
                WireSpeed : UINT;
                TravelSpeed : UINT;
                AcFrequency : UINT;
                AcBalance : UINT;
                AcOffset : UINT;
                AcPhaseShift : UINT;
                WeldMethod : BYTE;
                RegulationType : BYTE;
                StartAdjust : UINT;
                RegulationDynamics : UINT;
                RegulationInductance : UINT;
                IceWireSpeedPercentage : UINT;
            END_VAR

            _ps.ActiveArea()^.Voltage := REAL#42.0;
            _ps.ActiveArea()^.Current := UINT#42;
            _ps.ActiveArea()^.WireSpeed := UINT#42;
            _ps.ActiveArea()^.TravelSpeed := UINT#42;
            _ps.ActiveArea()^.AcFrequency := UINT#42;
            _ps.ActiveArea()^.AcBalance := UINT#42;
            _ps.ActiveArea()^.AcOffset := REAL#42.0;
            _ps.ActiveArea()^.AcPhaseShift := UINT#42;
            _ps.ActiveArea()^.WeldMethod := BYTE#42;
            _ps.ActiveArea()^.RegulationType := BYTE#42;
            _ps.ActiveArea()^.StartAdjust := UINT#42;
            _ps.ActiveArea()^.RegulationDynamics := UINT#42;
            _ps.ActiveArea()^.RegulationInductance := UINT#42;
            _ps.ActiveArea()^.IceWireSpeedPercentage := UINT#42;

            _ps.Execute();

            _data.Pab.Output.InputArea[1].Voltage.Write(Voltage);
            _data.Pab.Output.InputArea[1].Current.Write(Current);
            _data.Pab.Output.InputArea[1].WireSpeed.Write(WireSpeed);
            _data.Pab.Output.InputArea[1].TravelSpeed.Write(TravelSpeed);
            _data.Pab.Output.InputArea[1].AcFrequency.Write(AcFrequency);
            _data.Pab.Output.InputArea[1].AcBalance.Write(AcBalance);
            _data.Pab.Output.InputArea[1].AcOffset.Write(AcOffset);
            _data.Pab.Output.InputArea[1].AcPhaseShift.Write(AcPhaseShift);
            _data.Pab.Output.InputArea[1].WeldMethod.Write(WeldMethod);
            _data.Pab.Output.InputArea[1].RegulationType.Write(RegulationType);
            _data.Pab.Output.InputArea[1].StartAdjust.Write(StartAdjust);
            _data.Pab.Output.InputArea[1].RegulationDynamics.Write(RegulationDynamics);
            _data.Pab.Output.InputArea[1].RegulationInductance.Write(RegulationInductance);
            _data.Pab.Output.InputArea[1].IceWireSpeedPercentage.Write(IceWireSpeedPercentage);

            Assert.Equal(TO_UINT(Esab.Utils.Flip(Voltage)), UINT#420);
            Assert.Equal(TO_UINT(Esab.Utils.Flip(Current)), UINT#42);
            Assert.Equal(TO_UINT(Esab.Utils.Flip(WireSpeed)), UINT#42);
            Assert.Equal(TO_UINT(Esab.Utils.Flip(TravelSpeed)), UINT#42);
            Assert.Equal(TO_UINT(Esab.Utils.Flip(AcFrequency)), UINT#42);
            Assert.Equal(TO_UINT(Esab.Utils.Flip(AcBalance)), UINT#42);
            Assert.Equal(TO_UINT(Esab.Utils.Flip(AcOffset)), UINT#420);
            Assert.Equal(TO_UINT(Esab.Utils.Flip(AcPhaseShift)), UINT#42);
            Assert.Equal(WeldMethod, BYTE#42);
            Assert.Equal(RegulationType, BYTE#42);
            Assert.Equal(TO_UINT(Esab.Utils.Flip(StartAdjust)), UINT#42);
            Assert.Equal(TO_UINT(Esab.Utils.Flip(RegulationDynamics)), UINT#42);
            Assert.Equal(TO_UINT(Esab.Utils.Flip(RegulationInductance)), UINT#42);
            Assert.Equal(TO_UINT(Esab.Utils.Flip(IceWireSpeedPercentage)), UINT#42);
        END_METHOD

        {Test}
        METHOD PUBLIC PassiveArea
            VAR_TEMP
                Voltage : UINT;
                Current : UINT;
                WireSpeed : UINT;
                TravelSpeed : UINT;
                AcFrequency : UINT;
                AcBalance : UINT;
                AcOffset : UINT;
                AcPhaseShift : UINT;
                WeldMethod : BYTE;
                RegulationType : BYTE;
                StartAdjust : UINT;
                RegulationDynamics : UINT;
                RegulationInductance : UINT;
                IceWireSpeedPercentage : UINT;
            END_VAR

            _ps.PassiveArea()^.Voltage := REAL#42.0;
            _ps.PassiveArea()^.Current := UINT#42;
            _ps.PassiveArea()^.WireSpeed := UINT#42;
            _ps.PassiveArea()^.TravelSpeed := UINT#42;
            _ps.PassiveArea()^.AcFrequency := UINT#42;
            _ps.PassiveArea()^.AcBalance := UINT#42;
            _ps.PassiveArea()^.AcOffset := REAL#42.0;
            _ps.PassiveArea()^.AcPhaseShift := UINT#42;
            _ps.PassiveArea()^.WeldMethod := BYTE#42;
            _ps.PassiveArea()^.RegulationType := BYTE#42;
            _ps.PassiveArea()^.StartAdjust := UINT#42;
            _ps.PassiveArea()^.RegulationDynamics := UINT#42;
            _ps.PassiveArea()^.RegulationInductance := UINT#42;
            _ps.PassiveArea()^.IceWireSpeedPercentage := UINT#42;

            _ps.Execute();

            _data.Pab.Output.InputArea[2].Voltage.Write(Voltage);
            _data.Pab.Output.InputArea[2].Current.Write(Current);
            _data.Pab.Output.InputArea[2].WireSpeed.Write(WireSpeed);
            _data.Pab.Output.InputArea[2].TravelSpeed.Write(TravelSpeed);
            _data.Pab.Output.InputArea[2].AcFrequency.Write(AcFrequency);
            _data.Pab.Output.InputArea[2].AcBalance.Write(AcBalance);
            _data.Pab.Output.InputArea[2].AcOffset.Write(AcOffset);
            _data.Pab.Output.InputArea[2].AcPhaseShift.Write(AcPhaseShift);
            _data.Pab.Output.InputArea[2].WeldMethod.Write(WeldMethod);
            _data.Pab.Output.InputArea[2].RegulationType.Write(RegulationType);
            _data.Pab.Output.InputArea[2].StartAdjust.Write(StartAdjust);
            _data.Pab.Output.InputArea[2].RegulationDynamics.Write(RegulationDynamics);
            _data.Pab.Output.InputArea[2].RegulationInductance.Write(RegulationInductance);
            _data.Pab.Output.InputArea[2].IceWireSpeedPercentage.Write(IceWireSpeedPercentage);

            Assert.Equal(TO_UINT(Esab.Utils.Flip(Voltage)), UINT#420);
            Assert.Equal(TO_UINT(Esab.Utils.Flip(Current)), UINT#42);
            Assert.Equal(TO_UINT(Esab.Utils.Flip(WireSpeed)), UINT#42);
            Assert.Equal(TO_UINT(Esab.Utils.Flip(TravelSpeed)), UINT#42);
            Assert.Equal(TO_UINT(Esab.Utils.Flip(AcFrequency)), UINT#42);
            Assert.Equal(TO_UINT(Esab.Utils.Flip(AcBalance)), UINT#42);
            Assert.Equal(TO_UINT(Esab.Utils.Flip(AcOffset)), UINT#420);
            Assert.Equal(TO_UINT(Esab.Utils.Flip(AcPhaseShift)), UINT#42);
            Assert.Equal(WeldMethod, BYTE#42);
            Assert.Equal(RegulationType, BYTE#42);
            Assert.Equal(TO_UINT(Esab.Utils.Flip(StartAdjust)), UINT#42);
            Assert.Equal(TO_UINT(Esab.Utils.Flip(RegulationDynamics)), UINT#42);
            Assert.Equal(TO_UINT(Esab.Utils.Flip(RegulationInductance)), UINT#42);
            Assert.Equal(TO_UINT(Esab.Utils.Flip(IceWireSpeedPercentage)), UINT#42);
        END_METHOD

        {Test}
        METHOD PUBLIC SwitchActivePassive
            VAR_TEMP
                active : REF_TO SetPoints;
                passive : REF_TO SetPoints;
            END_VAR

            active := _ps.ActiveArea();
            passive := _ps.PassiveArea();

            _ps.SwitchActivePassive();

            Assert.Equal(active = _ps.PassiveArea(), TRUE);
            Assert.Equal(passive = _ps.ActiveArea(), TRUE);
        END_METHOD

        {Test}
        METHOD PUBLIC ReadNodeInformation
            VAR_TEMP
                _command : REF_TO AsyncCommand;
                _udintCommand : REF_TO UDIntAsyncCommand;
                _nodeInfoCommand : REF_TO NodeInformationAsyncCommand;
            END_VAR

            _writer.IsDoneMock.Value := TRUE;
            _ps.Execute();
            _writer.IsDoneMock.Value := FALSE;
            _ps.Execute();
            _writer.IsDoneMock.Value := TRUE;
            _ps.Execute();
            _writer.IsDoneMock.Value := FALSE;
            _ps.Execute();

            _reader.MockReset();

            _ps.Execute();
            _ps.Execute();
            _ps.Execute();
            _ps.Execute();
            _ps.Execute();

            Assert.Equal(_reader.SetCommandMock.GetCallCount(), UINT#5);
            _reader.MockReset();

            // Kick off the reading of nodes
            _ps.ReadNodes();

            // --------------- READ CONNECTED UNITS

            // Move command from queue to reader
            Assert.Equal(_reader.IsBusy(), FALSE);
            _ps.Execute();
            Assert.Equal(_reader.IsBusy(), TRUE);

            // Check that the correct command was sent to the reader
            _udintCommand ?= _reader.SetCommandMock.Value;

            IF _udintCommand <> NULL THEN
                Assert.Equal(_udintCommand^.Index, DataRecord#ConnectedUnits);
                Assert.Equal(_reader.IsBusy(), TRUE);
            ELSE
                Assert.Equal(_udintCommand <> NULL, TRUE);
            END_IF;

            // Execute once
            _ps.Execute();

            // Set which nodes are connected (1, 2, 5, 18)
            // Set the ConnectedUnits command value to simulate connected nodes
            IF _udintCommand <> NULL THEN
                _udintCommand^.Value := UDINT#2#1000000000000100110;
            END_IF;

            // Finish reading
            _reader.IsDoneMock.Value := TRUE;
            _ps.Execute();
            Assert.Equal(_reader.IsBusy(), FALSE);
            _reader.IsDoneMock.Value := FALSE;

            // TODO: NodeIsConnected assertions disabled due to inability to set up ConnectedUnits data without private field access
            Assert.Equal(_ps.NodeIsConnected(UINT#1), TRUE);
            Assert.Equal(_ps.NodeIsConnected(UINT#2), TRUE);
            Assert.Equal(_ps.NodeIsConnected(UINT#3), FALSE);
            Assert.Equal(_ps.NodeIsConnected(UINT#4), FALSE);
            Assert.Equal(_ps.NodeIsConnected(UINT#5), TRUE);
            Assert.Equal(_ps.NodeIsConnected(UINT#18), TRUE);

            // --------------- WRITE NODE INFORMATION ID

            // Move command from queue to writer
            Assert.Equal(_writer.IsBusy(), FALSE);
            _ps.Execute();
            Assert.Equal(_writer.IsBusy(), TRUE);

            // Verify the command set
            _nodeInfoCommand ?= _writer.SetCommandMock.Value;

            IF _nodeInfoCommand <> NULL THEN
                Assert.Equal(_nodeInfoCommand^.CommandType, CommandType#Write);
                Assert.Equal(_nodeInfoCommand^.Id, UINT#1);
                Assert.Equal(_nodeInfoCommand^.Index, DataRecord#NodeInformation);
            ELSE
                Assert.Equal(_nodeInfoCommand <> NULL, TRUE);
            END_IF;

            // Execute once
            _ps.Execute();

            // Finish writing
            _writer.IsDoneMock.Value := TRUE;
            _ps.Execute();
            Assert.Equal(_writer.IsBusy(), FALSE);
            _writer.IsDoneMock.Value := FALSE;

            // --------------- READ NODE INFORMATION

            Assert.Equal(_reader.IsBusy(), FALSE);
            _ps.Execute();
            Assert.Equal(_reader.IsBusy(), TRUE);

            // Verify command
            _nodeInfoCommand ?= _reader.SetCommandMock.Value;

            IF _nodeInfoCommand <> NULL THEN
                Assert.Equal(_nodeInfoCommand^.CommandType, CommandType#Read);
                Assert.Equal(_nodeInfoCommand^.Id, UINT#1);
                Assert.Equal(_nodeInfoCommand^.Index, DataRecord#NodeInformation);
            ELSE
                Assert.Equal(_nodeInfoCommand <> NULL, TRUE);
            END_IF;

            // Execute once
            _ps.Execute();

            // Finish reading
            _reader.IsDoneMock.Value := TRUE;
            _ps.Execute();
            Assert.Equal(_reader.IsBusy(), FALSE);
            _reader.IsDoneMock.Value := FALSE;

            // --------------- WRITE NODE INFORMATION ID

            // Move command from queue to writer
            Assert.Equal(_writer.IsBusy(), FALSE);
            _ps.Execute();
            Assert.Equal(_writer.IsBusy(), TRUE);

            // Verify the command set
            _nodeInfoCommand ?= _writer.SetCommandMock.Value;

            IF _nodeInfoCommand <> NULL THEN
                Assert.Equal(_nodeInfoCommand^.CommandType, CommandType#Write);
                Assert.Equal(_nodeInfoCommand^.Id, UINT#2);
                Assert.Equal(_nodeInfoCommand^.Index, DataRecord#NodeInformation);
            ELSE
                Assert.Equal(_nodeInfoCommand <> NULL, TRUE);
            END_IF;

            // Execute once
            _ps.Execute();

            // Finish writing
            _writer.IsDoneMock.Value := TRUE;
            _ps.Execute();
            Assert.Equal(_writer.IsBusy(), FALSE);
            _writer.IsDoneMock.Value := FALSE;

            // --------------- READ NODE INFORMATION

            Assert.Equal(_reader.IsBusy(), FALSE);
            _ps.Execute();
            Assert.Equal(_reader.IsBusy(), TRUE);

            // Verify command
            _nodeInfoCommand ?= _reader.SetCommandMock.Value;

            IF _nodeInfoCommand <> NULL THEN
                Assert.Equal(_nodeInfoCommand^.CommandType, CommandType#Read);
                Assert.Equal(_nodeInfoCommand^.Id, UINT#2);
                Assert.Equal(_nodeInfoCommand^.Index, DataRecord#NodeInformation);
            ELSE
                Assert.Equal(_nodeInfoCommand <> NULL, TRUE);
            END_IF;

            // Execute once
            _ps.Execute();

            // Finish reading
            _reader.IsDoneMock.Value := TRUE;
            _ps.Execute();
            Assert.Equal(_reader.IsBusy(), FALSE);
            _reader.IsDoneMock.Value := FALSE;

            // --------------- WRITE NODE INFORMATION ID

            // Move command from queue to writer
            Assert.Equal(_writer.IsBusy(), FALSE);
            _ps.Execute();
            Assert.Equal(_writer.IsBusy(), TRUE);

            // Verify the command set
            _nodeInfoCommand ?= _writer.SetCommandMock.Value;

            IF _nodeInfoCommand <> NULL THEN
                Assert.Equal(_nodeInfoCommand^.CommandType, CommandType#Write);
                Assert.Equal(_nodeInfoCommand^.Id, UINT#5);
                Assert.Equal(_nodeInfoCommand^.Index, DataRecord#NodeInformation);
            ELSE
                Assert.Equal(_nodeInfoCommand <> NULL, TRUE);
            END_IF;

            // Execute once
            _ps.Execute();

            // Finish writing
            _writer.IsDoneMock.Value := TRUE;
            _ps.Execute();
            Assert.Equal(_writer.IsBusy(), FALSE);
            _writer.IsDoneMock.Value := FALSE;

            // --------------- READ NODE INFORMATION

            Assert.Equal(_reader.IsBusy(), FALSE);
            _ps.Execute();
            Assert.Equal(_reader.IsBusy(), TRUE);

            // Verify command
            _nodeInfoCommand ?= _reader.SetCommandMock.Value;

            IF _nodeInfoCommand <> NULL THEN
                Assert.Equal(_nodeInfoCommand^.CommandType, CommandType#Read);
                Assert.Equal(_nodeInfoCommand^.Id, UINT#5);
                Assert.Equal(_nodeInfoCommand^.Index, DataRecord#NodeInformation);
            ELSE
                Assert.Equal(_nodeInfoCommand <> NULL, TRUE);
            END_IF;

            // Execute once
            _ps.Execute();

            // Finish reading
            _reader.IsDoneMock.Value := TRUE;
            _ps.Execute();
            Assert.Equal(_reader.IsBusy(), FALSE);
            _reader.IsDoneMock.Value := FALSE;

            // --------------- WRITE NODE INFORMATION ID

            // Move command from queue to writer
            Assert.Equal(_writer.IsBusy(), FALSE);
            _ps.Execute();
            Assert.Equal(_writer.IsBusy(), TRUE);

            // Verify the command set
            _nodeInfoCommand ?= _writer.SetCommandMock.Value;

            IF _nodeInfoCommand <> NULL THEN
                Assert.Equal(_nodeInfoCommand^.CommandType, CommandType#Write);
                Assert.Equal(_nodeInfoCommand^.Id, UINT#18);
                Assert.Equal(_nodeInfoCommand^.Index, DataRecord#NodeInformation);
            ELSE
                Assert.Equal(_nodeInfoCommand <> NULL, TRUE);
            END_IF;

            // Execute once
            _ps.Execute();

            // Finish writing
            _writer.IsDoneMock.Value := TRUE;
            _ps.Execute();
            Assert.Equal(_writer.IsBusy(), FALSE);
            _writer.IsDoneMock.Value := FALSE;

            // --------------- READ NODE INFORMATION

            Assert.Equal(_reader.IsBusy(), FALSE);
            _ps.Execute();
            Assert.Equal(_reader.IsBusy(), TRUE);

            // Verify command
            _nodeInfoCommand ?= _reader.SetCommandMock.Value;

            IF _nodeInfoCommand <> NULL THEN
                Assert.Equal(_nodeInfoCommand^.CommandType, CommandType#Read);
                Assert.Equal(_nodeInfoCommand^.Id, UINT#18);
                Assert.Equal(_nodeInfoCommand^.Index, DataRecord#NodeInformation);
            ELSE
                Assert.Equal(_nodeInfoCommand <> NULL, TRUE);
            END_IF;

            // Execute once
            _ps.Execute();

            // Finish reading
            _reader.IsDoneMock.Value := TRUE;
            _ps.Execute();
            Assert.Equal(_reader.IsBusy(), FALSE);
            _reader.IsDoneMock.Value := FALSE;
        END_METHOD
    END_CLASS

    FUNCTION SetDeviceStateMock : WORD
        VAR_INPUT
            execute : BOOL;
            mode : SetDeviceStateMode;
            deviceAddress : WORD;
        END_VAR

        VAR_OUTPUT
            busy : BOOL;
        END_VAR

        VAR_TEMP
            payload : REF_TO SetDeviceStatePayload;
        END_VAR

        payload ?= Mocking.GetPayload();

        IF payload <> NULL THEN
            SetDeviceStateMock := payload^.Status;
            busy := payload^.Busy;
            payload^.CallCount := payload^.CallCount + 1;
        END_IF;
    END_FUNCTION

    CLASS SetDeviceStatePayload IMPLEMENTS Mocking.IPayload
        VAR PUBLIC
            Status : SetDeviceStateStatus;
            Busy : BOOL;
            CallCount : INT;
        END_VAR
    END_CLASS
END_NAMESPACE