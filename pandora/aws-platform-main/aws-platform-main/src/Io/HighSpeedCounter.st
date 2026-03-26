USING Esab.Io;
USING Esab.Utils.Alarming;

NAMESPACE Esab.Io

    /// Interface for a HSC wrapper.
    INTERFACE IHighSpeedCounter
        /// Cyclic execute.
        METHOD Execute
        END_METHOD

        /// Enables the counter
        METHOD Enable
        END_METHOD

        /// Disables the counter
        METHOD Disable
        END_METHOD

        /// Returns the counter value in increments
        METHOD GetCountValue : DINT
        END_METHOD

        /// Returns the measured value, for our application this is the speed
        /// in increments/second
        METHOD GetMeasuredValue : DINT
        END_METHOD

        /// Returns the maximum possible value for this counter
        METHOD GetUpperCountingLimit : DINT
        END_METHOD

        /// Returns the minimum possible value for this counter
        METHOD GetLowerCountingLimit : DINT
        END_METHOD

        /// Reset counter value to value
        METHOD SetCountValue
            VAR_INPUT
                value : DINT;
            END_VAR
        END_METHOD

        /// Returns TRUE if the counter has an error.
        METHOD HasError : BOOL
        END_METHOD
    END_INTERFACE

    CLASS HighSpeedCounter EXTENDS Object IMPLEMENTS IHighSpeedCounter, InputChangedListener
        VAR PRIVATE
            _io : REF_TO HighSpeedCounterIo;
            _hardwareConfiguration : REF_TO HighSpeedCounterHardwareConfiguration;
            _loadCommandErrorAlarm : IAlarm;
            _encoderErrorAlarm : IAlarm;
            _powerSupplyAlarm : IAlarm;

            _currentSlot0Command : HighSpeedCounterLoadCommand;
            _currentSlot1Command : HighSpeedCounterLoadCommand;
        END_VAR

        METHOD PUBLIC Setup
            VAR_INPUT
                io : REF_TO HighSpeedCounterIo;
                hardwareConfiguration : REF_TO HighSpeedCounterHardwareConfiguration;
                loadCommandErrorAlarm : IAlarm;
                encoderErrorAlarm : IAlarm;
                powerSupplyAlarm : IAlarm;
                setupAlarm : IAlarm;
            END_VAR

            _io := io;
            _hardwareConfiguration := hardwareConfiguration;
            _loadCommandErrorAlarm := loadCommandErrorAlarm;
            _encoderErrorAlarm := encoderErrorAlarm;
            _powerSupplyAlarm := powerSupplyAlarm;
            _setupAlarm := setupAlarm;

            _isSetup := _io <> NULL AND _hardwareConfiguration <> NULL AND _encoderErrorAlarm <> NULL AND _powerSupplyAlarm <> NULL;

            IF _isSetup THEN
                _io^.Inputs.LoadError.SetChangedHandler(THIS);
                _io^.Inputs.Slot0Loaded.SetChangedHandler(THIS);
                _io^.Inputs.Slot1Loaded.SetChangedHandler(THIS);

                THIS.LoadSlot0(_hardwareConfiguration^.LowerCountingLimit, HighSpeedCounterLoadCommand#LoadLowCountingLimit);
                THIS.LoadSlot1(_hardwareConfiguration^.UpperCountingLimit, HighSpeedCounterLoadCommand#LoadHighCountingLimit);
            END_IF;
        END_METHOD

        METHOD PUBLIC OVERRIDE Execute
            SUPER.Execute();

            IF _setupAlarm.IsActive() THEN
                RETURN;
            END_IF;

            _loadCommandErrorAlarm.Execute(_io^.Inputs.LoadError.GetValue());
            _encoderErrorAlarm.Execute(_io^.Inputs.EncoderError.GetValue());
            _powerSupplyAlarm.Execute(_io^.Inputs.PowerSupplyError.GetValue());
        END_METHOD

        METHOD PUBLIC OVERRIDE UpdateState
            IF _setupAlarm.IsActive() THEN
                _currentState := HighSpeedCounterState#Error;
            ELSIF _encoderErrorAlarm.IsActive() OR _powerSupplyAlarm.IsActive() THEN
                _currentState := HighSpeedCounterState#Error;
            ELSE
                _currentState := HighSpeedCounterState#Healthy;
            END_IF;
        END_METHOD

        METHOD PUBLIC SetHardwareConfiguration
            VAR_INPUT
                hwConfiguration : REF_TO HighSpeedCounterHardwareConfiguration;
            END_VAR

            _hardwareConfiguration := hwConfiguration;
        END_METHOD

        METHOD PUBLIC Enable
            _io^.Outputs.SoftwareGate.Set();
        END_METHOD

        METHOD PUBLIC Disable
            _io^.Outputs.SoftwareGate.Reset();
        END_METHOD

        METHOD PUBLIC GetCountValue : DINT
            GetCountValue := _io^.Inputs.CountValue.GetValue();
        END_METHOD

        METHOD PUBLIC GetMeasuredValue : DINT
            GetMeasuredValue := _io^.Inputs.MeasuredValue.GetValue();
        END_METHOD

        METHOD PUBLIC GetUpperCountingLimit : DINT
            GetUpperCountingLimit := _hardwareConfiguration^.UpperCountingLimit;
        END_METHOD

        METHOD PUBLIC GetLowerCountingLimit : DINT
            GetLowerCountingLimit := _hardwareConfiguration^.LowerCountingLimit;
        END_METHOD

        METHOD PUBLIC SetCountValue
            VAR_INPUT
                value : DINT;
            END_VAR

            _io^.Outputs.Slot0.SetValue(value);
            _io^.Outputs.LoadSlotX.SetValue(HighSpeedCounterLoadCommand#LoadCounter);
        END_METHOD

        METHOD PUBLIC HasError : BOOL
            HasError := THIS.GetState() = HighSpeedCounterState#Error;
        END_METHOD

        METHOD PUBLIC InputChanged
            VAR_INPUT
                input : REF_TO Esab.Io.Input;
            END_VAR

            IF (input = REF(_io^.Inputs.LoadError) AND _io^.Inputs.LoadError.RisingEdge()) OR
               (input = REF(_io^.Inputs.Slot0Loaded) AND _io^.Inputs.Slot0Loaded.RisingEdge()) THEN

                THIS.LoadSlot0(DINT#0, HighSpeedCounterLoadCommand#Idle);
            ELSIF (input = REF(_io^.Inputs.LoadError) AND _io^.Inputs.LoadError.RisingEdge()) OR
                  (input = REF(_io^.Inputs.Slot0Loaded) AND _io^.Inputs.Slot0Loaded.RisingEdge()) THEN

                THIS.LoadSlot1(DINT#0, HighSpeedCounterLoadCommand#Idle);
            END_IF;
        END_METHOD

        METHOD PRIVATE LoadSlot0
            VAR_INPUT
                value : DINT;
                command : HighSpeedCounterLoadCommand;
            END_VAR

            _io^.Outputs.Slot0.SetValue(value);
            _currentSlot0Command := command;
            _io^.Outputs.LoadSlotX.SetValue(_currentSlot0Command AND SHL(_currentSlot1Command, UINT#4));
        END_METHOD

        METHOD PRIVATE LoadSlot1
            VAR_INPUT
                value : DINT;
                command : HighSpeedCounterLoadCommand;
            END_VAR

            _io^.Outputs.Slot1.SetValue(value);
            _currentSlot1Command := command;
            _io^.Outputs.LoadSlotX.SetValue(_currentSlot0Command AND SHL(_currentSlot1Command, UINT#4));
        END_METHOD
    END_CLASS

    TYPE
        HighSpeedCounterHardwareConfiguration : STRUCT
            UpperCountingLimit : DINT := DINT#2147483647;
            LowerCountingLimit : DINT := DINT#-2147483648;
        END_STRUCT;

        HighSpeedCounterState : INT(
            Healthy := 0,
            Error := 1
        );

        HighSpeedCounterLoadCommand : BYTE(
            Idle := BYTE#0,
            LoadCounter := BYTE#1,
            LoadStartValue := BYTE#3,
            LoadComparison0 := BYTE#4,
            LoadComparison1 := BYTE#5,
            LoadLowCountingLimit := BYTE#6,
            LoadHighCountingLimit := BYTE#7
        );

        HighSpeedCounterIo : STRUCT
            Inputs : HighSpeedCounterInputs;
            Outputs : HighSpeedCounterOutputs;
        END_STRUCT;

        HighSpeedCounterOutputs : STRUCT
            Slot0 : DIntOutput;
            Slot1 : DIntOutput;
            LoadSlotX : UIntOutput;
            EnableCapture : DigitalOutput;
            EnableSynchronizationDown : DigitalOutput;
            EnableSynchronizationUp : DigitalOutput;
            SetDq1 : DigitalOutput;
            SetDq0 : DigitalOutput;
            TmCtrlDq1 : DigitalOutput;
            TmCtrlDq0 : DigitalOutput;
            SoftwareGate : DigitalOutput;
            CountDirection : DigitalOutput;
            ResetEvents : DigitalOutput;
            ResetErrors : DigitalOutput;
        END_STRUCT;

        HighSpeedCounterInputs : STRUCT
            CountValue : DIntInput;
            CapturedValue : DIntInput;
            MeasuredValue : DIntInput;
            LoadError : DigitalInput;
            EncoderError : DigitalInput;
            PowerSupplyError : DigitalInput;
            SoftwareGate : DigitalInput;
            Ready : DigitalInput;
            Slot1Loaded : DigitalInput;
            Slot0Loaded : DigitalInput;
            ResetEventsAcknowledge : DigitalInput;
            Di2 : DigitalInput;
            Di1 : DigitalInput;
            Di0 : DigitalInput;
            Dq1 : DigitalInput;
            Dq0 : DigitalInput;
            InternalGate : DigitalInput;
            Counting : DigitalInput;
            Direction : DigitalInput;
            MeasurementPulseDetected : DigitalInput;
            CaptureEvent : DigitalInput;
            SynchronizationEvent : DigitalInput;
            ComparisonEvent1 : DigitalInput;
            ComparisonEvent0 : DigitalInput;
            OverflowEvent : DigitalInput;
            UnderflowEvent : DigitalInput;
            ZeroPassEvent : DigitalInput;
        END_STRUCT;

        RawHighSpeedCounterOutputs : STRUCT
            Slot0 AT %B0 : DINT;
            Slot1 AT %B4 : DINT;
            LoadSlotX AT %B8 : BYTE;
            EnableCapture AT %X9.7 : BOOL;
            EnableSynchronizationDown AT %X9.6 : BOOL;
            EnableSynchronizationUp AT %X9.5 : BOOL;
            SetDq1 AT %X9.4 : BOOL;
            SetDq0 AT %X9.3 : BOOL;
            TmCtrlDq1 AT %X9.2 : BOOL;
            TmCtrlDq0 AT %X9.1 : BOOL;
            SoftwareGate AT %X9.0 : BOOL;
            CountDirection AT %X10.7 : BOOL;
            // Bits 2 to 6 are reserved
            ResetEvents AT %X10.1 : BOOL;
            ResetErrors AT %X10.0 : BOOL;
        END_STRUCT;

        RawHighSpeedCounterInputs : STRUCT
            CountValue AT %B0 : DINT;
            CapturedValue AT %B4 : DINT;
            MeasuredValue AT %B8 : DINT;
            // Bits 2 to 7 are reserved
            LoadError AT %X12.2 : BOOL;
            EncoderError AT %X12.1 : BOOL;
            PowerSupplyError AT %X12.0 : BOOL;
            // Bits 6 to 7 are reserved
            SoftwareGate AT %X13.5 : BOOL;
            Ready AT %X13.4 : BOOL;
            Slot1Loaded AT %X13.3 : BOOL;
            Slot0Loaded AT %X13.2 : BOOL;
            ResetEventsAcknowledge AT %X13.1 : BOOL;
            // Bit 0 is reserved
            Di2 AT %X14.7 : BOOL;
            Di1 AT %X14.6 : BOOL;
            Di0 AT %X14.5 : BOOL;
            Dq1 AT %X14.4 : BOOL;
            Dq0 AT %X14.3 : BOOL;
            InternalGate AT %X14.2 : BOOL;
            Counting AT %X14.1 : BOOL;
            Direction AT %X14.0 : BOOL;
            MeasurementPulseDetected AT %X15.7 : BOOL;
            CaptureEvent AT %X15.6 : BOOL;
            SynchronizationEvent AT %X15.5 : BOOL;
            ComparisonEvent1 AT %X15.4 : BOOL;
            ComparisonEvent0 AT %X15.3 : BOOL;
            OverflowEvent AT %X15.2 : BOOL;
            UnderflowEvent AT %X15.1 : BOOL;
            ZeroPassEvent AT %X15.0 : BOOL;
        END_STRUCT;
    END_TYPE

END_NAMESPACE