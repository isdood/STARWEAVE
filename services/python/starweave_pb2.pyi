from google.protobuf.internal import containers as _containers
from google.protobuf import descriptor as _descriptor
from google.protobuf import message as _message
from collections.abc import Iterable as _Iterable, Mapping as _Mapping
from typing import ClassVar as _ClassVar, Optional as _Optional, Union as _Union

DESCRIPTOR: _descriptor.FileDescriptor

class Pattern(_message.Message):
    __slots__ = ("id", "data", "metadata", "timestamp")
    class MetadataEntry(_message.Message):
        __slots__ = ("key", "value")
        KEY_FIELD_NUMBER: _ClassVar[int]
        VALUE_FIELD_NUMBER: _ClassVar[int]
        key: str
        value: str
        def __init__(self, key: _Optional[str] = ..., value: _Optional[str] = ...) -> None: ...
    ID_FIELD_NUMBER: _ClassVar[int]
    DATA_FIELD_NUMBER: _ClassVar[int]
    METADATA_FIELD_NUMBER: _ClassVar[int]
    TIMESTAMP_FIELD_NUMBER: _ClassVar[int]
    id: str
    data: bytes
    metadata: _containers.ScalarMap[str, str]
    timestamp: float
    def __init__(self, id: _Optional[str] = ..., data: _Optional[bytes] = ..., metadata: _Optional[_Mapping[str, str]] = ..., timestamp: _Optional[float] = ...) -> None: ...

class PatternRequest(_message.Message):
    __slots__ = ("pattern", "context")
    PATTERN_FIELD_NUMBER: _ClassVar[int]
    CONTEXT_FIELD_NUMBER: _ClassVar[int]
    pattern: Pattern
    context: _containers.RepeatedScalarFieldContainer[str]
    def __init__(self, pattern: _Optional[_Union[Pattern, _Mapping]] = ..., context: _Optional[_Iterable[str]] = ...) -> None: ...

class PatternResponse(_message.Message):
    __slots__ = ("request_id", "labels", "confidences", "error", "metadata")
    class ConfidencesEntry(_message.Message):
        __slots__ = ("key", "value")
        KEY_FIELD_NUMBER: _ClassVar[int]
        VALUE_FIELD_NUMBER: _ClassVar[int]
        key: str
        value: float
        def __init__(self, key: _Optional[str] = ..., value: _Optional[float] = ...) -> None: ...
    class MetadataEntry(_message.Message):
        __slots__ = ("key", "value")
        KEY_FIELD_NUMBER: _ClassVar[int]
        VALUE_FIELD_NUMBER: _ClassVar[int]
        key: str
        value: str
        def __init__(self, key: _Optional[str] = ..., value: _Optional[str] = ...) -> None: ...
    REQUEST_ID_FIELD_NUMBER: _ClassVar[int]
    LABELS_FIELD_NUMBER: _ClassVar[int]
    CONFIDENCES_FIELD_NUMBER: _ClassVar[int]
    ERROR_FIELD_NUMBER: _ClassVar[int]
    METADATA_FIELD_NUMBER: _ClassVar[int]
    request_id: str
    labels: _containers.RepeatedScalarFieldContainer[str]
    confidences: _containers.ScalarMap[str, float]
    error: str
    metadata: _containers.ScalarMap[str, str]
    def __init__(self, request_id: _Optional[str] = ..., labels: _Optional[_Iterable[str]] = ..., confidences: _Optional[_Mapping[str, float]] = ..., error: _Optional[str] = ..., metadata: _Optional[_Mapping[str, str]] = ...) -> None: ...

class StatusRequest(_message.Message):
    __slots__ = ("detailed",)
    DETAILED_FIELD_NUMBER: _ClassVar[int]
    detailed: bool
    def __init__(self, detailed: bool = ...) -> None: ...

class StatusResponse(_message.Message):
    __slots__ = ("status", "version", "uptime", "metrics")
    class MetricsEntry(_message.Message):
        __slots__ = ("key", "value")
        KEY_FIELD_NUMBER: _ClassVar[int]
        VALUE_FIELD_NUMBER: _ClassVar[int]
        key: str
        value: str
        def __init__(self, key: _Optional[str] = ..., value: _Optional[str] = ...) -> None: ...
    STATUS_FIELD_NUMBER: _ClassVar[int]
    VERSION_FIELD_NUMBER: _ClassVar[int]
    UPTIME_FIELD_NUMBER: _ClassVar[int]
    METRICS_FIELD_NUMBER: _ClassVar[int]
    status: str
    version: str
    uptime: int
    metrics: _containers.ScalarMap[str, str]
    def __init__(self, status: _Optional[str] = ..., version: _Optional[str] = ..., uptime: _Optional[int] = ..., metrics: _Optional[_Mapping[str, str]] = ...) -> None: ...
