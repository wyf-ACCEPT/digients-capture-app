#!/usr/bin/env python3
"""
Egocentric Video Recording Schema Validator

This script validates recording directories against the schema defined in Section 5
of the Mobile App Specification. It checks the structure, metadata, and invariants
of egocentric video capture recordings.

Usage:
    python validate_recording.py <recording_directory>
    python validate_recording.py recording_550e8400-e29b-41d4-a716-446655440000/

Requirements:
    - Python 3.6+
    - Standard library only (no external dependencies)
"""

import json
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

    SCHEMA_VERSION = "1.0"
    VALID_OS = ["ios", "android"]
    VALID_LENS_TYPES = ["ultrawide", "wide", "telephoto", "unknown"]
    VALID_INTRINSICS_SOURCES = ["per_frame", "static", "estimated_fallback", "none"]
    VALID_DISTORTION_MODELS = ["brown_conrady", "kannala_brandt"]

    def __init__(self, recording_dir: str):
        self.recording_dir = Path(recording_dir)
        self.metadata = None
        self.frames_data = None

    def validate(self) -> bool:
        """Main validation method. Returns True if valid, raises ValidationError if not."""
        try:
            print(f"Validating recording directory: {self.recording_dir}")

            self._validate_directory_structure()
            self._load_metadata()
            self._validate_metadata_schema()
            self._validate_video_file()
            self._validate_frames_file()
            self._validate_invariants()

            print("✅ Recording package is valid!")
            return True

        except ValidationError as e:
            print(f"❌ Validation failed: {e}")
            return False

    def _validate_directory_structure(self):
        """Validate the basic directory structure."""
        if not self.recording_dir.is_dir():
            raise ValidationError(f"Recording directory does not exist: {self.recording_dir}")

        # Check directory naming convention
        dir_name = self.recording_dir.name
        if not re.match(r'^recording_[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', dir_name):
            raise ValidationError(f"Invalid directory name format: {dir_name}")

        # Check required files
        metadata_file = self.recording_dir / "metadata.json"
        video_file = self.recording_dir / "video.mp4"

        if not metadata_file.exists():
            raise ValidationError("Missing required file: metadata.json")

        if not video_file.exists():
            raise ValidationError("Missing required file: video.mp4")

        print("✅ Directory structure is valid")

    def _load_metadata(self):
        """Load and parse the metadata.json file."""
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
        """Validate the metadata.json schema."""
        required_fields = [
            "schema_version", "session_id", "captured_at_utc", "app_version",
            "device", "camera", "video", "intrinsics", "capture_platform"
        ]

        for field in required_fields:
            if field not in self.metadata:
                raise ValidationError(f"Missing required field in metadata: {field}")

        # Validate schema version
        if self.metadata["schema_version"] != self.SCHEMA_VERSION:
            raise ValidationError(f"Unsupported schema version: {self.metadata['schema_version']}")

        # Validate session_id format (UUID v4)
        session_id = self.metadata["session_id"]
        if not re.match(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$', session_id):
            raise ValidationError(f"Invalid session_id format: {session_id}")

        # Validate device info
        self._validate_device_info(self.metadata["device"])

        # Validate camera info
        self._validate_camera_info(self.metadata["camera"])

        # Validate video info
        self._validate_video_info(self.metadata["video"])

        # Validate intrinsics info
        self._validate_intrinsics_info(self.metadata["intrinsics"])

        print("✅ metadata.json schema is valid")

    def _validate_device_info(self, device: Dict[str, Any]):
        """Validate device information."""
        required_fields = ["os", "os_version", "manufacturer", "model", "model_identifier"]

        for field in required_fields:
            if field not in device:
                raise ValidationError(f"Missing required field in device: {field}")

        if device["os"] not in self.VALID_OS:
            raise ValidationError(f"Invalid OS: {device['os']}")

    def _validate_camera_info(self, camera: Dict[str, Any]):
        """Validate camera information."""
        required_fields = [
            "lens_id", "lens_type", "horizontal_fov_deg",
            "video_stabilization_enabled", "optical_stabilization_enabled"
        ]

        for field in required_fields:
            if field not in camera:
                raise ValidationError(f"Missing required field in camera: {field}")

        if camera["lens_type"] not in self.VALID_LENS_TYPES:
            raise ValidationError(f"Invalid lens_type: {camera['lens_type']}")

        # Validate stabilization is disabled
        if camera["video_stabilization_enabled"] is not False:
            raise ValidationError("video_stabilization_enabled must be false")

        if camera["optical_stabilization_enabled"] is not False:
            raise ValidationError("optical_stabilization_enabled must be false")

    def _validate_video_info(self, video: Dict[str, Any]):
        """Validate video information."""
        required_fields = [
            "codec", "container", "width", "height", "framerate",
            "duration_sec", "frame_count", "bitrate_bps", "color_space",
            "pixel_format", "has_audio_track"
        ]

        for field in required_fields:
            if field not in video:
                raise ValidationError(f"Missing required field in video: {field}")

        # Validate video format
        if video["codec"] != "hevc":
            raise ValidationError(f"Invalid codec: {video['codec']}")

        if video["container"] != "mp4":
            raise ValidationError(f"Invalid container: {video['container']}")

        if video["has_audio_track"] is not False:
            raise ValidationError("has_audio_track must be false")

        # Validate resolution
        if video["width"] != 1920 or video["height"] != 1080:
            raise ValidationError(f"Invalid resolution: {video['width']}x{video['height']}")

    def _validate_intrinsics_info(self, intrinsics: Dict[str, Any]):
        """Validate intrinsics information."""
        required_fields = ["source", "reliable"]

        for field in required_fields:
            if field not in intrinsics:
                raise ValidationError(f"Missing required field in intrinsics: {field}")

        source = intrinsics["source"]
        if source not in self.VALID_INTRINSICS_SOURCES:
            raise ValidationError(f"Invalid intrinsics source: {source}")

        # Validate source-specific fields
        if source == "per_frame":
            if "per_frame_file" not in intrinsics:
                raise ValidationError("per_frame_file required for per_frame source")
            if intrinsics["static_matrix"] is not None:
                raise ValidationError("static_matrix must be null for per_frame source")
        elif source in ["static", "estimated_fallback"]:
            if "static_matrix" not in intrinsics or intrinsics["static_matrix"] is None:
                raise ValidationError(f"static_matrix required for {source} source")
            if "per_frame_file" in intrinsics and intrinsics["per_frame_file"] is not None:
                raise ValidationError("per_frame_file must be null for static source")

        # Validate distortion model if present
        if "distortion_model" in intrinsics and intrinsics["distortion_model"] is not None:
            if intrinsics["distortion_model"] not in self.VALID_DISTORTION_MODELS:
                raise ValidationError(f"Invalid distortion_model: {intrinsics['distortion_model']}")

    def _validate_video_file(self):
        """Validate the video.mp4 file."""
        video_file = self.recording_dir / "video.mp4"

        if not video_file.exists():
            raise ValidationError("video.mp4 not found")

        # Basic file size check
        file_size = video_file.stat().st_size
        if file_size == 0:
            raise ValidationError("video.mp4 is empty")

        print("✅ video.mp4 exists and is non-empty")

    def _validate_frames_file(self):
        """Validate the frames.jsonl file if it should exist."""
        frames_file = self.recording_dir / "frames.jsonl"
        intrinsics = self.metadata["intrinsics"]

        if intrinsics["source"] == "per_frame":
            if not frames_file.exists():
                raise ValidationError("frames.jsonl required but not found")

            # Load and validate frames file
            self._load_frames_file(frames_file)
            self._validate_frames_format()

        else:
            if frames_file.exists():
                raise ValidationError("frames.jsonl should not exist for non-per_frame source")

        print("✅ frames.jsonl validation passed")

    def _load_frames_file(self, frames_file: Path):
        """Load the frames.jsonl file."""
        self.frames_data = []

        try:
            with open(frames_file, 'r', encoding='utf-8') as f:
                for line_num, line in enumerate(f, 1):
                    line = line.strip()
                    if not line:
                        continue

                    try:
                        frame_data = json.loads(line)
                        self.frames_data.append(frame_data)
                    except json.JSONDecodeError as e:
                        raise ValidationError(f"Invalid JSON in frames.jsonl line {line_num}: {e}")

        except Exception as e:
            raise ValidationError(f"Error reading frames.jsonl: {e}")

    def _validate_frames_format(self):
        """Validate the format of frames data."""
        if not self.frames_data:
            raise ValidationError("frames.jsonl is empty")

        for i, frame in enumerate(self.frames_data):
            # Check required fields
            required_fields = ["frame_idx", "timestamp_ns", "intrinsic_matrix"]
            for field in required_fields:
                if field not in frame:
                    raise ValidationError(f"Missing field '{field}' in frame {i}")

            # Validate frame index
            if frame["frame_idx"] != i:
                raise ValidationError(f"Frame index mismatch: expected {i}, got {frame['frame_idx']}")

            # Validate intrinsic matrix format
            matrix = frame["intrinsic_matrix"]
            if not isinstance(matrix, list) or len(matrix) != 3:
                raise ValidationError(f"Invalid intrinsic matrix in frame {i}: must be 3x3")

            for row_idx, row in enumerate(matrix):
                if not isinstance(row, list) or len(row) != 3:
                    raise ValidationError(f"Invalid intrinsic matrix row {row_idx} in frame {i}")

            # Validate timestamp is monotonic
            if i > 0 and frame["timestamp_ns"] <= self.frames_data[i-1]["timestamp_ns"]:
                raise ValidationError(f"Non-monotonic timestamp in frame {i}")

    def _validate_invariants(self):
        """Validate the invariants specified in the schema."""
        video_info = self.metadata["video"]
        intrinsics_info = self.metadata["intrinsics"]

        # Invariant: frames.jsonl presence matches intrinsics source
        frames_file = self.recording_dir / "frames.jsonl"
        frames_exists = frames_file.exists()

        if intrinsics_info["source"] == "per_frame" and not frames_exists:
            raise ValidationError("frames.jsonl must exist for per_frame intrinsics source")

        if intrinsics_info["source"] != "per_frame" and frames_exists:
            raise ValidationError("frames.jsonl must not exist for non-per_frame intrinsics source")

        # Invariant: frame count consistency
        if self.frames_data is not None:
            if len(self.frames_data) != video_info["frame_count"]:
                raise ValidationError(f"Frame count mismatch: metadata says {video_info['frame_count']}, "
                                    f"frames.jsonl has {len(self.frames_data)}")

        # Invariant: has_audio_track must be false
        if video_info["has_audio_track"] is not False:
            raise ValidationError("has_audio_track must be false")

        print("✅ All invariants satisfied")


def main():
    """Main entry point."""
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