USING Esab.Io;
USING Esab.Utils.Alarming;
USING Esab.Utils.Assets;

NAMESPACE Esab.WeldSystem.Flux.Standard

    CLASS FluxSystem EXTENDS Asset IMPLEMENTS IFluxSystem
        VAR PRIVATE
            _io : REF_TO Io;
            _lowLevelAlarm : IAlarm;
            _releasing : BOOL := FALSE;
            _recovering : BOOL := FALSE;
            _observable : FluxSystemObservable;
        END_VAR

        METHOD PUBLIC Setup
            VAR_INPUT
                io : REF_TO Io;
                lowLevelAlarm : IAlarm;
                setupAlarm : IAlarm;
            END_VAR

            _io := io;
            _lowLevelAlarm := lowLevelAlarm;
            _setupAlarm := setupAlarm;

            _isSetup := _io <> NULL AND _lowLevelAlarm <> NULL;
        END_METHOD

        METHOD PUBLIC OVERRIDE Execute
            SUPER.Execute();

            IF _setupAlarm.IsActive() THEN
                RETURN;
            END_IF;

            _lowLevelAlarm.Execute(_io^.Input.LowLevel.GetValue());

            THIS.UpdateObservable();
        END_METHOD

        METHOD PUBLIC OVERRIDE UpdateState
            IF _setupAlarm.IsActive() THEN
                _currentState := FluxSystemState#Error;
            ELSIF _releasing OR _recovering THEN
                _currentState := FluxSystemState#Active;
            ELSIF _lowLevelAlarm.IsActive() THEN
                _currentState := FluxSystemState#LowLevel;
            ELSE
                _currentState := FluxSystemState#Idle;
            END_IF;
        END_METHOD

        METHOD PUBLIC Release
            _io^.Output.Release.Set();
            _releasing := TRUE;
        END_METHOD

        METHOD PUBLIC Recover
            _io^.Output.Recover.Set();
            _recovering := TRUE;
        END_METHOD

        METHOD PUBLIC StopRelease
            _io^.Output.Release.Reset();
            _releasing := FALSE;
        END_METHOD

        METHOD PUBLIC StopRecover
            _io^.Output.Recover.Reset();
            _recovering := FALSE;
        END_METHOD

        METHOD PUBLIC IsReleasing : BOOL
            IsReleasing := _releasing;
        END_METHOD

        METHOD PUBLIC IsRecovering : BOOL
            IsRecovering := _recovering;
        END_METHOD

        METHOD PUBLIC LowLevel : BOOL
            LowLevel := _io^.Input.LowLevel.GetValue();
        END_METHOD

        METHOD PUBLIC OVERRIDE Observe : IAssetObservable
            Observe := _observable;
        END_METHOD

        METHOD PRIVATE UpdateObservable
            _observable.State := _currentState;
            _observable.LowLevel := THIS.LowLevel();
            _observable.Recovering := THIS.IsRecovering();
            _observable.Releasing := THIS.IsReleasing();
            _observable.Temperature := REAL#-1.0;
        END_METHOD
    END_CLASS

    CLASS FluxSystemObservable EXTENDS Esab.WeldSystem.Flux.FluxSystemObservable
        VAR PUBLIC
            LowLevel : BOOL;
        END_VAR
    END_CLASS

    TYPE
        {S7.Extern=ReadWrite}
        Io : STRUCT
            Input : Input;
            Output : Output;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        Input : STRUCT
            LowLevel : DigitalInput;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        Output : STRUCT
            Release : DigitalOutput;
            Recover : DigitalOutput;
        END_STRUCT;

        FluxSystemState : INT(
            Idle := 0,
            Error := 1,
            LowLevel := 2,
            /// Releasing and/or recovering
            Active := 3
        );
    END_TYPE

END_NAMESPACE