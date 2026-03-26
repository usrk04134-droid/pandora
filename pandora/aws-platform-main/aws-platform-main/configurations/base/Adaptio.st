USING Esab.Modes;
USING Esab.Utils.Alarming;
USING Esab.Utils.Assets;
USING Esab.Utils.Heartbeat;
USING Esab.Utils.Timer;

USING Siemens.Simatic.S71500.Tasks;
USING Siemens.Simatic.S71500.Alarming;

CONFIGURATION AdaptioSystemConfiguration

    TASK AdaptioIoTask : ProgramCycle;

    PROGRAM AdaptioIoReadWrite WITH AdaptioIoTask: AdaptioIoReadWrite;

    // Constants
    VAR_GLOBAL CONSTANT
    END_VAR

    // Objects
    VAR_GLOBAL
        {S7.Extern=Read}
        Adaptio : Adaptio;
        AdaptioRuntimeParameters : AdaptioRuntimeParameters;
        AdaptioWeldSequence : AdaptioWeldSequence;
        AdaptioWeldSequenceStateTimer : ITimer;
        AdaptioHeartbeat : IncrementingHeartbeat;
        AdaptioRequestTimer : OnDelay;
        AdaptioJoystickClickTimer : OnDelay;
        AdaptioWeldingStateTimer : OnDelay;
        AdaptioHeartbeatTimer : OnDelay;
    END_VAR

    // Alarms
    VAR_GLOBAL
        AdaptioHeartbeatAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Adaptio: Heartbeat missing."}
        AdaptioHeartbeatAlarm : ProgramAlarm;

        AdaptioSetupAlarmWrapper : AlarmWrapper;
        {S7.Alarm = NoAck, "Adaptio: Setup error."}
        AdaptioSetupAlarm : ProgramAlarm;
    END_VAR

    // Interface
    VAR_GLOBAL
        {S7.Extern=ReadWrite}
        AdaptioIo : AdaptioIo;
    END_VAR
END_CONFIGURATION

FUNCTION InitializeAdaptio
    VAR_INPUT
        assetsManager : IAssetsManager;
    END_VAR

    VAR_EXTERNAL
        AdaptioIo : AdaptioIo;

        Adaptio : Adaptio;
        AdaptioRuntimeParameters : AdaptioRuntimeParameters;
        AdaptioWeldSequence : AdaptioWeldSequence;
        AdaptioWeldSequenceStateTimer : ITimer;
        AdaptioHeartbeat : IncrementingHeartbeat;
        AdaptioRequestTimer : OnDelay;
        AdaptioJoystickClickTimer : OnDelay;
        AdaptioWeldingStateTimer : OnDelay;
        AdaptioHeartbeatTimer : OnDelay;

        AdaptioHeartbeatAlarmWrapper : AlarmWrapper;
        AdaptioHeartbeatAlarm : ProgramAlarm;

        AdaptioSetupAlarmWrapper : AlarmWrapper;
        AdaptioSetupAlarm : ProgramAlarm;
    END_VAR

    AdaptioWeldSequence.Setup(AdaptioWeldSequenceStateTimer); // Weld axis and orchestrator is set inside the Adaptio manager
    AdaptioHeartbeatAlarmWrapper.Setup(REF(AdaptioHeartbeatAlarm));
    AdaptioSetupAlarmWrapper.Setup(REF(AdaptioSetupAlarm));

    AdaptioHeartbeat.Setup(AdaptioIo.FromAdaptio.SystemControl.Heartbeat,
                           AdaptioIo.ToAdaptio.SystemControl.Heartbeat,
                           AdaptioHeartbeatTimer,
                           AdaptioHeartbeatAlarmWrapper);

    Adaptio.Setup(REF(AdaptioIo),
                  REF(AdaptioRuntimeParameters),
                  assetsManager,
                  AdaptioWeldSequence,
                  AdaptioHeartbeat,
                  AdaptioRequestTimer,
                  AdaptioJoystickClickTimer,
                  AdaptioSetupAlarmWrapper);
END_FUNCTION

PROGRAM AdaptioIoReadWrite
    VAR_EXTERNAL
        AdaptioIo : AdaptioIo;
        I_Adaptio : RawFromAdaptio;
        Q_Adaptio : RawToAdaptio;
    END_VAR

    AdaptioIo.FromAdaptio.SystemControl.Heartbeat.Read(I_Adaptio.SystemControl.Heartbeat);

    AdaptioIo.FromAdaptio.WeldControl.Start.Read(I_Adaptio.WeldControl.Start);
    AdaptioIo.FromAdaptio.WeldControl.Stop.Read(I_Adaptio.WeldControl.Stop);
    AdaptioIo.FromAdaptio.WeldControl.QuickStop.Read(I_Adaptio.WeldControl.QuickStop);

    AdaptioIo.FromAdaptio.PowerSource1.Enable.Read(I_Adaptio.PowerSource1.Enable);
    AdaptioIo.FromAdaptio.PowerSource1.ActiveAreaSelect.Read(I_Adaptio.PowerSource1.ActiveAreaSelect);
    AdaptioIo.FromAdaptio.PowerSource1.SwitchAreas.Read(I_Adaptio.PowerSource1.SwitchAreas);
    AdaptioIo.FromAdaptio.PowerSource1.Voltage.Read(I_Adaptio.PowerSource1.Voltage);
    AdaptioIo.FromAdaptio.PowerSource1.Current.Read(I_Adaptio.PowerSource1.Current);
    AdaptioIo.FromAdaptio.PowerSource1.WireSpeed.Read(I_Adaptio.PowerSource1.WireSpeed);
    AdaptioIo.FromAdaptio.PowerSource1.RegulationType.Read(I_Adaptio.PowerSource1.RegulationType);
    AdaptioIo.FromAdaptio.PowerSource1.WeldMethod.Read(I_Adaptio.PowerSource1.WeldMethod);
    AdaptioIo.FromAdaptio.PowerSource1.AcFrequency.Read(I_Adaptio.PowerSource1.AcFrequency);
    AdaptioIo.FromAdaptio.PowerSource1.AcBalance.Read(I_Adaptio.PowerSource1.AcBalance);
    AdaptioIo.FromAdaptio.PowerSource1.AcOffset.Read(I_Adaptio.PowerSource1.AcOffset);
    AdaptioIo.FromAdaptio.PowerSource1.AcPhaseShift.Read(I_Adaptio.PowerSource1.AcPhaseShift);
    AdaptioIo.FromAdaptio.PowerSource1.StartAdjust.Read(I_Adaptio.PowerSource1.StartAdjust);
    AdaptioIo.FromAdaptio.PowerSource1.RegulationDynamics.Read(I_Adaptio.PowerSource1.RegulationDynamics);
    AdaptioIo.FromAdaptio.PowerSource1.RegulationInductance.Read(I_Adaptio.PowerSource1.RegulationInductance);
    AdaptioIo.FromAdaptio.PowerSource1.IceWireSpeed.Read(I_Adaptio.PowerSource1.IceWireSpeed);

    AdaptioIo.FromAdaptio.PowerSource2.Enable.Read(I_Adaptio.PowerSource2.Enable);
    AdaptioIo.FromAdaptio.PowerSource2.ActiveAreaSelect.Read(I_Adaptio.PowerSource2.ActiveAreaSelect);
    AdaptioIo.FromAdaptio.PowerSource2.SwitchAreas.Read(I_Adaptio.PowerSource2.SwitchAreas);
    AdaptioIo.FromAdaptio.PowerSource2.Voltage.Read(I_Adaptio.PowerSource2.Voltage);
    AdaptioIo.FromAdaptio.PowerSource2.Current.Read(I_Adaptio.PowerSource2.Current);
    AdaptioIo.FromAdaptio.PowerSource2.WireSpeed.Read(I_Adaptio.PowerSource2.WireSpeed);
    AdaptioIo.FromAdaptio.PowerSource2.RegulationType.Read(I_Adaptio.PowerSource2.RegulationType);
    AdaptioIo.FromAdaptio.PowerSource2.WeldMethod.Read(I_Adaptio.PowerSource2.WeldMethod);
    AdaptioIo.FromAdaptio.PowerSource2.AcFrequency.Read(I_Adaptio.PowerSource2.AcFrequency);
    AdaptioIo.FromAdaptio.PowerSource2.AcBalance.Read(I_Adaptio.PowerSource2.AcBalance);
    AdaptioIo.FromAdaptio.PowerSource2.AcOffset.Read(I_Adaptio.PowerSource2.AcOffset);
    AdaptioIo.FromAdaptio.PowerSource2.AcPhaseShift.Read(I_Adaptio.PowerSource2.AcPhaseShift);
    AdaptioIo.FromAdaptio.PowerSource2.StartAdjust.Read(I_Adaptio.PowerSource2.StartAdjust);
    AdaptioIo.FromAdaptio.PowerSource2.RegulationDynamics.Read(I_Adaptio.PowerSource2.RegulationDynamics);
    AdaptioIo.FromAdaptio.PowerSource2.RegulationInductance.Read(I_Adaptio.PowerSource2.RegulationInductance);
    AdaptioIo.FromAdaptio.PowerSource2.IceWireSpeed.Read(I_Adaptio.PowerSource2.IceWireSpeed);

    AdaptioIo.FromAdaptio.WeldAxis.EnableMotion.Read(I_Adaptio.WeldAxis.EnableMotion);
    AdaptioIo.FromAdaptio.WeldAxis.Reset.Read(I_Adaptio.WeldAxis.Reset);
    AdaptioIo.FromAdaptio.WeldAxis.InvalidateReference.Read(I_Adaptio.WeldAxis.InvalidateReference);
    AdaptioIo.FromAdaptio.WeldAxis.ResetLinearObjectDistance.Read(I_Adaptio.WeldAxis.ResetLinearObjectDistance);
    AdaptioIo.FromAdaptio.WeldAxis.MovementType.Read(I_Adaptio.WeldAxis.MovementType);
    AdaptioIo.FromAdaptio.WeldAxis.MovementMode.Read(I_Adaptio.WeldAxis.MovementMode);
    AdaptioIo.FromAdaptio.WeldAxis.Radius.Read(I_Adaptio.WeldAxis.Radius);
    AdaptioIo.FromAdaptio.WeldAxis.Position.Read(I_Adaptio.WeldAxis.Position);
    AdaptioIo.FromAdaptio.WeldAxis.Velocity.Read(I_Adaptio.WeldAxis.Velocity);

    AdaptioIo.FromAdaptio.WeldHeadManipulator.EnableMotion.Read(I_Adaptio.WeldHeadManipulator.EnableMotion);
    AdaptioIo.FromAdaptio.WeldHeadManipulator.Interpolate.Read(I_Adaptio.WeldHeadManipulator.Interpolate);
    AdaptioIo.FromAdaptio.WeldHeadManipulator.XPosition.Read(I_Adaptio.WeldHeadManipulator.XPosition);
    AdaptioIo.FromAdaptio.WeldHeadManipulator.YPosition.Read(I_Adaptio.WeldHeadManipulator.YPosition);
    AdaptioIo.FromAdaptio.WeldHeadManipulator.InterpolatedSpeed.Read(I_Adaptio.WeldHeadManipulator.InterpolatedSpeed);
    AdaptioIo.FromAdaptio.WeldHeadManipulator.XSpeed.Read(I_Adaptio.WeldHeadManipulator.XSpeed);
    AdaptioIo.FromAdaptio.WeldHeadManipulator.YSpeed.Read(I_Adaptio.WeldHeadManipulator.YSpeed);

    AdaptioIo.ToAdaptio.SystemVersions.Major.Write(Q_Adaptio.SystemVersions.Major);
    AdaptioIo.ToAdaptio.SystemVersions.Minor.Write(Q_Adaptio.SystemVersions.Minor);
    AdaptioIo.ToAdaptio.SystemVersions.Patch.Write(Q_Adaptio.SystemVersions.Patch);

    AdaptioIo.ToAdaptio.SystemControl.StartRequest.Write(Q_Adaptio.SystemControl.StartRequest);
    AdaptioIo.ToAdaptio.SystemControl.StopRequest.Write(Q_Adaptio.SystemControl.StopRequest);
    AdaptioIo.ToAdaptio.SystemControl.QuickStopRequest.Write(Q_Adaptio.SystemControl.QuickStopRequest);
    AdaptioIo.ToAdaptio.SystemControl.ShutdownRequest.Write(Q_Adaptio.SystemControl.ShutdownRequest);
    AdaptioIo.ToAdaptio.SystemControl.Heartbeat.Write(Q_Adaptio.SystemControl.Heartbeat);

    AdaptioIo.ToAdaptio.Joystick.State.Write(Q_Adaptio.Joystick.State);

    AdaptioIo.ToAdaptio.FluxSystem.State.Write(Q_Adaptio.FluxSystem.State);

    AdaptioIo.ToAdaptio.WeldControl.State.Write(Q_Adaptio.WeldControl.State);

    AdaptioIo.ToAdaptio.PowerSource1.Enabled.Write(Q_Adaptio.PowerSource1.Enabled);
    AdaptioIo.ToAdaptio.PowerSource1.State.Write(Q_Adaptio.PowerSource1.State);
    AdaptioIo.ToAdaptio.PowerSource1.ActiveVoltage.Write(Q_Adaptio.PowerSource1.ActiveVoltage);
    AdaptioIo.ToAdaptio.PowerSource1.ActiveCurrent.Write(Q_Adaptio.PowerSource1.ActiveCurrent);
    AdaptioIo.ToAdaptio.PowerSource1.ActiveWireSpeed.Write(Q_Adaptio.PowerSource1.ActiveWireSpeed);
    AdaptioIo.ToAdaptio.PowerSource1.ActiveRegulationType.Write(Q_Adaptio.PowerSource1.ActiveRegulationType);
    AdaptioIo.ToAdaptio.PowerSource1.ActiveWeldMethod.Write(Q_Adaptio.PowerSource1.ActiveWeldMethod);
    AdaptioIo.ToAdaptio.PowerSource1.ActiveAcFrequency.Write(Q_Adaptio.PowerSource1.ActiveAcFrequency);
    AdaptioIo.ToAdaptio.PowerSource1.ActiveAcBalance.Write(Q_Adaptio.PowerSource1.ActiveAcBalance);
    AdaptioIo.ToAdaptio.PowerSource1.ActiveAcOffset.Write(Q_Adaptio.PowerSource1.ActiveAcOffset);
    AdaptioIo.ToAdaptio.PowerSource1.ActiveAcPhaseShift.Write(Q_Adaptio.PowerSource1.ActiveAcPhaseShift);
    AdaptioIo.ToAdaptio.PowerSource1.ActiveStartAdjust.Write(Q_Adaptio.PowerSource1.ActiveStartAdjust);
    AdaptioIo.ToAdaptio.PowerSource1.ActiveRegulationDynamics.Write(Q_Adaptio.PowerSource1.ActiveRegulationDynamics);
    AdaptioIo.ToAdaptio.PowerSource1.ActiveRegulationInductance.Write(Q_Adaptio.PowerSource1.ActiveRegulationInductance);
    AdaptioIo.ToAdaptio.PowerSource1.ActiveIceWireSpeed.Write(Q_Adaptio.PowerSource1.ActiveIceWireSpeed);
    AdaptioIo.ToAdaptio.PowerSource1.MeasuredVoltage.Write(Q_Adaptio.PowerSource1.MeasuredVoltage);
    AdaptioIo.ToAdaptio.PowerSource1.MeasuredCurrent.Write(Q_Adaptio.PowerSource1.MeasuredCurrent);
    AdaptioIo.ToAdaptio.PowerSource1.MeasuredWireSpeed.Write(Q_Adaptio.PowerSource1.MeasuredWireSpeed);
    AdaptioIo.ToAdaptio.PowerSource1.MeasuredIceWireSpeed.Write(Q_Adaptio.PowerSource1.MeasuredIceWireSpeed);
    AdaptioIo.ToAdaptio.PowerSource1.CalculatedHeatInput.Write(Q_Adaptio.PowerSource1.CalculatedHeatInput);
    AdaptioIo.ToAdaptio.PowerSource1.CalculatedDepositionRate.Write(Q_Adaptio.PowerSource1.CalculatedDepositionRate);

    AdaptioIo.ToAdaptio.PowerSource2.Enabled.Write(Q_Adaptio.PowerSource2.Enabled);
    AdaptioIo.ToAdaptio.PowerSource2.State.Write(Q_Adaptio.PowerSource2.State);
    AdaptioIo.ToAdaptio.PowerSource2.ActiveVoltage.Write(Q_Adaptio.PowerSource2.ActiveVoltage);
    AdaptioIo.ToAdaptio.PowerSource2.ActiveCurrent.Write(Q_Adaptio.PowerSource2.ActiveCurrent);
    AdaptioIo.ToAdaptio.PowerSource2.ActiveWireSpeed.Write(Q_Adaptio.PowerSource2.ActiveWireSpeed);
    AdaptioIo.ToAdaptio.PowerSource2.ActiveRegulationType.Write(Q_Adaptio.PowerSource2.ActiveRegulationType);
    AdaptioIo.ToAdaptio.PowerSource2.ActiveWeldMethod.Write(Q_Adaptio.PowerSource2.ActiveWeldMethod);
    AdaptioIo.ToAdaptio.PowerSource2.ActiveAcFrequency.Write(Q_Adaptio.PowerSource2.ActiveAcFrequency);
    AdaptioIo.ToAdaptio.PowerSource2.ActiveAcBalance.Write(Q_Adaptio.PowerSource2.ActiveAcBalance);
    AdaptioIo.ToAdaptio.PowerSource2.ActiveAcOffset.Write(Q_Adaptio.PowerSource2.ActiveAcOffset);
    AdaptioIo.ToAdaptio.PowerSource2.ActiveAcPhaseShift.Write(Q_Adaptio.PowerSource2.ActiveAcPhaseShift);
    AdaptioIo.ToAdaptio.PowerSource2.ActiveStartAdjust.Write(Q_Adaptio.PowerSource2.ActiveStartAdjust);
    AdaptioIo.ToAdaptio.PowerSource2.ActiveRegulationDynamics.Write(Q_Adaptio.PowerSource2.ActiveRegulationDynamics);
    AdaptioIo.ToAdaptio.PowerSource2.ActiveRegulationInductance.Write(Q_Adaptio.PowerSource2.ActiveRegulationInductance);
    AdaptioIo.ToAdaptio.PowerSource2.ActiveIceWireSpeed.Write(Q_Adaptio.PowerSource2.ActiveIceWireSpeed);
    AdaptioIo.ToAdaptio.PowerSource2.MeasuredVoltage.Write(Q_Adaptio.PowerSource2.MeasuredVoltage);
    AdaptioIo.ToAdaptio.PowerSource2.MeasuredCurrent.Write(Q_Adaptio.PowerSource2.MeasuredCurrent);
    AdaptioIo.ToAdaptio.PowerSource2.MeasuredWireSpeed.Write(Q_Adaptio.PowerSource2.MeasuredWireSpeed);
    AdaptioIo.ToAdaptio.PowerSource2.MeasuredIceWireSpeed.Write(Q_Adaptio.PowerSource2.MeasuredIceWireSpeed);
    AdaptioIo.ToAdaptio.PowerSource2.CalculatedHeatInput.Write(Q_Adaptio.PowerSource2.CalculatedHeatInput);
    AdaptioIo.ToAdaptio.PowerSource2.CalculatedDepositionRate.Write(Q_Adaptio.PowerSource2.CalculatedDepositionRate);

    AdaptioIo.ToAdaptio.WeldAxis.InPosition.Write(Q_Adaptio.WeldAxis.InPosition);
    AdaptioIo.ToAdaptio.WeldAxis.ReferenceValid.Write(Q_Adaptio.WeldAxis.ReferenceValid);
    AdaptioIo.ToAdaptio.WeldAxis.State.Write(Q_Adaptio.WeldAxis.State);
    AdaptioIo.ToAdaptio.WeldAxis.ErrorCode.Write(Q_Adaptio.WeldAxis.ErrorCode);
    AdaptioIo.ToAdaptio.WeldAxis.AxisType.Write(Q_Adaptio.WeldAxis.AxisType);
    AdaptioIo.ToAdaptio.WeldAxis.Radius.Write(Q_Adaptio.WeldAxis.Radius);
    AdaptioIo.ToAdaptio.WeldAxis.Position.Write(Q_Adaptio.WeldAxis.Position);
    AdaptioIo.ToAdaptio.WeldAxis.LinearObjectDistance.Write(Q_Adaptio.WeldAxis.LinearObjectDistance);
    AdaptioIo.ToAdaptio.WeldAxis.Velocity.Write(Q_Adaptio.WeldAxis.Velocity);

    AdaptioIo.ToAdaptio.WeldHeadManipulator.InPosition.Write(Q_Adaptio.WeldHeadManipulator.InPosition);
    AdaptioIo.ToAdaptio.WeldHeadManipulator.State.Write(Q_Adaptio.WeldHeadManipulator.State);
    AdaptioIo.ToAdaptio.WeldHeadManipulator.XPosition.Write(Q_Adaptio.WeldHeadManipulator.XPosition);
    AdaptioIo.ToAdaptio.WeldHeadManipulator.YPosition.Write(Q_Adaptio.WeldHeadManipulator.YPosition);
    AdaptioIo.ToAdaptio.WeldHeadManipulator.InterpolatedSpeed.Write(Q_Adaptio.WeldHeadManipulator.InterpolatedSpeed);
    AdaptioIo.ToAdaptio.WeldHeadManipulator.XVelocity.Write(Q_Adaptio.WeldHeadManipulator.XVelocity);
    AdaptioIo.ToAdaptio.WeldHeadManipulator.YVelocity.Write(Q_Adaptio.WeldHeadManipulator.YVelocity);
END_PROGRAM