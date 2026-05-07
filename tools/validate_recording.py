#!/usr/bin/env python3
"""
Egocentric Video Recording Schema Validator

Validates recording directories against the schema defined in
RECORDING_DATA_STRUCTURE_V1.1.md (also accepts legacy v1.0 captures).

Usage:
    python validate_recording.py <recording_directory>
    python validate_recording.py recording_550e8400-e29b-41d4-a716-446655440000/

Requirements:
    - Python 3.6+
    - Standard library only (no external dependencies)
"""

import json
import math
import os
import sys
import re
from typing import Dict, List, Any, Optional
from pathlib import Path


class ValidationError(Exception):
    """Custom exception for validation errors."""
    pass


class RecordingValidator:
    """Validates egocentric video recording packages."""

    SUPPORTED_SCHEMA_VERSIONS = ("1.0", "1.1", "1.2")
    VALID_OS = ["ios", "android"]
    VALID_LENS_TYPES = ["ultrawide", "wide", "telephoto", "unknown"]
    VALID_INTRINSICS_SOURCES = ["per_frame", "static", "estimated_fallback", "none"]
    # "opencv5" was a v1.0/v1.1 writer-side typo for Brown-Conrady (the
    # OpenCV 5-coefficient distortion model is exactly Brown-Conrady).
    # v1.2 rejects it; we still accept it for v1.0/v1.1 captures so old
    # bundles validate cleanly.
    VALID_DISTORTION_MODELS = ["brown_conrady", "kannala_brandt", "opencv5"]
    VALID_POSE_SOURCES = ["arkit", "arcore", "imu_raw", "none"]
    VALID_CLOCK_ORIGINS = ["unix_epoch", "session_start"]
    # v1.2 tightening (RECORDING_DATA_STRUCTURE_V1.2.md):
    # widest-lens + raw-IMU + static-K only.
    V1_2_VALID_LENS_TYPES = ["ultrawide", "wide"]
    V1_2_VALID_INTRINSICS_SOURCES = ["static"]
    V1_2_VALID_DISTORTION_MODELS = ["brown_conrady", "kannala_brandt"]
    V1_2_VALID_POSE_SOURCES = ["imu_raw"]
    V1_2_VALID_EXTRINSICS_SOURCES = [
        "platform_api", "model_calibration_table", "factory", "online_estimated",
    ]

    def __init__(self, recording_dir: str):
        self.recording_dir = Path(recording_dir)
        self.metadata: Optional[Dict[str, Any]] = None
        self.frames_data: Optional[List[Dict[str, Any]]] = None
        self.poses_data: Optional[List[Dict[str, Any]]] = None
        self.motion_data: Optional[List[Dict[str, Any]]] = None
        self.warnings: List[str] = []

    @property
    def schema_version(self) -> str:
        return self.metadata["schema_version"] if self.metadata else "unknown"

    def validate(self) -> bool:
        try:
            print(f"Validating recording directory: {self.recording_dir}")

            self._validate_directory_structure()
            self._load_metadata()
            self._validate_metadata_schema()
            self._validate_video_file()
            self._validate_frames_file()
            self._validate_poses_file()
            self._validate_motion_file()
            self._validate_invariants()

            for w in self.warnings:
                print(f"⚠️  {w}")
            print("✅ Recording package is valid!")
            return True

        except ValidationError as e:
            print(f"❌ Validation failed: {e}")
            return False

    def _validate_directory_structure(self):
        if not self.recording_dir.is_dir():
            raise ValidationError(f"Recording directory does not exist: {self.recording_dir}")

        dir_name = self.recording_dir.name
        if not re.match(r'^recording_[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', dir_name):
            raise ValidationError(f"Invalid directory name format: {dir_name}")

        metadata_file = self.recording_dir / "metadata.json"
        video_file = self.recording_dir / "video.mp4"

        if not metadata_file.exists():
            raise ValidationError("Missing required file: metadata.json")
        if not video_file.exists():
            raise ValidationError("Missing required file: video.mp4")

        print("✅ Directory structure is valid")

    def _load_metadata(self):
        metadata_file = self.recording_dir / "metadata.json"
        try:
            with open(metadata_file, 'r', encoding='utf-8') as f:
                self.metadata = json.load(f)
        except json.JSONDecodeError as e:
            raise ValidationError(f"Invalid JSON in metadata.json: {e}")
        except Exception as e:
            raise ValidationError(f"Error reading metadata.json: {e}")
        print("✅ metadata.json loaded successfully")

    def _validate_metadata_schema(self):
        required_fields = [
            "schema_version", "session_id", "captured_at_utc", "app_version",
            "device", "camera", "video", "intrinsics", "capture_platform"
        ]
        for field in required_fields:
            if field not in self.metadata:
                raise ValidationError(f"Missing required field in metadata: {field}")

        version = self.metadata["schema_version"]
        if version not in self.SUPPORTED_SCHEMA_VERSIONS:
            raise ValidationError(
                f"Unsupported schema version: {version} "
                f"(supported: {', '.join(self.SUPPORTED_SCHEMA_VERSIONS)})"
            )

        session_id = self.metadata["session_id"]
        if not re.match(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$', session_id):
            raise ValidationError(f"Invalid session_id format: {session_id}")

        # v1.1-only fields
        if version == "1.1":
            self._validate_v1_1_extras()

        self._validate_device_info(self.metadata["device"])
        self._validate_camera_info(self.metadata["camera"])
        self._validate_video_info(self.metadata["video"])
        self._validate_intrinsics_info(self.metadata["intrinsics"])

        # v1.2 tightening — applied after the per-block checks so each
        # block has already loaded.
        if version == "1.2":
            self._validate_v1_2_extras()

        print(f"✅ metadata.json schema is valid (version {version})")

    def _validate_v1_2_extras(self):
        # session_clock_origin required.
        if "session_clock_origin" not in self.metadata:
            raise ValidationError("v1.2 metadata missing session_clock_origin")
        if self.metadata["session_clock_origin"] not in self.VALID_CLOCK_ORIGINS:
            raise ValidationError(
                f"Invalid session_clock_origin: {self.metadata['session_clock_origin']}"
            )

        # camera.lens_type tightened.
        lens_type = self.metadata["camera"].get("lens_type")
        if lens_type not in self.V1_2_VALID_LENS_TYPES:
            raise ValidationError(
                f"v1.2 camera.lens_type must be one of {self.V1_2_VALID_LENS_TYPES} "
                f"(got {lens_type!r})"
            )

        # intrinsics.source tightened.
        intr_source = self.metadata["intrinsics"].get("source")
        if intr_source not in self.V1_2_VALID_INTRINSICS_SOURCES:
            raise ValidationError(
                f"v1.2 intrinsics.source must be 'static' (got {intr_source!r})"
            )
        if "static_matrix" not in self.metadata["intrinsics"] or \
                self.metadata["intrinsics"].get("static_matrix") is None:
            raise ValidationError("v1.2 requires intrinsics.static_matrix")
        d_model = self.metadata["intrinsics"].get("distortion_model")
        if d_model is not None and d_model not in self.V1_2_VALID_DISTORTION_MODELS:
            raise ValidationError(
                f"v1.2 intrinsics.distortion_model must be one of "
                f"{self.V1_2_VALID_DISTORTION_MODELS} or null (got {d_model!r})"
            )

        # poses.jsonl and frames.jsonl are forbidden under v1.2.
        if (self.recording_dir / "frames.jsonl").exists():
            raise ValidationError("v1.2 forbids frames.jsonl (intrinsics are static)")
        if (self.recording_dir / "poses.jsonl").exists():
            raise ValidationError("v1.2 forbids poses.jsonl (no ARKit/ARCore path)")

        # If a pose block is present at all, source must be imu_raw.
        pose = self.metadata.get("pose")
        if pose is not None:
            src = pose.get("source")
            if src not in self.V1_2_VALID_POSE_SOURCES:
                raise ValidationError(
                    f"v1.2 pose.source must be 'imu_raw' if present (got {src!r}); "
                    f"prefer omitting the pose block entirely"
                )

        # motion block: required, non-empty file.
        motion = self.metadata.get("motion")
        if motion is None or not motion.get("recorded"):
            raise ValidationError("v1.2 requires motion.recorded=true")
        motion_path = self.recording_dir / "motion.jsonl"
        if not motion_path.exists() or motion_path.stat().st_size == 0:
            raise ValidationError("v1.2 requires motion.jsonl present and non-empty")

        # If extrinsics block present, validate it.
        extr = self.metadata.get("extrinsics")
        if extr is not None:
            t = extr.get("T_cam_imu")
            if not isinstance(t, list) or len(t) != 4 or any(
                not isinstance(row, list) or len(row) != 4 for row in t
            ):
                raise ValidationError("extrinsics.T_cam_imu must be 4x4")
            br = t[3]
            if any(abs(br[i]) > 1e-6 for i in range(3)) or abs(br[3] - 1.0) > 1e-6:
                raise ValidationError("extrinsics.T_cam_imu bottom row must be [0,0,0,1]")
            src = extr.get("source")
            if src not in self.V1_2_VALID_EXTRINSICS_SOURCES:
                raise ValidationError(
                    f"extrinsics.source must be one of {self.V1_2_VALID_EXTRINSICS_SOURCES} "
                    f"(got {src!r})"
                )

    def _validate_v1_1_extras(self):
        # session_clock_origin required.
        if "session_clock_origin" not in self.metadata:
            raise ValidationError("v1.1 metadata missing session_clock_origin")
        origin = self.metadata["session_clock_origin"]
        if origin not in self.VALID_CLOCK_ORIGINS:
            raise ValidationError(f"Invalid session_clock_origin: {origin}")

        # pose block required.
        if "pose" not in self.metadata:
            raise ValidationError("v1.1 metadata missing 'pose'")
        pose = self.metadata["pose"]
        if "source" not in pose:
            raise ValidationError("pose.source is required")
        if pose["source"] not in self.VALID_POSE_SOURCES:
            raise ValidationError(f"Invalid pose.source: {pose['source']}")

        # motion block required.
        if "motion" not in self.metadata:
            raise ValidationError("v1.1 metadata missing 'motion'")
        motion = self.metadata["motion"]
        if "recorded" not in motion:
            raise ValidationError("motion.recorded is required")
        if motion.get("recorded"):
            for field in ("rate_hz", "gyro_units", "accel_units", "accel_includes_gravity", "frame"):
                if field not in motion:
                    raise ValidationError(f"motion.{field} required when motion.recorded is true")

    def _validate_device_info(self, device: Dict[str, Any]):
        required_fields = ["os", "os_version", "manufacturer", "model", "model_identifier"]
        for field in required_fields:
            if field not in device:
                raise ValidationError(f"Missing required field in device: {field}")
        if device["os"] not in self.VALID_OS:
            raise ValidationError(f"Invalid OS: {device['os']}")

    def _validate_camera_info(self, camera: Dict[str, Any]):
        required_fields = [
            "lens_id", "lens_type", "horizontal_fov_deg",
            "video_stabilization_enabled", "optical_stabilization_enabled"
        ]
        for field in required_fields:
            if field not in camera:
                raise ValidationError(f"Missing required field in camera: {field}")
        if camera["lens_type"] not in self.VALID_LENS_TYPES:
            raise ValidationError(f"Invalid lens_type: {camera['lens_type']}")
        if camera["video_stabilization_enabled"] is not False:
            raise ValidationError("video_stabilization_enabled must be false")
        if camera["optical_stabilization_enabled"] is not False:
            raise ValidationError("optical_stabilization_enabled must be false")

    def _validate_video_info(self, video: Dict[str, Any]):
        required_fields = [
            "codec", "container", "width", "height", "framerate",
            "duration_sec", "frame_count", "bitrate_bps", "color_space",
            "pixel_format", "has_audio_track"
        ]
        for field in required_fields:
            if field not in video:
                raise ValidationError(f"Missing required field in video: {field}")
        if video["codec"] != "hevc":
            raise ValidationError(f"Invalid codec: {video['codec']}")
        if video["container"] != "mp4":
            raise ValidationError(f"Invalid container: {video['container']}")
        if video["has_audio_track"] is not False:
            raise ValidationError("has_audio_track must be false")
        if video["width"] != 1920 or video["height"] != 1080:
            raise ValidationError(f"Invalid resolution: {video['width']}x{video['height']}")

    def _validate_intrinsics_info(self, intrinsics: Dict[str, Any]):
        required_fields = ["source", "reliable"]
        for field in required_fields:
            if field not in intrinsics:
                raise ValidationError(f"Missing required field in intrinsics: {field}")

        source = intrinsics["source"]
        if source not in self.VALID_INTRINSICS_SOURCES:
            raise ValidationError(f"Invalid intrinsics source: {source}")

        if source == "per_frame":
            if "per_frame_file" not in intrinsics:
                raise ValidationError("per_frame_file required for per_frame source")
            if intrinsics["static_matrix"] is not None:
                raise ValidationError("static_matrix must be null for per_frame source")
        elif source in ["static", "estimated_fallback"]:
            if "static_matrix" not in intrinsics or intrinsics["static_matrix"] is None:
                raise ValidationError(f"static_matrix required for {source} source")
            if intrinsics.get("per_frame_file") is not None:
                raise ValidationError("per_frame_file must be null for static source")

        if intrinsics.get("distortion_model") is not None:
            if intrinsics["distortion_model"] not in self.VALID_DISTORTION_MODELS:
                raise ValidationError(f"Invalid distortion_model: {intrinsics['distortion_model']}")

        # v1.1 §6.3: when a static K is present, the FOV it implies (using
        # video.width and fx) must agree with camera.horizontal_fov_deg to
        # within 10%. Catches the sensor-vs-video coordinate-mixing bug.
        static_matrix = intrinsics.get("static_matrix")
        if static_matrix and isinstance(static_matrix, list) and len(static_matrix) == 3:
            try:
                fx = float(static_matrix[0][0])
                video_width = float(self.metadata["video"]["width"])
                advertised_fov = float(self.metadata["camera"]["horizontal_fov_deg"])
                if fx > 0 and video_width > 0 and advertised_fov > 0:
                    implied_fov = 2.0 * math.atan(video_width / (2.0 * fx)) * 180.0 / math.pi
                    rel_err = abs(implied_fov - advertised_fov) / advertised_fov
                    if rel_err > 0.10:
                        raise ValidationError(
                            f"Static K is internally inconsistent: implied FOV "
                            f"{implied_fov:.1f}° differs from camera.horizontal_fov_deg "
                            f"{advertised_fov:.1f}° by {rel_err*100:.1f}% (>10%). "
                            f"See RECORDING_DATA_STRUCTURE_V1.1.md §6.3 — fx/fy must "
                            f"be in video pixels, not sensor pixels."
                        )
            except (TypeError, ValueError, KeyError, IndexError):
                pass

    def _validate_video_file(self):
        video_file = self.recording_dir / "video.mp4"
        if not video_file.exists():
            raise ValidationError("video.mp4 not found")
        if video_file.stat().st_size == 0:
            raise ValidationError("video.mp4 is empty")
        # v1.1 §10: video.mp4 must be openable without "moov atom not found".
        # Without ffprobe/PyAV we can't fully verify, but we can spot the
        # canonical broken-mp4 signature: missing 'moov' atom anywhere in the file
        # for files small enough to scan cheaply.
        try:
            with open(video_file, 'rb') as f:
                head = f.read(min(2_000_000, video_file.stat().st_size))
            if b'moov' not in head:
                # Larger files often have moov at the tail; only warn when small.
                if video_file.stat().st_size <= 2_000_000:
                    self.warnings.append("video.mp4 missing 'moov' atom in head — may not be finalized")
        except Exception:
            pass
        print("✅ video.mp4 exists and is non-empty")

    # ---------------- frames.jsonl ----------------

    def _validate_frames_file(self):
        frames_file = self.recording_dir / "frames.jsonl"
        intrinsics = self.metadata["intrinsics"]

        if intrinsics["source"] == "per_frame":
            if not frames_file.exists():
                raise ValidationError("frames.jsonl required but not found")
            self._load_frames_file(frames_file)
            self._validate_frames_format()
        else:
            if frames_file.exists():
                raise ValidationError("frames.jsonl should not exist for non-per_frame source")

        print("✅ frames.jsonl validation passed")

    def _load_frames_file(self, frames_file: Path):
        self.frames_data = []
        try:
            with open(frames_file, 'r', encoding='utf-8') as f:
                for line_num, line in enumerate(f, 1):
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        self.frames_data.append(json.loads(line))
                    except json.JSONDecodeError as e:
                        raise ValidationError(f"Invalid JSON in frames.jsonl line {line_num}: {e}")
        except ValidationError:
            raise
        except Exception as e:
            raise ValidationError(f"Error reading frames.jsonl: {e}")

    def _validate_frames_format(self):
        if not self.frames_data:
            raise ValidationError("frames.jsonl is empty")

        for i, frame in enumerate(self.frames_data):
            for field in ("frame_idx", "timestamp_ns", "intrinsic_matrix"):
                if field not in frame:
                    raise ValidationError(f"Missing field '{field}' in frame {i}")

            if frame["frame_idx"] != i:
                raise ValidationError(f"Frame index mismatch: expected {i}, got {frame['frame_idx']}")

            matrix = frame["intrinsic_matrix"]
            if not isinstance(matrix, list) or len(matrix) != 3:
                raise ValidationError(f"Invalid intrinsic matrix in frame {i}: must be 3x3")
            for row_idx, row in enumerate(matrix):
                if not isinstance(row, list) or len(row) != 3:
                    raise ValidationError(f"Invalid intrinsic matrix row {row_idx} in frame {i}")

            # v1.1: third row must be exactly [0, 0, 1]. Tolerant for v1.0
            # since the iOS simd serialization bug was active there.
            if self.schema_version == "1.1":
                third_row = matrix[2]
                if [round(float(x), 6) for x in third_row] != [0.0, 0.0, 1.0]:
                    raise ValidationError(
                        f"Frame {i}: intrinsic_matrix third row must be [0, 0, 1] "
                        f"(got {third_row}) — see RECORDING_DATA_STRUCTURE_V1.1.md §6.1"
                    )
            else:
                third_row = matrix[2]
                if [round(float(x), 6) for x in third_row] != [0.0, 0.0, 1.0]:
                    self.warnings.append(
                        f"Frame {i}: legacy_ios_simd_intrinsic — third row not [0,0,1] (v1.0 captures only)"
                    )

            if i > 0 and frame["timestamp_ns"] <= self.frames_data[i-1]["timestamp_ns"]:
                raise ValidationError(f"Non-monotonic timestamp in frame {i}")

    # ---------------- poses.jsonl ----------------

    def _validate_poses_file(self):
        poses_file = self.recording_dir / "poses.jsonl"
        if self.schema_version != "1.1":
            if poses_file.exists():
                self.warnings.append("poses.jsonl present in v1.0 bundle — ignored by validator")
            return

        pose_source = self.metadata.get("pose", {}).get("source")
        if pose_source in ("arkit", "arcore"):
            if not poses_file.exists():
                raise ValidationError(f"poses.jsonl required when pose.source = '{pose_source}'")
            self._load_poses_file(poses_file)
            self._validate_poses_format()
        else:
            if poses_file.exists():
                raise ValidationError(
                    f"poses.jsonl present but pose.source = '{pose_source}' (expected 'arkit' or 'arcore')"
                )
        print("✅ poses.jsonl validation passed")

    def _load_poses_file(self, poses_file: Path):
        self.poses_data = []
        try:
            with open(poses_file, 'r', encoding='utf-8') as f:
                for line_num, line in enumerate(f, 1):
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        self.poses_data.append(json.loads(line))
                    except json.JSONDecodeError as e:
                        raise ValidationError(f"Invalid JSON in poses.jsonl line {line_num}: {e}")
        except ValidationError:
            raise
        except Exception as e:
            raise ValidationError(f"Error reading poses.jsonl: {e}")

    def _validate_poses_format(self):
        if not self.poses_data:
            raise ValidationError("poses.jsonl is empty")
        for i, pose in enumerate(self.poses_data):
            for field in ("frame_idx", "timestamp_ns", "transform", "tracking_state"):
                if field not in pose:
                    raise ValidationError(f"Missing field '{field}' in poses.jsonl row {i}")
            if pose["frame_idx"] != i:
                raise ValidationError(f"poses.jsonl frame_idx mismatch at row {i}: got {pose['frame_idx']}")
            t = pose["transform"]
            if not isinstance(t, list) or len(t) != 4:
                raise ValidationError(f"poses.jsonl row {i} transform must be 4×4")
            for r, row in enumerate(t):
                if not isinstance(row, list) or len(row) != 4:
                    raise ValidationError(f"poses.jsonl row {i} transform row {r} must have 4 columns")
            if pose["tracking_state"] not in ("normal", "limited", "not_available"):
                raise ValidationError(f"poses.jsonl row {i} invalid tracking_state: {pose['tracking_state']}")

    # ---------------- motion.jsonl ----------------

    def _validate_motion_file(self):
        motion_file = self.recording_dir / "motion.jsonl"
        if self.schema_version != "1.1":
            return

        motion_meta = self.metadata.get("motion", {})
        recorded = motion_meta.get("recorded", False)
        pose_source = self.metadata.get("pose", {}).get("source")

        if pose_source == "imu_raw":
            if not motion_file.exists():
                raise ValidationError("motion.jsonl required when pose.source == 'imu_raw'")
            if not recorded:
                raise ValidationError("motion.recorded must be true when pose.source == 'imu_raw'")

        if recorded and not motion_file.exists():
            raise ValidationError("motion.recorded is true but motion.jsonl is missing")
        if not recorded and motion_file.exists():
            self.warnings.append("motion.jsonl exists but motion.recorded is false")

        if not motion_file.exists():
            return

        self._load_motion_file(motion_file)
        self._validate_motion_format()

        # Rate-hz consistency check (median Δt within 30% of advertised).
        if self.motion_data and len(self.motion_data) > 10:
            timestamps = [s["timestamp_ns"] for s in self.motion_data]
            deltas = sorted(
                timestamps[i + 1] - timestamps[i] for i in range(len(timestamps) - 1)
            )
            median_dt_ns = deltas[len(deltas) // 2]
            if median_dt_ns > 0:
                effective_hz = 1e9 / median_dt_ns
                advertised_hz = motion_meta.get("rate_hz")
                if advertised_hz and abs(effective_hz - advertised_hz) / advertised_hz > 0.30:
                    self.warnings.append(
                        f"motion rate_hz drift: advertised {advertised_hz:.1f} Hz, "
                        f"observed {effective_hz:.1f} Hz"
                    )

        print("✅ motion.jsonl validation passed")

    def _load_motion_file(self, motion_file: Path):
        self.motion_data = []
        try:
            with open(motion_file, 'r', encoding='utf-8') as f:
                for line_num, line in enumerate(f, 1):
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        self.motion_data.append(json.loads(line))
                    except json.JSONDecodeError as e:
                        raise ValidationError(f"Invalid JSON in motion.jsonl line {line_num}: {e}")
        except ValidationError:
            raise
        except Exception as e:
            raise ValidationError(f"Error reading motion.jsonl: {e}")

    def _validate_motion_format(self):
        if not self.motion_data:
            raise ValidationError("motion.jsonl is empty but advertised as recorded")
        for i, sample in enumerate(self.motion_data):
            for field in ("timestamp_ns", "gyro", "accel"):
                if field not in sample:
                    raise ValidationError(f"motion.jsonl row {i} missing '{field}'")
            for field in ("gyro", "accel"):
                vec = sample[field]
                if not isinstance(vec, list) or len(vec) != 3:
                    raise ValidationError(f"motion.jsonl row {i} field '{field}' must be a 3-element list")
            if i > 0 and sample["timestamp_ns"] < self.motion_data[i - 1]["timestamp_ns"]:
                raise ValidationError(f"motion.jsonl row {i} non-monotonic timestamp")

    # ---------------- invariants ----------------

    def _validate_invariants(self):
        video_info = self.metadata["video"]
        intrinsics_info = self.metadata["intrinsics"]

        frames_file = self.recording_dir / "frames.jsonl"
        frames_exists = frames_file.exists()

        if intrinsics_info["source"] == "per_frame" and not frames_exists:
            raise ValidationError("frames.jsonl must exist for per_frame intrinsics source")
        if intrinsics_info["source"] != "per_frame" and frames_exists:
            raise ValidationError("frames.jsonl must not exist for non-per_frame intrinsics source")

        if self.frames_data is not None:
            if len(self.frames_data) != video_info["frame_count"]:
                raise ValidationError(
                    f"Frame count mismatch: metadata says {video_info['frame_count']}, "
                    f"frames.jsonl has {len(self.frames_data)}"
                )

        if self.poses_data is not None:
            if len(self.poses_data) != video_info["frame_count"]:
                raise ValidationError(
                    f"poses.jsonl line count {len(self.poses_data)} != video.frame_count {video_info['frame_count']}"
                )

        if video_info["has_audio_track"] is not False:
            raise ValidationError("has_audio_track must be false")

        print("✅ All invariants satisfied")


def main():
    if len(sys.argv) != 2:
        print("Usage: python validate_recording.py <recording_directory>")
        print("Example: python validate_recording.py recording_550e8400-e29b-41d4-a716-446655440000/")
        sys.exit(1)

    recording_dir = sys.argv[1]

    try:
        validator = RecordingValidator(recording_dir)
        is_valid = validator.validate()
        if is_valid:
            print("\n🎉 Recording package validation PASSED!")
            sys.exit(0)
        else:
            print("\n💥 Recording package validation FAILED!")
            sys.exit(1)
    except Exception as e:
        print(f"\n💥 Validation error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
