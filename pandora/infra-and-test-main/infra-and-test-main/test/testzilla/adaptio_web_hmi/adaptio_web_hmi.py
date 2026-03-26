"""
https://gitlab.com/esab/abw/adaptio/-/blob/a3e97d79095207afdae559d742b36dbecdbadc00/docs/WebHMI_Interface_Description.md
"""

import asyncio
import json
import time
from enum import Enum, unique
from typing import Any, Callable, Dict

import websockets.exceptions as websocketsExc
from loguru import logger
from pydantic import BaseModel, ValidationError, create_model
from testzilla.utility.websocket_client import WebSocketClientSync


@unique
class MessageName(Enum):
    """Enum class for Adaptio WebHMI message names."""

    GET_ACTIVITY_STATUS = "GetActivityStatus"
    GET_ACTIVITY_STATUS_RSP = "GetActivityStatusRsp"
    GET_ADAPTIO_VERSION = "GetAdaptioVersion"
    GET_ADAPTIO_VERSION_RSP = "GetAdaptioVersionRsp"
    ADD_WELD_PROCESS_PARAMETERS = "AddWeldProcessParameters"
    ADD_WELD_PROCESS_PARAMETERS_RSP = "AddWeldProcessParametersRsp"
    ADD_WELD_DATA_SET = "AddWeldDataSet"
    ADD_WELD_DATA_SET_RSP = "AddWeldDataSetRsp"
    SELECT_WELD_DATA_SET = "SelectWeldDataSet"
    SELECT_WELD_DATA_SET_RSP = "SelectWeldDataSetRsp"
    UPDATE_WELD_PROCESS_PARAMETERS = "UpdateWeldProcessParameters"
    UPDATE_WELD_PROCESS_PARAMETERS_RSP = "UpdateWeldProcessParametersRsp"
    REMOVE_WELD_PROCESS_PARAMETERS = "RemoveWeldProcessParameters"
    REMOVE_WELD_PROCESS_PARAMETERS_RSP = "RemoveWeldProcessParametersRsp"
    GET_WELD_PROCESS_PARAMETERS = "GetWeldProcessParameters"
    GET_WELD_PROCESS_PARAMETERS_RSP = "GetWeldProcessParametersRsp"
    UPDATE_WELD_DATA_SET = "UpdateWeldDataSet"
    UPDATE_WELD_DATA_SET_RSP = "UpdateWeldDataSetRsp"
    REMOVE_WELD_DATA_SET = "RemoveWeldDataSet"
    REMOVE_WELD_DATA_SET_RSP = "RemoveWeldDataSetRsp"
    GET_WELD_DATA_SETS = "GetWeldDataSets"
    GET_WELD_DATA_SETS_RSP = "GetWeldDataSetsRsp"
    SUBSCRIBE_ARC_STATE = "SubscribeArcState"
    GET_ARC_STATE = "GetArcState"
    GET_ARC_STATE_RSP = "GetArcStateRsp"
    ARC_STATE = "ArcState"
    SUBSCRIBE_WELD_DATA = "SubscribeWeldData"
    SUBSCRIBE_WELD_DATA_RSP = "SubscribeWeldDataRsp"
    WELD_DATA = "WeldData"
    ADJUST_VOLTAGE = "AdjustVoltage"
    ADJUST_VOLTAGE_RSP = "AdjustVoltageRsp"
    ADJUST_CURRENT = "AdjustCurrent"
    ADJUST_CURRENT_RSP = "AdjustCurrentRsp"
    CLEAR_WELD_SESSION = "ClearWeldSession"
    CLEAR_WELD_SESSION_RSP = "ClearWeldSessionRsp"
    SET_JOINT_GEOMETRY = "SetJointGeometry"
    GET_JOINT_GEOMETRY = "GetJointGeometry"
    GET_JOINT_GEOMETRY_RSP = "GetJointGeometryRsp"
    LASER_TO_TORCH_CALIBRATION = "LaserToTorchCalibration"
    LASER_TO_TORCH_CALIBRATION_RSP = "LaserToTorchCalibrationRsp"
    SET_LASER_TO_TORCH_CALIBRATION = "SetLaserToTorchCalibration"
    SET_LASER_TO_TORCH_CALIBRATION_RSP = "SetLaserToTorchCalibrationRsp"
    GET_LASER_TO_TORCH_CALIBRATION = "GetLaserToTorchCalibration"
    GET_LASER_TO_TORCH_CALIBRATION_RSP = "GetLaserToTorchCalibrationRsp"
    WELD_OBJECT_CALIBRATION = "WeldObjectCalibration"
    WELD_OBJECT_CALIBRATION_RSP = "WeldObjectCalibrationRsp"
    SET_WELD_OBJECT_CALIBRATION = "SetWeldObjectCalibration"
    SET_WELD_OBJECT_CALIBRATION_RSP = "SetWeldObjectCalibrationRsp"
    GET_WELD_OBJECT_CALIBRATION = "GetWeldObjectCalibration"
    GET_WELD_OBJECT_CALIBRATION_RSP = "GetWeldObjectCalibrationRsp"
    GET_SLIDES_STATUS = "GetSlidesStatus"
    GET_SLIDES_STATUS_RSP = "GetSlidesStatusRsp"
    GET_SLIDES_POSITION = "GetSlidesPosition"
    GET_SLIDES_POSITION_RSP = "GetSlidesPositionRsp"
    SET_SLIDES_POSITION = "SetSlidesPosition"
    SERVICE_MODE_KINEMATICS_CONTROL = "ServiceModeKinematicsControl"
    SERVICE_MODE_TRACKING = "ServiceModeTracking"
    START_TRACKING = "StartTracking"
    GET_PLC_SW_VERSION = "GetPlcSwVersion"
    GET_PLC_SW_VERSION_RSP = "GetPlcSwVersionRsp"


@unique
class ActivityStatus(Enum):
    """Enum class for Adaptio activity status."""

    IDLE = 0
    LASER_TORCH_CALIBRATION = 1
    WELD_OBJECT_CALIBRATION = 2
    TRACKING = 3
    SERVICE_MODE_TRACKING = 4
    SERVICE_MODE_KINEMATICS = 5
    SERVICE_MODE_IMAGE_COLLECTION = 6


class AdaptioWebHmiMessage(BaseModel):
    """Base class for the Adaptio WebHMI message format."""

    name: str
    payload: Dict[str, Any]
    result: str | None = None  # New separate result field in response

    def __str__(self):
        return self.model_dump_json()


def create_name_condition(name: str) -> Callable[[Any], bool]:
    """Create condition for matching name in the message data."""

    def condition(message: Any) -> bool:
        data = json.loads(message)
        return data.get("name") == name

    return condition


def validate_kwargs(fields, **kwargs) -> BaseModel:
    """Validate the kwargs input against the defined fields."""
    model = create_model("model", **fields)

    try:
        validated_data = model(**kwargs)
        return validated_data
    except ValidationError:
        logger.exception("Kwargs validation error!")
        raise


class AdaptioWebHmi:
    def __init__(self, uri: str = "ws://adaptio.local:8080") -> None:
        """Initialize a new instance."""
        self.uri = uri
        self.ws_client = WebSocketClientSync(uri=self.uri)
        self._closed = False

    def __del__(self) -> None:
        """Destructor called when an instance is destroyed."""
        self.close()

    def close(self) -> None:
        """Explicitly close the WebSocket connection."""
        if not self._closed and hasattr(self, "ws_client"):
            try:
                # WebSocketClientSync.close() is synchronous and handles cleanup properly
                if hasattr(self.ws_client, "close") and callable(self.ws_client.close):
                    self.ws_client.close()
            except RuntimeError:
                # Event loop might be closed - acceptable during cleanup
                pass
            except Exception:
                # Never raise during cleanup
                pass
            finally:
                # Mark as closed to prevent double-close
                self._closed = True

    def connect(self, retries=3, retry_delay=1) -> None:
        """Connect to the websocket."""
        if self._closed:
            raise RuntimeError("AdaptioWebHmi instance has been closed")

        attempt = 1
        while not self.ws_client.is_connected():
            if attempt > retries:
                raise ConnectionError("Failed to connect to WebSocket after multiple attempts.")

            if attempt > 1:
                logger.warning(f"Client not connected. Attempting to reconnect (attempt {attempt}/{retries})...")

            try:
                self.ws_client.connect()
            except (
                websocketsExc.ConnectionClosedError,
                websocketsExc.InvalidURI,
                asyncio.TimeoutError,
            ):
                logger.exception(f"Connection error during attempt {attempt}/{retries}")
                attempt += 1
                time.sleep(retry_delay)
                continue

    def send_message(self, message: AdaptioWebHmiMessage) -> None:
        """Send message to the websocket client."""
        if self._closed:
            raise RuntimeError("AdaptioWebHmi instance has been closed")
        self.connect()
        self.ws_client.send_message(str(message))

    def receive_message(
        self, condition: Callable[[Any], bool] | None = None, max_retries: int = 5
    ) -> AdaptioWebHmiMessage:
        """Wait for a message that match the condition."""
        if self._closed:
            raise RuntimeError("AdaptioWebHmi instance has been closed")
        self.connect()

        retries = 0
        while retries < max_retries:
            response = self.ws_client.receive_message()
            if condition is None or condition(response):
                return AdaptioWebHmiMessage.model_validate_json(response)
            retries += 1

        raise TimeoutError("Max retries reached without receiving the expected message.")

    def send_and_receive_message(
        self, condition, request_name: str, response_name: str, payload: Dict[str, Any]
    ) -> AdaptioWebHmiMessage:
        """Create the message and send it."""
        if self._closed:
            raise RuntimeError("AdaptioWebHmi instance has been closed")

        message = AdaptioWebHmiMessage(name=request_name, payload=payload)

        if not condition:
            condition = create_name_condition(name=response_name)

        self.send_message(message)

        response = self.receive_message(condition)

        return response
    
    def send_and_receive_data(
        self, condition, request_name: str, response_name: str, payload: Dict[str, Any], message: str
    ) -> AdaptioWebHmiMessage:
        """Create the message and send it."""
        if self._closed:
            raise RuntimeError("AdaptioWebHmi instance has been closed")

        data = AdaptioWebHmiMessage(name=request_name, payload=payload, message=message)

        if not condition:
            condition = create_name_condition(name=response_name)

        self.send_message(data)

        response = self.receive_message(condition)

        return response

    def get_activity_status(self, condition: Callable[[Any], bool] | None = None) -> AdaptioWebHmiMessage:
        """Get current activity status."""
        payload = {}

        response = self.send_and_receive_message(
            condition,
            MessageName.GET_ACTIVITY_STATUS.value,
            MessageName.GET_ACTIVITY_STATUS_RSP.value,
            payload,
        )

        return response

    def get_adaptio_version(self, condition: Callable[[Any], bool] | None = None) -> AdaptioWebHmiMessage:
        """Get Adaptio version."""
        payload = {}

        response = self.send_and_receive_message(
            condition,
            MessageName.GET_ADAPTIO_VERSION.value,
            MessageName.GET_ADAPTIO_VERSION_RSP.value,
            payload,
        )

        return response

    def add_weld_process_parameters(
        self, condition: Callable[[Any], bool] | None = None, **kwargs
    ) -> AdaptioWebHmiMessage:
        """Add weld process parameters.

        Args:
            kwargs:
                - **name** (str): Weld process name.
                - **method** (str): Weld method.
                - **regulationType** (str): Regulation type.
                - **startAdjust** (int): Start adjust.
                - **startType** (str): Start type.
                - **voltage** (float): Voltage.
                - **current** (float): Current.
                - **wireSpeed** (float): Wire speed.
                - **iceWireSpeed** (float): Ice wire speed.
                - **acFrequency** (float): AC frequency.
                - **acOffset** (float): AC offset.
                - **acPhaseShift** (float): AC phase shift.
                - **craterFillTime** (float): Crater fill time.
                - **burnBackTime** (float): Burn back time.
        """
        fields = {
            "name": (str, ""),
            "method": (str, ""),
            "regulationType": (str, ""),
            "startAdjust": (int, 0),
            "startType": (str, ""),
            "voltage": (float, 0.0),
            "current": (float, 0.0),
            "wireSpeed": (float, 0.0),
            "iceWireSpeed": (float, 0.0),
            "acFrequency": (float, 0.0),
            "acOffset": (float, 0.0),
            "acPhaseShift": (float, 0.0),
            "craterFillTime": (float, 0.0),
            "burnBackTime": (float, 0.0),
        }

        payload = validate_kwargs(fields, **kwargs).model_dump()

        response = self.send_and_receive_message(
            condition,
            MessageName.ADD_WELD_PROCESS_PARAMETERS.value,
            MessageName.ADD_WELD_PROCESS_PARAMETERS_RSP.value,
            payload,
        )

        return response

    def add_weld_data_set(self, condition: Callable[[Any], bool] | None = None, **kwargs) -> AdaptioWebHmiMessage:
        """Add weld data set.

        Args:
            kwargs:
                - **name** (str): Weld data set name.
                - **ws1WppId** (int): Weld system 1 weld process parameter ID.
                - **ws2WppId** (int): Weld system 2 weld process parameter ID.
        """
        fields = {
            "name": (str, ""),
            "ws1WppId": (int, 0),
            "ws2WppId": (int, 0),
        }

        payload = validate_kwargs(fields, **kwargs).model_dump()

        response = self.send_and_receive_message(
            condition,
            MessageName.ADD_WELD_DATA_SET.value,
            MessageName.ADD_WELD_DATA_SET_RSP.value,
            payload,
        )

        return response

    def select_weld_data_set(self, condition: Callable[[Any], bool] | None = None, **kwargs) -> AdaptioWebHmiMessage:
        """Select weld data set.

        Args:
            kwargs:
                - **id** (int): Weld data set ID.
        """
        fields = {
            "id": (int, 0),
        }

        payload = validate_kwargs(fields, **kwargs).model_dump()

        response = self.send_and_receive_message(
            condition,
            MessageName.SELECT_WELD_DATA_SET.value,
            MessageName.SELECT_WELD_DATA_SET_RSP.value,
            payload,
        )

        return response

    def update_weld_process_parameters(
        self, condition: Callable[[Any], bool] | None = None, **kwargs
    ) -> AdaptioWebHmiMessage:
        """Update existing weld process parameters.

        Args:
            kwargs:
                - **id** (int): Weld process parameter ID to update.
                - **name** (str): Weld process name.
                - **method** (str): Weld method.
                - **regulationType** (str): Regulation type.
                - **startAdjust** (int): Start adjust.
                - **startType** (str): Start type.
                - **voltage** (float): Voltage.
                - **current** (float): Current.
                - **wireSpeed** (float): Wire speed.
                - **iceWireSpeed** (float): Ice wire speed.
                - **acFrequency** (float): AC frequency.
                - **acOffset** (float): AC offset.
                - **acPhaseShift** (float): AC phase shift.
                - **craterFillTime** (float): Crater fill time.
                - **burnBackTime** (float): Burn back time.
        """
        fields = {
            "id": (int, 0),
            "name": (str, ""),
            "method": (str, ""),
            "regulationType": (str, ""),
            "startAdjust": (int, 0),
            "startType": (str, ""),
            "voltage": (float, 0.0),
            "current": (float, 0.0),
            "wireSpeed": (float, 0.0),
            "iceWireSpeed": (float, 0.0),
            "acFrequency": (float, 0.0),
            "acOffset": (float, 0.0),
            "acPhaseShift": (float, 0.0),
            "craterFillTime": (float, 0.0),
            "burnBackTime": (float, 0.0),
        }

        payload = validate_kwargs(fields, **kwargs).model_dump()

        response = self.send_and_receive_message(
            condition,
            MessageName.UPDATE_WELD_PROCESS_PARAMETERS.value,
            MessageName.UPDATE_WELD_PROCESS_PARAMETERS_RSP.value,
            payload,
        )

        return response

    def remove_weld_process_parameters(
        self, condition: Callable[[Any], bool] | None = None, **kwargs
    ) -> AdaptioWebHmiMessage:
        """Remove weld process parameters by ID.

        Args:
            kwargs:
                - **id** (int): Weld process parameter ID to remove.
        """
        fields = {
            "id": (int, 0),
        }

        payload = validate_kwargs(fields, **kwargs).model_dump()

        response = self.send_and_receive_message(
            condition,
            MessageName.REMOVE_WELD_PROCESS_PARAMETERS.value,
            MessageName.REMOVE_WELD_PROCESS_PARAMETERS_RSP.value,
            payload,
        )

        return response

    def get_weld_process_parameters(
        self, condition: Callable[[Any], bool] | None = None
    ) -> AdaptioWebHmiMessage:
        """Get all stored weld process parameters."""
        payload = {}

        response = self.send_and_receive_message(
            condition,
            MessageName.GET_WELD_PROCESS_PARAMETERS.value,
            MessageName.GET_WELD_PROCESS_PARAMETERS_RSP.value,
            payload,
        )

        return response

    def update_weld_data_set(
        self, condition: Callable[[Any], bool] | None = None, **kwargs
    ) -> AdaptioWebHmiMessage:
        """Update an existing weld data set.

        Args:
            kwargs:
                - **id** (int): Weld data set ID to update.
                - **name** (str): Weld data set name.
                - **ws1WppId** (int): Weld system 1 weld process parameter ID.
                - **ws2WppId** (int): Weld system 2 weld process parameter ID.
        """
        fields = {
            "id": (int, 0),
            "name": (str, ""),
            "ws1WppId": (int, 0),
            "ws2WppId": (int, 0),
        }

        payload = validate_kwargs(fields, **kwargs).model_dump()

        response = self.send_and_receive_message(
            condition,
            MessageName.UPDATE_WELD_DATA_SET.value,
            MessageName.UPDATE_WELD_DATA_SET_RSP.value,
            payload,
        )

        return response

    def remove_weld_data_set(
        self, condition: Callable[[Any], bool] | None = None, **kwargs
    ) -> AdaptioWebHmiMessage:
        """Remove a weld data set by ID.

        Args:
            kwargs:
                - **id** (int): Weld data set ID to remove.
        """
        fields = {
            "id": (int, 0),
        }

        payload = validate_kwargs(fields, **kwargs).model_dump()

        response = self.send_and_receive_message(
            condition,
            MessageName.REMOVE_WELD_DATA_SET.value,
            MessageName.REMOVE_WELD_DATA_SET_RSP.value,
            payload,
        )

        return response

    def get_weld_data_sets(
        self, condition: Callable[[Any], bool] | None = None
    ) -> AdaptioWebHmiMessage:
        """Get all stored weld data sets."""
        payload = {}

        response = self.send_and_receive_message(
            condition,
            MessageName.GET_WELD_DATA_SETS.value,
            MessageName.GET_WELD_DATA_SETS_RSP.value,
            payload,
        )

        return response

    def subscribe_arc_state(self) -> None:
        """Subscribe to arc state push notifications.

        After subscribing, ArcState messages are pushed on every state change.
        """
        message = AdaptioWebHmiMessage(
            name=MessageName.SUBSCRIBE_ARC_STATE.value, payload={}
        )
        self.send_message(message)

    def get_arc_state(
        self, condition: Callable[[Any], bool] | None = None
    ) -> AdaptioWebHmiMessage:
        """Get current arc state."""
        payload = {}

        response = self.send_and_receive_message(
            condition,
            MessageName.GET_ARC_STATE.value,
            MessageName.GET_ARC_STATE_RSP.value,
            payload,
        )

        return response

    def subscribe_weld_data(
        self, condition: Callable[[Any], bool] | None = None
    ) -> AdaptioWebHmiMessage:
        """Subscribe to weld data push notifications."""
        payload = {}

        response = self.send_and_receive_message(
            condition,
            MessageName.SUBSCRIBE_WELD_DATA.value,
            MessageName.SUBSCRIBE_WELD_DATA_RSP.value,
            payload,
        )

        return response

    def receive_arc_state(self, max_retries: int = 10) -> AdaptioWebHmiMessage:
        """Wait for an ArcState push message."""
        condition = create_name_condition(name=MessageName.ARC_STATE.value)
        return self.receive_message(condition=condition, max_retries=max_retries)

    def adjust_voltage(
        self, condition: Callable[[Any], bool] | None = None, **kwargs
    ) -> AdaptioWebHmiMessage:
        """Adjust voltage setpoint for a weld system.

        Args:
            kwargs:
                - **wsId** (int): Weld system ID (1 or 2).
                - **delta** (float): Voltage delta to apply.
        """
        fields = {
            "wsId": (int, 0),
            "delta": (float, 0.0),
        }

        payload = validate_kwargs(fields, **kwargs).model_dump()

        response = self.send_and_receive_message(
            condition,
            MessageName.ADJUST_VOLTAGE.value,
            MessageName.ADJUST_VOLTAGE_RSP.value,
            payload,
        )

        return response

    def adjust_current(
        self, condition: Callable[[Any], bool] | None = None, **kwargs
    ) -> AdaptioWebHmiMessage:
        """Adjust current setpoint for a weld system.

        Args:
            kwargs:
                - **wsId** (int): Weld system ID (1 or 2).
                - **delta** (float): Current delta to apply.
        """
        fields = {
            "wsId": (int, 0),
            "delta": (float, 0.0),
        }

        payload = validate_kwargs(fields, **kwargs).model_dump()

        response = self.send_and_receive_message(
            condition,
            MessageName.ADJUST_CURRENT.value,
            MessageName.ADJUST_CURRENT_RSP.value,
            payload,
        )

        return response

    def clear_weld_session(
        self, condition: Callable[[Any], bool] | None = None
    ) -> AdaptioWebHmiMessage:
        """Clear the current weld session and reset state."""
        payload = {}

        response = self.send_and_receive_message(
            condition,
            MessageName.CLEAR_WELD_SESSION.value,
            MessageName.CLEAR_WELD_SESSION_RSP.value,
            payload,
        )

        return response

    def set_joint_geometry(self, **kwargs) -> None:
        """
        Set and store joint geometry parameters.

        Args:
            kwargs:
                - **grooveDepthMm** (float): Groove depth.
                - **leftJointAngleRad** (float): Left joint angle.
                - **leftMaxSurfaceAngleRad** (float): Left maximum surface angle.
                - **rightJointAngleRad** (float): Right joint angle.
                - **rightMaxSurfaceAngleRad** (float): Right maximum surface angle.
                - **upperJointWidthMm** (float): Upper joint width.
        """
        fields = {
            "grooveDepthMm": (float, 0.0),
            "leftJointAngleRad": (float, 0.0),
            "leftMaxSurfaceAngleRad": (float, 0.0),
            "rightJointAngleRad": (float, 0.0),
            "rightMaxSurfaceAngleRad": (float, 0.0),
            "upperJointWidthMm": (float, 0.0),
        }

        payload = validate_kwargs(fields, **kwargs).model_dump()

        message = AdaptioWebHmiMessage(name=MessageName.SET_JOINT_GEOMETRY.value, payload=payload)
        self.send_message(message)

    def get_joint_geometry(self, condition: Callable[[Any], bool] | None = None) -> AdaptioWebHmiMessage:
        """Get stored joint geometry parameters."""
        payload = {}

        response = self.send_and_receive_message(
            condition,
            MessageName.GET_JOINT_GEOMETRY.value,
            MessageName.GET_JOINT_GEOMETRY_RSP.value,
            payload,
        )

        return response

    def laser_to_torch_calibration(
        self, condition: Callable[[Any], bool] | None = None, **kwargs
    ) -> AdaptioWebHmiMessage:
        """Request a calibration measurement and calculation, no state change or storage.

        Args:
            kwargs:
                - **angle** (float): Angle in radians.
                - **offset** (float): Offset.
                - **stickout** (int): Stickout.
        """
        fields = {
            "angle": (float, 0.0),
            "offset": (float, 0.0),
            "stickout": (int, 0),
        }
        payload = validate_kwargs(fields, **kwargs).model_dump()

        response = self.send_and_receive_message(
            condition,
            MessageName.LASER_TO_TORCH_CALIBRATION.value,
            MessageName.LASER_TO_TORCH_CALIBRATION_RSP.value,
            payload,
        )

        return response

    def set_laser_to_torch_calibration(
        self, condition: Callable[[Any], bool] | None = None, **kwargs
    ) -> AdaptioWebHmiMessage:
        """Set and store calibration parameters.

        Args:
            kwargs:
                - **angle** (float): Angle in radians.
                - **x** (float): X coordinate.
                - **y** (float): Y coordinate.
                - **z** (float): Z coordinate.
        """
        fields = {
            "angle": (float, 0.0),
            "x": (float, 0.0),
            "y": (float, 0.0),
            "z": (float, 0.0),
        }

        payload = validate_kwargs(fields, **kwargs).model_dump()

        response = self.send_and_receive_message(
            condition,
            MessageName.SET_LASER_TO_TORCH_CALIBRATION.value,
            MessageName.SET_LASER_TO_TORCH_CALIBRATION_RSP.value,
            payload,
        )

        return response

    def get_laser_to_torch_calibration(self, condition: Callable[[Any], bool] | None = None) -> AdaptioWebHmiMessage:
        """Get the stored calibration parameters."""
        payload = {}

        response = self.send_and_receive_message(
            condition,
            MessageName.GET_LASER_TO_TORCH_CALIBRATION.value,
            MessageName.GET_LASER_TO_TORCH_CALIBRATION_RSP.value,
            payload,
        )

        return response

    def weld_object_calibration(self, condition: Callable[[Any], bool] | None = None, **kwargs) -> AdaptioWebHmiMessage:
        """Request a calibration measurement and calculation, no state change or storage.

        Args:
            kwargs:
                - **radius** (float): Radius.
                - **stickout** (int): Stickout.
        """
        fields = {
            "radius": (float, 0.0),
            "stickout": (int, 0),
        }

        payload = validate_kwargs(fields, **kwargs).model_dump()

        response = self.send_and_receive_message(
            condition,
            MessageName.WELD_OBJECT_CALIBRATION.value,
            MessageName.WELD_OBJECT_CALIBRATION_RSP.value,
            payload,
        )

        return response

    def set_weld_object_calibration(
        self, condition: Callable[[Any], bool] | None = None, **kwargs
    ) -> AdaptioWebHmiMessage:
        """Set and store calibration parameters.

        Args:
            kwargs:
                - **y** (float): Y coordinate.
                - **z** (float): Z coordinate.
        """
        fields = {
            "y": (float, 0.0),
            "z": (float, 0.0),
        }

        payload = validate_kwargs(fields, **kwargs).model_dump()

        response = self.send_and_receive_message(
            condition,
            MessageName.SET_WELD_OBJECT_CALIBRATION.value,
            MessageName.SET_WELD_OBJECT_CALIBRATION_RSP.value,
            payload,
        )

        return response

    def get_weld_object_calibration(self, condition: Callable[[Any], bool] | None = None) -> AdaptioWebHmiMessage:
        """Get the stored calibration parameters."""
        payload = {}

        response = self.send_and_receive_message(
            condition,
            MessageName.GET_WELD_OBJECT_CALIBRATION.value,
            MessageName.GET_WELD_OBJECT_CALIBRATION_RSP.value,
            payload,
        )

        return response

    def service_mode_tracking(self) -> None:
        """Request to enter service mode tracking."""
        message = AdaptioWebHmiMessage(name=MessageName.SERVICE_MODE_TRACKING.value, payload={})
        self.send_message(message=message)

    def start_tracking(self) -> None:
        """Request to start service mode tracking."""
        message = AdaptioWebHmiMessage(name=MessageName.START_TRACKING.value, payload={})
        self.send_message(message=message)

    def get_slides_status(self, condition: Callable[[Any], bool] | None = None) -> AdaptioWebHmiMessage:
        """Get the status of the slides, if they are in position or not."""
        payload = {}

        response = self.send_and_receive_message(
            condition,
            MessageName.GET_SLIDES_STATUS.value,
            MessageName.GET_SLIDES_STATUS_RSP.value,
            payload,
        )

        return response

    def get_slides_position(self, condition: Callable[[Any], bool] | None = None) -> AdaptioWebHmiMessage:
        """Get the horizontal and vertical slides position(mm)."""
        payload = {}

        response = self.send_and_receive_message(
            condition,
            MessageName.GET_SLIDES_POSITION.value,
            MessageName.GET_SLIDES_POSITION_RSP.value,
            payload,
        )

        return response

    def set_slides_position(self, **kwargs) -> None:
        """Set the horizontal and vertical slides position.

        Args:
            kwargs:
                - **horizontal** (float): Horizontal position in mm.
                - **vertical** (float): Vertical position in mm.
        """
        fields = {
            "horizontal": (float, 0.0),
            "vertical": (float, 0.0),
        }

        payload = validate_kwargs(fields, **kwargs).model_dump()
        message = AdaptioWebHmiMessage(name=MessageName.SET_SLIDES_POSITION.value, payload=payload)
        self.send_message(message=message)

    def service_mode_kinematics_control(self) -> None:
        """Request to enter service mode kinematics control."""
        message = AdaptioWebHmiMessage(name=MessageName.SERVICE_MODE_KINEMATICS_CONTROL.value, payload={})
        self.send_message(message=message)

    def get_plc_sw_version(self, condition: Callable[[Any], bool] | None = None) -> AdaptioWebHmiMessage:
        """Get the plc software version."""
        payload = {}

        response = self.send_and_receive_message(
            condition,
            MessageName.GET_PLC_SW_VERSION.value,
            MessageName.GET_PLC_SW_VERSION_RSP.value,
            payload,
        )

        return response
