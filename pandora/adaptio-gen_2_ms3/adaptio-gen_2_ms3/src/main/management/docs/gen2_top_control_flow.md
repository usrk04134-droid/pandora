---
title: "Gen2 Top Control Flow"
id: gen2-top-control-flow-uuid
version: 0
status: draft
type: sysfun
dependencies:
---

# Definition

This document describes the top-level control flow differences between legacy and Gen2 systems for starting joint tracking. Internal Adaptio components (Management Server, Management Client, WeldControl) are shown as a single "Adaptio" participant.

# Legacy Control Flow

The sequence below shows the legacy control flow for starting joint tracking

```plantuml
@startuml
Actor "Operator" as oper
Participant "PLC HMI" as plc_hmi
Participant PLC as plc
Participant Adaptio as adaptio

oper -> plc_hmi: Start Tracking
plc_hmi -> plc: Start Tracking
plc -> adaptio: TrackingStart

@enduml
```

# Gen2 Control Flow

The sequence below shows the Gen2 control flow for starting joint tracking

```plantuml
@startuml
Actor "Operator" as oper
Participant WHMI as whmi
Participant Adaptio as adaptio

oper -> whmi: Start Tracking
whmi -> adaptio: TrackingStart

@enduml
```
