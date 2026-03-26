# System description

This document briefly describes the functions (system actions), configurable parameters (hardware configuration, speed, etc.), and other required values (position, temperature, etc.) that the PLC must provide in its system role.

We have three main interfaces to the: Profinet, JSON-RPC, and physical/internal. In general, profinet should handle information that needs to be streamed continously or required a low latency. JSON-RPC will be used for settings variables or calling functions that does not need contious monitoring. Physcial is the physical buttons on the button panels. These are mainly used for jogging. Whether to route these through adaptio or not depends on the button/function. For example, jogging an axis vs starting the weld. Here, starting the weld will be performed by adaptio but the user interface is the start button, while jogging an axle will be performed directly by the joystick movement without adaptio being in control.

---

## Slide Cross

### Functions

| Function                  | Interface   |
|---------------------------|-------------|
| Jog vertical slide        | Physcial    |
| Jog horizontal slide      | Physcial    |
| Vertical slide homing     | JSON-RPC    |
| Horizontal slide homing   | JSON-RPC    |
| Move to position (2D)     | Profinet    |

### Vertical Slide Parameters (Runtime)

| Parameter       | Interface |
|-----------------|-----------|
| Jog speed       | JSON-RPC  |
| High jog speed  | JSON-RPC  |
| Acceleration    | JSON-RPC  |
| Deceleration    | JSON-RPC  |
| Jerk            | JSON-RPC  |
| Speed           | Profinet  |

### Horizontal Slide Parameters (Runtime)

| Parameter       | Interface |
|-----------------|-----------|
| Acceleration    | JSON-RPC  |
| Deceleration    | JSON-RPC  |
| Jerk            | JSON-RPC  |
| Speed           | PROFINET  |
| High jog speed  | JSON-RPC  |

### Vertical Slide Status

| Status        | Interface |
|---------------|-----------|
| Position      | Profinet  |
| Current speed | Profinet  |
| Home done     | JSON-RPC  |

### Horizontal Slide Status

| Status        | Interface |
|---------------|-----------|
| Position      | Profinet  |
| Current speed | Profinet  |
| Home done     | JSON-RPC  |

---

## Rollerbed

### Rollerbed functions

| Function                                    | Interface |
|---------------------------------------------|-----------|
| Jog rollerbed                               | Hardware  |
| Move rollerbed in direction                 | Profinet  |
| Move rollerbed to position                  | JSON-RPC  |
| Rollerbed homing                            | Profinet  |
| Rollerbed calibration (speed measurement)   | JSON-RPC  |

### Rollerbed Parameters (Runtime)

| Parameter       | Interface |
|-----------------|-----------|
| Acceleration    | JSON-RPC  |
| Deceleration    | JSON-RPC  |
| Jerk            | JSON-RPC  |
| Jog speed       | JSON-RPC  |
| High jog speed  | JSON-RPC  |

### Speed Wheel Parameters (Hardware)

| Parameter            | Interface |
|----------------------|-----------|
| Gear ratio           | JSON-RPC  |
| Drive wheel diameter | JSON-RPC  |
| Encoder settings     | JSON-RPC  |

### Rollerbed Status

| Status            | Interface |
|-------------------|-----------|
| Linear position   | Profinet  |
| Current speed     | Profinet  |
| Angular position  | Profinet  |
| Home done         | JSON-RPC  |
| Calibration done  | JSON-RPC  |
| Object diameter   | JSON-RPC  |

---

## Boom

### Boom Functions

| Function             | Interface |
|----------------------|-----------|
| Jog boom             | Profinet  |
| Move boom to position| JSON-RPC  |
| Home boom            | Profinet  |

### Boom Parameters (Runtime)

| Parameter       | Interface |
|-----------------|-----------|
| Acceleration    | JSON-RPC  |
| Deceleration    | JSON-RPC  |
| Jerk            | JSON-RPC  |
| Jog speed       | JSON-RPC  |
| High jog speed  | JSON-RPC  |

### Boom Status

| Status        | Interface |
|---------------|-----------|
| Position      | Profinet  |
| Current speed | Profinet  |
| Home done     | JSON-RPC  |

---

## Flux System

### Flux system functions

| Function      | Interface |
|---------------|-----------|
| Release flux  | Profinet  |
| Recover flux  | Profinet  |

### Flux System Status

| Status                  | Interface |
|-------------------------|-----------|
| Big bag error/Low level | JSON-RPC  |
| Flux temperature        | JSON-RPC  |

---

## Point Laser

### Point laser Functions

| Function      | Interface |
|---------------|-----------|
| Activate      | Profinet  |
| Deactivate    | Profinet  |

---

## Temperature Sensor

### Temperature Sensor Parameters

| Parameter  | Interface |
|------------|-----------|
| Scale low  | JSON-RPC  |
| Scale high | JSON-RPC  |

## Status

| Status      | Interface |
|-------------|-----------|
| Temperature | Profinet  |

---

## Weld System

### Weld System Functions

| Function     | Interface            |
|--------------|----------------------|
| Start        | JSON-RPC             |
| Stop         | JSON-RPC             |
| Quickstop    | JSON-RPC             |
| Jog wire N   | Hardware / JSON-RPC  |

Note: Hardware only supports jogging two set of wires.

### Wire Feed Parameters (Hardware)

| Parameter              | Interface |
|------------------------|-----------|
| Load side gear (N2)    | JSON-RPC  |
| Motor side gear (N1)   | JSON-RPC  |
| Drive wheel diameter   | JSON-RPC  |
| Encoder PPR            | JSON-RPC  |
| Max current            | JSON-RPC  |
| RPM                    | JSON-RPC  |

### Wire Feed Parameters (Runtime)

| Parameter       | Interface |
|-----------------|-----------|
| Jog speed       | JSON-RPC  |
| High jog speed  | JSON-RPC  |

### Weld Parameters (Hardware)

| Parameter      | Interface |
|----------------|-----------|
| Wire type      | JSON-RPC  |
| Wire diameter  | JSON-RPC  |
| Push motors    | JSON-RPC  |

### Weld Parameters (Runtime)

| Parameter        | Interface |
|------------------|-----------|
| Weld method      | Profinet  |
| Regulation type  | Profinet  |
| Inductance       | Profinet  |
| Dynamics         | Profinet  |

### Weld Control Values

| Parameter               | Interface |
|-------------------------|-----------|
| Current setpoint        | Profinet  |
| Voltage setpoint        | Profinet  |
| Wire feed speed setpoint| Profinet  |

### AC-Only Parameters

| Parameter   | Interface |
|-------------|-----------|
| Balance     | Profinet  |
| Offset      | Profinet  |
| Phase shift | Profinet  |

### Start Parameters

| Parameter               | Interface |
|-------------------------|-----------|
| Start adjust percentage | JSON-RPC  |

### Start Phase

| Parameter                     | Interface |
|-------------------------------|-----------|
| Start current                 | JSON-RPC  |
| Start voltage                 | JSON-RPC  |
| Start wire feed speed         | JSON-RPC  |
| Welding speed (ownership TBD) | JSON-RPC  |
| Start time                    | JSON-RPC  |

### Stop Sequence (need clarification from ESAB)

| Parameter                | Interface |
|--------------------------|-----------|
| Stop sequence parameters | JSON-RPC  |

### Weld System Status

| Status                                | Interface |
|---------------------------------------|-----------|
| Measured current                      | Profinet  |
| Measured voltage                      | Profinet  |
| Measured wire speed                   | Profinet  |
| State (welding/starting/stopping/...) | Profinet  |

---

## Physical HMI

### Joystick Parameters

| Parameters   | Interface |
|--------------|-----------|
| Control Mode | Profinet  |

### Joystick Status

| Input        | Interface |
|--------------|-----------|
| Long up      | Profinet  |
| Long down    | Profinet  |
| Long left    | Profinet  |
| Long right   | Profinet  |
| Short up     | Profinet  |
| Short down   | Profinet  |
| Short left   | Profinet  |
| Short right  | Profinet  |

### Stop Button Status

| Status     | Interface |
|------------|-----------|
| Stop       | Profinet  |
| Quick stop | Profinet  |

### Start Button Status

| Status | Interface |
|--------|-----------|
| Start  | Profinet  |

---

## Some open questions

Ownership of the weld axis during welding:
Should Adaptio determine weld axis movement, or does the start/stop sequence own it? Is partial ownership possible (e.g., Adaptio sets a base speed that can be modified by the start/stop sequence)? Coordination between weld axis, weld parameters, and slide control is required. Currently, parts of the weld sequence run in the PLC, so coordination between Adaptio and the PLC is critical. Thorough systemization of this aspect is needed.

General error handling including Forwarding errors from the PLC / hardware components to the rest of the system.
