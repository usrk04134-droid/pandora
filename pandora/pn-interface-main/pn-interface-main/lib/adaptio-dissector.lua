-- Protocol definitions
local pn_interface_input = Proto("pn_interface_input", "Adaptio PN Interface Input")
local pn_interface_output = Proto("pn_interface_output", "Adaptio PN Interface Output")

-- Field definitions
local f_profinet_preamble = ProtoField.uint16("pn_interface.preamble", "Preamble", base.HEX)
local f_profiet_predata = ProtoField.uint8("pn_interface.predata", "Predata", base.HEX)
local f_profinet_postamble = ProtoField.uint32("pn_interface.postamble", "Postamble", base.HEX)
local f_profiet_postdata = ProtoField.uint8("pn_interface.postdata", "Postdata", base.HEX)

-- Field definitions for AdaptioInput
local f_adaptio_in_commands = ProtoField.uint32("pn_interface.adaptio_in.commands", "Commands", base.HEX)
local f_adaptio_in_cmd_start = ProtoField.bool("pn_interface.adaptio_in.commands.start", "Start", 32, nil, 0x00000001)
local f_adaptio_in_cmd_stop = ProtoField.bool("pn_interface.adaptio_in.commands.stop", "Stop", 32, nil, 0x00000002)
local f_adaptio_in_cmd_shutdown = ProtoField.bool("pn_interface.adaptio_in.commands.shutdown", "Shutdown", 32, nil, 0x00000004)
local f_adaptio_in_sequence_type = ProtoField.uint32("pn_interface.adaptio_in.sequence_type", "Sequence Type", base.DEC)
local f_adaptio_in_heartbeat = ProtoField.uint32("pn_interface.adaptio_in.heartbeat", "Heartbeat", base.DEC)
local f_adaptio_in_reserved2 = ProtoField.uint32("pn_interface.adaptio_in.reserved2", "Reserved2", base.HEX)
local f_adaptio_in_reserved3 = ProtoField.uint32("pn_interface.adaptio_in.reserved3", "Reserved3", base.HEX)
local f_adaptio_in_reserved4 = ProtoField.uint32("pn_interface.adaptio_in.reserved4", "Reserved4", base.HEX)

-- Field definitions for AdaptioOutput
local f_adaptio_out_status = ProtoField.uint32("pn_interface.adaptio_out.status", "Status", base.HEX)
local f_adaptio_out_ready = ProtoField.bool("pn_interface.adaptio_out.status.ready", "Ready", 32, nil, 0x00000001)
local f_adaptio_out_active = ProtoField.bool("pn_interface.adaptio_out.status.active", "Active", 32, nil, 0x00000002)
local f_adaptio_out_error = ProtoField.bool("pn_interface.adaptio_out.status.error", "Error", 32, nil, 0x00000004)
local f_adaptio_out_ready_tracking = ProtoField.bool("pn_interface.adaptio_out.status.ready_for_tracking", "Ready for Tracking", 32, nil, 0x00000008)
local f_adaptio_out_ready_abp = ProtoField.bool("pn_interface.adaptio_out.status.ready_for_abp", "Ready for ABP", 32, nil, 0x00000010)
local f_adaptio_out_ready_cap = ProtoField.bool("pn_interface.adaptio_out.status.ready_for_cap", "Ready for Cap", 32, nil, 0x00000020)
local f_adaptio_out_ready_auto_cap = ProtoField.bool("pn_interface.adaptio_out.status.ready_for_auto_cap", "Ready for Auto Cap", 32, nil, 0x00000040)
local f_adaptio_out_active_sequence = ProtoField.uint32("pn_interface.adaptio_out.active_sequence_type", "Active Sequence Type", base.DEC)
local f_adaptio_out_heartbeat = ProtoField.uint32("pn_interface.adaptio_out.heartbeat", "Heartbeat", base.DEC)
local f_adaptio_out_reserved7 = ProtoField.uint32("pn_interface.adaptio_out.reserved7", "Reserved7", base.HEX)
local f_adaptio_out_reserved8 = ProtoField.uint32("pn_interface.adaptio_out.reserved8", "Reserved8", base.HEX)

-- Field definitions for AxisInput
local f_axis_in_status = ProtoField.uint32("pn_interface.axis_in.status", "Status", base.HEX)
local f_axis_in_enabled = ProtoField.bool("pn_interface.axis_in.status.enabled", "Enabled", 32, nil, 0x00000001)
local f_axis_in_busy = ProtoField.bool("pn_interface.axis_in.status.busy", "Busy", 32, nil, 0x00000002)
local f_axis_in_error = ProtoField.bool("pn_interface.axis_in.status.error", "Error", 32, nil, 0x00000004)
local f_axis_in_in_position = ProtoField.bool("pn_interface.axis_in.status.in_position", "In Position", 32, nil, 0x00000008)
local f_axis_in_homed = ProtoField.bool("pn_interface.axis_in.status.homed", "Homed", 32, nil, 0x00000010)
local f_axis_in_type = ProtoField.bool("pn_interface.axis_in.status.type", "Type", 32, nil, 0x00000020)
local f_axis_in_following = ProtoField.bool("pn_interface.axis_in.status.following_position", "Following Position", 32, nil, 0x00000040)
local f_axis_in_id = ProtoField.uint32("pn_interface.axis_in.axis_id", "Axis ID", base.DEC)
local f_axis_in_position = ProtoField.float("pn_interface.axis_in.position", "Current Position")
local f_axis_in_velocity = ProtoField.float("pn_interface.axis_in.velocity", "Current Velocity")
local f_axis_in_reserved17 = ProtoField.uint32("pn_interface.axis_in.reserved17", "Reserved17", base.HEX)
local f_axis_in_reserved18 = ProtoField.uint32("pn_interface.axis_in.reserved18", "Reserved18", base.HEX)
local f_axis_in_reserved19 = ProtoField.uint32("pn_interface.axis_in.reserved19", "Reserved19", base.HEX)
local f_axis_in_reserved20 = ProtoField.uint32("pn_interface.axis_in.reserved20", "Reserved20", base.HEX)

-- Field definitions for AxisOutput
local f_axis_out_commands = ProtoField.uint32("pn_interface.axis_out.commands", "Commands", base.HEX)
local f_axis_out_execute = ProtoField.bool("pn_interface.axis_out.commands.execute", "Execute", 32, nil, 0x00000001)
local f_axis_out_stop = ProtoField.bool("pn_interface.axis_out.commands.stop", "Stop", 32, nil, 0x00000002)
local f_axis_out_follow = ProtoField.bool("pn_interface.axis_out.commands.follow_position", "Follow Position", 32, nil, 0x00000004)
local f_axis_out_id = ProtoField.uint32("pn_interface.axis_out.axis_id", "Axis ID", base.DEC)
local f_axis_out_position = ProtoField.float("pn_interface.axis_out.position", "Position Setpoint")
local f_axis_out_velocity = ProtoField.float("pn_interface.axis_out.velocity", "Velocity Setpoint")
local f_axis_out_acceleration = ProtoField.float("pn_interface.axis_out.acceleration", "Acceleration Setpoint")
local f_axis_out_jerk = ProtoField.float("pn_interface.axis_out.jerk", "Jerk Setpoint")
local f_axis_out_reserved21 = ProtoField.uint32("pn_interface.axis_out.reserved21", "Reserved21", base.HEX)
local f_axis_out_reserved22 = ProtoField.uint32("pn_interface.axis_out.reserved22", "Reserved22", base.HEX)
local f_axis_out_reserved23 = ProtoField.uint32("pn_interface.axis_out.reserved23", "Reserved23", base.HEX)
local f_axis_out_reserved24 = ProtoField.uint32("pn_interface.axis_out.reserved24", "Reserved24", base.HEX)

-- Field definitions for PowerSourceInput
local f_ps_in_status = ProtoField.uint32("pn_interface.power_source_in.status", "Status", base.HEX)
local f_ps_in_ready = ProtoField.bool("pn_interface.power_source_in.status.ready_to_start", "Ready to Start", 32, nil, 0x00000001)
local f_ps_in_welding = ProtoField.bool("pn_interface.power_source_in.status.in_welding_sequence", "In Welding Sequence", 32, nil, 0x00000002)
local f_ps_in_arcing = ProtoField.bool("pn_interface.power_source_in.status.arcing", "Arcing", 32, nil, 0x00000004)
local f_ps_in_start_failure = ProtoField.bool("pn_interface.power_source_in.status.start_failure", "Start Failure", 32, nil, 0x00000008)
local f_ps_in_error = ProtoField.bool("pn_interface.power_source_in.status.error", "Error", 32, nil, 0x00000010)
local f_ps_in_deviation = ProtoField.bool("pn_interface.power_source_in.status.deviation_setpoint_actual", "Deviation Setpoint Actual", 32, nil, 0x00000020)
local f_ps_in_twin_wire = ProtoField.bool("pn_interface.power_source_in.status.twin_wire", "Twin Wire", 32, nil, 0x00000040)
local f_ps_in_voltage = ProtoField.float("pn_interface.power_source_in.voltage", "Actual Voltage")
local f_ps_in_current = ProtoField.float("pn_interface.power_source_in.current", "Actual Current")
local f_ps_in_wire_speed = ProtoField.float("pn_interface.power_source_in.wire_speed", "Actual Wire Speed (cm/min)")
local f_ps_in_ice_wire_speed = ProtoField.float("pn_interface.power_source_in.ice_wire_speed", "Actual ICE Wire Speed")
local f_ps_in_deposition_rate = ProtoField.float("pn_interface.power_source_in.deposition_rate", "Actual Deposition Rate")
local f_ps_in_heat_input = ProtoField.float("pn_interface.power_source_in.heat_input", "Actual Heat Input")
local f_ps_in_distance_leading = ProtoField.float("pn_interface.power_source_in.distance_to_leading_torch", "Distance to Leading Torch (mm)")
local f_ps_in_wire_diameter = ProtoField.float("pn_interface.power_source_in.wire_diameter", "Wire Diameter (mm)")
local f_ps_in_reserved26 = ProtoField.uint32("pn_interface.power_source_in.reserved26", "Reserved26", base.HEX)
local f_ps_in_reserved27 = ProtoField.uint32("pn_interface.power_source_in.reserved27", "Reserved27", base.HEX)
local f_ps_in_reserved28 = ProtoField.uint32("pn_interface.power_source_in.reserved28", "Reserved28", base.HEX)

-- Field definitions for PowerSourceOutput
local f_ps_out_commands = ProtoField.uint32("pn_interface.power_source_out.commands", "Commands", base.HEX)
local f_ps_out_start = ProtoField.bool("pn_interface.power_source_out.commands.start", "Start", 32, nil, 0x00000001)
local f_ps_out_quick_stop = ProtoField.bool("pn_interface.power_source_out.commands.quick_stop", "Quick Stop", 32, nil, 0x00000002)
local f_ps_out_wire_down = ProtoField.bool("pn_interface.power_source_out.commands.wire_down", "Wire Down", 32, nil, 0x00000004)
local f_ps_out_wire_up = ProtoField.bool("pn_interface.power_source_out.commands.wire_up", "Wire Up", 32, nil, 0x00000008)
local f_ps_out_ice_wire_down = ProtoField.bool("pn_interface.power_source_out.commands.ice_wire_down", "ICE Wire Down", 32, nil, 0x00000010)
local f_ps_out_ice_wire_up = ProtoField.bool("pn_interface.power_source_out.commands.ice_wire_up", "ICE Wire Up", 32, nil, 0x00000020)
local f_ps_out_method = ProtoField.uint32("pn_interface.power_source_out.method", "Method", base.DEC)
local f_ps_out_regulation_type = ProtoField.uint32("pn_interface.power_source_out.regulation_type", "Regulation Type", base.DEC)
local f_ps_out_start_adjust = ProtoField.uint32("pn_interface.power_source_out.start_adjust", "Start Adjust", base.DEC)
local f_ps_out_start_type = ProtoField.uint32("pn_interface.power_source_out.start_type", "Start Type", base.DEC)
local f_ps_out_voltage = ProtoField.float("pn_interface.power_source_out.voltage", "Voltage Setpoint")
local f_ps_out_current = ProtoField.float("pn_interface.power_source_out.current", "Current Setpoint")
local f_ps_out_wire_speed = ProtoField.float("pn_interface.power_source_out.wire_speed", "Wire Speed Setpoint")
local f_ps_out_ice_wire_speed = ProtoField.float("pn_interface.power_source_out.ice_wire_speed", "ICE Wire Speed Setpoint")
local f_ps_out_ac_frequency = ProtoField.float("pn_interface.power_source_out.ac_frequency", "AC Frequency Setpoint")
local f_ps_out_ac_offset = ProtoField.float("pn_interface.power_source_out.ac_offset", "AC Offset Setpoint")
local f_ps_out_ac_phase_shift = ProtoField.float("pn_interface.power_source_out.ac_phase_shift", "AC Phase Shift Setpoint")
local f_ps_out_crater_fill_time = ProtoField.float("pn_interface.power_source_out.crater_fill_time", "Crater Fill Time")
local f_ps_out_burn_back_time = ProtoField.float("pn_interface.power_source_out.burn_back_time", "Burn Back Time")
local f_ps_out_reserved29 = ProtoField.uint32("pn_interface.power_source_out.reserved29", "Reserved29", base.HEX)
local f_ps_out_reserved30 = ProtoField.uint32("pn_interface.power_source_out.reserved30", "Reserved30", base.HEX)
local f_ps_out_reserved31 = ProtoField.uint32("pn_interface.power_source_out.reserved31", "Reserved31", base.HEX)
local f_ps_out_reserved32 = ProtoField.uint32("pn_interface.power_source_out.reserved32", "Reserved32", base.HEX)

-- Field definitions for TrackInput
local f_track_in_horizontal_offset = ProtoField.float("pn_interface.track_in.horizontal_offset", "Horizontal Offset")
local f_track_in_vertical_offset = ProtoField.float("pn_interface.track_in.vertical_offset", "Vertical Offset")
local f_track_in_joint_tracking_mode = ProtoField.uint32("pn_interface.track_in.joint_tracking_mode", "Joint Tracking Mode", base.DEC)
local f_track_in_weld_object_radius = ProtoField.float("pn_interface.track_in.weld_object_radius", "Weld Object Radius (mm)")
local f_track_in_edge_tracker_value = ProtoField.float("pn_interface.track_in.edge_tracker_value", "Edge Tracker Value (mm)")
local f_track_in_status = ProtoField.uint32("pn_interface.track_in.status", "Status", base.HEX)
local f_track_in_edge_valid = ProtoField.bool("pn_interface.track_in.status.edge_tracker_value_valid", "Edge Tracker Value Valid", 32, nil, 0x00000001)
local f_track_in_reserved36 = ProtoField.uint32("pn_interface.track_in.reserved36", "Reserved36", base.HEX)

-- Field definitions for TrackOutput
local f_track_out_status = ProtoField.uint32("pn_interface.track_out.status", "Status", base.HEX)
local f_track_out_active = ProtoField.bool("pn_interface.track_out.status.active", "Tracking Active", 32, nil, 0x00000001)
local f_track_out_shallow = ProtoField.bool("pn_interface.track_out.status.shallow", "Groove Shallow", 32, nil, 0x00000002)
local f_track_out_error = ProtoField.bool("pn_interface.track_out.status.error", "Tracking Error", 32, nil, 0x00000004)
local f_track_out_active_horizontal_offset = ProtoField.float("pn_interface.track_out.active_horizontal_offset", "Active Horizontal Offset")
local f_track_out_active_vertical_offset = ProtoField.float("pn_interface.track_out.active_vertical_offset", "Active Vertical Offset")
local f_track_out_active_joint_tracking_mode = ProtoField.uint32("pn_interface.track_out.active_joint_tracking_mode", "Active Joint Tracking Mode", base.DEC)
local f_track_out_reserved36 = ProtoField.uint32("pn_interface.track_out.reserved36", "Reserved36", base.HEX)

pn_interface_input.fields = {
    f_adaptio_in_commands,
    f_adaptio_in_cmd_start,
    f_adaptio_in_cmd_stop,
    f_adaptio_in_cmd_shutdown,
    f_adaptio_in_sequence_type,
    f_adaptio_in_heartbeat,
    f_adaptio_in_reserved2,
    f_adaptio_in_reserved3,
    f_adaptio_in_reserved4,

    f_axis_in_status,
    f_axis_in_enabled,
    f_axis_in_busy,
    f_axis_in_error,
    f_axis_in_in_position,
    f_axis_in_homed,
    f_axis_in_type,
    f_axis_in_following,
    f_axis_in_id,
    f_axis_in_position,
    f_axis_in_velocity,
    f_axis_in_reserved17,
    f_axis_in_reserved18,
    f_axis_in_reserved19,
    f_axis_in_reserved20,

    f_ps_in_status,
    f_ps_in_ready,
    f_ps_in_welding,
    f_ps_in_arcing,
    f_ps_in_start_failure,
    f_ps_in_error,
    f_ps_in_deviation,
    f_ps_in_twin_wire,
    f_ps_in_voltage,
    f_ps_in_current,
    f_ps_in_wire_speed,
    f_ps_in_ice_wire_speed,
    f_ps_in_deposition_rate,
    f_ps_in_heat_input,
    f_ps_in_distance_leading,
    f_ps_in_wire_diameter,
    f_ps_in_reserved26,
    f_ps_in_reserved27,
    f_ps_in_reserved28,

    f_track_in_status,
    f_track_in_edge_valid,
    f_track_in_horizontal_offset,
    f_track_in_vertical_offset,
    f_track_in_joint_tracking_mode,
    f_track_in_weld_object_radius,
    f_track_in_edge_tracker_value,
    f_track_in_reserved36
}

pn_interface_output.fields = {
    f_adaptio_out_status,
    f_adaptio_out_ready,
    f_adaptio_out_active,
    f_adaptio_out_error,
    f_adaptio_out_ready_tracking,
    f_adaptio_out_ready_abp,
    f_adaptio_out_ready_cap,
    f_adaptio_out_ready_auto_cap,
    f_adaptio_out_active_sequence,
    f_adaptio_out_heartbeat,
    f_adaptio_out_reserved7,
    f_adaptio_out_reserved8,

    f_axis_out_commands,
    f_axis_out_execute,
    f_axis_out_stop,
    f_axis_out_follow,
    f_axis_out_id,
    f_axis_out_position,
    f_axis_out_velocity,
    f_axis_out_acceleration,
    f_axis_out_jerk,
    f_axis_out_reserved21,
    f_axis_out_reserved22,
    f_axis_out_reserved23,
    f_axis_out_reserved24,

    f_ps_out_commands,
    f_ps_out_start,
    f_ps_out_quick_stop,
    f_ps_out_wire_down,
    f_ps_out_wire_up,
    f_ps_out_ice_wire_down,
    f_ps_out_ice_wire_up,
    f_ps_out_method,
    f_ps_out_regulation_type,
    f_ps_out_start_adjust,
    f_ps_out_start_type,
    f_ps_out_voltage,
    f_ps_out_current,
    f_ps_out_wire_speed,
    f_ps_out_ice_wire_speed,
    f_ps_out_ac_frequency,
    f_ps_out_ac_offset,
    f_ps_out_ac_phase_shift,
    f_ps_out_crater_fill_time,
    f_ps_out_burn_back_time,
    f_ps_out_reserved29,
    f_ps_out_reserved30,
    f_ps_out_reserved31,
    f_ps_out_reserved32,

    f_track_out_status,
    f_track_out_active,
    f_track_out_shallow,
    f_track_out_error,
    f_track_out_active_horizontal_offset,
    f_track_out_active_vertical_offset,
    f_track_out_active_joint_tracking_mode,
    f_track_out_reserved36
}

-- Helper to add float field and increment offset
local function add_float_field(tree, field, buffer, offset)
    tree:add(field, buffer(offset, 4))
    return offset + 4
end

-- Shared parsing blocks for reusable structures
local function parse_adaptio_input(tree, buffer, offset)
    tree:add(f_adaptio_in_commands, buffer(offset, 4))
    tree:add(f_adaptio_in_cmd_start, buffer(offset, 4))
    tree:add(f_adaptio_in_cmd_stop, buffer(offset, 4))
    tree:add(f_adaptio_in_cmd_shutdown, buffer(offset, 4)); offset = offset + 4
    tree:add(f_adaptio_in_sequence_type, buffer(offset, 4)); offset = offset + 4
    tree:add(f_adaptio_in_heartbeat, buffer(offset, 4)); offset = offset + 4
    tree:add(f_adaptio_in_reserved2, buffer(offset, 4)); offset = offset + 4
    tree:add(f_adaptio_in_reserved3, buffer(offset, 4)); offset = offset + 4
    tree:add(f_adaptio_in_reserved4, buffer(offset, 4)); offset = offset + 4
    return offset
end

local function parse_adaptio_output(tree, buffer, offset)
    tree:add(f_adaptio_out_status, buffer(offset, 4))
    tree:add(f_adaptio_out_ready, buffer(offset, 4))
    tree:add(f_adaptio_out_active, buffer(offset, 4))
    tree:add(f_adaptio_out_error, buffer(offset, 4))
    tree:add(f_adaptio_out_ready_tracking, buffer(offset, 4))
    tree:add(f_adaptio_out_ready_abp, buffer(offset, 4))
    tree:add(f_adaptio_out_ready_cap, buffer(offset, 4))
    tree:add(f_adaptio_out_ready_auto_cap, buffer(offset, 4)); offset = offset + 4
    tree:add(f_adaptio_out_active_sequence, buffer(offset, 4)); offset = offset + 4
    tree:add(f_adaptio_out_heartbeat, buffer(offset, 4)); offset = offset + 4
    tree:add(f_adaptio_out_reserved7, buffer(offset, 4)); offset = offset + 4
    tree:add(f_adaptio_out_reserved8, buffer(offset, 4)); offset = offset + 4
    return offset
end

local function parse_axis_input(tree, buffer, offset)
    tree:add(f_axis_in_status, buffer(offset, 4))
    tree:add(f_axis_in_enabled, buffer(offset, 4))
    tree:add(f_axis_in_busy, buffer(offset, 4))
    tree:add(f_axis_in_error, buffer(offset, 4))
    tree:add(f_axis_in_in_position, buffer(offset, 4))
    tree:add(f_axis_in_homed, buffer(offset, 4))
    tree:add(f_axis_in_type, buffer(offset, 4))
    tree:add(f_axis_in_following, buffer(offset, 4))
    offset = offset + 4
    tree:add(f_axis_in_id, buffer(offset, 4)); offset = offset + 4
    offset = add_float_field(tree, f_axis_in_position, buffer, offset)
    offset = add_float_field(tree, f_axis_in_velocity, buffer, offset)
    tree:add(f_axis_in_reserved17, buffer(offset, 4)); offset = offset + 4
    tree:add(f_axis_in_reserved18, buffer(offset, 4)); offset = offset + 4
    tree:add(f_axis_in_reserved19, buffer(offset, 4)); offset = offset + 4
    tree:add(f_axis_in_reserved20, buffer(offset, 4)); offset = offset + 4
    return offset
end

local function parse_axis_output(tree, buffer, offset)
    tree:add(f_axis_out_commands, buffer(offset, 4))
    tree:add(f_axis_out_execute, buffer(offset, 4))
    tree:add(f_axis_out_stop, buffer(offset, 4))
    tree:add(f_axis_out_follow, buffer(offset, 4)); offset = offset + 4
    tree:add(f_axis_out_id, buffer(offset, 4)); offset = offset + 4
    offset = add_float_field(tree, f_axis_out_position, buffer, offset)
    offset = add_float_field(tree, f_axis_out_velocity, buffer, offset)
    offset = add_float_field(tree, f_axis_out_acceleration, buffer, offset)
    offset = add_float_field(tree, f_axis_out_jerk, buffer, offset)
    tree:add(f_axis_out_reserved21, buffer(offset, 4)); offset = offset + 4
    tree:add(f_axis_out_reserved22, buffer(offset, 4)); offset = offset + 4
    tree:add(f_axis_out_reserved23, buffer(offset, 4)); offset = offset + 4
    tree:add(f_axis_out_reserved24, buffer(offset, 4)); offset = offset + 4
    return offset
end

local function parse_ps_input(tree, buffer, offset)
    tree:add(f_ps_in_status, buffer(offset, 4))
    tree:add(f_ps_in_ready, buffer(offset, 4))
    tree:add(f_ps_in_welding, buffer(offset, 4))
    tree:add(f_ps_in_arcing, buffer(offset, 4))
    tree:add(f_ps_in_start_failure, buffer(offset, 4))
    tree:add(f_ps_in_error, buffer(offset, 4))
    tree:add(f_ps_in_deviation, buffer(offset, 4))
    tree:add(f_ps_in_twin_wire, buffer(offset, 4)); offset = offset + 4
    offset = add_float_field(tree, f_ps_in_voltage, buffer, offset)
    offset = add_float_field(tree, f_ps_in_current, buffer, offset)
    offset = add_float_field(tree, f_ps_in_wire_speed, buffer, offset)
    offset = add_float_field(tree, f_ps_in_ice_wire_speed, buffer, offset)
    offset = add_float_field(tree, f_ps_in_deposition_rate, buffer, offset)
    offset = add_float_field(tree, f_ps_in_heat_input, buffer, offset)
    offset = add_float_field(tree, f_ps_in_distance_leading, buffer, offset)
    offset = add_float_field(tree, f_ps_in_wire_diameter, buffer, offset)
    tree:add(f_ps_in_reserved26, buffer(offset, 4)); offset = offset + 4
    tree:add(f_ps_in_reserved27, buffer(offset, 4)); offset = offset + 4
    tree:add(f_ps_in_reserved28, buffer(offset, 4)); offset = offset + 4
    return offset
end

local function parse_ps_output(tree, buffer, offset)
    tree:add(f_ps_out_commands, buffer(offset, 4))
    tree:add(f_ps_out_start, buffer(offset, 4))
    tree:add(f_ps_out_quick_stop, buffer(offset, 4))
    tree:add(f_ps_out_wire_down, buffer(offset, 4))
    tree:add(f_ps_out_wire_up, buffer(offset, 4))
    tree:add(f_ps_out_ice_wire_down, buffer(offset, 4))
    tree:add(f_ps_out_ice_wire_up, buffer(offset, 4)); offset = offset + 4
    tree:add(f_ps_out_method, buffer(offset, 4)); offset = offset + 4
    tree:add(f_ps_out_regulation_type, buffer(offset, 4)); offset = offset + 4
    tree:add(f_ps_out_start_adjust, buffer(offset, 4)); offset = offset + 4
    tree:add(f_ps_out_start_type, buffer(offset, 4)); offset = offset + 4
    offset = add_float_field(tree, f_ps_out_voltage, buffer, offset)
    offset = add_float_field(tree, f_ps_out_current, buffer, offset)
    offset = add_float_field(tree, f_ps_out_wire_speed, buffer, offset)
    offset = add_float_field(tree, f_ps_out_ice_wire_speed, buffer, offset)
    offset = add_float_field(tree, f_ps_out_ac_frequency, buffer, offset)
    offset = add_float_field(tree, f_ps_out_ac_offset, buffer, offset)
    offset = add_float_field(tree, f_ps_out_ac_phase_shift, buffer, offset)
    offset = add_float_field(tree, f_ps_out_crater_fill_time, buffer, offset)
    offset = add_float_field(tree, f_ps_out_burn_back_time, buffer, offset)
    tree:add(f_ps_out_reserved29, buffer(offset, 4)); offset = offset + 4
    tree:add(f_ps_out_reserved30, buffer(offset, 4)); offset = offset + 4
    tree:add(f_ps_out_reserved31, buffer(offset, 4)); offset = offset + 4
    tree:add(f_ps_out_reserved32, buffer(offset, 4)); offset = offset + 4
    return offset
end

local function parse_tracking_input(tree, buffer, offset)
    offset = add_float_field(tree, f_track_in_horizontal_offset, buffer, offset)
    offset = add_float_field(tree, f_track_in_vertical_offset, buffer, offset)
    tree:add(f_track_in_joint_tracking_mode, buffer(offset, 4)); offset = offset + 4
    offset = add_float_field(tree, f_track_in_weld_object_radius, buffer, offset)
    offset = add_float_field(tree, f_track_in_edge_tracker_value, buffer, offset)
    tree:add(f_track_in_edge_valid, buffer(offset, 4)); offset = offset + 4
    tree:add(f_track_in_reserved36, buffer(offset, 4)); offset = offset + 4
    return offset
end

local function parse_tracking_output(tree, buffer, offset)
    tree:add(f_track_out_status, buffer(offset, 4))
    tree:add(f_track_out_active, buffer(offset, 4))
    tree:add(f_track_out_shallow, buffer(offset, 4))
    tree:add(f_track_out_error, buffer(offset, 4)); offset = offset + 4
    offset = add_float_field(tree, f_track_out_active_horizontal_offset, buffer, offset)
    offset = add_float_field(tree, f_track_out_active_vertical_offset, buffer, offset)
    tree:add(f_track_out_active_joint_tracking_mode, buffer(offset, 4)); offset = offset + 4
    tree:add(f_track_out_reserved36, buffer(offset, 4)); offset = offset + 4
    return offset
end

-- Input Dissector
function pn_interface_input.dissector(buffer, pinfo, tree)
    pinfo.cols.protocol = "PN Input"
    local subtree = tree:add(pn_interface_input, buffer(), "PN Interface Input Data")
    local offset = 0

    subtree:add(pn_interface_output, buffer(offset), "Preamble")
    offset = offset + 2

    --subtree:add(pn_interface_output, buffer(offset), "Predata")
    --offset = offset + 1


    -- AdaptioInput
    local adaptio_tree = subtree:add(pn_interface_input, buffer(offset), "AdaptioInput")
    offset = parse_adaptio_input(adaptio_tree, buffer, offset)

    -- AxisInput (repeated)
    for i = 1, 3 do
        local axis_tree = subtree:add(pn_interface_input, buffer(offset), "AxisInput[" .. i .. "]")
        offset = parse_axis_input(axis_tree, buffer, offset)
    end

    -- PowerSourceInput (repeated)
    for i = 1, 2 do
        local ps_tree = subtree:add(pn_interface_input, buffer(offset), "PowerSourceInput[" .. i .. "]")
        offset = parse_ps_input(ps_tree, buffer, offset)
    end

    -- TrackInput
    local tracking_tree = subtree:add(pn_interface_input, buffer(offset), "TrackingInput")
    offset = parse_tracking_input(tracking_tree, buffer, offset)

    subtree:add(pn_interface_output, buffer(offset), "Postamble")
    offset = offset + 4

    --subtree:add(pn_interface_output, buffer(offset), "Postdata")
   -- offset = offset + 1
end

-- Output Dissector
function pn_interface_output.dissector(buffer, pinfo, tree)
    pinfo.cols.protocol = "PN Output"
    local subtree = tree:add(pn_interface_output, buffer(), "PN Interface Output Data")
    local offset = 0

    subtree:add(pn_interface_output, buffer(offset), "Preamble")
    offset = offset + 2

    subtree:add(pn_interface_output, buffer(offset), "Predata")
    offset = offset + 1

    -- AdaptioOutput
    local adaptio_tree = subtree:add(pn_interface_output, buffer(offset), "AdaptioOutput")
    offset = parse_adaptio_output(adaptio_tree, buffer, offset)

    -- AxisOutput (repeated)
    for i = 1, 3 do
        local axis_tree = subtree:add(pn_interface_output, buffer(offset), "AxisOutput[" .. i .. "]")
        offset = parse_axis_output(axis_tree, buffer, offset)
    end

    -- PowerSourceOutput (repeated)
    for i = 1, 2 do
        local ps_tree = subtree:add(pn_interface_output, buffer(offset), "PowerSourceOutput[" .. i .. "]")
        offset = parse_ps_output(ps_tree, buffer, offset)
    end

    -- TrackOutput
    local tracking_tree = subtree:add(pn_interface_output, buffer(offset), "TrackingOutput")
    offset = parse_tracking_output(tracking_tree, buffer, offset)

    subtree:add(pn_interface_output, buffer(offset), "Postdata")
    offset = offset + 1

    subtree:add(pn_interface_output, buffer(offset), "Postamble")
    offset = offset + 4
end

-- Register for "Decode As..." support in generic data dissector table

DissectorTable.get("tcp.port"):add(0, pn_interface_input)
DissectorTable.get("udp.port"):add(0, pn_interface_input)
DissectorTable.get("ethertype"):add(0x88B5, pn_interface_input)
DissectorTable.get("ip.proto"):add(253, pn_interface_input)

DissectorTable.get("tcp.port"):add(0, pn_interface_output)
DissectorTable.get("udp.port"):add(0, pn_interface_output)
DissectorTable.get("ethertype"):add(0x88B5, pn_interface_output)
DissectorTable.get("ip.proto"):add(253, pn_interface_output)


-- DissectorTable.get("data"):add(0, pn_interface_input)
-- DissectorTable.get("data"):add(0, pn_interface_output)
