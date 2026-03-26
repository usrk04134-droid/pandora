USING Esab.Utils.Alarming;
USING Esab.Utils.Assets;
USING Esab.Io;

NAMESPACE Esab.Utils.Power

    /// Implements asset for the SITOP UPS1600
    CLASS Ups1600 EXTENDS Asset IMPLEMENTS IUps
        VAR PRIVATE
            _io : REF_TO Ups1600Io;

            _inputVoltageOkAlarm     : IAlarm;
            _chargeInsufficientAlarm : IAlarm;
            _batteryChangeAlarm      : IAlarm;
            _batteryMaintenanceAlarm : IAlarm;
            _unknownBatteryAlarm     : IAlarm;

            _observable : Ups1600Observable;
        END_VAR

        METHOD PUBLIC Setup
            VAR_INPUT
                io                      : REF_TO Ups1600Io;
                inputVoltageOkAlarm     : IAlarm;
                chargeInsufficientAlarm : IAlarm;
                batteryChangeAlarm      : IAlarm;
                batteryMaintenanceAlarm : IAlarm;
                unknownBatteryAlarm     : IAlarm;
                setupAlarm              : IAlarm;
            END_VAR

            _io := io;
            _inputVoltageOkAlarm := inputVoltageOkAlarm;
            _chargeInsufficientAlarm := chargeInsufficientAlarm;
            _batteryChangeAlarm := batteryChangeAlarm;
            _batteryMaintenanceAlarm := batteryMaintenanceAlarm;
            _unknownBatteryAlarm := unknownBatteryAlarm;
            _setupAlarm := setupAlarm;

            _isSetup := _io <> NULL;
        END_METHOD

        METHOD PUBLIC OVERRIDE Execute
            SUPER.Execute();

            IF _inputVoltageOkAlarm <> NULL THEN
                _inputVoltageOkAlarm.Execute(NOT _io^.Inputs.InputVoltageOk.GetValue());
            END_IF;

            IF _chargeInsufficientAlarm <> NULL THEN
                _chargeInsufficientAlarm.Execute(NOT _io^.Inputs.ChargeSufficient.GetValue());
            END_IF;

            IF _batteryChangeAlarm <> NULL THEN
                _batteryChangeAlarm.Execute(_io^.Inputs.BatteryChangeRecommended.GetValue());
            END_IF;

            IF _batteryMaintenanceAlarm <> NULL THEN
                _batteryMaintenanceAlarm.Execute(_io^.Inputs.BatteryMaintenanceRequired.GetValue());
            END_IF;

            IF _unknownBatteryAlarm <> NULL THEN
                _unknownBatteryAlarm.Execute(_io^.Inputs.UnknownBattery.GetValue());
            END_IF;

            THIS.UpdateObservable();
        END_METHOD

        METHOD PUBLIC OVERRIDE Observe : IAssetObservable
            Observe := _observable;
        END_METHOD

        METHOD PRIVATE UpdateObservable
            _observable.InputVoltageOk := _io^.Inputs.InputVoltageOk.GetValue();
            _observable.BufferModeActive := _io^.Inputs.BufferModeActive.GetValue();
            _observable.ReadyForBuffering := _io^.Inputs.ReadyForBuffering.GetValue();
            _observable.ChargeSufficient := _io^.Inputs.ChargeSufficient.GetValue();
            _observable.BatteryChangeRecommended := _io^.Inputs.BatteryChangeRecommended.GetValue();
            _observable.NewAlarmsPending := _io^.Inputs.NewAlarmsPending.GetValue();
            _observable.BatteryChargeLevel := _io^.Inputs.BatteryChargeLevel.GetValue();
            _observable.UnknownBattery := _io^.Inputs.UnknownBattery.GetValue();
            _observable.BatteryMaintenanceRequired := _io^.Inputs.BatteryMaintenanceRequired.GetValue();
        END_METHOD
    END_CLASS

    CLASS Ups1600Observable IMPLEMENTS IAssetObservable
        VAR PUBLIC
            InputVoltageOk              : BOOL;
            BufferModeActive            : BOOL;
            ReadyForBuffering           : BOOL;
            ChargeSufficient            : BOOL;
            BatteryChangeRecommended    : BOOL;
            NewAlarmsPending            : BOOL;
            BatteryChargeLevel          : UINT;
            UnknownBattery              : BOOL;
            BatteryMaintenanceRequired  : BOOL;
        END_VAR
    END_CLASS

    TYPE
        Ups1600Io : STRUCT
            Inputs : Ups1600Inputs;
        END_STRUCT;

        Ups1600Inputs : STRUCT
            InputVoltageOk              : DigitalInput;
            BufferModeActive            : DigitalInput;
            ReadyForBuffering           : DigitalInput;
            ChargeSufficient            : DigitalInput;
            BatteryChangeRecommended    : DigitalInput;
            NewAlarmsPending            : DigitalInput;
            BatteryChargeLevel          : UIntInput;
            UnknownBattery              : DigitalInput;
            BatteryMaintenanceRequired  : DigitalInput;
        END_STRUCT;
    END_TYPE

    {::ifndef UNLINK_UPS_IO}
    TYPE
        RawFromUps1600 : STRUCT
            InputVoltageOk              AT %B0: BYTE;
            BufferModeActive                  AT %B1: BYTE;
            ReadyForBuffering           AT %B2: BYTE;
            ChargeSufficient            AT %B3: BYTE;
            BatteryChangeRecommended    AT %B4: BYTE;
            NewAlarmsPending            AT %B5: BYTE;
            BatteryChargeLevel          AT %B6: BYTE;
            BatteryMaintenanceRequired  AT %B7: BYTE;
        END_STRUCT;
    END_TYPE
    {::else}
    TYPE
        RawFromUps1600 : STRUCT
            InputVoltageOk             : BYTE;
            BufferModeActive                 : BYTE;
            ReadyForBuffering          : BYTE;
            ChargeSufficient           : BYTE;
            BatteryChangeRecommended   : BYTE;
            NewAlarmsPending           : BYTE;
            BatteryChargeLevel         : BYTE;
            BatteryMaintenanceRequired : BYTE;
        END_STRUCT;
    END_TYPE
    {::endif}

    FUNCTION ReadUps1600Inputs
        VAR_INPUT
            io : REF_TO Ups1600Io;
            raw : REF_TO RawFromUps1600;
        END_VAR

        io^.Inputs.InputVoltageOk.Read(raw^.InputVoltageOk = BYTE#255);
        io^.Inputs.BufferModeActive.Read(raw^.BufferModeActive <> BYTE#0);
        io^.Inputs.ReadyForBuffering.Read(raw^.ReadyForBuffering = BYTE#255);
        io^.Inputs.ChargeSufficient.Read(raw^.ChargeSufficient <> BYTE#0);
        io^.Inputs.BatteryChangeRecommended.Read(raw^.BatteryChangeRecommended <> BYTE#0);
        io^.Inputs.NewAlarmsPending.Read(raw^.NewAlarmsPending <> BYTE#0);
        io^.Inputs.BatteryChargeLevel.Read(raw^.BatteryChargeLevel);
        io^.Inputs.UnknownBattery.Read(raw^.BatteryChargeLevel = BYTE#255);
        io^.Inputs.BatteryMaintenanceRequired.Read(raw^.BatteryMaintenanceRequired = BYTE#255);
    END_FUNCTION

END_NAMESPACE