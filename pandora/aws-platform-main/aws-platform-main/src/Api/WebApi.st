USING Esab.Motion;
USING Esab.Io;
USING Esab.WeldSystem.PowerSources;
USING Esab.WeldSystem;
USING Esab.WeldSystem.Flux.Standard;
USING Esab.Utils.Assets;
USING Esab.WeldSystem;
USING Esab.Utils.Io;
USING Esab.Utils.Alarming;
USING Esab.WeldSystem.Flux;

USING System.EdgeDetection;

USING Siemens.Simatic.S71500.Alarming;

NAMESPACE Esab.Api

    INTERFACE IWebApi
        METHOD Execute
        END_METHOD
    END_INTERFACE

    CLASS WebApi EXTENDS Object IMPLEMENTS IWebApi, IAssetRequester, InputChangedListener, IAsyncCommandListener
        VAR PRIVATE
            _assetsManager : IAssetsManager := NULL;
            _api : REF_TO WebApiData;

            _weldSystem : IWeldSystemOrchestrator := NULL;
            _powerSource1Observable : REF_TO PowerSourceObservable := NULL;
            _powerSource2Observable : REF_TO PowerSourceObservable := NULL;

            _fluxSystem : IFluxSystem := NULL;
            _fluxSystemObservable : REF_TO Esab.WeldSystem.Flux.FluxSystemObservable := NULL;

            _horizontalAxis : Esab.Motion.IAxis := NULL;
            _horizontalAxisObservable : REF_TO Esab.Motion.AxisObservable := NULL;
            _verticalAxis : Esab.Motion.IAxis := NULL;
            _verticalAxisObservable : REF_TO Esab.Motion.AxisObservable := NULL;

            _pointLaser : Esab.Peripheral.IActivatableAsset := NULL;
            _pointLaserObservable : REF_TO Esab.Peripheral.ActivatableObservable := NULL;

            _rollerBed : Esab.Motion.IAxis := NULL;
            _rollerBedObservable : REF_TO Esab.Motion.AxisObservable := NULL;

            _pauseInputChangedListener : BOOL := FALSE;
            _asyncReadCommandPs1 : UIntAsyncCommand;
            _asyncWriteCommandPs1 : UIntAsyncCommand;
            _asyncReadCommandPs2 : UIntAsyncCommand;
            _asyncWriteCommandPs2 : UIntAsyncCommand;
        END_VAR

        METHOD PUBLIC Setup
            VAR_INPUT
                assetsManager : IAssetsManager;
                api : REF_TO WebApiData;
                setupAlarm : IAlarm;
            END_VAR

            _assetsManager := assetsManager;
            _api := api;
            _setupAlarm := setupAlarm;

            _isSetup := _assetsManager <> NULL AND _api <> NULL;

            IF _isSetup THEN
                _api^.Inputs.PowerSource1.Commands.StartWeld.Execute.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource1.Commands.StopWeld.Execute.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource1.Commands.WriteAsync.Execute.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource1.Commands.ReadAsync.Execute.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource1.Commands.LoadWeldDataSet.Execute.Input.SetChangedHandler(THIS);

                _api^.Inputs.PowerSource1.ActiveArea.WeldMethod.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource1.ActiveArea.RegulationType.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource1.ActiveArea.Voltage.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource1.ActiveArea.WireFeedSpeed.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource1.ActiveArea.Current.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource1.ActiveArea.TravelSpeed.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource1.ActiveArea.AcFrequency.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource1.ActiveArea.AcBalance.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource1.ActiveArea.AcOffset.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource1.ActiveArea.AcPhaseShift.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource1.ActiveArea.StartAdjust.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource1.ActiveArea.RegulationDynamics.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource1.ActiveArea.RegulationInductance.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource1.ActiveArea.IceWireSpeedPercentage.Input.SetChangedHandler(THIS);

                _api^.Inputs.PowerSource1.RuntimeParameters.WireFeedJogSpeed.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource1.RuntimeParameters.WireFeedJogHighSpeed.Input.SetChangedHandler(THIS);


                _api^.Inputs.PowerSource2.Commands.StartWeld.Execute.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource2.Commands.StopWeld.Execute.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource2.Commands.WriteAsync.Execute.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource2.Commands.ReadAsync.Execute.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource2.Commands.LoadWeldDataSet.Execute.Input.SetChangedHandler(THIS);

                _api^.Inputs.PowerSource2.ActiveArea.WeldMethod.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource2.ActiveArea.RegulationType.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource2.ActiveArea.Voltage.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource2.ActiveArea.WireFeedSpeed.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource2.ActiveArea.Current.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource2.ActiveArea.TravelSpeed.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource2.ActiveArea.AcFrequency.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource2.ActiveArea.AcBalance.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource2.ActiveArea.AcOffset.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource2.ActiveArea.AcPhaseShift.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource2.ActiveArea.StartAdjust.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource2.ActiveArea.RegulationDynamics.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource2.ActiveArea.RegulationInductance.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource2.ActiveArea.IceWireSpeedPercentage.Input.SetChangedHandler(THIS);

                _api^.Inputs.PowerSource2.RuntimeParameters.WireFeedJogSpeed.Input.SetChangedHandler(THIS);
                _api^.Inputs.PowerSource2.RuntimeParameters.WireFeedJogHighSpeed.Input.SetChangedHandler(THIS);

                _api^.Inputs.RollerBed.RuntimeParameters.JogSpeed.Input.SetChangedHandler(THIS);
                _api^.Inputs.RollerBed.RuntimeParameters.JogHighSpeed.Input.SetChangedHandler(THIS);
                _api^.Inputs.RollerBed.RuntimeParameters.ObjectRadius.Input.SetChangedHandler(THIS);
                _api^.Inputs.RollerBed.HardwareConfiguration.MaximumSpeed.Input.SetChangedHandler(THIS);

                _asyncReadCommandPs1.SetListener(THIS);
                _asyncWriteCommandPs1.SetListener(THIS);
                _asyncReadCommandPs2.SetListener(THIS);
                _asyncWriteCommandPs2.SetListener(THIS);
            END_IF;
        END_METHOD

        METHOD PUBLIC OVERRIDE Execute
            SUPER.Execute();

            IF _setupAlarm.IsActive() THEN
                RETURN;
            END_IF;

            IF _powerSource1Observable = NULL THEN
                _powerSource1Observable ?= _assetsManager.ObserveAsset(AssetIdentifier#PowerSource1);
            END_IF;

            IF _powerSource2Observable = NULL THEN
                _powerSource2Observable ?= _assetsManager.ObserveAsset(AssetIdentifier#PowerSource2);
            END_IF;

            IF _fluxSystemObservable = NULL THEN
                _fluxSystemObservable ?= _assetsManager.ObserveAsset(AssetIdentifier#FluxSystem);
            END_IF;

            IF _horizontalAxisObservable = NULL THEN
                _horizontalAxisObservable ?= _assetsManager.ObserveAsset(AssetIdentifier#HorizontalSlideAxis);
            END_IF;

            IF _verticalAxisObservable = NULL THEN
                _verticalAxisObservable ?= _assetsManager.ObserveAsset(AssetIdentifier#VerticalSlideAxis);
            END_IF;

            IF _pointLaserObservable = NULL THEN
                _pointLaserObservable ?= _assetsManager.ObserveAsset(AssetIdentifier#PointLaser);
            END_IF;

            IF _rollerBedObservable = NULL THEN
                _rollerBedObservable ?= _assetsManager.ObserveAsset(AssetIdentifier#RollerBed);
            END_IF;

            _api^.Outputs.PowerSource1.Valid.Output.SetValue(_powerSource1Observable <> NULL);

            IF _powerSource1Observable <> NULL THEN
                _api^.Outputs.PowerSource1.Status.State.Output.SetValue(TO_UINT(_powerSource1Observable^.State));
                _api^.Outputs.PowerSource1.Status.ReadyToWeld.Output.SetValue(_powerSource1Observable^.ReadyToStart);
                _api^.Outputs.PowerSource1.Status.Welding.Output.SetValue(_powerSource1Observable^.Welding);
                _api^.Outputs.PowerSource1.Status.Error.Output.SetValue(_powerSource1Observable^.Error);
                _api^.Outputs.PowerSource1.Status.Connected.Output.SetValue(_powerSource1Observable^.Connected);
                _api^.Outputs.PowerSource1.Status.WeldMethod.Output.SetValue(_powerSource1Observable^.WeldMethod);
                _api^.Outputs.PowerSource1.Status.MeasuredVoltage.Output.SetValue(_powerSource1Observable^.MeasuredVoltage);
                _api^.Outputs.PowerSource1.Status.MeasuredCurrent.Output.SetValue(_powerSource1Observable^.MeasuredCurrent);
                _api^.Outputs.PowerSource1.Status.MeasuredHeatInput.Output.SetValue(_powerSource1Observable^.MeasuredHeatInput);
                _api^.Outputs.PowerSource1.Status.MeasuredWireSpeed.Output.SetValue(_powerSource1Observable^.MeasuredWireSpeed);
                _api^.Outputs.PowerSource1.Status.MeasuredTravelSpeed.Output.SetValue(_powerSource1Observable^.MeasuredTravelSpeed);
                _api^.Outputs.PowerSource1.Status.RequestedWireSpeed.Output.SetValue(_powerSource1Observable^.RequestedWireSpeed);
                _api^.Outputs.PowerSource1.Status.RequestedTravelSpeed.Output.SetValue(_powerSource1Observable^.RequestedTravelSpeed);
            END_IF;

            _api^.Outputs.PowerSource2.Valid.Output.SetValue(_powerSource2Observable <> NULL);

            IF _powerSource2Observable <> NULL THEN
                _api^.Outputs.PowerSource2.Status.State.Output.SetValue(TO_UINT(_powerSource2Observable^.State));
                _api^.Outputs.PowerSource2.Status.ReadyToWeld.Output.SetValue(_powerSource2Observable^.ReadyToStart);
                _api^.Outputs.PowerSource2.Status.Welding.Output.SetValue(_powerSource2Observable^.Welding);
                _api^.Outputs.PowerSource2.Status.Error.Output.SetValue(_powerSource2Observable^.Error);
                _api^.Outputs.PowerSource2.Status.Connected.Output.SetValue(_powerSource2Observable^.Connected);
                _api^.Outputs.PowerSource2.Status.WeldMethod.Output.SetValue(_powerSource2Observable^.WeldMethod);
                _api^.Outputs.PowerSource2.Status.MeasuredVoltage.Output.SetValue(_powerSource2Observable^.MeasuredVoltage);
                _api^.Outputs.PowerSource2.Status.MeasuredCurrent.Output.SetValue(_powerSource2Observable^.MeasuredCurrent);
                _api^.Outputs.PowerSource2.Status.MeasuredHeatInput.Output.SetValue(_powerSource2Observable^.MeasuredHeatInput);
                _api^.Outputs.PowerSource2.Status.MeasuredWireSpeed.Output.SetValue(_powerSource2Observable^.MeasuredWireSpeed);
                _api^.Outputs.PowerSource2.Status.MeasuredTravelSpeed.Output.SetValue(_powerSource2Observable^.MeasuredTravelSpeed);
                _api^.Outputs.PowerSource2.Status.RequestedWireSpeed.Output.SetValue(_powerSource2Observable^.RequestedWireSpeed);
                _api^.Outputs.PowerSource2.Status.RequestedTravelSpeed.Output.SetValue(_powerSource2Observable^.RequestedTravelSpeed);
            END_IF;

            _api^.Outputs.FluxSystem.Valid.Output.SetValue(_fluxSystemObservable <> NULL);
            _api^.Outputs.HorizontalSlide.Valid.Output.SetValue(_horizontalAxisObservable <> NULL);
            _api^.Outputs.VerticalSlide.Valid.Output.SetValue(_verticalAxisObservable <> NULL);
            _api^.Outputs.PointLaser.Valid.Output.SetValue(_pointLaserObservable <> NULL);
            _api^.Outputs.RollerBed.Valid.Output.SetValue(_rollerBedObservable <> NULL);

            IF _rollerBedObservable <> NULL THEN
                _api^.Outputs.RollerBed.Status.State.Output.SetValue(_rollerBedObservable^.State);
                _api^.Outputs.RollerBed.Status.Enabled.Output.SetValue(_rollerBedObservable^.Enabled);
                _api^.Outputs.RollerBed.Status.Velocity.Output.SetValue(TO_REAL(_rollerBedObservable^.LinearVelocity));
                _api^.Outputs.RollerBed.Status.ObjectPosition.Output.SetValue(TO_REAL(_rollerBedObservable^.AngularPosition));
                _api^.Outputs.RollerBed.Status.LinearPosition.Output.SetValue(TO_REAL(_rollerBedObservable^.LinearPosition));
                _api^.Outputs.RollerBed.Status.ObjectRadius.Output.SetValue(TO_REAL(_rollerBedObservable^.ObjectRadius));
            END_IF;

            // Horizontal axis: request on demand and lock only while executing a command
            THIS.HandleHorizontalAxis();

            // Vertical axis: request on demand and lock only while executing a command
            THIS.HandleVerticalAxis();

            THIS.HandleFluxSystem();
            THIS.HandlePointLaser();

        END_METHOD

        METHOD PUBLIC AssetAssigned
            VAR_INPUT
                asset : REF_TO Asset;
            END_VAR

            ;
        END_METHOD

        METHOD PUBLIC AssetRemoved
            VAR_INPUT
                identifier : INT;
            END_VAR

            CASE identifier OF
                AssetIdentifier#HorizontalSlideAxis:
                    _horizontalAxis := NULL;
                AssetIdentifier#VerticalSlideAxis:
                    _verticalAxis := NULL;
            END_CASE;
        END_METHOD

        METHOD PUBLIC AsyncCommandCallback
            VAR_INPUT
                command : REF_TO AsyncCommand;
                status : CommandStatus;
            END_VAR
            VAR_TEMP
                uintCommand : REF_TO UIntAsyncCommand;
            END_VAR
            IF command = NULL THEN
                RETURN;
            END_IF;

            uintCommand ?= command;
            IF uintCommand = NULL THEN
                RETURN;
            END_IF;

            IF uintCommand = REF(_asyncReadCommandPs1) THEN
                IF status = CommandStatus#Error THEN
                    _api^.Outputs.PowerSource1.Commands.ReadAsync.ErrorCode.Value := UINT#2;
                ELSE
                    _api^.Outputs.PowerSource1.Commands.ReadAsync.Value.Value := uintCommand^.Value;
                    _api^.Outputs.PowerSource1.Commands.ReadAsync.ErrorCode.Value := UINT#0;
                END_IF;
                _api^.Outputs.PowerSource1.Commands.ReadAsync.Busy.Value := FALSE;
                RETURN;
            END_IF;

            IF uintCommand = REF(_asyncReadCommandPs2) THEN
                IF status = CommandStatus#Error THEN
                    _api^.Outputs.PowerSource2.Commands.ReadAsync.ErrorCode.Value := UINT#2;
                ELSE
                    _api^.Outputs.PowerSource2.Commands.ReadAsync.ErrorCode.Value := UINT#0;
                    _api^.Outputs.PowerSource2.Commands.ReadAsync.Value.Value := uintCommand^.Value;
                END_IF;
                    _api^.Outputs.PowerSource2.Commands.ReadAsync.Busy.Value := FALSE;
                RETURN;
            END_IF;

            IF uintCommand = REF(_asyncWriteCommandPs1) THEN
                IF status = CommandStatus#Error THEN
                    _api^.Outputs.PowerSource1.Commands.WriteAsync.ErrorCode.Value := UINT#2;
                ELSE
                    _api^.Outputs.PowerSource1.Commands.WriteAsync.ErrorCode.Value := UINT#0;
                END_IF;
                _api^.Outputs.PowerSource1.Commands.WriteAsync.Busy.Value := FALSE;
                RETURN;
            END_IF;

            IF uintCommand = REF(_asyncWriteCommandPs2) THEN
                IF status = CommandStatus#Error THEN
                    _api^.Outputs.PowerSource2.Commands.WriteAsync.ErrorCode.Value := UINT#2;
                ELSE
                    _api^.Outputs.PowerSource2.Commands.WriteAsync.ErrorCode.Value := UINT#0;
                END_IF;
                _api^.Outputs.PowerSource2.Commands.WriteAsync.Busy.Value := FALSE;

                RETURN;
            END_IF;
        END_METHOD

        METHOD PRIVATE RequestHorizontalAxisControl : BOOL
            VAR_TEMP
                asset : REF_TO Asset;
            END_VAR

            IF _horizontalAxis = NULL THEN
                asset := _assetsManager.RequestAssetHandle(THIS, AssetIdentifier#HorizontalSlideAxis);

                IF asset <> NULL THEN
                    // Bind the axis interface
                    _horizontalAxis ?= asset^;

                    RequestHorizontalAxisControl := _horizontalAxis <> NULL;
                    RETURN;
                END_IF;
            END_IF;

            RequestHorizontalAxisControl := FALSE;
        END_METHOD

        METHOD PRIVATE RequestVerticalAxisControl : BOOL
            VAR_TEMP
                asset : REF_TO Asset;
            END_VAR

            IF _verticalAxis = NULL THEN
                asset := _assetsManager.RequestAssetHandle(THIS, AssetIdentifier#VerticalSlideAxis);

                IF asset <> NULL THEN
                    _verticalAxis ?= asset^;

                    RequestVerticalAxisControl := _verticalAxis <> NULL;
                    RETURN;
                END_IF;
            END_IF;

            RequestVerticalAxisControl := FALSE;
        END_METHOD

        METHOD PRIVATE RequestRollerBed
            VAR_TEMP
                asset : REF_TO Asset;
            END_VAR

            IF _rollerBed = NULL THEN
                asset := _assetsManager.RequestAssetHandle(THIS, AssetIdentifier#RollerBed);

                IF asset <> NULL THEN
                    _rollerBed ?= asset^;
                END_IF;
            END_IF;
        END_METHOD

        METHOD PRIVATE HandleHorizontalAxis
            VAR_TEMP
                busyNow : BOOL := FALSE;
                positioningCommand : Esab.Motion.AxisPositioningCommand;
                homingCommand : Esab.Motion.AxisHomingCommand;
                asset : IAsset := NULL;
            END_VAR

            IF _api^.Inputs.HorizontalSlide.Commands.Enable.Execute.Input.RisingEdge() THEN
                THIS.RequestHorizontalAxisControl();

                IF _horizontalAxis <> NULL THEN
                    busyNow := TRUE;
                    asset ?= _horizontalAxis;
                    asset.Lock();
                    _horizontalAxis.PowerOn();
                END_IF;

                _api^.Inputs.HorizontalSlide.Commands.Enable.Execute.Value := FALSE;
            ELSIF _api^.Inputs.HorizontalSlide.Commands.Disable.Execute.Input.RisingEdge() THEN
                THIS.RequestHorizontalAxisControl();

                IF _horizontalAxis <> NULL THEN
                    busyNow := TRUE;
                    asset ?= _horizontalAxis;
                    asset.Lock();
                    _horizontalAxis.PowerOff();
                END_IF;

                _api^.Inputs.HorizontalSlide.Commands.Disable.Execute.Value := FALSE;
            ELSIF _api^.Inputs.HorizontalSlide.Commands.Positioning.Execute.Input.RisingEdge() THEN
                THIS.RequestHorizontalAxisControl();

                IF _horizontalAxis <> NULL THEN
                    busyNow := TRUE;
                    asset ?= _horizontalAxis;
                    asset.Lock();

                    positioningCommand.CommandType := TO_INT(_api^.Inputs.HorizontalSlide.Commands.Positioning.CommandType.Input.GetValue());
                    positioningCommand.Velocity := _api^.Inputs.HorizontalSlide.Commands.Positioning.Velocity.Input.GetValue();
                    positioningCommand.Position := _api^.Inputs.HorizontalSlide.Commands.Positioning.Position.Input.GetValue();
                    positioningCommand.Acceleration := _api^.Inputs.HorizontalSlide.Commands.Positioning.Acceleration.Input.GetValue();
                    positioningCommand.Deceleration := _api^.Inputs.HorizontalSlide.Commands.Positioning.Deceleration.Input.GetValue();
                    positioningCommand.Jerk := _api^.Inputs.HorizontalSlide.Commands.Positioning.Jerk.Input.GetValue();

                    _horizontalAxis.ExecutePositioningCommand(positioningCommand);
                END_IF;

                _api^.Inputs.HorizontalSlide.Commands.Positioning.Execute.Value := FALSE;
            ELSIF _api^.Inputs.HorizontalSlide.Commands.Homing.Execute.Input.RisingEdge() THEN
                THIS.RequestHorizontalAxisControl();

                IF _horizontalAxis <> NULL THEN
                    busyNow := TRUE;
                    asset ?= _horizontalAxis;
                    asset.Lock();

                    homingCommand.HomingType := TO_INT(_api^.Inputs.HorizontalSlide.Commands.Homing.HomingType.Input.GetValue());
                    homingCommand.Position := _api^.Inputs.HorizontalSlide.Commands.Homing.Position.Input.GetValue();

                    _horizontalAxis.ExecuteHomingCommand(homingCommand);
                END_IF;

                _api^.Inputs.HorizontalSlide.Commands.Homing.Execute.Value := FALSE;
            END_IF;

            IF _horizontalAxis <> NULL THEN
                busyNow := busyNow OR _horizontalAxis.IsBusy();

                IF NOT busyNow THEN
                    asset ?= _horizontalAxis;
                    asset.Unlock();
                END_IF;
            END_IF;

            IF _horizontalAxisObservable <> NULL THEN
                _api^.Outputs.HorizontalSlide.Status.Enabled.Output.SetValue(_horizontalAxisObservable^.Enabled);
                _api^.Outputs.HorizontalSlide.Status.Homed.Output.SetValue(_horizontalAxisObservable^.Homed);
                _api^.Outputs.HorizontalSlide.Status.Error.Output.SetValue(_horizontalAxisObservable^.Error);
                _api^.Outputs.HorizontalSlide.Status.Busy.Output.SetValue(_horizontalAxisObservable^.Busy);
                _api^.Outputs.HorizontalSlide.Status.Position.Output.SetValue(TO_REAL(_horizontalAxisObservable^.LinearPosition));
                _api^.Outputs.HorizontalSlide.Status.Velocity.Output.SetValue(TO_REAL(_horizontalAxisObservable^.LinearVelocity));
            END_IF;
        END_METHOD

        METHOD PRIVATE RequestPowerSource : IPowerSource
            VAR_INPUT
                id : INT;
            END_VAR

            VAR_TEMP
                asset : REF_TO Asset;
                identifier : Esab.AssetIdentifier;
            END_VAR

            CASE id OF
                1 :
                    identifier := Esab.AssetIdentifier#PowerSource1;
                2 :
                    identifier := Esab.AssetIdentifier#PowerSource2;
            ELSE
                RETURN;
            END_CASE;

            asset := _assetsManager.RequestAssetHandle(THIS, identifier);
            IF asset <> NULL THEN
                RequestPowerSource ?= asset^;
            ELSE
                RequestPowerSource := NULL;
            END_IF;
        END_METHOD

        METHOD PRIVATE HandleVerticalAxis
            VAR_TEMP
                busyNow : BOOL := FALSE;
                positioningCommand : Esab.Motion.AxisPositioningCommand;
                homingCommand : Esab.Motion.AxisHomingCommand;
                asset : IAsset := NULL;
            END_VAR

            IF _api^.Inputs.VerticalSlide.Commands.Enable.Execute.Input.RisingEdge() THEN
                THIS.RequestVerticalAxisControl();

                IF _verticalAxis <> NULL THEN
                    busyNow := TRUE;
                    asset ?= _verticalAxis;
                    asset.Lock();
                    _verticalAxis.PowerOn();
                END_IF;

                _api^.Inputs.VerticalSlide.Commands.Enable.Execute.Value := FALSE;
            ELSIF _api^.Inputs.VerticalSlide.Commands.Disable.Execute.Input.RisingEdge() THEN
                THIS.RequestVerticalAxisControl();

                IF _verticalAxis <> NULL THEN
                    busyNow := TRUE;
                    asset ?= _verticalAxis;
                    asset.Lock();
                    _verticalAxis.PowerOff();
                END_IF;

                _api^.Inputs.VerticalSlide.Commands.Disable.Execute.Value := FALSE;
            ELSIF _api^.Inputs.VerticalSlide.Commands.Positioning.Execute.Input.RisingEdge() THEN
                THIS.RequestVerticalAxisControl();

                IF _verticalAxis <> NULL THEN
                    busyNow := TRUE;
                    asset ?= _verticalAxis;
                    asset.Lock();

                    positioningCommand.CommandType := TO_INT(_api^.Inputs.VerticalSlide.Commands.Positioning.CommandType.Input.GetValue());
                    positioningCommand.Velocity := _api^.Inputs.VerticalSlide.Commands.Positioning.Velocity.Input.GetValue();
                    positioningCommand.Position := _api^.Inputs.VerticalSlide.Commands.Positioning.Position.Input.GetValue();
                    positioningCommand.Acceleration := _api^.Inputs.VerticalSlide.Commands.Positioning.Acceleration.Input.GetValue();
                    positioningCommand.Deceleration := _api^.Inputs.VerticalSlide.Commands.Positioning.Deceleration.Input.GetValue();
                    positioningCommand.Jerk := _api^.Inputs.VerticalSlide.Commands.Positioning.Jerk.Input.GetValue();

                    _verticalAxis.ExecutePositioningCommand(positioningCommand);
                END_IF;

                _api^.Inputs.VerticalSlide.Commands.Positioning.Execute.Value := FALSE;
            ELSIF _api^.Inputs.VerticalSlide.Commands.Homing.Execute.Input.RisingEdge() THEN
                THIS.RequestVerticalAxisControl();

                IF _verticalAxis <> NULL THEN
                    busyNow := TRUE;
                    asset ?= _verticalAxis;
                    asset.Lock();

                    homingCommand.HomingType := TO_INT(_api^.Inputs.VerticalSlide.Commands.Homing.HomingType.Input.GetValue());
                    homingCommand.Position := _api^.Inputs.VerticalSlide.Commands.Homing.Position.Input.GetValue();

                    _verticalAxis.ExecuteHomingCommand(homingCommand);
                END_IF;

                _api^.Inputs.VerticalSlide.Commands.Homing.Execute.Value := FALSE;
            END_IF;

            IF _verticalAxis <> NULL THEN
                busyNow := busyNow OR _verticalAxis.IsBusy();

                IF NOT busyNow THEN
                    asset ?= _verticalAxis;
                    asset.Unlock();
                END_IF;
            END_IF;

            IF _verticalAxisObservable <> NULL THEN
                _api^.Outputs.VerticalSlide.Status.Enabled.Output.SetValue(_verticalAxisObservable^.Enabled);
                _api^.Outputs.VerticalSlide.Status.Homed.Output.SetValue(_verticalAxisObservable^.Homed);
                _api^.Outputs.VerticalSlide.Status.Error.Output.SetValue(_verticalAxisObservable^.Error);
                _api^.Outputs.VerticalSlide.Status.Busy.Output.SetValue(_verticalAxisObservable^.Busy);
                _api^.Outputs.VerticalSlide.Status.Position.Output.SetValue(TO_REAL(_verticalAxisObservable^.LinearPosition));
                _api^.Outputs.VerticalSlide.Status.Velocity.Output.SetValue(TO_REAL(_verticalAxisObservable^.LinearVelocity));
            END_IF;
        END_METHOD

        METHOD PRIVATE HandleFluxSystem
            VAR_TEMP
                willUse: BOOL;
                asset : REF_TO Asset;
            END_VAR;

            IF _fluxSystemObservable <> NULL THEN
                _api^.Outputs.FluxSystem.Status.IsRecovering.Output.SetValue(_fluxSystemObservable^.Recovering);
                _api^.Outputs.FluxSystem.Status.IsReleasing.Output.SetValue(_fluxSystemObservable^.Releasing);
                _api^.Outputs.FluxSystem.Status.Temperature.Output.SetValue(_fluxSystemObservable^.Temperature);
            END_IF;

            willUse := _api^.Inputs.FluxSystem.Commands.Recover.Execute.Input.GetValue() OR
                        _api^.Inputs.FluxSystem.Commands.Release.Execute.Input.GetValue() OR
                        _api^.Inputs.FluxSystem.Commands.StopRecover.Execute.Input.GetValue() OR
                        _api^.Inputs.FluxSystem.Commands.StopRelease.Execute.Input.GetValue();

            IF NOT willUse THEN
                RETURN;
            END_IF;

            asset := _assetsManager.RequestAssetHandle(THIS, AssetIdentifier#FluxSystem);
            IF asset = NULL THEN
                RETURN;
            END_IF;

            _fluxSystem ?= asset^;
            asset^.Lock();

            IF _api^.Inputs.FluxSystem.Commands.Recover.Execute.Input.GetValue() THEN
                _fluxSystem.Recover();
                _api^.Inputs.FluxSystem.Commands.Recover.Execute.Read(FALSE);
            END_IF;

            IF _api^.Inputs.FluxSystem.Commands.Release.Execute.Input.GetValue() THEN
                _fluxSystem.Release();
                _api^.Inputs.FluxSystem.Commands.Release.Execute.Read(FALSE);
            END_IF;

            IF _api^.Inputs.FluxSystem.Commands.StopRecover.Execute.Input.GetValue() THEN
                _fluxSystem.StopRecover();
                _api^.Inputs.FluxSystem.Commands.StopRecover.Execute.Read(FALSE);
            END_IF;

            IF _api^.Inputs.FluxSystem.Commands.StopRelease.Execute.Input.GetValue() THEN
                _fluxSystem.StopRelease();
                _api^.Inputs.FluxSystem.Commands.StopRelease.Execute.Read(FALSE);
            END_IF;

            _fluxSystem := NULL;
            asset^.Unlock();
        END_METHOD

        METHOD PRIVATE HandlePointLaser
            VAR_TEMP
                willUse: BOOL;
                asset : REF_TO Asset;
            END_VAR;

            IF _pointLaserObservable <> NULL THEN
                _api^.Outputs.PointLaser.Status.Active.Output.SetValue(_pointLaserObservable^.Active);
            END_IF;


            IF _api^.Inputs.PointLaser.Commands.Activate.Execute.Input.GetValue() THEN
                _api^.Inputs.PointLaser.Commands.Activate.Execute.Read(FALSE);

                asset := _assetsManager.RequestAssetHandle(THIS, AssetIdentifier#PointLaser);

                IF asset <> NULL THEN
                    _pointLaser ?= asset^;
                    _pointLaser.Activate();
                END_IF;
            END_IF;

            IF _api^.Inputs.PointLaser.Commands.Deactivate.Execute.Input.GetValue() THEN
                _api^.Inputs.PointLaser.Commands.Deactivate.Execute.Read(FALSE);

                asset := _assetsManager.RequestAssetHandle(THIS, AssetIdentifier#PointLaser);

                IF asset <> NULL THEN
                    _pointLaser ?= asset^;
                    _pointLaser.Deactivate();
                END_IF;
            END_IF;

            _pointLaser := NULL;
        END_METHOD

        METHOD PRIVATE HandleInputChanged
            VAR_INPUT
                input : REF_TO Esab.Io.Input;
            END_VAR

            VAR_TEMP
                powerSource : IPowerSource := NULL;
                index : INT := 1;
                commands : REF_TO PowerSourceCommandsInputs := NULL;
                commandsOut : REF_TO PowerSourceCommandsOutputs := NULL;
                activeArea : REF_TO PowerSourceParameters := NULL;
                weldDataSet : REF_TO PowerSourceParameters := NULL;
                runtimeParameters : REF_TO PowerSourceRuntimeParameters := NULL;
                hardwareConfiguration : REF_TO PowerSourceHardwareConfiguration := NULL;
                asyncReadCommand : REF_TO UIntAsyncCommand := NULL;
                asyncWriteCommand : REF_TO UIntAsyncCommand := NULL;
                asyncReadOut : REF_TO PowerSourceReadAsyncOutput := NULL;
                commandOutput : REF_TO CommandOutputs := NULL;
            END_VAR

            // NOTE: We need to temporarily pause the input changed listener to not cause infinite recursion when
            // writing back the values!

            FOR index := 1 TO 2 DO
                CASE index OF
                    1:
                        commands := REF(_api^.Inputs.PowerSource1.Commands);
                        commandsOut := REF(_api^.Outputs.PowerSource1.Commands);
                        activeArea := REF(_api^.Inputs.PowerSource1.ActiveArea);
                        weldDataSet := REF(_api^.Inputs.PowerSource1.WeldDataSet);
                        runtimeParameters := REF(_api^.Inputs.PowerSource1.RuntimeParameters);
                        hardwareConfiguration := REF(_api^.Inputs.PowerSource1.HardwareConfiguration);
                        asyncReadOut := REF(_api^.Outputs.PowerSource1.Commands.ReadAsync);
                        asyncReadCommand := REF(_asyncReadCommandPs1);
                        asyncWriteCommand := REF(_asyncWriteCommandPs1);
                    2:
                        commands := REF(_api^.Inputs.PowerSource2.Commands);
                        commandsOut := REF(_api^.Outputs.PowerSource2.Commands);
                        activeArea := REF(_api^.Inputs.PowerSource2.ActiveArea);
                        weldDataSet := REF(_api^.Inputs.PowerSource2.WeldDataSet);
                        runtimeParameters := REF(_api^.Inputs.PowerSource2.RuntimeParameters);
                        hardwareConfiguration := REF(_api^.Inputs.PowerSource2.HardwareConfiguration);
                        asyncReadOut := REF(_api^.Outputs.PowerSource2.Commands.ReadAsync);
                        asyncReadCommand := REF(_asyncReadCommandPs2);
                        asyncWriteCommand := REF(_asyncWriteCommandPs2);
                END_CASE;

                powerSource := THIS.RequestPowerSource(index);

                IF input = REF(commands^.StartWeld.Execute.Input) THEN
                    commandOutput := REF(commandsOut^.StartWeld);
                    commandOutput^.Executed.Output.SetValue(commands^.StartWeld.Execute.Input.GetValue());
                    IF commands^.StartWeld.Execute.Input.RisingEdge() THEN
                        IF powerSource <> NULL THEN
                            powerSource.Start();
                            commandOutput^.ErrorCode.Output.SetValue(UINT#0);
                        ELSE;
                            commandOutput^.ErrorCode.Output.SetValue(UINT#1); // Asset not found error
                        END_IF;
                    END_IF;
                    RETURN;
                END_IF;

                IF input = REF(commands^.StopWeld.Execute.Input) THEN
                    commandOutput := REF(commandsOut^.StopWeld);
                    commandOutput^.Executed.Output.SetValue(commands^.StopWeld.Execute.Input.GetValue());
                    IF commands^.StopWeld.Execute.Input.RisingEdge() THEN
                        IF powerSource <> NULL THEN
                            powerSource.Stop();
                            commandOutput^.ErrorCode.Output.SetValue(UINT#0);
                        ELSE;
                            commandOutput^.ErrorCode.Output.SetValue(UINT#1);
                        END_IF;
                    END_IF;
                    RETURN;
                END_IF;

                IF input = REF(commands^.WriteAsync.Execute.Input) THEN
                    commandOutput := REF(commandsOut^.WriteAsync);
                    commandOutput^.Executed.Output.SetValue(commands^.WriteAsync.Execute.Input.GetValue());
                    IF commands^.WriteAsync.Execute.Input.RisingEdge() THEN
                        IF powerSource = NULL THEN
                            commandOutput^.ErrorCode.Output.SetValue(UINT#1);
                            commandOutput^.Busy.Output.Reset();
                            RETURN;
                        END_IF;

                        commandOutput^.Busy.Output.Set();
                        asyncWriteCommand^.Index := commands^.WriteAsync.Index.Value;
                        asyncWriteCommand^.Value := commands^.WriteAsync.Value.Value;
                        powerSource.WriteAsync(asyncWriteCommand);
                    END_IF;
                    RETURN;
                END_IF;

                IF input = REF(commands^.ReadAsync.Execute.Input) THEN
                    asyncReadOut := REF(commandsOut^.ReadAsync);
                    asyncReadOut^.Executed.Value := commands^.ReadAsync.Execute.Input.GetValue();
                    IF commands^.ReadAsync.Execute.Input.RisingEdge() THEN
                        asyncReadOut^.Value.Value := UINT#0;
                        IF powerSource = NULL THEN
                            asyncReadOut^.ErrorCode.Output.SetValue(UINT#1);
                            asyncReadOut^.Busy.Output.Reset();
                            RETURN;
                        END_IF;
                        asyncReadOut^.Busy.Value := TRUE;
                        asyncReadCommand^.Index := commands^.ReadAsync.Index.Value;
                        powerSource.ReadAsync(asyncReadCommand);
                    END_IF;
                    RETURN;
                END_IF;

                IF input = REF(commands^.LoadWeldDataSet.Execute.Input) THEN
                    commandOutput := REF(commandsOut^.LoadWeldDataSet);
                    commandOutput^.Executed.Output.SetValue(commands^.LoadWeldDataSet.Execute.Input.GetValue());

                    IF powerSource = NULL THEN
                        commandOutput^.ErrorCode.Output.SetValue(UINT#1);
                        RETURN;
                    END_IF;

                    IF commands^.LoadWeldDataSet.Execute.Input.RisingEdge() THEN
                        powerSource.PassiveArea()^.Voltage := weldDataSet^.Voltage.Value;
                        powerSource.PassiveArea()^.Current := weldDataSet^.Current.Value;
                        powerSource.PassiveArea()^.WireSpeed := weldDataSet^.WireFeedSpeed.Value;
                        powerSource.PassiveArea()^.AcFrequency := weldDataSet^.AcFrequency.Value;
                        powerSource.PassiveArea()^.AcBalance := weldDataSet^.AcBalance.Value;
                        powerSource.PassiveArea()^.AcOffset := weldDataSet^.AcOffset.Value;
                        powerSource.PassiveArea()^.AcPhaseShift := weldDataSet^.AcPhaseShift.Value;
                        powerSource.PassiveArea()^.WeldMethod := TO_BYTE(weldDataSet^.WeldMethod.Value);
                        powerSource.PassiveArea()^.RegulationType := TO_BYTE(weldDataSet^.RegulationType.Value);
                        powerSource.PassiveArea()^.RegulationInductance := weldDataSet^.RegulationInductance.Value;
                        powerSource.PassiveArea()^.RegulationDynamics := weldDataSet^.RegulationDynamics.Value;

                        powerSource.SwitchActivePassive();
                    END_IF;

                ELSIF input = REF(runtimeParameters^.WireFeedJogSpeed.Input) THEN
                    IF powerSource <> NULL THEN
                        powerSource.SetWireFeedJogSpeed(runtimeParameters^.WireFeedJogSpeed.Input.GetValue());
                    ELSE
                        ; // TODO: Write back actual value to API
                    END_IF;
                ELSIF input = REF(runtimeParameters^.WireFeedJogHighSpeed.Input) THEN
                    IF powerSource <> NULL THEN
                        powerSource.SetWireFeedJogHighSpeed(runtimeParameters^.WireFeedJogHighSpeed.Input.GetValue());
                    ELSE
                        ; // TODO: Write back actual value to API
                    END_IF;
                END_IF;
            END_FOR;

            IF input = REF(_api^.Inputs.RollerBed.RuntimeParameters.JogSpeed.Input) THEN
                THIS.RequestRollerBed();

                IF _rollerBed <> NULL THEN
                    _rollerBed.SetJogSpeed(_api^.Inputs.RollerBed.RuntimeParameters.JogSpeed.Input.GetValue());
                ELSE
                    ;
                END_IF;
            ELSIF input = REF(_api^.Inputs.RollerBed.RuntimeParameters.JogHighSpeed.Input) THEN
                THIS.RequestRollerBed();

                IF _rollerBed <> NULL THEN
                    _rollerBed.SetJogHighSpeed(_api^.Inputs.RollerBed.RuntimeParameters.JogHighSpeed.Input.GetValue());
                ELSE
                    ;
                END_IF;
            ELSIF input = REF(_api^.Inputs.RollerBed.RuntimeParameters.ObjectRadius.Input) THEN
                THIS.RequestRollerBed();

                IF _rollerBed <> NULL THEN
                    _rollerBed.SetObjectRadius(_api^.Inputs.RollerBed.RuntimeParameters.ObjectRadius.Input.GetValue());
                ELSE
                    ;
                END_IF;
            END_IF;
        END_METHOD

        METHOD PUBLIC InputChanged
            VAR_INPUT
                input : REF_TO Esab.Io.Input;
            END_VAR

            IF _pauseInputChangedListener THEN
                RETURN;
            END_IF;

            // NOTE: Prevent recurrsive calls
            _pauseInputChangedListener := TRUE;
            THIS.HandleInputChanged(input);
            _pauseInputChangedListener := FALSE;
        END_METHOD
    END_CLASS

    TYPE
        {S7.Extern=ReadWrite}
        WebApiData : STRUCT
            Inputs : Inputs;
            Outputs : Outputs;
        END_STRUCT;

        // --- Interface struct declarations
        {S7.Extern=ReadWrite}
        Inputs : STRUCT
            HorizontalSlide : PositioningAxisInputs;
            VerticalSlide : PositioningAxisInputs;
            PowerSource1 : PowerSourceInputs;
            PowerSource2 : PowerSourceInputs;
            FluxSystem : FluxSystemInputs;
            PointLaser : PointLaserInputs;
            RollerBed : RollerBedInputs;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        Outputs : STRUCT
            HorizontalSlide : PositioningAxisOutputs;
            VerticalSlide : PositioningAxisOutputs;
            PowerSource1 : PowerSourceOutputs;
            PowerSource2 : PowerSourceOutputs;
            FluxSystem : FluxSystemOutputs;
            PointLaser : PointLaserOutputs;
            RollerBed : RollerBedOutputs;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        PositioningAxisInputs : STRUCT
            /// Axis commands
            Commands : PositioningAxisCommandsInput;
            /// Runtime parameters
            Parameters : PositioningAxisParameters;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        PositioningAxisOutputs : STRUCT
            /// The output of this axis is valid
            Valid : DigitalOutputGroup;
            Commands : PositioningAxisCommandsOutputs;
            /// Axis status
            Status : PositioningAxisStatus;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        PositioningAxisCommandsInput : STRUCT
            /// Enables the axis
            Enable : CommandInputs;
            /// Disables the axis
            Disable : CommandInputs;
            /// Will send a halt command to the axis
            Halt : CommandInputs;
            /// Jogs the axis in the positive direction (only while the value is TRUE)
            JogPositive : CommandInputs;
            /// Jogs the axis in the positive direction (only while the value is TRUE)
            JogNegative : CommandInputs;
            /// The positioning command executed by the "Execute" command
            Positioning : PositioningCommand;
            /// The homing command executed by the "ExecuteHoming" command
            Homing : HomingCommand;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        PositioningAxisCommandsOutputs : STRUCT
            Enable : CommandOutputs;
            Disable : CommandOutputs;
            Halt : CommandOutputs;
            JogPositive : CommandOutputs;
            JogNegative : CommandOutputs;
            Positioning : CommandOutputs;
            Homing : CommandOutputs;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        PositioningAxisParameters : STRUCT
            /// Speed used when jogging this axis
            JogSpeed : RealInputGroup := (Input := (Endianness := Endianness#Big, Scale := REAL#1.0));
            JogHighSpeed : RealInputGroup := (Input := (Endianness := Endianness#Big, Scale := REAL#1.0));
        END_STRUCT;

        {S7.Extern=ReadWrite}
        PositioningAxisStatus : STRUCT
            /// TRUE if the axis is enabled
            Enabled : DigitalOutputGroup;
            /// TRUE if the axis is experiencing an error
            Error : DigitalOutputGroup;
            /// TRUE if the axis is homed
            Homed : DigitalOutputGroup;
            /// TRUE if the axis is currently executing a command
            Busy : DigitalOutputGroup;
            /// The actual position of the axis
            Position : RealOutputGroup := (Output := (Endianness := Endianness#Big, Scale := REAL#1.0));
            /// The actual velocity of the axis
            Velocity : RealOutputGroup := (Output := (Endianness := Endianness#Big, Scale := REAL#1.0));
        END_STRUCT;

        {S7.Extern=ReadWrite}
        PositioningCommand : STRUCT
            /// Execute this command set
            Execute : DigitalInputGroup;
            /// The type of positioning
            CommandType : UIntInputGroup := (Input := (Endianness := Endianness#Big));
            /// A position target (in mm/rad), interpreted as a distance for relative motion and ignored for velocity motion
            Position : RealInputGroup := (Input := (Endianness := Endianness#Big, Scale := REAL#1.0));
            /// Target velocity of the motion
            Velocity : RealInputGroup := (Input := (Endianness := Endianness#Big, Scale := REAL#1.0));
            /// Acceleration
            Acceleration : RealInputGroup := (Input := (Endianness := Endianness#Big, Scale := REAL#1.0));
            /// Deceleration
            Deceleration : RealInputGroup := (Input := (Endianness := Endianness#Big, Scale := REAL#1.0));
            /// Jerk
            Jerk : RealInputGroup := (Input := (Endianness := Endianness#Big, Scale := REAL#1.0));
        END_STRUCT;

        /// Supported motion types of a positioning axis
        PositioningCommandType : UINT (
            /// Absolute positioning
            Absolute := UINT#0,
            /// Relative positioning
            Relative := UINT#1,
            /// Velocity mode
            Velocity := UINT#2,
            /// Halts the current motion with the set deceleration and jerk
            Halt := UINT#3
        );

        {S7.Extern=ReadWrite}
        HomingCommand : STRUCT
            /// Execute this command set
            Execute : DigitalInputGroup;
            /// The type of homing
            HomingType : UIntInputGroup := (Input := (Endianness := Endianness#Big));
            /// The position set after homing, if applicable
            Position : RealInputGroup := (Input := (Endianness := Endianness#Big, Scale := REAL#1.0));
        END_STRUCT;

        /// The type of homing.
        HomingCommandType : UINT (
            /// Direct homing (absolute). The position will be set to the value of the parameter "Position".
            DirectAbsolute := UINT#0,
            /// Direct homing (relative). The position will be shifted by the value of the parameter "Position".
            DirectRelative := UINT#1,
            /// Active homing. The axis will perform a homing movement according to the TO configuration.
            Active := UINT#2,
            /// Passive homing. When the homing mark is detected, the position will be set to the value of the parameter "Position".
            Passive := UINT#3,
            /// Absolute encoder adjustment (relative). The current position will be shifted by the value of the parameter "Position".
            AbsoluteEncoderAdjustementRelative := UINT#4,
            /// Absolute encoder adjustment (absolute). The position is set to the value of the parameter "Position".
            AbsoluteEncoderAdjustementAbsolute := UINT#5
        );

        {S7.Extern=ReadWrite}
        PowerSourceInputs : STRUCT
            Commands : PowerSourceCommandsInputs;
            ActiveArea : PowerSourceParameters;
            WeldDataSet : PowerSourceParameters;
            RuntimeParameters : PowerSourceRuntimeParameters;
            HardwareConfiguration : PowerSourceHardwareConfiguration;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        PowerSourceOutputs : STRUCT
            /// The output of this power source is valid
            Valid : DigitalOutputGroup;
            Commands : PowerSourceCommandsOutputs;
            /// Power source status
            Status : PowerSourceStatus;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        PowerSourceCommandsInputs : STRUCT
            /// Triggers a weld start.
            StartWeld : CommandInputs;
            /// Triggers a weld stop.
            StopWeld : CommandInputs;
            /// Triggers an async write with the set parameters.
            WriteAsync : PowerSourceWriteAsync;
            /// Triggers an async read with the set values.
            ReadAsync : PowerSourceReadAsync;
            /// Triggers a read of all connected nodes.
            ReadNodes : CommandInputs;
            /// Trigger an update of the power source status
            UpdateStatus : CommandInputs;
            /// Swaps the active and passive areas.
            LoadWeldDataSet : CommandInputs;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        PowerSourceCommandsOutputs : STRUCT
            StartWeld : CommandOutputs;
            StopWeld : CommandOutputs;
            WriteAsync : CommandOutputs;
            ReadAsync : PowerSourceReadAsyncOutput;
            /// Triggers a read of all connected nodes.
            ReadNodes : CommandOutputs;
            /// Trigger an update of the power source status
            UpdateStatus : CommandOutputs;
            /// Swaps the active and passive areas.
            LoadWeldDataSet : CommandOutputs;
        END_STRUCT;


        {S7.Extern=ReadWrite}
        PowerSourceParameters : STRUCT
            WeldMethod : UIntInputGroup := (Input := (Endianness := Endianness#Big));
            RegulationType : UIntInputGroup := (Input := (Endianness := Endianness#Big));
            Voltage : RealInputGroup := (Input := (Endianness := Endianness#Big));
            WireFeedSpeed : UIntInputGroup := (Input := (Endianness := Endianness#Big));
            Current : UIntInputGroup := (Input := (Endianness := Endianness#Big));
            TravelSpeed : UIntInputGroup := (Input := (Endianness := Endianness#Big));
            AcFrequency : UIntInputGroup := (Input := (Endianness := Endianness#Big));
            AcBalance : UIntInputGroup := (Input := (Endianness := Endianness#Big));
            AcOffset : RealInputGroup := (Input := (Endianness := Endianness#Big));
            AcPhaseShift : UIntInputGroup := (Input := (Endianness := Endianness#Big));
            StartAdjust : UIntInputGroup := (Input := (Endianness := Endianness#Big));
            RegulationDynamics : UIntInputGroup := (Input := (Endianness := Endianness#Big));
            RegulationInductance : UIntInputGroup := (Input := (Endianness := Endianness#Big));
            IceWireSpeedPercentage : UIntInputGroup := (Input := (Endianness := Endianness#Big));
        END_STRUCT;

        {S7.Extern=ReadWrite}
        PowerSourceStatus : STRUCT
            State : UIntOutputGroup := (Output := (Endianness := Endianness#Big));
            ReadyToWeld : DigitalOutputGroup := (Output := (Endianness := Endianness#Big));
            Welding : DigitalOutputGroup := (Output := (Endianness := Endianness#Big));
            Error : DigitalOutputGroup := (Output := (Endianness := Endianness#Big));
            Connected : DigitalOutputGroup := (Output := (Endianness := Endianness#Big));
            WeldMethod : UIntOutputGroup := (Output := (Endianness := Endianness#Big));
            MeasuredVoltage  : RealOutputGroup := (Output := (Endianness := Endianness#Big));
            MeasuredCurrent : UIntOutputGroup := (Output := (Endianness := Endianness#Big));
            MeasuredHeatInput : RealOutputGroup := (Output := (Endianness := Endianness#Big));
            MeasuredWireSpeed : IntOutputGroup := (Output := (Endianness := Endianness#Big));
            MeasuredTravelSpeed : IntOutputGroup := (Output := (Endianness := Endianness#Big));
            RequestedWireSpeed : IntOutputGroup := (Output := (Endianness := Endianness#Big));
            RequestedTravelSpeed : IntOutputGroup := (Output := (Endianness := Endianness#Big));
        END_STRUCT;

        {S7.Extern=ReadWrite}
        PowerSourceWriteAsync : STRUCT
            Execute : DigitalInputGroup;
            Index : DIntInputGroup := (Input := (Endianness := Endianness#Big));
            Value : UIntInputGroup := (Input := (Endianness := Endianness#Big));
        END_STRUCT;

        {S7.Extern=ReadWrite}
        PowerSourceReadAsync : STRUCT
            Execute : DigitalInputGroup;
            Index : DIntInputGroup := (Input := (Endianness := Endianness#Big));
        END_STRUCT;

        {S7.Extern=ReadWrite}
        PowerSourceReadAsyncOutput : STRUCT
            Executed : DigitalOutputGroup;
            Busy : DigitalOutputGroup;
            ErrorCode : UIntOutputGroup;
            Value : UIntOutputGroup;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        PowerSourceRuntimeParameters : STRUCT
            WireFeedJogSpeed : UIntInputGroup := (Input := (Endianness := Endianness#Big));
            WireFeedJogHighSpeed : UIntInputGroup := (Input := (Endianness := Endianness#Big));
        END_STRUCT;

        {S7.Extern=ReadWrite}
        PowerSourceHardwareConfiguration : STRUCT
            WireMotor : PowerSourceMotorConfiguration;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        PowerSourceMotorConfiguration : STRUCT
            Gear : PowerSourceMotorGearConfiguration;
            Rpm : UIntInputGroup := (Input := (Endianness := Endianness#Big));
            FeedRollDiameter : UIntInputGroup := (Input := (Endianness := Endianness#Big));
            EncoderPpr : UIntInputGroup := (Input := (Endianness := Endianness#Big));
            MaxCurrent : UIntInputGroup := (Input := (Endianness := Endianness#Big));
        END_STRUCT;

        {S7.Extern=ReadWrite}
        PowerSourceMotorGearConfiguration : STRUCT
            N1 : UIntInputGroup := (Input := (Endianness := Endianness#Big));
            N2 : UIntInputGroup := (Input := (Endianness := Endianness#Big));
        END_STRUCT;

        {S7.Extern=ReadWrite}
        RollerBedInputs : STRUCT
            RuntimeParameters : RollerBedRuntimeParameters;
            HardwareConfiguration : RollerBedHardwareConfiguration;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        RollerBedOutputs : STRUCT
            Valid : DigitalOutputGroup;
            Status : RollerBedStatus;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        RollerBedRuntimeParameters : STRUCT
            JogSpeed : RealInputGroup;
            JogHighSpeed : RealInputGroup;
            ObjectRadius : RealInputGroup;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        RollerBedHardwareConfiguration : STRUCT
            MaximumSpeed : RealInputGroup;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        RollerBedStatus : STRUCT
            State : IntOutputGroup;
            Enabled : DigitalOutputGroup;
            Velocity : RealOutputGroup;
            ObjectPosition : RealOutputGroup;
            ObjectRadius : RealOutputGroup;
            LinearPosition : RealOutputGroup;
        END_STRUCT;

        /// An enum representing the weld method
        WeldMethod : UINT (
            DCp := UINT#0,
            AC := UINT#1,
            DCn := UINT#2
        );

        RegulationType : UINT (
            ConstantAmperage := UINT#0,
            ConstantWire := UINT#1,
            ConstantCurrent := UINT#2
        );

        {S7.Extern=ReadWrite}
        FluxSystemInputs : STRUCT
            Commands : FluxSystemInputsCommands;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        FluxSystemOutputs : STRUCT
            Valid : DigitalOutputGroup;
            Commands : FluxSystemCommandOutputs;
            Status: FluxSystemStatus;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        FluxSystemInputsCommands : STRUCT
            Release : CommandInputs;
            Recover : CommandInputs;
            StopRelease : CommandInputs;
            StopRecover : CommandInputs;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        FluxSystemStatus : STRUCT
            IsReleasing : DigitalOutputGroup;
            IsRecovering : DigitalOutputGroup;
            Temperature : RealOutputGroup;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        FluxSystemCommandOutputs : STRUCT
            Release : CommandOutputs;
            Recover : CommandOutputs;
            StopRelease : CommandOutputs;
            StopRecover : CommandOutputs;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        PointLaserInputs : STRUCT
            Commands : PointLaserCommandInputs;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        PointLaserOutputs : STRUCT
            Valid : DigitalOutputGroup;
            Commands : PointLaserCommandOutputs;
            Status : PointLaserStatus;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        PointLaserCommandInputs : STRUCT
            Activate : CommandInputs;
            Deactivate : CommandInputs;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        PointLaserStatus : STRUCT
            Active: DigitalOutputGroup;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        PointLaserCommandOutputs : STRUCT
            Activate : CommandOutputs;
            Deactivate : CommandOutputs;
        END_STRUCT;

        {S7.Extern=ReadWrite}
        CommandOutputs : STRUCT
            Executed : DigitalOutputGroup; // Follows the execute flag.
            Busy : DigitalOutputGroup;
            ErrorCode : UIntOutputGroup; // 0 = OK
        END_STRUCT;

        {S7.Extern=ReadWrite}
        CommandInputs : STRUCT
            Execute: DigitalInputGroup;
        END_STRUCT;
    END_TYPE

    // These input/output group classes are used in the WebApi configuration,
    // this is done so that each class holds a public var Value with the primitive type of what the input/output represents.
    // This way we can for example reset a command input when we have processed it.

    {S7.Extern=ReadWrite}
    CLASS DigitalInputGroup
        VAR PUBLIC
            Input : DigitalInput;
            Value : BOOL;
        END_VAR

        METHOD PUBLIC Read
            Input.Read(Value);
        END_METHOD

        METHOD PUBLIC Read
            VAR_INPUT
                value : BOOL;
            END_VAR

            THIS.Value := value;
            THIS.Read();
        END_METHOD
    END_CLASS

    {S7.Extern=ReadWrite}
    CLASS DigitalOutputGroup
        VAR PUBLIC
            Output : DigitalOutput;
            Value : BOOL;
        END_VAR

        METHOD PUBLIC Write
            Output.Write(value => Value);
        END_METHOD
    END_CLASS

    {S7.Extern=ReadWrite}
    CLASS UIntInputGroup
        VAR PUBLIC
            Input : UIntInput;
            Value : UINT;
        END_VAR

        METHOD PUBLIC Read
            Input.Read(Value);
        END_METHOD

        METHOD PUBLIC Read
            VAR_INPUT
                value : UINT;
            END_VAR

            THIS.Value := value;
            THIS.Read();
        END_METHOD
    END_CLASS

    {S7.Extern=ReadWrite}
    CLASS UIntOutputGroup
        VAR PUBLIC
            Output : UIntOutput;
            Value : UINT;
        END_VAR

        METHOD PUBLIC Write
            Output.Write(value => Value);
        END_METHOD
    END_CLASS

    {S7.Extern=ReadWrite}
    CLASS DIntInputGroup
        VAR PUBLIC
            Input : DIntInput;
            Value : DINT;
        END_VAR

        METHOD PUBLIC Read
            Input.Read(Value);
        END_METHOD

        METHOD PUBLIC Read
            VAR_INPUT
                value : DINT;
            END_VAR

            THIS.Value := value;
            THIS.Read();
        END_METHOD
    END_CLASS

    {S7.Extern=ReadWrite}
    CLASS DIntOutputGroup
        VAR PUBLIC
            Output : DIntOutput;
            Value : DINT;
        END_VAR

        METHOD PUBLIC Write
            Output.Write(value => Value);
        END_METHOD
    END_CLASS

    {S7.Extern=ReadWrite}
    CLASS IntInputGroup
        VAR PUBLIC
            Input : IntInput;
            Value : INT;
        END_VAR

        METHOD PUBLIC Read
            Input.Read(Value);
        END_METHOD

        METHOD PUBLIC Read
            VAR_INPUT
                value : INT;
            END_VAR

            THIS.Value := value;
            THIS.Read();
        END_METHOD
    END_CLASS

    {S7.Extern=ReadWrite}
    CLASS IntOutputGroup
        VAR PUBLIC
            Output : IntOutput;
            Value : INT;
        END_VAR

        METHOD PUBLIC Write
            Output.Write(value => Value);
        END_METHOD
    END_CLASS

    {S7.Extern=ReadWrite}
    CLASS RealInputGroup
        VAR PUBLIC
            Input : RealInput;
            Value : REAL;
        END_VAR

        METHOD PUBLIC Read
            Input.Read(Value);
        END_METHOD

        METHOD PUBLIC Read
            VAR_INPUT
                value : REAL;
            END_VAR

            THIS.Value := value;
            THIS.Read();
        END_METHOD
    END_CLASS

    {S7.Extern=ReadWrite}
    CLASS RealOutputGroup
        VAR PUBLIC
            Output : RealOutput;
            Value : REAL;
        END_VAR

        METHOD PUBLIC Write
            Output.Write(value => Value);
        END_METHOD
    END_CLASS

END_NAMESPACE