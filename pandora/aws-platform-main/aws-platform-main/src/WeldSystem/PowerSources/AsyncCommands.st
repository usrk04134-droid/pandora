USING Esab.Io;
USING Esab.Utils.Collections;

NAMESPACE Esab.WeldSystem.PowerSources

    CLASS AsyncCommands
        VAR PUBLIC
            WireType : UIntAsyncCommand := (Index := DataRecord#WeldMethod);
            WireDimension : UIntAsyncCommand := (Index := DataRecord#WeldMethod);
            StartType : UIntAsyncCommand := (Index := DataRecord#StartType );
            CraterFillTime : UIntAsyncCommand := (Index := DataRecord#CraterFillTime);
            BurnBackTime : UIntAsyncCommand := (Index := DataRecord#BurnBackTime);
            LwasNoOfStarts : UIntAsyncCommand := (Index := DataRecord#LwasNoOfStarts);
            LwasTimeout : UIntAsyncCommand := (Index := DataRecord#LwasTimeout);
            CableArea : UIntAsyncCommand := (Index := DataRecord#CableArea);
            CableLength : UIntAsyncCommand := (Index := DataRecord#CableLength);
            GetWireDimensions : UIntAsyncCommand := (Index := DataRecord#GetWireDimensions);
            GetWireTypes : UIntAsyncCommand := (Index := DataRecord#GetWireTypes);
            MeasureValueFrequency : UIntAsyncCommand := (Index := DataRecord#MeasureValueFrequency);
            MaxOcv : UIntAsyncCommand := (Index := DataRecord#MaxOcv);
            ParallelPowerSources : UIntAsyncCommand := (Index := DataRecord#ParallelPowerSources);
            AcSyncMaster : UIntAsyncCommand := (Index := DataRecord#AcSyncMaster);
            CoupleId : UIntAsyncCommand := (Index := DataRecord#CoupleId);
            PairParallelCouple : UIntAsyncCommand := (Index := DataRecord#PairParallelCouple);
            MeasureValueFilter : UIntAsyncCommand := (Index := DataRecord#MeasureValueFilter);
            TandemRole : UIntAsyncCommand := (Index := DataRecord#TandemRole);
            CreepStart : UIntAsyncCommand := (Index := DataRecord#CreepStart);
            CreepSpeed : UIntAsyncCommand := (Index := DataRecord#CreepSpeed);
            MaxTravelSpeed : UIntAsyncCommand := (Index := DataRecord#MaxTravelSpeed);
            TravelControl : UIntAsyncCommand := (Index := DataRecord#TravelControl);
            TravelMotorDrive : UIntAsyncCommand := (Index := DataRecord#TravelMotorDrive);
            WireMotorScaleFactor1 : UIntAsyncCommand := (Index := DataRecord#WireMotorScaleFactor1);
            WireMotorScaleFactor2 : UIntAsyncCommand := (Index := DataRecord#WireMotorScaleFactor2);
            MaxWireMotorCurrent : UIntAsyncCommand := (Index := DataRecord#MaxWireMotorCurrent);
            ConnectedUnits : UDIntAsyncCommand := (Index := DataRecord#ConnectedUnits);
            NodeInformation : NodeInformationAsyncCommand := (Index := DataRecord#NodeInformation);
            Can2NodeId : UIntAsyncCommand := (Index := DataRecord#Can2NodeId);
            GetWeldingSystem : UIntAsyncCommand := (Index := DataRecord#GetWeldingSystem);
            JogWireFeedSpeed : UIntAsyncCommand := (Index := DataRecord#WireJogLowSpeed);
            JogWireFeedHighSpeed : UIntAsyncCommand := (Index := DataRecord#WireJogHighSpeed);
        END_VAR
    END_CLASS

    CLASS UIntAsyncCommand EXTENDS AsyncCommand
        VAR PUBLIC
            Value : UINT := UINT#0;
        END_VAR

        METHOD PUBLIC OVERRIDE ValueAsBytes
            VAR_INPUT
                buffer : REF_TO ARRAY[*] OF BYTE;
            END_VAR

            buffer^[0] := Value.%B1;
            buffer^[1] := Value.%B0;
        END_METHOD

        METHOD PUBLIC OVERRIDE ValueFromBytes
            VAR_INPUT
                buffer : REF_TO ARRAY[*] OF BYTE;
            END_VAR

            Value.%B1 := buffer^[0];
            Value.%B0 := buffer^[1];
        END_METHOD

        METHOD PUBLIC OVERRIDE GetSize : UINT
            GetSize := UINT#2;
        END_METHOD
    END_CLASS

    CLASS UDIntAsyncCommand EXTENDS AsyncCommand
        VAR PUBLIC
            Value : UDINT := UDINT#0;
        END_VAR

        METHOD PUBLIC OVERRIDE ValueAsBytes
            VAR_INPUT
                buffer : REF_TO ARRAY[*] OF BYTE;
            END_VAR

            buffer^[0] := Value.%B1;
            buffer^[1] := Value.%B0;
            buffer^[2] := Value.%B3;
            buffer^[3] := Value.%B2;
        END_METHOD

        METHOD PUBLIC OVERRIDE ValueFromBytes
            VAR_INPUT
                buffer : REF_TO ARRAY[*] OF BYTE;
            END_VAR

            Value.%B1 := buffer^[0];
            Value.%B0 := buffer^[1];
            Value.%B3 := buffer^[2];
            Value.%B2 := buffer^[3];
        END_METHOD

        METHOD PUBLIC OVERRIDE GetSize : UINT
            GetSize := UINT#4;
        END_METHOD
    END_CLASS

    CLASS RealAsyncCommand EXTENDS AsyncCommand
        VAR PUBLIC
            Value : REAL := REAL#0.0;
        END_VAR

        METHOD PUBLIC OVERRIDE ValueAsBytes
            VAR_INPUT
                buffer : REF_TO ARRAY[*] OF BYTE;
            END_VAR

            VAR_TEMP
                _value : DWORD;
            END_VAR

            _value := TO_DWORD(Value);

            buffer^[0] := _value.%B1;
            buffer^[1] := _value.%B0;
            buffer^[2] := _value.%B3;
            buffer^[3] := _value.%B2;
        END_METHOD

        METHOD PUBLIC OVERRIDE ValueFromBytes
            VAR_INPUT
                buffer : REF_TO ARRAY[*] OF BYTE;
            END_VAR

            VAR_TEMP
                _value : DWORD;
            END_VAR

            _value.%B1 := buffer^[0];
            _value.%B0 := buffer^[1];
            _value.%B3 := buffer^[2];
            _value.%B2 := buffer^[3];

            Value := TO_REAL(_value);
        END_METHOD

        METHOD PUBLIC OVERRIDE GetSize : UINT
            GetSize := UINT#4;
        END_METHOD
    END_CLASS

    /// Async command that fetches the information of a node
    /// This command is a bit special. When used to write it will
    /// send the provided id, and when used to read it will populate the
    /// Value variable.
    CLASS NodeInformationAsyncCommand EXTENDS AsyncCommand
        VAR PUBLIC
            Id : UINT;
            Value : NodeInformation;
        END_VAR

        METHOD PUBLIC OVERRIDE ValueAsBytes
            VAR_INPUT
                buffer : REF_TO ARRAY[*] OF BYTE;
            END_VAR

            buffer^[0] := Id.%B1;
            buffer^[1] := Id.%B0;
        END_METHOD

        METHOD PUBLIC OVERRIDE ValueFromBytes
            VAR_INPUT
                buffer : REF_TO ARRAY[*] OF BYTE;
            END_VAR

            VAR_TEMP
                Version : UINT;
                SubVersion : UINT;
                DeviceType : UINT;
                MachineId : UINT;
            END_VAR

            Version.%B1 := buffer^[0];
            Version.%B0 := buffer^[1];
            SubVersion.%B1 := buffer^[2];
            SubVersion.%B0 := buffer^[3];
            DeviceType.%B1 := buffer^[4];
            DeviceType.%B0 := buffer^[5];
            MachineId.%B1 := buffer^[6];
            MachineId.%B0 := buffer^[7];

            Value.Version := Version;
            Value.SubVersion := TO_CHAR(TO_BYTE(SubVersion));
            Value.DeviceType := DeviceType;
            Value.MachineId := MachineId;
        END_METHOD

        METHOD PUBLIC OVERRIDE GetSize : UINT
            GetSize := UINT#8;
        END_METHOD
    END_CLASS

END_NAMESPACE