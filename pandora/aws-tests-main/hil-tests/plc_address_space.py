class PositioningCommand:
    def __init__(self, prefix: str):
        self.Execute = prefix + "Execute.Value"
        self.CommandType = prefix + "CommandType.Value"
        self.Position = prefix + "Position.Value"
        self.Velocity = prefix + "Velocity.Value"
        self.Acceleration = prefix + "Acceleration.Value"
        self.Deceleration = prefix + "Deceleration.Value"
        self.Jerk = prefix + "Jerk.Value"


class HomingCommand:
    def __init__(self, prefix: str):
        self.Execute = prefix + "Execute.Value"
        self.HomingType = prefix + "HomingType.Value"
        self.Position = prefix + "Position.Value"


class PositioningAxisCommands:
    def __init__(self, prefix: str):
        self.Enable = prefix + "Enable.Value"
        self.Disable = prefix + "Disable.Value"
        self.Halt = prefix + "Halt.Value"
        self.JogPositive = prefix + "JogPositive.Value"
        self.JogNegative = prefix + "JogNegative.Value"
        self.PositioningCommand = PositioningCommand(prefix + "PositioningCommand.")
        self.HomingCommand = HomingCommand(prefix + "HomingCommand.")


class PositioningAxisParameters:
    def __init__(self, prefix: str):
        self.JogSpeed = prefix + "JogSpeed.Value"
        self.JogHighSpeed = prefix + "JogHighSpeed.Value"


class PositioningAxisStatus:
    def __init__(self, prefix: str):
        self.Enabled = prefix + "Enabled.Value"
        self.Error = prefix + "Error.Value"
        self.ErrorId = prefix + "ErrorId.Value"
        self.Homed = prefix + "Homed.Value"
        self.Busy = prefix + "Busy.Value"
        self.Position = prefix + "Position.Value"
        self.Velocity = prefix + "Velocity.Value"


class PositioningAxisInputs:
    def __init__(self, prefix: str):
        self.Commands = PositioningAxisCommands(prefix + "Commands.")
        self.Parameters = PositioningAxisParameters(prefix + "Parameters.")


class PositioningAxisOutputs:
    def __init__(self, prefix: str):
        self.Status = PositioningAxisStatus(prefix + "Status.")


class PowerSourceWriteAsync:
    def __init__(self, prefix: str):
        self.Execute = prefix + "Execute.Value"
        self.Index = prefix + "Index.Value"
        self.Value = prefix + "Value.Value"


class PowerSourceReadAsync:
    def __init__(self, prefix: str):
        self.Execute = prefix + "Execute.Value"
        self.Index = prefix + "Index.Value"


class PowerSourceCommands:
    def __init__(self, prefix: str):
        self.AcquireControl = prefix + "AcquireControl.Value"
        self.StartWeld = prefix + "StartWeld.Value"
        self.StopWeld = prefix + "StopWeld.Value"
        self.WriteAsync = PowerSourceWriteAsync(prefix + "WriteAsync.")
        self.ReadAsync = PowerSourceReadAsync(prefix + "ReadAsync.")
        self.ReadNodes = prefix + "ReadNodes.Value"
        self.UpdateStatus = prefix + "UpdateStatus.Value"


class PowerSourceParameters:
    def __init__(self, prefix: str):
        self.WeldMethod = prefix + "WeldMethod.Value"
        self.RegulationType = prefix + "RegulationType.Value"
        self.Voltage = prefix + "Voltage.Value"
        self.Current = prefix + "Current.Value"


class PowerSourceInputs:
    def __init__(self, prefix: str):
        self.Commands = PowerSourceCommands(prefix + "Commands.")
        self.Parameters = PowerSourceParameters(prefix + "Parameters.")


class PowerSourceStatus:
    def __init__(self, prefix: str):
        self.InControl = prefix + "InControl.Value"
        self.ReadyToWeld = prefix + "ReadyToWeld.Value"
        self.Error = prefix + "Error.Value"


class PowerSourceOutputs:
    def __init__(self, prefix: str):
        self.Status = PowerSourceStatus(prefix + "Status.")


class HmiInputs:
    def __init__(self, prefix: str):
        self.HorizontalSlide = PositioningAxisInputs(prefix + "HorizontalSlide.")
        self.VerticalSlide = PositioningAxisInputs(prefix + "VerticalSlide.")
        self.PowerSource1 = PowerSourceInputs(prefix + "PowerSource1.")
        self.PowerSource2 = PowerSourceInputs(prefix + "PowerSource2.")


class HmiOutputs:
    def __init__(self, prefix: str):
        self.HorizontalSlide = PositioningAxisOutputs(prefix + "HorizontalSlide.")
        self.VerticalSlide = PositioningAxisOutputs(prefix + "VerticalSlide.")
        self.PowerSource1 = PowerSourceOutputs(prefix + "PowerSource1.")
        self.PowerSource2 = PowerSourceOutputs(prefix + "PowerSource2.")


class Hmi:
    def __init__(self, prefix: str):
        self.Inputs = HmiInputs(prefix + "Inputs.")
        self.Outputs = HmiOutputs(prefix + "Outputs.")


class AdaptioInputs:
    def __init__(self, prefix: str):
        return


class AdaptioOutputs:
    def __init__(self, prefix: str):
        return


class Adaptio:
    def __init__(self, prefix: str):
        self.Inputs = AdaptioInputs(prefix + "Inputs.")
        self.Outputs = AdaptioOutputs(prefix + "Outputs.")

class IoInputs:
    def __init__(self, prefix: str):
        self.DI_MotionJoystick_Up = prefix + "DI_MotionJoystick_Up"
        self.DI_MotionJoystick_Down = prefix + "DI_MotionJoystick_Down"
        self.DI_MotionJoystick_Triangle = prefix + "DI_MotionJoystick_Triangle"
        self.DI_MotionJoystick_Square = prefix + "DI_MotionJoystick_Square"
        self.DI_PushButton_HighSpeed = prefix + "DI_PushButton_HighSpeed"

class IoOutputs:
    def __init__(self, prefix: str):
        self.DQ_PushButton_HighSpeed = prefix + "DQ_PushButton_HighSpeed"

class Io:
    def __init__(self, prefix: str):
        self.Inputs = IoInputs(prefix + "")
        self.Outputs = IoOutputs(prefix + "")


class Addresses:
    def __init__(self):
        self.Hmi = Hmi("\"TGlobalVariablesDB\".WebApiData.")
        self.Io = Io("\"TGlobalVariablesDB\".")
