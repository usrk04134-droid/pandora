# Diagram

```plantuml

skinparam backgroundColor #DCE8F7
skinparam sequenceParticipant {
    BackgroundColor #6AA5F0
    BorderColor #000000
    FontColor #FFFFFF
}

hide footbox

participant "Adaptio" as Adaptio
participant "WebHMI" as WebHMI

== Update Frontend ==
WebHMI -> Adaptio: LWCalGet

alt ok
    WebHMI <- Adaptio: LWCalGetRsp(result:"ok")
    note over WebHMI: Status: Calibrated
else fail
    WebHMI <- Adaptio: LWCalGetRsp(result:"fail")
    note over WebHMI: Status: Not calibrated
end


== Calibration success ==
note over Adaptio
  preconditions:
  - idle
  - valid joint geometry (type="lw")
end note

note over WebHMI : "Start Calibration" button press
WebHMI -> Adaptio : LWCalStart(distanceLaserTorch, stickout, scannerMountAngle)
note over Adaptio : Start scanner and capture\nsingle observation immediately
WebHMI <- Adaptio : LWCalStartRsp(result:"ok")

note over WebHMI : "Top Position" button press
WebHMI -> Adaptio : LWCalTopPos
WebHMI <- Adaptio : LWCalTopPosRsp(result:"ok")

note over WebHMI : "Left wall" button press
WebHMI -> Adaptio : LWCalLeftPos
Adaptio -> WebHMI : LWCalLeftPosRsp(result:"ok")

note over WebHMI : "Right wall" button press
WebHMI -> Adaptio : LWCalRightPos
Adaptio -> WebHMI : LWCalRightPosRsp(result:"ok")
note over Adaptio : Compute calibration result\nand send immediately
WebHMI <- Adaptio: LWCalResult(result:"ok", payload)
note over Adaptio : idle

WebHMI -> Adaptio: LWCalSet(payload)
WebHMI <- Adaptio: LWCalSetRsp(result:"ok")
note over WebHMI: Status: Calibrated


== Stop/reset ==

note over Adaptio : busy / in calibration

WebHMI -> Adaptio : LWCalStop
WebHMI <- Adaptio : LWCalStopRsp(result:"ok")
note over Adaptio : idle

WebHMI -> Adaptio: LWCalGet

alt ok
    WebHMI <- Adaptio: LWCalGetRsp(result:"ok", payload)
    note over WebHMI: Status: Calibrated
else fail
    WebHMI <- Adaptio: LWCalGetRsp(result:"fail")
    note over WebHMI: Status: Not calibrated
end

```
