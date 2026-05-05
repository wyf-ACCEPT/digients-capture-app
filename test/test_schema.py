"""Schema validation tests (Section 5)."""

from __future__ import annotations

import copy
import json

import pytest

from pipeline.schema import SchemaError, validate_metadata, validate_recording


def _base_meta() -> dict:
    return {
        "schema_version": "1.0",
        "session_id": "550e8400-e29b-41d4-a716-446655440000",
        "captured_at_utc": "2026-04-24T14:32:11.123Z",
        "app_version": "1.0.0",
        "device": {
            "os": "ios",
            "os_version": "17.4.1",
            "manufacturer": "Apple",
            "model": "iPhone 15 Pro",
            "model_identifier": "iPhone16,1",
        },
        "camera": {
            "lens_type": "ultrawide",
            "horizontal_fov_deg": 120.0,
        },
        "video": {
            "codec": "hevc",
            "container": "mp4",
            "width": 1920,
            "height": 1080,
            "framerate": 30.0,
            "duration_sec": 12.5,
            "frame_count": 375,
            "has_audio_track": False,
        },
        "intrinsics": {
            "source": "per_frame",
            "per_frame_file": "frames.jsonl",
            "static_matrix": None,
            "distortion_model": "brown_conrady",
            "distortion_coeffs": [-0.12, 0.08, 0.0, 0.0, 0.0],
            "reliable": True,
        },
    }


def test_valid_metadata_parses():
    m = validate_metadata(_base_meta())
    assert m.intrinsics.source == "per_frame"
    assert m.video.frame_count == 375


def test_wrong_schema_version_rejected():
    # 1.0 and 1.1 both accepted; anything else rejected.
    d = _base_meta()
    d["schema_version"] = "2.0"
    with pytest.raises(SchemaError):
        validate_metadata(d)


def test_schema_v1_1_accepted():
    d = _base_meta()
    d["schema_version"] = "1.1"
    d["session_clock_origin"] = "unix_epoch"
    d["pose"] = {"source": "imu_raw", "rate_hz": 30.0}
    d["motion"] = {"recorded": True, "rate_hz": 100.0}
    m = validate_metadata(d)
    assert m.schema_version == "1.1"
    assert m.pose is not None and m.pose.source == "imu_raw"
    assert m.motion is not None and m.motion.recorded is True


def test_non_uuid_session_id_rejected():
    d = _base_meta()
    d["session_id"] = "not-a-uuid"
    with pytest.raises(SchemaError):
        validate_metadata(d)


def test_has_audio_true_rejected():
    d = _base_meta()
    d["video"]["has_audio_track"] = True
    with pytest.raises(SchemaError):
        validate_metadata(d)


# --------------------------------------------------------------------------- #
# v1.2 schema (RECORDING_DATA_STRUCTURE_V1.2.md): widest-lens + raw-IMU only #
# --------------------------------------------------------------------------- #


def _v12_meta() -> dict:
    d = _base_meta()
    d["schema_version"] = "1.2"
    d["session_clock_origin"] = "unix_epoch"
    d["camera"]["lens_type"] = "ultrawide"
    d["intrinsics"] = {
        "source": "static",
        "per_frame_file": None,
        "static_matrix": [
            [960.0, 0.0, 960.0],
            [0.0, 960.0, 540.0],
            [0.0, 0.0, 1.0],
        ],
        "distortion_model": "brown_conrady",
        "distortion_coeffs": [0.0, 0.0, 0.0, 0.0, 0.0],
        "reliable": True,
    }
    d["motion"] = {
        "recorded": True,
        "rate_hz": 200.0,
        "gyro_units": "rad/s",
        "accel_units": "m/s^2",
        "accel_includes_gravity": True,
        "frame": "device_body",
    }
    return d


def _write_v12_recording(tmp_path, *, with_frames=False, with_poses=False, meta=None):
    """Build a minimal on-disk v1.2 bundle. video.mp4 is a stub since the
    schema validator only checks for file presence (decode happens elsewhere)."""
    import json as _json

    rec = tmp_path / "recording_550e8400-e29b-41d4-a716-446655440000"
    rec.mkdir()
    (rec / "video.mp4").write_bytes(b"\x00")  # presence-only
    (rec / "metadata.json").write_text(_json.dumps(meta or _v12_meta()))
    (rec / "motion.jsonl").write_text(
        '{"timestamp_ns":1,"gyro":[0,0,0],"accel":[0,0,9.81]}\n'
    )
    if with_frames:
        (rec / "frames.jsonl").write_text(
            '{"frame_idx":0,"timestamp_ns":1,'
            '"intrinsic_matrix":[[960,0,960],[0,960,540],[0,0,1]]}\n'
        )
    if with_poses:
        (rec / "poses.jsonl").write_text(
            '{"frame_idx":0,"timestamp_ns":1,'
            '"transform":[[1,0,0,0],[0,1,0,0],[0,0,1,0],[0,0,0,1]],'
            '"tracking_state":"normal"}\n'
        )
    return rec


def test_v12_minimal_bundle_accepted(tmp_path):
    rec = _write_v12_recording(tmp_path)
    v = validate_recording(rec)
    assert v.metadata.schema_version == "1.2"
    assert v.frames is None and v.frames_path is None
    assert v.poses_path is None
    assert v.motion_path is not None


def test_v12_rejects_telephoto(tmp_path):
    meta = _v12_meta()
    meta["camera"]["lens_type"] = "telephoto"
    rec = _write_v12_recording(tmp_path, meta=meta)
    with pytest.raises(SchemaError):
        validate_recording(rec)


def test_v12_rejects_per_frame_intrinsics(tmp_path):
    meta = _v12_meta()
    meta["intrinsics"] = {
        "source": "per_frame",
        "per_frame_file": "frames.jsonl",
        "static_matrix": None,
        "distortion_model": "brown_conrady",
        "distortion_coeffs": [0.0, 0.0, 0.0, 0.0, 0.0],
        "reliable": True,
    }
    rec = _write_v12_recording(tmp_path, with_frames=True, meta=meta)
    with pytest.raises(SchemaError):
        validate_recording(rec)


def test_v12_rejects_poses_jsonl(tmp_path):
    rec = _write_v12_recording(tmp_path, with_poses=True)
    with pytest.raises(SchemaError):
        validate_recording(rec)


def test_v12_rejects_frames_jsonl(tmp_path):
    rec = _write_v12_recording(tmp_path, with_frames=True)
    with pytest.raises(SchemaError):
        validate_recording(rec)


def test_v12_rejects_arkit_pose_source(tmp_path):
    meta = _v12_meta()
    meta["pose"] = {"source": "arkit", "rate_hz": 60.0}
    rec = _write_v12_recording(tmp_path, meta=meta)
    with pytest.raises(SchemaError):
        validate_recording(rec)


def test_v12_requires_motion_recorded(tmp_path):
    meta = _v12_meta()
    meta["motion"]["recorded"] = False
    rec = _write_v12_recording(tmp_path, meta=meta)
    with pytest.raises(SchemaError):
        validate_recording(rec)


def test_v12_extrinsics_block_validates(tmp_path):
    meta = _v12_meta()
    meta["extrinsics"] = {
        "T_cam_imu": [
            [1.0, 0.0, 0.0, 0.012],
            [0.0, 1.0, 0.0, -0.003],
            [0.0, 0.0, 1.0, 0.041],
            [0.0, 0.0, 0.0, 1.0],
        ],
        "source": "platform_api",
        "time_offset_sec": 0.005,
    }
    meta["camera"]["rolling_shutter_skew_ns"] = 16_000_000
    meta["motion"].update(
        {
            "noise_density_gyro": 1.7e-4,
            "noise_density_accel": 2.0e-3,
            "random_walk_gyro": 2.0e-5,
            "random_walk_accel": 3.0e-3,
        }
    )
    rec = _write_v12_recording(tmp_path, meta=meta)
    v = validate_recording(rec)
    assert v.metadata.extrinsics is not None
    assert v.metadata.extrinsics.source == "platform_api"
    assert v.metadata.camera.rolling_shutter_skew_ns == 16_000_000
    assert v.metadata.motion.noise_density_gyro == 1.7e-4


def test_v12_extrinsics_rejects_non_4x4(tmp_path):
    meta = _v12_meta()
    meta["extrinsics"] = {
        "T_cam_imu": [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]],
        "source": "platform_api",
    }
    rec = _write_v12_recording(tmp_path, meta=meta)
    with pytest.raises(SchemaError):
        validate_recording(rec)


def test_v12_extrinsics_rejects_bad_bottom_row(tmp_path):
    meta = _v12_meta()
    meta["extrinsics"] = {
        "T_cam_imu": [
            [1.0, 0.0, 0.0, 0.0],
            [0.0, 1.0, 0.0, 0.0],
            [0.0, 0.0, 1.0, 0.0],
            [0.1, 0.0, 0.0, 1.0],
        ],
        "source": "platform_api",
    }
    rec = _write_v12_recording(tmp_path, meta=meta)
    with pytest.raises(SchemaError):
        validate_recording(rec)


def test_per_frame_requires_per_frame_file():
    d = _base_meta()
    d["intrinsics"]["per_frame_file"] = None
    with pytest.raises(SchemaError):
        validate_metadata(d)


def test_static_requires_matrix():
    d = _base_meta()
    d["intrinsics"] = {
        "source": "static",
        "per_frame_file": None,
        "static_matrix": None,
        "distortion_model": None,
        "distortion_coeffs": None,
        "reliable": True,
    }
    with pytest.raises(SchemaError):
        validate_metadata(d)


def test_static_matrix_last_row_checked():
    d = _base_meta()
    d["intrinsics"] = {
        "source": "static",
        "per_frame_file": None,
        "static_matrix": [[1000, 0, 960], [0, 1000, 540], [0, 0, 0]],  # bad last row
        "distortion_model": None,
        "distortion_coeffs": None,
        "reliable": True,
    }
    with pytest.raises(SchemaError):
        validate_metadata(d)


def test_recording_directory_valid(ios_per_frame_recording):
    rec = validate_recording(ios_per_frame_recording)
    assert rec.metadata.intrinsics.source == "per_frame"
    assert rec.frames is not None
    assert len(rec.frames) == rec.metadata.video.frame_count


def test_recording_frames_count_mismatch(ios_per_frame_recording):
    # Truncate frames.jsonl so line count != frame_count
    f = ios_per_frame_recording / "frames.jsonl"
    lines = f.read_text().splitlines()
    f.write_text("\n".join(lines[:-1]) + "\n")
    with pytest.raises(SchemaError):
        validate_recording(ios_per_frame_recording)


def test_recording_extra_frames_jsonl_rejected(android_static_recording):
    # Android static should NOT have frames.jsonl
    extra = android_static_recording / "frames.jsonl"
    extra.write_text('{"frame_idx":0,"timestamp_ns":0,"intrinsic_matrix":[[1,0,0],[0,1,0],[0,0,1]]}\n')
    with pytest.raises(SchemaError):
        validate_recording(android_static_recording)


def test_android_static_and_fallback_recordings_valid(android_static_recording, android_fallback_recording):
    for rec in (android_static_recording, android_fallback_recording):
        v = validate_recording(rec)
        assert v.frames is None
        assert v.metadata.intrinsics.static_matrix is not None
