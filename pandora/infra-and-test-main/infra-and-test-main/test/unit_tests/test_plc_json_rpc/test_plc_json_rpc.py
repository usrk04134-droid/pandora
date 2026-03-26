# pylint: disable=unused-argument

import gc
import json
from unittest.mock import Mock, patch

import pytest
import requests
from testzilla.plc.models import (
    JsonRpcError,
    JsonRpcRequest,
    PlcProgramBrowse,
    PlcProgramRead,
    PlcProgramWrite,
)
from testzilla.plc.plc_json_rpc import AuthenticationError, PlcJsonRpc


@pytest.fixture(name="post_request")
def fixture_post_requests():
    with patch("testzilla.plc.plc_json_rpc.requests.post") as mock_post:
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"jsonrpc": "2.0", "id": 1, "result": {"token": "mock_token"}}
        mock_post.return_value = mock_response
        yield mock_post


@pytest.fixture(name="logger")
def fixture_logger():
    with patch("testzilla.plc.plc_json_rpc.logger") as mock_log:
        yield mock_log


@pytest.fixture(name="atexit_register")
def fixture_atexit_register():
    with patch("testzilla.plc.plc_json_rpc.atexit.register") as mock_register:
        yield mock_register


def test_plc_json_rpc_atexit(post_request, atexit_register):
    # Preparation
    rpc = PlcJsonRpc("https://testserver/api/jsonrpc")
    rpc.login("test_user", "test_password")

    # Execution
    del rpc
    gc.collect()  # Force garbage collection

    # Verification
    atexit_register.assert_called_once()


def test_plc_json_rpc_cleanup(post_request, atexit_register, logger):
    # Preparation
    rpc = PlcJsonRpc("https://testserver/api/jsonrpc")
    rpc.login("test_user", "test_password")

    # Execution
    post_request.return_value.json.return_value["result"] = True
    rpc._cleanup()  # pylint: disable=protected-access

    # Verification
    assert len(post_request.call_args_list) == 2
    _, call_kwargs = post_request.call_args_list[1]
    data = json.loads(call_kwargs["data"])
    assert data["method"] == "Api.Logout"
    logger.warning.assert_not_called()


def test_login_success(post_request, atexit_register):
    # Preparation
    rpc = PlcJsonRpc("https://testserver/api/jsonrpc")

    # Execution
    rpc.login("test_user", "test_password")

    # Verification
    assert rpc._token == "mock_token"  # pylint: disable=protected-access


def test_login_failure_with_error(post_request, atexit_register):
    # Preparation
    rpc = PlcJsonRpc("https://testserver/api/jsonrpc")
    post_request.return_value.json.return_value["error"] = {"code": 100, "message": "Login failed"}
    post_request.return_value.json.return_value["result"] = None

    # Execution and Verification
    with pytest.raises(AuthenticationError) as exc_info:
        rpc.login("test_user", "test_password")

    assert str(exc_info.value) == "Authentication failed: 100 Login failed"


def test_login_failure_with_no_result(post_request, atexit_register):
    # Preparation
    rpc = PlcJsonRpc("https://testserver/api/jsonrpc")
    post_request.return_value.json.return_value["result"] = None

    # Execution and Verification
    with pytest.raises(AuthenticationError) as exc_info:
        rpc.login("test_user", "test_password")

    assert str(exc_info.value) == "Failed to acquire a valid token from the server."


def test_login_failure_with_no_token(post_request, atexit_register):
    # Preparation
    rpc = PlcJsonRpc("https://testserver/api/jsonrpc")
    post_request.return_value.json.return_value["result"] = {"dummy": "dummy"}

    # Execution and Verification
    with pytest.raises(AuthenticationError) as exc_info:
        rpc.login("test_user", "test_password")

    assert str(exc_info.value) == "Failed to acquire a valid token from the server."


def test_logout_failure_with_error(post_request, logger, atexit_register):
    # Preparation
    rpc = PlcJsonRpc("https://testserver/api/jsonrpc")
    rpc.login("test_user", "test_password")
    post_request.return_value.json.return_value["error"] = {"code": 666, "message": "Logout failed"}
    post_request.return_value.json.return_value["result"] = None

    # Execution
    rpc.logout()

    # Verification
    logger.warning.assert_called_with("Failed to logout session: 666 Logout failed")


def test_logout_failure_without_result(post_request, logger, atexit_register):
    # Preparation
    rpc = PlcJsonRpc("https://testserver/api/jsonrpc")
    rpc.login("test_user", "test_password")
    post_request.return_value.json.return_value["result"] = None

    # Execution
    rpc.logout()

    # Verification
    logger.warning.assert_called_with("Failed to logout session!")


def test_send_request(post_request, atexit_register):
    # Preparation
    rpc = PlcJsonRpc("https://testserver/api/jsonrpc")
    rpc.login("test_user", "test_password")
    post_request.return_value.json.return_value["result"] = {"dummy": "dummy"}

    # Execution
    response = rpc.send_request(JsonRpcRequest(method="dummy"))

    # Verification
    post_request.assert_called_with(
        "https://testserver/api/jsonrpc",
        headers={"Content-Type": "application/json", "X-Auth-Token": "mock_token"},
        data='{"id":1,"jsonrpc":"2.0","method":"dummy"}',
        verify=False,
        timeout=5,
    )
    assert response.result == {"dummy": "dummy"}
    assert response.error is None


def test_send_request_with_http_not_ok(post_request, logger, atexit_register):
    # Preparation
    rpc = PlcJsonRpc("https://testserver/api/jsonrpc")
    rpc.login("test_user", "test_password")
    post_request.return_value.status_code = 400
    post_request.side_effect = requests.RequestException("Mocked exception")

    # Execution
    with pytest.raises(requests.RequestException) as exc_info:
        rpc.send_request(JsonRpcRequest(method="dummy"))

    # Verification
    assert str(exc_info.value) == "Mocked exception"
    logger.exception.assert_called_with(
        'Request to https://testserver/api/jsonrpc with payload {"id":1,"jsonrpc":"2.0","method":"dummy"} failed!'
    )


def test_browse(post_request, atexit_register):
    # Preparation
    rpc = PlcJsonRpc("https://testserver/api/jsonrpc")
    rpc.login("test_user", "test_password")

    # Execution
    post_request.return_value.json.return_value["result"] = [{"test": "test"}]
    result, error = rpc.browse()

    # Verification
    _, call_kwargs = post_request.call_args_list[1]
    data = json.loads(call_kwargs["data"])
    assert data["method"] == "PlcProgram.Browse"
    assert data["params"] == {"mode": "children"}

    assert result == [{"test": "test"}]
    assert error is None


def test_read(post_request, atexit_register):
    # Preparation
    rpc = PlcJsonRpc("https://testserver/api/jsonrpc")
    rpc.login("test_user", "test_password")

    # Execution
    post_request.return_value.json.return_value["result"] = -42
    result, error = rpc.read(var="dummy")

    # Verification
    _, call_kwargs = post_request.call_args_list[1]
    data = json.loads(call_kwargs["data"])
    assert data["method"] == "PlcProgram.Read"
    assert data["params"] == {"mode": "simple", "var": "dummy"}

    assert result == -42
    assert error is None


def test_write(post_request, atexit_register):
    # Preparation
    rpc = PlcJsonRpc("https://testserver/api/jsonrpc")
    rpc.login("test_user", "test_password")

    # Execution
    post_request.return_value.json.return_value["result"] = True
    result, error = rpc.write(value=-42, var="dummy")

    # Verification
    _, call_kwargs = post_request.call_args_list[1]
    data = json.loads(call_kwargs["data"])
    assert data["method"] == "PlcProgram.Write"
    assert data["params"] == {"mode": "simple", "value": -42, "var": "dummy"}

    assert result
    assert error is None


def test_ping_with_authenticate(post_request, atexit_register):
    # Preparation
    rpc = PlcJsonRpc("https://testserver/api/jsonrpc")
    rpc.login("test_user", "test_password")

    # Execution
    post_request.return_value.json.return_value["result"] = "dummyCPUid"
    result, error = rpc.ping(authenticate=True)

    # Verification
    _, call_kwargs = post_request.call_args_list[1]
    data = json.loads(call_kwargs["data"])
    headers = call_kwargs["headers"]
    assert data["method"] == "Api.Ping"
    assert headers["X-Auth-Token"] == "mock_token"
    assert result == "dummyCPUid"
    assert error is None


def test_ping_without_authenticate(post_request, logger, atexit_register):
    # Preparation
    rpc = PlcJsonRpc("https://testserver/api/jsonrpc")
    rpc.login("test_user", "test_password")
    assert rpc.cpu_id is None

    # Execution
    post_request.return_value.json.return_value["result"] = "dummyCPUid"
    result, error = rpc.ping()

    # Verification
    _, call_kwargs = post_request.call_args_list[1]
    data = json.loads(call_kwargs["data"])
    headers = call_kwargs["headers"]
    assert data["method"] == "Api.Ping"
    assert "X-Auth-Token" not in headers
    assert result == "dummyCPUid"
    assert error is None
    assert rpc.cpu_id == "dummyCPUid"
    logger.debug.assert_called_with("Store new CPU ID: dummyCPUid")


def test_ping_with_unchanged_cpu_id(post_request, logger, atexit_register):
    # Preparation
    rpc = PlcJsonRpc("https://testserver/api/jsonrpc")
    rpc.login("test_user", "test_password")
    rpc.cpu_id = "dummyCPUid"

    # Execution
    post_request.return_value.json.return_value["result"] = "dummyCPUid"
    result, error = rpc.ping()

    # Verification
    _, call_kwargs = post_request.call_args_list[1]
    data = json.loads(call_kwargs["data"])
    headers = call_kwargs["headers"]
    assert data["method"] == "Api.Ping"
    assert "X-Auth-Token" not in headers
    assert result == "dummyCPUid"
    assert error is None
    assert ("Store new CPU ID: dummyCPUid",) not in logger.call_args_list


def test_bulk_request(post_request, atexit_register):
    # Preparation
    rpc = PlcJsonRpc("https://testserver/api/jsonrpc")
    rpc.login("test_user", "test_password")
    methods = [
        PlcProgramBrowse(params={"var": '"browse".dummy.address', "mode": "children"}),
        PlcProgramRead(params={"var": '"read".dummy.address'}),
        PlcProgramWrite(params={"var": '"write".dummy.address', "value": "dummy"}),
    ]

    # Execution
    post_request.return_value.json.return_value = [
        {"jsonrpc": "2.0", "id": 1, "result": {"value": 42}},
        {"jsonrpc": "2.0", "id": 2, "error": {"code": 201, "message": "Invalid address"}},
        {"jsonrpc": "2.0", "id": 3, "result": {"value": "1990-01-01"}},
    ]

    responses = rpc.bulk_request(methods)

    # Verification
    _, call_kwargs = post_request.call_args_list[1]
    data = json.loads(call_kwargs["data"])
    assert data[0]["method"] == "PlcProgram.Browse"
    assert data[0]["params"] == {"mode": "children", "type": None, "var": '"browse".dummy.address'}
    assert data[1]["method"] == "PlcProgram.Read"
    assert data[1]["params"] == {"mode": "simple", "var": '"read".dummy.address'}
    assert data[2]["method"] == "PlcProgram.Write"
    assert data[2]["params"] == {"mode": "simple", "value": "dummy", "var": '"write".dummy.address'}
    assert responses == [
        ({"value": 42}, None),
        (None, JsonRpcError(code=201, message="Invalid address")),
        ({"value": "1990-01-01"}, None),
    ]
