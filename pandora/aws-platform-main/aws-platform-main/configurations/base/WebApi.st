USING Esab.Api;
USING Esab.Utils.Alarming;
USING Esab.Utils.Assets;

USING Siemens.Simatic.S71500.Tasks;
USING Siemens.Simatic.S71500.Alarming;

CONFIGURATION WebApiConfiguration
    TASK WebApiTask : ProgramCycle;

    PROGRAM WebApiReadInputs WITH WebApiTask: WebApiReadInputs;
    PROGRAM WebApiWriteOutputs WITH WebApiTask: WebApiWriteOutputs;

    // Objects
    VAR_GLOBAL
        WebApi : WebApi;
    END_VAR

    // Alarms
    VAR_GLOBAL
        WebApiSetupAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Roller Bed: Setup error."}
        WebApiSetupAlarm : ProgramAlarm;
    END_VAR

    // Interface
    VAR_GLOBAL
        {S7.Extern=ReadWrite}
        WebApiData : WebApiData;
    END_VAR

END_CONFIGURATION

FUNCTION InitializeWebApi
    VAR_INPUT
        assetsManager : IAssetsManager;
    END_VAR

    VAR_EXTERNAL
        WebApi : WebApi;

        WebApiSetupAlarmWrapper : AlarmWrapper;
        WebApiSetupAlarm : ProgramAlarm;

        WebApiData : WebApiData;
    END_VAR

    WebApiSetupAlarmWrapper.Setup(REF(WebApiSetupAlarm));
    WebApi.Setup(assetsManager, REF(WebApiData), WebApiSetupAlarmWrapper);
END_FUNCTION

PROGRAM WebApiReadInputs
    VAR_EXTERNAL
        WebApiData : WebApiData;
    END_VAR

    WebApiData.Inputs.HorizontalSlide.Commands.Enable.Execute.Read();
    WebApiData.Inputs.HorizontalSlide.Commands.Disable.Execute.Read();
    WebApiData.Inputs.HorizontalSlide.Commands.Halt.Execute.Read();
    WebApiData.Inputs.HorizontalSlide.Commands.JogPositive.Execute.Read();
    WebApiData.Inputs.HorizontalSlide.Commands.JogNegative.Execute.Read();

    WebApiData.Inputs.HorizontalSlide.Commands.Positioning.Execute.Read();
    WebApiData.Inputs.HorizontalSlide.Commands.Positioning.CommandType.Read();
    WebApiData.Inputs.HorizontalSlide.Commands.Positioning.Position.Read();
    WebApiData.Inputs.HorizontalSlide.Commands.Positioning.Velocity.Read();
    WebApiData.Inputs.HorizontalSlide.Commands.Positioning.Acceleration.Read();
    WebApiData.Inputs.HorizontalSlide.Commands.Positioning.Deceleration.Read();
    WebApiData.Inputs.HorizontalSlide.Commands.Positioning.Jerk.Read();

    WebApiData.Inputs.HorizontalSlide.Commands.Homing.Execute.Read();
    WebApiData.Inputs.HorizontalSlide.Commands.Homing.HomingType.Read();
    WebApiData.Inputs.HorizontalSlide.Commands.Homing.Position.Read();

    WebApiData.Inputs.HorizontalSlide.Parameters.JogSpeed.Read();
    WebApiData.Inputs.HorizontalSlide.Parameters.JogHighSpeed.Read();


    WebApiData.Inputs.VerticalSlide.Commands.Enable.Execute.Read();
    WebApiData.Inputs.VerticalSlide.Commands.Disable.Execute.Read();
    WebApiData.Inputs.VerticalSlide.Commands.Halt.Execute.Read();
    WebApiData.Inputs.VerticalSlide.Commands.JogPositive.Execute.Read();
    WebApiData.Inputs.VerticalSlide.Commands.JogNegative.Execute.Read();

    WebApiData.Inputs.VerticalSlide.Commands.Positioning.Execute.Read();
    WebApiData.Inputs.VerticalSlide.Commands.Positioning.CommandType.Read();
    WebApiData.Inputs.VerticalSlide.Commands.Positioning.Position.Read();
    WebApiData.Inputs.VerticalSlide.Commands.Positioning.Velocity.Read();
    WebApiData.Inputs.VerticalSlide.Commands.Positioning.Acceleration.Read();
    WebApiData.Inputs.VerticalSlide.Commands.Positioning.Deceleration.Read();
    WebApiData.Inputs.VerticalSlide.Commands.Positioning.Jerk.Read();

    WebApiData.Inputs.VerticalSlide.Commands.Homing.Execute.Read();
    WebApiData.Inputs.VerticalSlide.Commands.Homing.HomingType.Read();
    WebApiData.Inputs.VerticalSlide.Commands.Homing.Position.Read();

    WebApiData.Inputs.VerticalSlide.Parameters.JogSpeed.Read();
    WebApiData.Inputs.VerticalSlide.Parameters.JogHighSpeed.Read();


    WebApiData.Inputs.PowerSource1.Commands.StartWeld.Execute.Read();
    WebApiData.Inputs.PowerSource1.Commands.StopWeld.Execute.Read();
    WebApiData.Inputs.PowerSource1.Commands.WriteAsync.Execute.Read();
    WebApiData.Inputs.PowerSource1.Commands.WriteAsync.Index.Read();
    WebApiData.Inputs.PowerSource1.Commands.WriteAsync.Value.Read();
    WebApiData.Inputs.PowerSource1.Commands.ReadAsync.Execute.Read();
    WebApiData.Inputs.PowerSource1.Commands.ReadAsync.Index.Read();
    WebApiData.Inputs.PowerSource1.Commands.ReadNodes.Execute.Read();
    WebApiData.Inputs.PowerSource1.Commands.UpdateStatus.Execute.Read();
    WebApiData.Inputs.PowerSource1.Commands.LoadWeldDataSet.Execute.Read();


    WebApiData.Inputs.PowerSource1.ActiveArea.WeldMethod.Read();
    WebApiData.Inputs.PowerSource1.ActiveArea.RegulationType.Read();
    WebApiData.Inputs.PowerSource1.ActiveArea.Voltage.Read();
    WebApiData.Inputs.PowerSource1.ActiveArea.WireFeedSpeed.Read();
    WebApiData.Inputs.PowerSource1.ActiveArea.Current.Read();
    WebApiData.Inputs.PowerSource1.ActiveArea.TravelSpeed.Read();
    WebApiData.Inputs.PowerSource1.ActiveArea.AcFrequency.Read();
    WebApiData.Inputs.PowerSource1.ActiveArea.AcBalance.Read();
    WebApiData.Inputs.PowerSource1.ActiveArea.AcOffset.Read();
    WebApiData.Inputs.PowerSource1.ActiveArea.AcPhaseShift.Read();
    WebApiData.Inputs.PowerSource1.ActiveArea.StartAdjust.Read();
    WebApiData.Inputs.PowerSource1.ActiveArea.RegulationDynamics.Read();
    WebApiData.Inputs.PowerSource1.ActiveArea.RegulationInductance.Read();
    WebApiData.Inputs.PowerSource1.ActiveArea.IceWireSpeedPercentage.Read();

    WebApiData.Inputs.PowerSource1.WeldDataSet.WeldMethod.Read();
    WebApiData.Inputs.PowerSource1.WeldDataSet.RegulationType.Read();
    WebApiData.Inputs.PowerSource1.WeldDataSet.Voltage.Read();
    WebApiData.Inputs.PowerSource1.WeldDataSet.WireFeedSpeed.Read();
    WebApiData.Inputs.PowerSource1.WeldDataSet.Current.Read();
    WebApiData.Inputs.PowerSource1.WeldDataSet.TravelSpeed.Read();
    WebApiData.Inputs.PowerSource1.WeldDataSet.AcFrequency.Read();
    WebApiData.Inputs.PowerSource1.WeldDataSet.AcBalance.Read();
    WebApiData.Inputs.PowerSource1.WeldDataSet.AcOffset.Read();
    WebApiData.Inputs.PowerSource1.WeldDataSet.AcPhaseShift.Read();
    WebApiData.Inputs.PowerSource1.WeldDataSet.StartAdjust.Read();
    WebApiData.Inputs.PowerSource1.WeldDataSet.RegulationDynamics.Read();
    WebApiData.Inputs.PowerSource1.WeldDataSet.RegulationInductance.Read();
    WebApiData.Inputs.PowerSource1.WeldDataSet.IceWireSpeedPercentage.Read();

    WebApiData.Inputs.PowerSource1.RuntimeParameters.WireFeedJogSpeed.Read();
    WebApiData.Inputs.PowerSource1.RuntimeParameters.WireFeedJogHighSpeed.Read();


    WebApiData.Inputs.PowerSource2.Commands.StartWeld.Execute.Read();
    WebApiData.Inputs.PowerSource2.Commands.StopWeld.Execute.Read();
    WebApiData.Inputs.PowerSource2.Commands.WriteAsync.Execute.Read();
    WebApiData.Inputs.PowerSource2.Commands.WriteAsync.Index.Read();
    WebApiData.Inputs.PowerSource2.Commands.WriteAsync.Value.Read();
    WebApiData.Inputs.PowerSource2.Commands.ReadAsync.Execute.Read();
    WebApiData.Inputs.PowerSource2.Commands.ReadAsync.Index.Read();
    WebApiData.Inputs.PowerSource2.Commands.ReadNodes.Execute.Read();
    WebApiData.Inputs.PowerSource2.Commands.UpdateStatus.Execute.Read();
    WebApiData.Inputs.PowerSource2.Commands.LoadWeldDataSet.Execute.Read();


    WebApiData.Inputs.PowerSource2.ActiveArea.WeldMethod.Read();
    WebApiData.Inputs.PowerSource2.ActiveArea.RegulationType.Read();
    WebApiData.Inputs.PowerSource2.ActiveArea.Voltage.Read();
    WebApiData.Inputs.PowerSource2.ActiveArea.WireFeedSpeed.Read();
    WebApiData.Inputs.PowerSource2.ActiveArea.Current.Read();
    WebApiData.Inputs.PowerSource2.ActiveArea.TravelSpeed.Read();
    WebApiData.Inputs.PowerSource2.ActiveArea.AcFrequency.Read();
    WebApiData.Inputs.PowerSource2.ActiveArea.AcBalance.Read();
    WebApiData.Inputs.PowerSource2.ActiveArea.AcOffset.Read();
    WebApiData.Inputs.PowerSource2.ActiveArea.AcPhaseShift.Read();
    WebApiData.Inputs.PowerSource2.ActiveArea.StartAdjust.Read();
    WebApiData.Inputs.PowerSource2.ActiveArea.RegulationDynamics.Read();
    WebApiData.Inputs.PowerSource2.ActiveArea.RegulationInductance.Read();
    WebApiData.Inputs.PowerSource2.ActiveArea.IceWireSpeedPercentage.Read();

    WebApiData.Inputs.PowerSource2.WeldDataSet.WeldMethod.Read();
    WebApiData.Inputs.PowerSource2.WeldDataSet.RegulationType.Read();
    WebApiData.Inputs.PowerSource2.WeldDataSet.Voltage.Read();
    WebApiData.Inputs.PowerSource2.WeldDataSet.WireFeedSpeed.Read();
    WebApiData.Inputs.PowerSource2.WeldDataSet.Current.Read();
    WebApiData.Inputs.PowerSource2.WeldDataSet.TravelSpeed.Read();
    WebApiData.Inputs.PowerSource2.WeldDataSet.AcFrequency.Read();
    WebApiData.Inputs.PowerSource2.WeldDataSet.AcBalance.Read();
    WebApiData.Inputs.PowerSource2.WeldDataSet.AcOffset.Read();
    WebApiData.Inputs.PowerSource2.WeldDataSet.AcPhaseShift.Read();
    WebApiData.Inputs.PowerSource2.WeldDataSet.StartAdjust.Read();
    WebApiData.Inputs.PowerSource2.WeldDataSet.RegulationDynamics.Read();
    WebApiData.Inputs.PowerSource2.WeldDataSet.RegulationInductance.Read();
    WebApiData.Inputs.PowerSource2.WeldDataSet.IceWireSpeedPercentage.Read();

    WebApiData.Inputs.PowerSource2.RuntimeParameters.WireFeedJogSpeed.Read();
    WebApiData.Inputs.PowerSource2.RuntimeParameters.WireFeedJogHighSpeed.Read();

    WebApiData.Inputs.FluxSystem.Commands.Release.Execute.Read();
    WebApiData.Inputs.FluxSystem.Commands.Recover.Execute.Read();
    WebApiData.Inputs.FluxSystem.Commands.StopRelease.Execute.Read();
    WebApiData.Inputs.FluxSystem.Commands.StopRecover.Execute.Read();

    WebApiData.Inputs.RollerBed.RuntimeParameters.JogSpeed.Read();
    WebApiData.Inputs.RollerBed.RuntimeParameters.JogHighSpeed.Read();
    WebApiData.Inputs.RollerBed.RuntimeParameters.ObjectRadius.Read();
    WebApiData.Inputs.RollerBed.HardwareConfiguration.MaximumSpeed.Read();
END_PROGRAM

PROGRAM WebApiWriteOutputs
    VAR_EXTERNAL
        WebApiData : WebApiData;
    END_VAR

    WebApiData.Outputs.HorizontalSlide.Valid.Write();
    WebApiData.Outputs.HorizontalSlide.Status.Enabled.Write();
    WebApiData.Outputs.HorizontalSlide.Status.Error.Write();
    WebApiData.Outputs.HorizontalSlide.Status.Homed.Write();
    WebApiData.Outputs.HorizontalSlide.Status.Busy.Write();
    WebApiData.Outputs.HorizontalSlide.Status.Position.Write();
    WebApiData.Outputs.HorizontalSlide.Status.Velocity.Write();

    WebApiData.Outputs.HorizontalSlide.Commands.Enable.Executed.Write();
    WebApiData.Outputs.HorizontalSlide.Commands.Enable.Busy.Write();
    WebApiData.Outputs.HorizontalSlide.Commands.Enable.ErrorCode.Write();   

    WebApiData.Outputs.HorizontalSlide.Commands.Disable.Executed.Write();
    WebApiData.Outputs.HorizontalSlide.Commands.Disable.Busy.Write();
    WebApiData.Outputs.HorizontalSlide.Commands.Disable.ErrorCode.Write();    

    WebApiData.Outputs.HorizontalSlide.Commands.Halt.Executed.Write();
    WebApiData.Outputs.HorizontalSlide.Commands.Halt.Busy.Write();
    WebApiData.Outputs.HorizontalSlide.Commands.Halt.ErrorCode.Write();

    WebApiData.Outputs.HorizontalSlide.Commands.JogPositive.Executed.Write();
    WebApiData.Outputs.HorizontalSlide.Commands.JogPositive.Busy.Write();
    WebApiData.Outputs.HorizontalSlide.Commands.JogPositive.ErrorCode.Write();

    WebApiData.Outputs.HorizontalSlide.Commands.JogNegative.Executed.Write();
    WebApiData.Outputs.HorizontalSlide.Commands.JogNegative.Busy.Write();
    WebApiData.Outputs.HorizontalSlide.Commands.JogNegative.ErrorCode.Write();

    WebApiData.Outputs.HorizontalSlide.Commands.Positioning.Executed.Write();
    WebApiData.Outputs.HorizontalSlide.Commands.Positioning.Busy.Write();
    WebApiData.Outputs.HorizontalSlide.Commands.Positioning.ErrorCode.Write();

    WebApiData.Outputs.HorizontalSlide.Commands.Homing.Executed.Write();
    WebApiData.Outputs.HorizontalSlide.Commands.Homing.Busy.Write();
    WebApiData.Outputs.HorizontalSlide.Commands.Homing.ErrorCode.Write();


    WebApiData.Outputs.VerticalSlide.Valid.Write();
    WebApiData.Outputs.VerticalSlide.Status.Enabled.Write();
    WebApiData.Outputs.VerticalSlide.Status.Error.Write();
    WebApiData.Outputs.VerticalSlide.Status.Homed.Write();
    WebApiData.Outputs.VerticalSlide.Status.Busy.Write();
    WebApiData.Outputs.VerticalSlide.Status.Position.Write();
    WebApiData.Outputs.VerticalSlide.Status.Velocity.Write();

    WebApiData.Outputs.VerticalSlide.Commands.Enable.Executed.Write();
    WebApiData.Outputs.VerticalSlide.Commands.Enable.Busy.Write();
    WebApiData.Outputs.VerticalSlide.Commands.Enable.ErrorCode.Write();   

    WebApiData.Outputs.VerticalSlide.Commands.Disable.Executed.Write();
    WebApiData.Outputs.VerticalSlide.Commands.Disable.Busy.Write();
    WebApiData.Outputs.VerticalSlide.Commands.Disable.ErrorCode.Write();    

    WebApiData.Outputs.VerticalSlide.Commands.Halt.Executed.Write();
    WebApiData.Outputs.VerticalSlide.Commands.Halt.Busy.Write();
    WebApiData.Outputs.VerticalSlide.Commands.Halt.ErrorCode.Write();

    WebApiData.Outputs.VerticalSlide.Commands.JogPositive.Executed.Write();
    WebApiData.Outputs.VerticalSlide.Commands.JogPositive.Busy.Write();
    WebApiData.Outputs.VerticalSlide.Commands.JogPositive.ErrorCode.Write();

    WebApiData.Outputs.VerticalSlide.Commands.JogNegative.Executed.Write();
    WebApiData.Outputs.VerticalSlide.Commands.JogNegative.Busy.Write();
    WebApiData.Outputs.VerticalSlide.Commands.JogNegative.ErrorCode.Write();

    WebApiData.Outputs.VerticalSlide.Commands.Positioning.Executed.Write();
    WebApiData.Outputs.VerticalSlide.Commands.Positioning.Busy.Write();
    WebApiData.Outputs.VerticalSlide.Commands.Positioning.ErrorCode.Write();

    WebApiData.Outputs.VerticalSlide.Commands.Homing.Executed.Write();
    WebApiData.Outputs.VerticalSlide.Commands.Homing.Busy.Write();
    WebApiData.Outputs.VerticalSlide.Commands.Homing.ErrorCode.Write();


    WebApiData.Outputs.PowerSource1.Valid.Write();
    WebApiData.Outputs.PowerSource1.Status.State.Write();
    WebApiData.Outputs.PowerSource1.Status.ReadyToWeld.Write();
    WebApiData.Outputs.PowerSource1.Status.Welding.Write();
    WebApiData.Outputs.PowerSource1.Status.Error.Write();
    WebApiData.Outputs.PowerSource1.Status.Connected.Write();
    WebApiData.Outputs.PowerSource1.Status.WeldMethod.Write();
    WebApiData.Outputs.PowerSource1.Status.MeasuredVoltage.Write();
    WebApiData.Outputs.PowerSource1.Status.MeasuredCurrent.Write();
    WebApiData.Outputs.PowerSource1.Status.MeasuredHeatInput.Write();
    WebApiData.Outputs.PowerSource1.Status.MeasuredWireSpeed.Write();
    WebApiData.Outputs.PowerSource1.Status.MeasuredTravelSpeed.Write();
    WebApiData.Outputs.PowerSource1.Status.RequestedWireSpeed.Write();
    WebApiData.Outputs.PowerSource1.Status.RequestedTravelSpeed.Write();

    WebApiData.Outputs.PowerSource1.Commands.StartWeld.Executed.Write();
    WebApiData.Outputs.PowerSource1.Commands.StartWeld.Busy.Write();
    WebApiData.Outputs.PowerSource1.Commands.StartWeld.ErrorCode.Write();

    WebApiData.Outputs.PowerSource1.Commands.StopWeld.Executed.Write();
    WebApiData.Outputs.PowerSource1.Commands.StopWeld.Busy.Write();
    WebApiData.Outputs.PowerSource1.Commands.StopWeld.ErrorCode.Write();

    WebApiData.Outputs.PowerSource1.Commands.WriteAsync.Executed.Write();
    WebApiData.Outputs.PowerSource1.Commands.WriteAsync.Busy.Write();
    WebApiData.Outputs.PowerSource1.Commands.WriteAsync.ErrorCode.Write();

    WebApiData.Outputs.PowerSource1.Commands.ReadAsync.Executed.Write();
    WebApiData.Outputs.PowerSource1.Commands.ReadAsync.Busy.Write();
    WebApiData.Outputs.PowerSource1.Commands.ReadAsync.ErrorCode.Write();
    WebApiData.Outputs.PowerSource2.Commands.ReadAsync.Value.Write();

    WebApiData.Outputs.PowerSource1.Commands.ReadNodes.Executed.Write();
    WebApiData.Outputs.PowerSource1.Commands.ReadNodes.Busy.Write();
    WebApiData.Outputs.PowerSource1.Commands.ReadNodes.ErrorCode.Write();

    WebApiData.Outputs.PowerSource1.Commands.UpdateStatus.Executed.Write();
    WebApiData.Outputs.PowerSource1.Commands.UpdateStatus.Busy.Write();
    WebApiData.Outputs.PowerSource1.Commands.UpdateStatus.ErrorCode.Write();

    WebApiData.Outputs.PowerSource1.Commands.LoadWeldDataSet.Executed.Write();
    WebApiData.Outputs.PowerSource1.Commands.LoadWeldDataSet.Busy.Write();
    WebApiData.Outputs.PowerSource1.Commands.LoadWeldDataSet.ErrorCode.Write();


    WebApiData.Outputs.PowerSource2.Valid.Write();
    WebApiData.Outputs.PowerSource2.Status.State.Write();
    WebApiData.Outputs.PowerSource2.Status.ReadyToWeld.Write();
    WebApiData.Outputs.PowerSource2.Status.Welding.Write();
    WebApiData.Outputs.PowerSource2.Status.Error.Write();
    WebApiData.Outputs.PowerSource2.Status.Connected.Write();
    WebApiData.Outputs.PowerSource2.Status.WeldMethod.Write();
    WebApiData.Outputs.PowerSource2.Status.MeasuredVoltage.Write();
    WebApiData.Outputs.PowerSource2.Status.MeasuredCurrent.Write();
    WebApiData.Outputs.PowerSource2.Status.MeasuredHeatInput.Write();
    WebApiData.Outputs.PowerSource2.Status.MeasuredWireSpeed.Write();
    WebApiData.Outputs.PowerSource2.Status.MeasuredTravelSpeed.Write();
    WebApiData.Outputs.PowerSource2.Status.RequestedWireSpeed.Write();
    WebApiData.Outputs.PowerSource2.Status.RequestedTravelSpeed.Write();

    WebApiData.Outputs.PowerSource2.Commands.StartWeld.Executed.Write();
    WebApiData.Outputs.PowerSource2.Commands.StartWeld.Busy.Write();
    WebApiData.Outputs.PowerSource2.Commands.StartWeld.ErrorCode.Write();

    WebApiData.Outputs.PowerSource2.Commands.StopWeld.Executed.Write();
    WebApiData.Outputs.PowerSource2.Commands.StopWeld.Busy.Write();
    WebApiData.Outputs.PowerSource2.Commands.StopWeld.ErrorCode.Write();

    WebApiData.Outputs.PowerSource2.Commands.WriteAsync.Executed.Write();
    WebApiData.Outputs.PowerSource2.Commands.WriteAsync.Busy.Write();
    WebApiData.Outputs.PowerSource2.Commands.WriteAsync.ErrorCode.Write();

    WebApiData.Outputs.PowerSource2.Commands.ReadAsync.Executed.Write();
    WebApiData.Outputs.PowerSource2.Commands.ReadAsync.Busy.Write();
    WebApiData.Outputs.PowerSource2.Commands.ReadAsync.ErrorCode.Write();
    WebApiData.Outputs.PowerSource2.Commands.ReadAsync.Value.Write();

    WebApiData.Outputs.PowerSource2.Commands.ReadNodes.Executed.Write();
    WebApiData.Outputs.PowerSource2.Commands.ReadNodes.Busy.Write();
    WebApiData.Outputs.PowerSource2.Commands.ReadNodes.ErrorCode.Write();

    WebApiData.Outputs.PowerSource2.Commands.UpdateStatus.Executed.Write();
    WebApiData.Outputs.PowerSource2.Commands.UpdateStatus.Busy.Write();
    WebApiData.Outputs.PowerSource2.Commands.UpdateStatus.ErrorCode.Write();

    WebApiData.Outputs.PowerSource2.Commands.LoadWeldDataSet.Executed.Write();
    WebApiData.Outputs.PowerSource2.Commands.LoadWeldDataSet.Busy.Write();
    WebApiData.Outputs.PowerSource2.Commands.LoadWeldDataSet.ErrorCode.Write();


    WebApiData.Outputs.FluxSystem.Valid.Write();
    WebApiData.Outputs.FluxSystem.Status.IsReleasing.Write();
    WebApiData.Outputs.FluxSystem.Status.IsRecovering.Write();
    WebApiData.Outputs.FluxSystem.Status.Temperature.Write();

    WebApiData.Outputs.FluxSystem.Commands.Release.Executed.Write();
    WebApiData.Outputs.FluxSystem.Commands.Release.Busy.Write();
    WebApiData.Outputs.FluxSystem.Commands.Release.ErrorCode.Write();   

    WebApiData.Outputs.FluxSystem.Commands.Recover.Executed.Write();
    WebApiData.Outputs.FluxSystem.Commands.Recover.Busy.Write();
    WebApiData.Outputs.FluxSystem.Commands.Recover.ErrorCode.Write();  

    WebApiData.Outputs.FluxSystem.Commands.StopRelease.Executed.Write();
    WebApiData.Outputs.FluxSystem.Commands.StopRelease.Busy.Write();
    WebApiData.Outputs.FluxSystem.Commands.StopRelease.ErrorCode.Write(); 
    
    WebApiData.Outputs.FluxSystem.Commands.StopRecover.Executed.Write();
    WebApiData.Outputs.FluxSystem.Commands.StopRecover.Busy.Write();
    WebApiData.Outputs.FluxSystem.Commands.StopRecover.ErrorCode.Write();  

    
    WebApiData.Outputs.RollerBed.Valid.Write();
    WebApiData.Outputs.RollerBed.Status.State.Write();
    WebApiData.Outputs.RollerBed.Status.Enabled.Write();
    WebApiData.Outputs.RollerBed.Status.Velocity.Write();
    WebApiData.Outputs.RollerBed.Status.ObjectPosition.Write();
    WebApiData.Outputs.RollerBed.Status.ObjectRadius.Write();
    WebApiData.Outputs.RollerBed.Status.LinearPosition.Write();
END_PROGRAM