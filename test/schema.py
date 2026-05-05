"""Schema validator for recording packages.

This module is the single source of truth for the Section 5 data contract between
the mobile app and the pipeline. Both sides import from here.

Two entry points:
- ``validate_metadata(obj)`` -> ``Metadata`` : validates a parsed metadata.json dict
- ``validate_recording(path)`` -> ``ValidatedRecording`` : validates a full
  recording directory on disk, including frames.jsonl line count and video
  existence/decodability.

Validation failures raise ``SchemaError`` carrying a structured error payload
suitable for emission as JSON.
"""

from __future__ import annotations

import json
import re
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any, List, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field, ValidationError, field_validator, model_validator

SCHEMA_VERSION = "1.2"  # latest accepted version
_ACCEPTED_SCHEMA_VERSIONS = {"1.0", "1.1", "1.2"}
# v1.2 simplifies the contract: only the widest available lens, only raw IMU
# (no ARKit/ARCore), only static intrinsics, no frames.jsonl, no poses.jsonl.
# See docs/specs/RECORDING_DATA_STRUCTURE_V1.2.md.
_V1_2_ALLOWED_LENS_TYPES = {"ultrawide", "wide"}
_V1_2_ALLOWED_INTRINSICS_SOURCES = {"static"}
_V1_2_ALLOWED_POSE_SOURCES = {"imu_raw"}

_ALLOWED_INTRINSICS_SOURCES = {"per_frame", "static", "estimated_fallback", "none"}
_ALLOWED_LENS_TYPES = {"ultrawide", "wide", "telephoto", "unknown"}
_ALLOWED_DISTORTION_MODELS = {"brown_conrady", "kannala_brandt", None}
_ALLOWED_OS = {"ios", "android"}
_ALLOWED_POSE_SOURCES = {"arkit", "arcore", "imu_raw", "none"}
_ALLOWED_CLOCK_ORIGINS = {"unix_epoch", "session_start"}


class SchemaError(Exception):
    """Raised when a recording fails schema validation.

    The ``errors`` attribute is a list of dicts suitable for JSON serialization.
    """

    def __init__(self, errors: List[dict[str, Any]], message: str = "Schema validation failed"):
        super().__init__(message)
        self.errors = errors

    def to_dict(self) -> dict[str, Any]:
        return {"error": "schema_validation_failed", "details": self.errors}


class Device(BaseModel):
    model_config = ConfigDict(extra="allow")
    os: Literal["ios", "android"]
    os_version: str
    manufacturer: str
    model: str
    model_identifier: Optional[str] = None
    has_arkit: Optional[bool] = None
    has_arcore: Optional[bool] = None


class Camera(BaseModel):
    model_config = ConfigDict(extra="allow")
    lens_id: Optional[str] = None
    lens_type: Literal["ultrawide", "wide", "telephoto", "unknown"]
    physical_focal_length_mm: Optional[float] = None
    sensor_physical_size_mm: Optional[List[float]] = None
    sensor_pixel_array_size: Optional[List[int]] = None
    horizontal_fov_deg: float
    video_stabilization_enabled: Optional[bool] = None
    optical_stabilization_enabled: Optional[bool] = None
    # v1.2: rolling-shutter top-to-bottom readout time. Required for VIO that
    # corrects rolling shutter; null only when the platform doesn't expose it.
    # Android: SENSOR_INFO_ROLLING_SHUTTER_SKEW. iOS: hardcoded per model_identifier.
    rolling_shutter_skew_ns: Optional[int] = Field(default=None, ge=0)


class Video(BaseModel):
    model_config = ConfigDict(extra="allow")
    codec: str
    container: str
    width: int = Field(gt=0)
    height: int = Field(gt=0)
    framerate: float = Field(gt=0)
    duration_sec: float = Field(ge=0)
    frame_count: int = Field(gt=0)
    bitrate_bps: Optional[int] = None
    color_space: Optional[str] = None
    pixel_format: Optional[str] = None
    has_audio_track: bool

    @field_validator("has_audio_track")
    @classmethod
    def _no_audio(cls, v: bool) -> bool:
        if v is not False:
            raise ValueError("video.has_audio_track must be false")
        return v


class Intrinsics(BaseModel):
    model_config = ConfigDict(extra="allow")
    source: Literal["per_frame", "static", "estimated_fallback", "none"]
    per_frame_file: Optional[str] = None
    static_matrix: Optional[List[List[float]]] = None
    distortion_model: Optional[Literal["brown_conrady", "kannala_brandt"]] = None
    distortion_coeffs: Optional[List[float]] = None
    reliable: bool
    notes: Optional[str] = None

    @model_validator(mode="after")
    def _cross_field(self) -> "Intrinsics":
        if self.source == "per_frame":
            if not self.per_frame_file:
                raise ValueError("intrinsics.per_frame_file required when source=per_frame")
            if self.static_matrix is not None:
                raise ValueError("intrinsics.static_matrix must be null when source=per_frame")
        elif self.source in {"static", "estimated_fallback"}:
            if self.static_matrix is None:
                raise ValueError(f"intrinsics.static_matrix required when source={self.source}")
            if self.per_frame_file is not None:
                raise ValueError(f"intrinsics.per_frame_file must be null when source={self.source}")
            _validate_3x3(self.static_matrix, "intrinsics.static_matrix")
        elif self.source == "none":
            if self.static_matrix is not None or self.per_frame_file is not None:
                raise ValueError("intrinsics.static_matrix and per_frame_file must be null when source=none")
        return self


class Pose(BaseModel):
    """v1.1: per-frame pose source (ARKit / ARCore / IMU / none)."""

    model_config = ConfigDict(extra="allow")
    source: Literal["arkit", "arcore", "imu_raw", "none"]
    frame_origin: Optional[str] = None
    coordinate_convention: Optional[str] = None
    transform_kind: Optional[Literal["camera_to_world", "world_to_camera"]] = "camera_to_world"
    rate_hz: Optional[float] = None
    tracking_state_field: Optional[str] = None
    notes: Optional[str] = None


class Motion(BaseModel):
    """Raw IMU stream metadata.

    v1.1 introduced the block; v1.2 adds optional noise-density / random-walk
    fields used by VIO weighting.
    """

    model_config = ConfigDict(extra="allow")
    recorded: bool
    rate_hz: Optional[float] = None
    gyro_units: Optional[str] = None
    accel_units: Optional[str] = None
    accel_includes_gravity: Optional[bool] = None
    frame: Optional[str] = "device_body"
    notes: Optional[str] = None
    # v1.2: IMU noise model. Continuous-time densities from the sensor
    # datasheet (or factory calibration). Required for sound VIO weighting;
    # OPTIONAL in the schema for backward compatibility but RECOMMENDED.
    noise_density_gyro: Optional[float] = Field(default=None, gt=0)   # rad/s/√Hz
    noise_density_accel: Optional[float] = Field(default=None, gt=0)  # m/s²/√Hz
    random_walk_gyro: Optional[float] = Field(default=None, gt=0)     # rad/s²/√Hz
    random_walk_accel: Optional[float] = Field(default=None, gt=0)    # m/s³/√Hz


class Extrinsics(BaseModel):
    """v1.2: rigid transform from IMU body frame to camera optical frame.

    ``T_cam_imu`` is a 4×4 row-major homogeneous matrix that maps a point
    expressed in the IMU body frame into the camera optical frame:
    ``p_cam = T_cam_imu @ p_imu``. Without this, VIO cannot fuse IMU and
    visual measurements; with a wrong rotation, it diverges in seconds.
    """

    model_config = ConfigDict(extra="allow")
    T_cam_imu: List[List[float]]
    source: Literal[
        "platform_api",            # Android Camera2 LENS_POSE_*; trustworthy
        "model_calibration_table", # per-model_identifier lookup; iOS-typical
        "factory",                 # from a per-device factory calibration file
        "online_estimated",        # estimated by an online VIO solver
    ]
    # Camera-IMU temporal offset: camera_pts_ns - imu_ts_ns at the same event.
    # Positive means the camera path lags the IMU. May be left null if unknown
    # (the offline VIO will estimate it online).
    time_offset_sec: Optional[float] = None
    # Optional uncertainty hints for the calibration source.
    rotation_stddev_deg: Optional[float] = Field(default=None, ge=0)
    translation_stddev_m: Optional[float] = Field(default=None, ge=0)
    notes: Optional[str] = None

    @field_validator("T_cam_imu")
    @classmethod
    def _check_4x4(cls, v: List[List[float]]) -> List[List[float]]:
        if len(v) != 4 or any(len(row) != 4 for row in v):
            raise ValueError("extrinsics.T_cam_imu must be 4x4")
        br = v[3]
        if not (
            abs(br[0]) < 1e-6
            and abs(br[1]) < 1e-6
            and abs(br[2]) < 1e-6
            and abs(br[3] - 1.0) < 1e-6
        ):
            raise ValueError("extrinsics.T_cam_imu bottom row must be [0,0,0,1]")
        return v


class CapturePlatform(BaseModel):
    model_config = ConfigDict(extra="allow")
    flutter_version: Optional[str] = None
    native_sdk_version: Optional[str] = None
    capture_pipeline_version: Optional[str] = None


class Metadata(BaseModel):
    model_config = ConfigDict(extra="allow")
    schema_version: str
    session_id: str
    captured_at_utc: str
    session_clock_origin: Optional[str] = "unix_epoch"
    app_version: str
    device: Device
    camera: Camera
    video: Video
    intrinsics: Intrinsics
    pose: Optional[Pose] = None
    motion: Optional[Motion] = None
    capture_platform: Optional[CapturePlatform] = None
    # v1.2: VIO calibration. RECOMMENDED for v1.2 captures intended for
    # downstream VIO; optional for backward compatibility with v1.0 / v1.1.
    extrinsics: Optional[Extrinsics] = None
    # v1.2: explicit clock-id label on top of session_clock_origin. Lets
    # consumers distinguish e.g. CLOCK_BOOTTIME vs. CLOCK_MONOTONIC on Android,
    # or kCMClockSourceTypeHostTime vs. mach_absolute_time on iOS.
    device_clock_id: Optional[str] = None

    @field_validator("schema_version")
    @classmethod
    def _schema_version(cls, v: str) -> str:
        if v not in _ACCEPTED_SCHEMA_VERSIONS:
            raise ValueError(
                f"schema_version must be one of {sorted(_ACCEPTED_SCHEMA_VERSIONS)}, got {v!r}"
            )
        return v

    @field_validator("session_clock_origin")
    @classmethod
    def _clock_origin(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and v not in _ALLOWED_CLOCK_ORIGINS:
            raise ValueError(
                f"session_clock_origin must be one of {sorted(_ALLOWED_CLOCK_ORIGINS)}, got {v!r}"
            )
        return v

    @field_validator("session_id")
    @classmethod
    def _session_id(cls, v: str) -> str:
        try:
            u = uuid.UUID(v)
        except Exception as e:
            raise ValueError(f"session_id must be a UUID, got {v!r}") from e
        if u.version != 4:
            raise ValueError(f"session_id must be UUID v4, got version {u.version}")
        return v

    @field_validator("captured_at_utc")
    @classmethod
    def _iso8601_utc(cls, v: str) -> str:
        # Accept forms like 2026-04-24T14:32:11.123Z or 2026-04-24T14:32:11Z
        if not re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z", v):
            raise ValueError(f"captured_at_utc must be ISO 8601 UTC ending in Z, got {v!r}")
        return v


class Frame(BaseModel):
    model_config = ConfigDict(extra="allow")
    frame_idx: int = Field(ge=0)
    timestamp_ns: int = Field(ge=0)
    intrinsic_matrix: List[List[float]]
    lens_id: Optional[str] = None

    @field_validator("intrinsic_matrix")
    @classmethod
    def _matrix_shape(cls, v: List[List[float]]) -> List[List[float]]:
        # Shape-only check: per-frame intrinsics may use a non-spec layout
        # (the iOS app currently emits a simd_float3x3 padding-bug serialization
        # where cy is missing). Semantic recovery happens in
        # ``pipeline.intrinsics._parse_intrinsic_matrix`` once we know the
        # video resolution.
        _validate_3x3_shape(v, "intrinsic_matrix")
        return v


def _validate_3x3(mat: List[List[float]], field: str) -> None:
    """Strict 3x3 intrinsic matrix check (used for static_matrix)."""
    _validate_3x3_shape(mat, field)
    if mat[2][0] != 0.0 or mat[2][1] != 0.0 or mat[2][2] != 1.0:
        raise ValueError(f"{field} last row must be [0,0,1]")


def _validate_3x3_shape(mat: List[List[float]], field: str) -> None:
    if len(mat) != 3 or any(len(row) != 3 for row in mat):
        raise ValueError(f"{field} must be 3x3")


@dataclass
class ValidatedRecording:
    """Result of validating a recording directory on disk."""

    root: Path
    metadata: Metadata
    video_path: Path
    frames_path: Optional[Path]
    frames: Optional[List[Frame]]  # populated iff source == per_frame
    poses_path: Optional[Path] = None  # v1.1: present iff pose.source ∈ {arkit, arcore}
    motion_path: Optional[Path] = None  # v1.1: present iff motion.recorded


def validate_metadata(obj: Any) -> Metadata:
    """Validate a parsed metadata.json dict, returning the typed model."""

    try:
        return Metadata.model_validate(obj)
    except ValidationError as e:
        raise SchemaError(e.errors()) from e


def validate_recording(path: Path | str) -> ValidatedRecording:
    """Validate a recording directory at ``path``.

    Checks:
    - metadata.json exists and parses
    - video.mp4 exists (does not decode it here; that happens in the decode step)
    - frames.jsonl exists iff source==per_frame, and its line count equals
      video.frame_count
    - all per-frame records parse and frame_idx values are 0..N-1 monotonic
    """

    root = Path(path)
    errors: List[dict[str, Any]] = []

    meta_path = root / "metadata.json"
    video_path = root / "video.mp4"
    frames_path = root / "frames.jsonl"

    if not meta_path.is_file():
        errors.append({"field": "metadata.json", "msg": "missing"})
    if not video_path.is_file():
        errors.append({"field": "video.mp4", "msg": "missing"})
    if errors:
        raise SchemaError(errors)

    try:
        with meta_path.open("r", encoding="utf-8") as f:
            meta_obj = json.load(f)
    except json.JSONDecodeError as e:
        raise SchemaError([{"field": "metadata.json", "msg": f"not valid JSON: {e}"}]) from e

    metadata = validate_metadata(meta_obj)

    frames: Optional[List[Frame]] = None
    frames_file: Optional[Path] = None
    if metadata.intrinsics.source == "per_frame":
        if not frames_path.is_file():
            raise SchemaError([{"field": "frames.jsonl", "msg": "missing but intrinsics.source=per_frame"}])
        frames_file = frames_path
        frames = _load_frames(frames_path)
        if len(frames) != metadata.video.frame_count:
            raise SchemaError(
                [
                    {
                        "field": "frames.jsonl",
                        "msg": (
                            f"line count {len(frames)} != video.frame_count "
                            f"{metadata.video.frame_count}"
                        ),
                    }
                ]
            )
        # Frame indices must be 0..N-1 monotonic, timestamps strictly increasing.
        prev_ts = -1
        for i, fr in enumerate(frames):
            if fr.frame_idx != i:
                raise SchemaError(
                    [{"field": "frames.jsonl", "msg": f"frame_idx {fr.frame_idx} at line {i} (expected {i})"}]
                )
            if fr.timestamp_ns <= prev_ts:
                raise SchemaError(
                    [{"field": "frames.jsonl", "msg": f"timestamps not strictly increasing at frame {i}"}]
                )
            prev_ts = fr.timestamp_ns
    else:
        # frames.jsonl must NOT be present when not per_frame (Section 5.4 invariant)
        if frames_path.is_file():
            raise SchemaError(
                [
                    {
                        "field": "frames.jsonl",
                        "msg": f"present but intrinsics.source={metadata.intrinsics.source}",
                    }
                ]
            )

    # v1.1: poses.jsonl + motion.jsonl
    poses_path: Optional[Path] = None
    motion_path: Optional[Path] = None

    pose_src = metadata.pose.source if metadata.pose is not None else None
    pj = root / "poses.jsonl"
    if pose_src in ("arkit", "arcore"):
        if not pj.is_file():
            raise SchemaError(
                [{"field": "poses.jsonl", "msg": f"missing but pose.source={pose_src}"}]
            )
        # Line-count check (cheap; full per-row validation deferred until used).
        with pj.open("r", encoding="utf-8") as f:
            n_lines = sum(1 for line in f if line.strip())
        if n_lines != metadata.video.frame_count:
            raise SchemaError(
                [
                    {
                        "field": "poses.jsonl",
                        "msg": (
                            f"line count {n_lines} != video.frame_count "
                            f"{metadata.video.frame_count}"
                        ),
                    }
                ]
            )
        poses_path = pj
    elif pj.is_file():
        # Present but not advertised — surface as a warning, not a hard error,
        # since the spec doesn't strictly forbid it.
        poses_path = pj

    if metadata.motion is not None and metadata.motion.recorded:
        mj = root / "motion.jsonl"
        if not mj.is_file():
            raise SchemaError(
                [{"field": "motion.jsonl", "msg": "motion.recorded=true but file missing"}]
            )
        # Sanity check: at least one row.
        with mj.open("r", encoding="utf-8") as f:
            for line in f:
                if line.strip():
                    motion_path = mj
                    break
            else:
                raise SchemaError(
                    [{"field": "motion.jsonl", "msg": "file is empty"}]
                )

    # v1.2 tighter rules: only the widest-lens + raw-IMU path is allowed.
    if metadata.schema_version == "1.2":
        v12_errors: List[dict[str, Any]] = []
        if metadata.camera.lens_type not in _V1_2_ALLOWED_LENS_TYPES:
            v12_errors.append(
                {
                    "field": "camera.lens_type",
                    "msg": (
                        f"v1.2 requires the widest available lens "
                        f"(must be one of {sorted(_V1_2_ALLOWED_LENS_TYPES)}, "
                        f"got {metadata.camera.lens_type!r})"
                    ),
                }
            )
        if metadata.intrinsics.source not in _V1_2_ALLOWED_INTRINSICS_SOURCES:
            v12_errors.append(
                {
                    "field": "intrinsics.source",
                    "msg": (
                        f"v1.2 only accepts {sorted(_V1_2_ALLOWED_INTRINSICS_SOURCES)} "
                        f"(got {metadata.intrinsics.source!r}); per_frame/estimated_fallback/none are removed"
                    ),
                }
            )
        if frames_file is not None or frames_path.is_file():
            v12_errors.append(
                {"field": "frames.jsonl", "msg": "v1.2 forbids frames.jsonl (intrinsics are static)"}
            )
        if poses_path is not None:
            v12_errors.append(
                {"field": "poses.jsonl", "msg": "v1.2 forbids poses.jsonl (no ARKit/ARCore path)"}
            )
        pose_src_v12 = metadata.pose.source if metadata.pose is not None else None
        if pose_src_v12 is not None and pose_src_v12 not in _V1_2_ALLOWED_POSE_SOURCES:
            v12_errors.append(
                {
                    "field": "pose.source",
                    "msg": (
                        f"v1.2 only accepts pose.source={sorted(_V1_2_ALLOWED_POSE_SOURCES)} "
                        f"(got {pose_src_v12!r}); arkit/arcore/none are removed"
                    ),
                }
            )
        if metadata.motion is None or not metadata.motion.recorded:
            v12_errors.append(
                {"field": "motion.recorded", "msg": "v1.2 requires motion.recorded=true (raw IMU is mandatory)"}
            )
        if motion_path is None:
            v12_errors.append(
                {"field": "motion.jsonl", "msg": "v1.2 requires motion.jsonl to be present and non-empty"}
            )
        if v12_errors:
            raise SchemaError(v12_errors)

    return ValidatedRecording(
        root=root,
        metadata=metadata,
        video_path=video_path,
        frames_path=frames_file,
        frames=frames,
        poses_path=poses_path,
        motion_path=motion_path,
    )


def _load_frames(path: Path) -> List[Frame]:
    out: List[Frame] = []
    with path.open("r", encoding="utf-8") as f:
        for lineno, raw in enumerate(f):
            raw = raw.strip()
            if not raw:
                continue
            try:
                obj = json.loads(raw)
            except json.JSONDecodeError as e:
                raise SchemaError(
                    [{"field": "frames.jsonl", "msg": f"line {lineno}: invalid JSON: {e}"}]
                ) from e
            try:
                out.append(Frame.model_validate(obj))
            except ValidationError as e:
                raise SchemaError(
                    [{"field": "frames.jsonl", "msg": f"line {lineno}: {e.errors()}"}]
                ) from e
    return out
