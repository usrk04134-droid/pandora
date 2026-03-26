---
title: "Gen2 Control Flow"
id: gen2-control-flow-uuid
version: 0
status: draft
type: sysfun
dependencies:
---

# Definition

This document describes the control flow differences between legacy and Gen2 systems for starting joint tracking.

# Legacy Control Flow

The sequence below shows the legacy control flow for starting joint tracking

```plantuml
@startuml
Actor "Operator" as oper
Participant "PLC HMI" as plc_hmi
Participant PLC as plc
Participant "Mgmt Client" as mgmt_client
Participant "Mgmt Server" as mgmt_server
Participant WeldControl as weld_control

oper -> plc_hmi: Start Tracking
plc_hmi -> plc: Start Tracking
plc -> mgmt_client: TrackingStart
mgmt_client -> mgmt_server: TrackingStart
mgmt_server -> weld_control: JointTrackingStart

@enduml
```

# Gen2 Control Flow

The sequence below shows the Gen2 control flow for starting joint tracking

```plantuml
@startuml
Actor "Operator" as oper
Participant WHMI as whmi
Participant "Mgmt Server" as mgmt_server
Participant WeldControl as weld_control

oper -> whmi: Start Tracking
whmi -> mgmt_server: TrackingStart
mgmt_server -> weld_control: JointTrackingStart

@enduml
```
