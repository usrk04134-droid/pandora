# External Weld Speed Control

## Background

When multiple weld heads operate on the same object, weld speed is controlled
externally. Adaptio still performs current adaptivity and bead placement, but
does not output weld speed commands. It must also raise the torch when
welding/tracking stops to prevent torch-object contact.

## Current Architecture

Weld speed in ABP is computed by `UpdateAdaptivity()`:

1. `CalculateAdaptivity()` outputs `weld_speed` (mm/s) based on groove area
   ratio, heat input limits, and `weldSpeedMin/Max`.
2. The speed is smoothed and sent to the PLC via
   `kinematics_client_->SetWeldAxisData()`.

ABP parameters (including `weldSpeed.min/max`) are configured via the frontend
and stored through `StoreABPParameters`.

## Proposed Changes

### 1. New ABP Parameter

Add `externalSpeedControl` (boolean) to `ABPParameters`.

- `false` (default): current behavior.
- `true`: Adaptio does not output weld speed. Current adaptivity and bead
  placement continue.

Stored and configured from the frontend alongside the other ABP parameters.

### 2. WeldControlImpl

In `UpdateAdaptivity()` when `externalSpeedControl` is true:

- Skip `SetWeldAxisData()` (do not send speed to PLC).
- Still run `CalculateAdaptivity()` for heat input constraint checking using
  the actual measured velocity (`cached_velocity_`), adjusting only
  `ws2_current`.
- Set `weld_axis_ang_velocity_desired_` to `cached_velocity_` (actual =
  desired) so that logs and metrics are not stale or misleading.
- `weldSpeedMin/Max` are ignored entirely in external speed mode.

Guard: do not run `CalculateAdaptivity()` when `cached_velocity_` is zero or
near-zero (e.g. external controller has not started yet), to avoid division by
zero in heat input calculations.

### 3. Torch Raise on Weld Stop

When welding stops in external speed mode, the object may continue moving.
Raise the torch by a configurable distance (WeldControl config parameter
`torch_raise_distance_mm`) via `SetSlidesPosition()`.

There are two trigger paths for the torch raise, both gated on
`cached_velocity_ > 0` and only active when `externalSpeedControl` is true:

**Scenario A — Arc loss:** Trigger from the existing arcing-lost in
`CheckSupervision()`. Arc loss at non-zero speed is an error:

1. Stop ABP and joint tracking
2. Raise the torch via `SetSlidesPosition()`.
3. Set error state
4. Send an event (to WebHMI)

Only raise if weld speed is non-zero when arcing is lost on both weld systems.
At zero speed, the wire is fused to the object.

**Scenario B — PLC stops joint tracking or ABP:** If the PLC commands a stop
of joint tracking or ABP while `cached_velocity_ > 0`, the torch should be
raised. This is a controlled stop, so no error state or event is needed.

### 4. Frontend

Add a toggle for `externalSpeedControl` in the ABP parameters page.

## Open Questions

1. **Torch raise threshold:** What velocity limit to use for the "non-zero"
   check (e.g., 0.1 mm/s)?

2. **Wire stick recovery:** If arcing stops at zero speed (wire possibly
   stuck), should Adaptio take any action or remain in position?

3. **Flux shut off:** When the torch is retracted, the flux flow must be shut
   off. The capability to control the flux flow must be verified.
