# pylint: disable=too-few-public-methods

from enum import Enum
from typing import Any, Self

from pydantic import BaseModel, field_serializer, model_validator


class JsonRpcBase(BaseModel):
    """Base model providing some global configuration."""

    @field_serializer("*", check_fields=False)
    def serialize_enum(self, value):
        if isinstance(value, Enum):
            return value.value
        return value

    def model_dump_json(self, **kwargs) -> str:
        return super().model_dump_json(exclude_none=True, **kwargs)

    def __str__(self):
        return self.model_dump_json()


class JsonRpcRequest(JsonRpcBase):
    """JSON-RPC request message model."""

    id: int | str = 1
    jsonrpc: str = "2.0"
    method: str


class JsonRpcError(JsonRpcBase):
    """JSON-RPC response error model."""

    code: int
    message: str
    data: Any | None = None


class JsonRpcResponse(JsonRpcBase):
    """JSON-RPC response message model."""

    id: int | str
    jsonrpc: str
    result: Any | None = None
    error: JsonRpcError | None = None


class BrowseType(str, Enum):
    """PlcProgram.Browse type."""

    CODE_BLOCKS = "code_blocks"
    DATA_BLOCKS = "data_blocks"
    TAGS = "tags"


class BrowseMode(str, Enum):
    """PlcProgram.Browse mode."""

    CHILDREN = "children"
    VAR = "var"


class ReadWriteMode(str, Enum):
    """PlcProgram.Read/Write mode."""

    RAW = "raw"
    SIMPLE = "simple"


class BrowseParams(JsonRpcBase):
    """PlcProgram.Browse params."""

    mode: BrowseMode
    type: list[BrowseType] | None = None
    var: str | None = None

    @model_validator(mode="after")
    def validate_combination(self) -> Self:
        if self.mode == BrowseMode.VAR and self.var is None:
            raise ValueError(f"'var' is required when 'mode' is '{BrowseMode.VAR.value}'")
        return self


class PlcProgramBrowse(JsonRpcRequest):
    """PlcProgram.Browse request message model."""

    method: str = "PlcProgram.Browse"
    params: BrowseParams


class LoginParams(JsonRpcBase):
    """Api.Login params."""

    user: str
    password: str


class ApiLogin(JsonRpcRequest):
    """Api.Login request message model."""

    method: str = "Api.Login"
    params: LoginParams


class ReadParams(JsonRpcBase):
    """PlcProgram.Read params."""

    mode: ReadWriteMode = "simple"
    var: str


class PlcProgramRead(JsonRpcRequest):
    """PlcProgram.Read request message model."""

    method: str = "PlcProgram.Read"
    params: ReadParams


class WriteParams(JsonRpcBase):
    """PlcProgram.Write params."""

    mode: ReadWriteMode = "simple"
    value: Any
    var: str


class PlcProgramWrite(JsonRpcRequest):
    """PlcProgram.Write request message model."""

    method: str = "PlcProgram.Write"
    params: WriteParams
