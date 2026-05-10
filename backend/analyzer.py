import time
import os
import statistics
import cv2
import mediapipe as mp

from utils import (
    LANDMARKS, find_angle, find_offset_angle,
    get_landmark_coords_from_normalized,
)
from thresholds import (
    OFFSET_THRESH, INACTIVE_THRESH,
    SQUAT_THRESHOLDS, PUSHUP_THRESHOLDS,
    DEADLIFT_THRESHOLDS, BENCH_THRESHOLDS,
    BUFFER_KNEE_START, BUFFER_KNEE_END,
    BUFFER_PUSHUP_START, BUFFER_PUSHUP_END,
    BUFFER_DEADLIFT_START, BUFFER_DEADLIFT_END,
    BUFFER_BENCH_START, BUFFER_BENCH_END,
    BUFFER_TIMEOUT_SECONDS,
)

BaseOptions = mp.tasks.BaseOptions
PoseLandmarker = mp.tasks.vision.PoseLandmarker
PoseLandmarkerOptions = mp.tasks.vision.PoseLandmarkerOptions
RunningMode = mp.tasks.vision.RunningMode

POSE_CONNECTIONS = mp.tasks.vision.PoseLandmarksConnections.POSE_LANDMARKS

MODEL_PATH = os.path.join(os.path.dirname(__file__), "pose_landmarker_heavy.task")
MAX_LOST_POSE_DURING_REP_SECONDS = 0.35
MIN_REP_BUFFER_FRAMES = 6
MIN_REP_DURATION_SECONDS = 0.35
SIDE_PROFILE_HYSTERESIS = 0.08
SIDE_PROFILE_JOINTS = ("shoulder", "hip", "knee", "ankle")


def serialize_landmark(landmark):
    return {
        "x": float(landmark.x),
        "y": float(landmark.y),
        "z": float(getattr(landmark, "z", 0.0)),
        "visibility": float(getattr(landmark, "visibility", 0.0)),
        "presence": float(getattr(landmark, "presence", 0.0)),
    }


def landmark_confidence(landmark):
    visibility = float(getattr(landmark, "visibility", 1.0))
    presence = float(getattr(landmark, "presence", 1.0))
    return min(visibility, presence)


def side_profile_confidence(landmarks, side):
    return statistics.mean(
        landmark_confidence(landmarks[LANDMARKS[f"{side}_{joint}"]])
        for joint in SIDE_PROFILE_JOINTS
    )


def choose_reliable_squat_side(landmarks, previous_side=None):
    left_confidence = side_profile_confidence(landmarks, "left")
    right_confidence = side_profile_confidence(landmarks, "right")

    if previous_side in {"left", "right"}:
        previous_confidence = (
            left_confidence if previous_side == "left" else right_confidence
        )
        other_confidence = (
            right_confidence if previous_side == "left" else left_confidence
        )
        if other_confidence <= previous_confidence + SIDE_PROFILE_HYSTERESIS:
            return previous_side

    return "left" if left_confidence >= right_confidence else "right"


def get_side_landmark_coords(landmarks, side, joint, w, h):
    return get_landmark_coords_from_normalized(
        landmarks,
        LANDMARKS[f"{side}_{joint}"],
        w,
        h,
    )


class ExerciseAnalyzer:
    """
    Base class for exercise form analyzers using MediaPipe pose estimation.

    Subclasses implement:
      _get_thresholds(mode)       — return the threshold dict for this exercise/mode
      _check_alignment(lm, w, h) — return (is_misaligned, feedback_str)
      _update_angles(lm, w, h)   — compute angles and store in self.primary_angle,
                                   self.secondary_angle, self._current_angles
      _on_enter_active()         — return feedback string when entering the active state
      _on_rep_complete(rep_analysis) — return (is_correct, feedback, extra_data_dict)
      get_angle_labels()         — return [(label, value), ...] for display
    """

    # Override in subclass:
    NEUTRAL_STATE = "standing"
    ACTIVE_STATE = "active"
    BUFFER_START = 165.0   # primary angle below this → start buffering
    BUFFER_END = 170.0     # primary angle above this (after active) → stop buffering
    DISCARD_ON_MISALIGNMENT = True

    def __init__(self, mode="beginner", on_rep_complete=None):
        self.mode = mode
        self.thresh = self._get_thresholds(mode)
        self.on_rep_complete = on_rep_complete
        self.last_pose_landmarks = []

        if not os.path.exists(MODEL_PATH):
            raise FileNotFoundError(
                f"Model not found at {MODEL_PATH}\n"
                "Run: python download_model.py"
            )

        options = PoseLandmarkerOptions(
            base_options=BaseOptions(model_asset_path=MODEL_PATH),
            running_mode=RunningMode.VIDEO,
            num_poses=1,
            min_pose_detection_confidence=0.5,
            min_tracking_confidence=0.5,
        )
        self.landmarker = PoseLandmarker.create_from_options(options)
        self.frame_timestamp_ms = 0
        self._last_frame_monotonic = time.monotonic()

        self.correct_count = 0
        self.incorrect_count = 0
        self.state = self.NEUTRAL_STATE
        self.feedback = ""
        self.primary_angle = 0.0
        self.secondary_angle = 0.0
        self._current_angles = {}
        self.last_detection_time = time.time()

        # Rep buffer state (decoupled from state machine)
        self.current_rep_buffer = []
        self._rep_frame_index = 0
        self._is_buffering = False
        self._buffer_start_time = 0.0
        self._buffer_saw_active = False
        self._missing_pose_started_at = None

    def _get_thresholds(self, mode):
        raise NotImplementedError

    @property
    def is_in_rep(self):
        return self.state == self.ACTIVE_STATE

    def reset(self):
        self.correct_count = 0
        self.incorrect_count = 0
        self.state = self.NEUTRAL_STATE
        self.feedback = ""
        self.primary_angle = 0.0
        self.secondary_angle = 0.0
        self._current_angles = {}

        self.current_rep_buffer = []
        self._rep_frame_index = 0
        self._is_buffering = False
        self._buffer_start_time = 0.0
        self._buffer_saw_active = False
        self._missing_pose_started_at = None

    def close(self):
        self.landmarker.close()

    def process_frame(self, frame):
        h, w, _ = frame.shape

        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)

        now = time.monotonic()
        elapsed_ms = max(1, int((now - self._last_frame_monotonic) * 1000))
        self._last_frame_monotonic = now
        self.frame_timestamp_ms += elapsed_ms
        results = self.landmarker.detect_for_video(mp_image, self.frame_timestamp_ms)

        if not results.pose_landmarks or len(results.pose_landmarks) == 0:
            elapsed = time.time() - self.last_detection_time
            if elapsed > INACTIVE_THRESH:
                self.reset()
            self._handle_missing_pose()
            self.last_pose_landmarks = []
            return frame

        self.last_detection_time = time.time()
        self._missing_pose_started_at = None
        landmarks = results.pose_landmarks[0]
        self.last_pose_landmarks = [serialize_landmark(lm) for lm in landmarks]

        self._draw_landmarks(frame, landmarks, w, h)

        # Alignment check (subclass-specific)
        misaligned, alignment_feedback = self._check_alignment(landmarks, w, h)
        if misaligned:
            self.feedback = alignment_feedback
            if self.DISCARD_ON_MISALIGNMENT:
                self._discard_current_rep()
                return frame

        # Angle extraction (subclass sets primary_angle, secondary_angle, _current_angles)
        self._update_angles(landmarks, w, h)

        t = self.thresh

        # --- Buffer logic (decoupled from state machine) ---
        if not self._is_buffering and self.primary_angle < self.BUFFER_START:
            self._is_buffering = True
            self._buffer_start_time = time.time()
            self._buffer_saw_active = False
            self._rep_frame_index = 0
            self.current_rep_buffer = []

        if self._is_buffering:
            self._append_to_rep_buffer()
            elapsed = time.time() - self._buffer_start_time
            if elapsed > BUFFER_TIMEOUT_SECONDS and not self._buffer_saw_active:
                self._is_buffering = False
                self.current_rep_buffer = []
                self._rep_frame_index = 0

        # --- State machine ---
        if self.state == self.NEUTRAL_STATE and self.primary_angle < t["active_angle_low"]:
            self.state = self.ACTIVE_STATE
            self._buffer_saw_active = True
            self.feedback = self._on_enter_active()

        elif self.state == self.ACTIVE_STATE and self.primary_angle > t["active_angle_high"]:
            self.state = self.NEUTRAL_STATE

            rep_analysis = self._analyze_rep()
            if not self._is_valid_completed_rep(rep_analysis):
                self.feedback = "Keep tracking"
                self._discard_current_rep()
                return frame

            is_correct, feedback, extra_data = self._on_rep_complete(rep_analysis)
            self.feedback = feedback

            if is_correct:
                self.correct_count += 1
            else:
                self.incorrect_count += 1

            if self.on_rep_complete:
                rep_data = {
                    "rep_number": self.correct_count + self.incorrect_count,
                    "is_correct": is_correct,
                    "mode": self.mode,
                    "correct_count": self.correct_count,
                    "incorrect_count": self.incorrect_count,
                    "rep_trajectory": list(self.current_rep_buffer),
                    "deepest_frame_index": rep_analysis["deepest_frame_index"],
                    "tempo": rep_analysis["tempo"],
                }
                rep_data.update(extra_data)
                self.on_rep_complete(rep_data)

        # --- Stop buffering when fully back to neutral ---
        if self._is_buffering and self._buffer_saw_active and self.primary_angle > self.BUFFER_END:
            self._is_buffering = False
            self.current_rep_buffer = []
            self._rep_frame_index = 0
            self._buffer_saw_active = False

        return frame

    def _handle_missing_pose(self):
        if not self._is_buffering and self.state != self.ACTIVE_STATE:
            self._missing_pose_started_at = None
            return

        now = time.time()
        if self._missing_pose_started_at is None:
            self._missing_pose_started_at = now
            return

        if now - self._missing_pose_started_at >= MAX_LOST_POSE_DURING_REP_SECONDS:
            self._discard_current_rep()
            self.feedback = "Step into frame"

    def _discard_current_rep(self):
        self.state = self.NEUTRAL_STATE
        self.current_rep_buffer = []
        self._rep_frame_index = 0
        self._is_buffering = False
        self._buffer_start_time = 0.0
        self._buffer_saw_active = False
        self._missing_pose_started_at = None

    def _is_valid_completed_rep(self, rep_analysis):
        return (
            rep_analysis["frame_count"] >= MIN_REP_BUFFER_FRAMES
            and rep_analysis["duration_seconds"] >= MIN_REP_DURATION_SECONDS
        )

    def _check_alignment(self, landmarks, w, h):
        return False, ""

    def _update_angles(self, landmarks, w, h):
        raise NotImplementedError

    def _on_enter_active(self):
        return ""

    def _on_rep_complete(self, rep_analysis):
        raise NotImplementedError

    def get_angle_labels(self):
        return [("Primary", self.primary_angle), ("Secondary", self.secondary_angle)]

    def get_stats_for_api(self):
        return {
            "correct_count": self.correct_count,
            "incorrect_count": self.incorrect_count,
            "current_feedback": self.feedback,
            "is_in_rep": self.is_in_rep,
            "state": self.state,
        }

    def _append_to_rep_buffer(self):
        self.current_rep_buffer.append({
            "frame_index": self._rep_frame_index,
            "timestamp_ms": int(time.time() * 1000),  # real wall-clock, not assumed 33ms/frame
            "landmarks": list(self.last_pose_landmarks),
            "angles": dict(self._current_angles),
        })
        self._rep_frame_index += 1

    def _analyze_rep(self):
        """
        Analyze a completed rep using smoothed values from a 5-frame window
        around the deepest position (minimum primary_angle).
        """
        buf = self.current_rep_buffer

        if not buf:
            return {
                "primary_angle": 0.0,
                "secondary_angle": 0.0,
                "angles": {},
                "deepest_frame_index": None,
                "frame_count": 0,
                "duration_seconds": 0.0,
                "tempo": {"descent_seconds": None, "ascent_seconds": None, "status": "unknown"},
            }

        # Find deepest frame (minimum primary_angle)
        i_min = min(range(len(buf)), key=lambda i: buf[i]["angles"].get("primary", float("inf")))

        # 5-frame window centered on i_min
        window_size = 5
        half = window_size // 2
        start = max(0, i_min - half)
        end = min(len(buf), i_min + half + 1)
        window_frames = buf[start:end]

        # Compute median for all angle keys over the window
        angle_keys = window_frames[0]["angles"].keys()
        median_angles = {}
        for key in angle_keys:
            vals = [f["angles"][key] for f in window_frames]
            median_angles[key] = statistics.median(vals)

        tempo = self._compute_tempo(i_min, len(buf), buf)

        return {
            "primary_angle": median_angles.get("primary", 0.0),
            "secondary_angle": median_angles.get("secondary", 0.0),
            "angles": median_angles,
            "deepest_frame_index": i_min,
            "frame_count": len(buf),
            "duration_seconds": round((buf[-1]["timestamp_ms"] - buf[0]["timestamp_ms"]) / 1000.0, 2),
            "tempo": tempo,
        }

    def _compute_tempo(self, deepest_index, buffer_length, buf=None):
        """
        Compute descent and ascent timing from real wall-clock timestamps in the buffer.
        Falls back to frame-count estimation if buffer not provided.
        Timing thresholds come from self.thresh so each exercise can differ.
        """
        # Minimum elapsed ms for a segment to be considered reliable
        _MIN_SEGMENT_MS = 80

        if buf and len(buf) >= 2:
            first_ts = buf[0]["timestamp_ms"]
            deepest_ts = buf[deepest_index]["timestamp_ms"]
            last_ts = buf[-1]["timestamp_ms"]

            descent_ms = deepest_ts - first_ts
            ascent_ms = last_ts - deepest_ts

            descent_seconds = round(descent_ms / 1000.0, 2) if descent_ms >= _MIN_SEGMENT_MS else None
            ascent_seconds = round(ascent_ms / 1000.0, 2) if ascent_ms >= _MIN_SEGMENT_MS else None
        else:
            # Fallback: estimate from frame count at assumed 30 FPS
            descent_frames = deepest_index
            ascent_frames = buffer_length - deepest_index - 1
            min_frames = 3
            descent_seconds = (
                round((descent_frames * 33) / 1000.0, 2)
                if descent_frames >= min_frames else None
            )
            ascent_seconds = (
                round((ascent_frames * 33) / 1000.0, 2)
                if ascent_frames >= min_frames else None
            )

        min_descent = self.thresh.get("min_descent_seconds", 0.45)
        min_ascent = self.thresh.get("min_ascent_seconds", 0.3)

        if descent_seconds is None or ascent_seconds is None:
            status = "unknown"
        elif ascent_seconds < min_ascent:
            status = "bounced_out"
        elif descent_seconds < min_descent:
            status = "rushed_descent"
        else:
            status = "ok"

        return {
            "descent_seconds": descent_seconds,
            "ascent_seconds": ascent_seconds,
            "status": status,
        }

    def _draw_landmarks(self, frame, landmarks, w, h):
        for connection in POSE_CONNECTIONS:
            start = landmarks[connection.start]
            end = landmarks[connection.end]
            x1, y1 = int(start.x * w), int(start.y * h)
            x2, y2 = int(end.x * w), int(end.y * h)
            cv2.line(frame, (x1, y1), (x2, y2), (245, 66, 230), 2)

        for lm in landmarks:
            cx, cy = int(lm.x * w), int(lm.y * h)
            cv2.circle(frame, (cx, cy), 4, (245, 117, 66), -1)


class SquatAnalyzer(ExerciseAnalyzer):
    """Analyzes squat form: depth (knee angle) and torso lean (hip angle)."""

    NEUTRAL_STATE = "standing"
    ACTIVE_STATE = "squatting"
    BUFFER_START = BUFFER_KNEE_START
    BUFFER_END = BUFFER_KNEE_END
    DISCARD_ON_MISALIGNMENT = False

    def __init__(self, mode="beginner", on_rep_complete=None):
        super().__init__(mode, on_rep_complete)
        self.knee_angle = 0.0
        self.hip_angle = 0.0
        self._side_profile_side = None

    def _get_thresholds(self, mode):
        return SQUAT_THRESHOLDS[mode]

    def reset(self):
        super().reset()
        self.knee_angle = 0.0
        self.hip_angle = 0.0

    def _check_alignment(self, landmarks, w, h):
        side = self._choose_tracking_side(landmarks)
        shoulder = get_side_landmark_coords(landmarks, side, "shoulder", w, h)
        hip = get_side_landmark_coords(landmarks, side, "hip", w, h)
        offset = find_offset_angle(shoulder, hip)
        if offset > OFFSET_THRESH:
            return True, f"Align to side view ({offset:.0f}°)"
        return False, ""

    def _update_angles(self, landmarks, w, h):
        side = self._choose_tracking_side(landmarks)
        shoulder = get_side_landmark_coords(landmarks, side, "shoulder", w, h)
        hip = get_side_landmark_coords(landmarks, side, "hip", w, h)
        knee = get_side_landmark_coords(landmarks, side, "knee", w, h)
        ankle = get_side_landmark_coords(landmarks, side, "ankle", w, h)

        knee_angle = find_angle(hip, knee, ankle)
        hip_angle = find_angle(shoulder, hip, knee)

        self.knee_angle = knee_angle
        self.hip_angle = hip_angle
        self.primary_angle = knee_angle
        self.secondary_angle = hip_angle
        self._current_angles = {
            "primary": knee_angle,
            "secondary": hip_angle,
            "knee_angle": knee_angle,
            "hip_angle": hip_angle,
        }

    def _choose_tracking_side(self, landmarks):
        self._side_profile_side = choose_reliable_squat_side(
            landmarks,
            previous_side=self._side_profile_side,
        )
        return self._side_profile_side

    def _on_enter_active(self):
        t = self.thresh
        form_ok = t["hip_angle_low"] <= self.hip_angle <= t["hip_angle_high"]
        return "Good depth!" if form_ok else f"Watch torso ({self.hip_angle:.0f}°)"

    def _on_rep_complete(self, rep_analysis):
        t = self.thresh
        angles = rep_analysis["angles"]
        knee_angle = angles.get("knee_angle", rep_analysis["primary_angle"])
        hip_angle = angles.get("hip_angle", rep_analysis["secondary_angle"])

        depth_ok = knee_angle <= t["knee_angle_correct"]
        torso_ok = t["hip_angle_low"] <= hip_angle <= t["hip_angle_high"]
        tempo_status = rep_analysis["tempo"]["status"]
        tempo_ok = tempo_status in ("ok", "unknown")

        is_correct = depth_ok and torso_ok and tempo_ok

        if is_correct:
            feedback = "Good rep!"
        elif not depth_ok:
            feedback = f"Go deeper ({knee_angle:.0f}° < {t['knee_angle_correct']}° needed)"
        elif not torso_ok:
            feedback = f"Check torso lean ({hip_angle:.0f}°)"
        elif tempo_status == "bounced_out":
            feedback = "Don't bounce - control the ascent"
        else:
            feedback = "Slow down the descent"

        extra_data = {
            "knee_angle": knee_angle,
            "hip_angle": hip_angle,
        }
        return is_correct, feedback, extra_data

    def get_angle_labels(self):
        return [("Knee", self.knee_angle), ("Hip", self.hip_angle)]

    def get_stats_for_api(self):
        d = super().get_stats_for_api()
        d["knee_angle"] = round(self.knee_angle, 1)
        d["hip_angle"] = round(self.hip_angle, 1)
        return d


class PushupAnalyzer(ExerciseAnalyzer):
    """
    Analyzes push-up form from a side (or slightly above-side) view.

    Tracks three angles:
      - Elbow angle (shoulder→elbow→wrist): primary, measures arm bend depth
      - Shoulder/glenohumeral angle (hip→shoulder→elbow): upper-arm position relative to torso
      - Body alignment (shoulder→hip→ankle): plank straightness
    """

    NEUTRAL_STATE = "up"
    ACTIVE_STATE = "down"
    BUFFER_START = BUFFER_PUSHUP_START
    BUFFER_END = BUFFER_PUSHUP_END

    def __init__(self, mode="beginner", on_rep_complete=None):
        super().__init__(mode, on_rep_complete)
        self.elbow_angle = 0.0
        self.shoulder_angle = 0.0
        self.body_angle = 0.0
        self._shoulder_angle_reliable = True

    def _get_thresholds(self, mode):
        return PUSHUP_THRESHOLDS[mode]

    def reset(self):
        super().reset()
        self.elbow_angle = 0.0
        self.shoulder_angle = 0.0
        self.body_angle = 0.0
        self._shoulder_angle_reliable = True

    def _check_alignment(self, landmarks, w, h):
        # Body should be roughly horizontal for push-up position.
        # find_offset_angle returns ~0° for vertical (standing), ~90° for horizontal (push-up).
        # Only alert if clearly upright (< 30° from vertical), to avoid false positives.
        l_shoulder = get_landmark_coords_from_normalized(landmarks, LANDMARKS["left_shoulder"], w, h)
        l_hip = get_landmark_coords_from_normalized(landmarks, LANDMARKS["left_hip"], w, h)
        offset = find_offset_angle(l_shoulder, l_hip)
        if offset < 30:
            return True, "Get into push-up position (side view)"
        return False, ""

    def _update_angles(self, landmarks, w, h):
        l_shoulder = get_landmark_coords_from_normalized(landmarks, LANDMARKS["left_shoulder"], w, h)
        r_shoulder = get_landmark_coords_from_normalized(landmarks, LANDMARKS["right_shoulder"], w, h)
        l_elbow = get_landmark_coords_from_normalized(landmarks, LANDMARKS["left_elbow"], w, h)
        r_elbow = get_landmark_coords_from_normalized(landmarks, LANDMARKS["right_elbow"], w, h)
        l_wrist = get_landmark_coords_from_normalized(landmarks, LANDMARKS["left_wrist"], w, h)
        r_wrist = get_landmark_coords_from_normalized(landmarks, LANDMARKS["right_wrist"], w, h)
        l_hip = get_landmark_coords_from_normalized(landmarks, LANDMARKS["left_hip"], w, h)
        r_hip = get_landmark_coords_from_normalized(landmarks, LANDMARKS["right_hip"], w, h)
        l_ankle = get_landmark_coords_from_normalized(landmarks, LANDMARKS["left_ankle"], w, h)
        r_ankle = get_landmark_coords_from_normalized(landmarks, LANDMARKS["right_ankle"], w, h)

        # Elbow angle (primary): shoulder → elbow → wrist
        l_elbow_angle = find_angle(l_shoulder, l_elbow, l_wrist)
        r_elbow_angle = find_angle(r_shoulder, r_elbow, r_wrist)
        elbow_angle = (l_elbow_angle + r_elbow_angle) / 2

        # Glenohumeral angle: hip → shoulder → elbow (upper arm relative to torso)
        l_shoulder_angle = find_angle(l_hip, l_shoulder, l_elbow)
        r_shoulder_angle = find_angle(r_hip, r_shoulder, r_elbow)
        shoulder_angle = (l_shoulder_angle + r_shoulder_angle) / 2

        # Body alignment (secondary): shoulder → hip → ankle (plank straightness)
        l_body_angle = find_angle(l_shoulder, l_hip, l_ankle)
        r_body_angle = find_angle(r_shoulder, r_hip, r_ankle)
        body_angle = (l_body_angle + r_body_angle) / 2

        # In a true side view, both elbows project to nearly the same x position —
        # elbow flare (in/out of frame plane) is invisible in 2D. If elbows are
        # horizontally close, the shoulder angle measurement is unreliable.
        elbow_h_sep = abs(l_elbow[0] - r_elbow[0]) / w  # 0 = perfectly overlapping
        self._shoulder_angle_reliable = elbow_h_sep > 0.08  # > 8% of frame width

        self.elbow_angle = elbow_angle
        self.shoulder_angle = shoulder_angle
        self.body_angle = body_angle
        self.primary_angle = elbow_angle
        self.secondary_angle = body_angle
        self._current_angles = {
            "primary": elbow_angle,
            "secondary": body_angle,
            "elbow_angle": elbow_angle,
            "shoulder_angle": shoulder_angle,
            "body_angle": body_angle,
        }

    def _on_enter_active(self):
        t = self.thresh
        body_ok = t["body_alignment_low"] <= self.body_angle <= t["body_alignment_high"]
        return "Lowering..." if body_ok else f"Keep body straight ({self.body_angle:.0f}°)"

    def _on_rep_complete(self, rep_analysis):
        t = self.thresh
        angles = rep_analysis["angles"]
        elbow_angle = angles.get("elbow_angle", rep_analysis["primary_angle"])
        body_angle = angles.get("body_angle", rep_analysis["secondary_angle"])
        shoulder_angle = angles.get("shoulder_angle", 0.0)

        depth_ok = elbow_angle <= t["elbow_angle_correct"]
        body_ok = t["body_alignment_low"] <= body_angle <= t["body_alignment_high"]
        # Only check shoulder angle if the measurement is reliable (not pure side view).
        # In side view the 2D projection can't capture elbow flare, so default to ok.
        shoulder_ok = (not self._shoulder_angle_reliable) or (
            t["shoulder_angle_low"] <= shoulder_angle <= t["shoulder_angle_high"]
        )
        tempo_status = rep_analysis["tempo"]["status"]
        tempo_ok = tempo_status in ("ok", "unknown")

        is_correct = depth_ok and body_ok and shoulder_ok and tempo_ok

        if is_correct:
            feedback = "Good rep!"
        elif not depth_ok:
            feedback = f"Go lower ({elbow_angle:.0f}° > {t['elbow_angle_correct']}° max)"
        elif not body_ok:
            feedback = f"Keep body straight ({body_angle:.0f}°)"
        elif not shoulder_ok:
            feedback = f"Watch elbow flare ({shoulder_angle:.0f}°)"
        elif tempo_status == "bounced_out":
            feedback = "Control the push - don't bounce"
        else:
            feedback = "Slow down the descent"

        extra_data = {
            "elbow_angle": elbow_angle,
            "shoulder_angle": shoulder_angle,
            "body_angle": body_angle,
        }
        return is_correct, feedback, extra_data

    def get_angle_labels(self):
        return [
            ("Elbow", self.elbow_angle),
            ("Shoulder", self.shoulder_angle),
            ("Body", self.body_angle),
        ]

    def get_stats_for_api(self):
        d = super().get_stats_for_api()
        d["elbow_angle"] = round(self.elbow_angle, 1)
        d["shoulder_angle"] = round(self.shoulder_angle, 1)
        d["body_angle"] = round(self.body_angle, 1)
        return d


class DeadliftAnalyzer(ExerciseAnalyzer):
    """
    Analyzes deadlift form from a side view.
    Primary angle: shoulder-hip-knee (hip hinge) — large when standing, small when bent over.
    Secondary angle: hip-knee-ankle (knee bend).
    """

    NEUTRAL_STATE = "standing"
    ACTIVE_STATE = "pulling"
    BUFFER_START = BUFFER_DEADLIFT_START
    BUFFER_END = BUFFER_DEADLIFT_END

    def __init__(self, mode="beginner", on_rep_complete=None):
        super().__init__(mode, on_rep_complete)
        self.hip_angle = 0.0
        self.knee_angle = 0.0

    def _get_thresholds(self, mode):
        return DEADLIFT_THRESHOLDS[mode]

    def reset(self):
        super().reset()
        self.hip_angle = 0.0
        self.knee_angle = 0.0

    def _check_alignment(self, landmarks, w, h):
        l_shoulder = get_landmark_coords_from_normalized(landmarks, LANDMARKS["left_shoulder"], w, h)
        l_hip = get_landmark_coords_from_normalized(landmarks, LANDMARKS["left_hip"], w, h)
        offset = find_offset_angle(l_shoulder, l_hip)
        if offset > OFFSET_THRESH:
            return True, f"Align to side view ({offset:.0f}°)"
        return False, ""

    def _update_angles(self, landmarks, w, h):
        l_shoulder = get_landmark_coords_from_normalized(landmarks, LANDMARKS["left_shoulder"], w, h)
        r_shoulder = get_landmark_coords_from_normalized(landmarks, LANDMARKS["right_shoulder"], w, h)
        l_hip = get_landmark_coords_from_normalized(landmarks, LANDMARKS["left_hip"], w, h)
        r_hip = get_landmark_coords_from_normalized(landmarks, LANDMARKS["right_hip"], w, h)
        l_knee = get_landmark_coords_from_normalized(landmarks, LANDMARKS["left_knee"], w, h)
        r_knee = get_landmark_coords_from_normalized(landmarks, LANDMARKS["right_knee"], w, h)
        l_ankle = get_landmark_coords_from_normalized(landmarks, LANDMARKS["left_ankle"], w, h)
        r_ankle = get_landmark_coords_from_normalized(landmarks, LANDMARKS["right_ankle"], w, h)

        l_hip_angle = find_angle(l_shoulder, l_hip, l_knee)
        r_hip_angle = find_angle(r_shoulder, r_hip, r_knee)
        hip_angle = (l_hip_angle + r_hip_angle) / 2

        l_knee_angle = find_angle(l_hip, l_knee, l_ankle)
        r_knee_angle = find_angle(r_hip, r_knee, r_ankle)
        knee_angle = (l_knee_angle + r_knee_angle) / 2

        self.hip_angle = hip_angle
        self.knee_angle = knee_angle
        self.primary_angle = hip_angle
        self.secondary_angle = knee_angle
        self._current_angles = {
            "primary": hip_angle,
            "secondary": knee_angle,
            "hip_angle": hip_angle,
            "knee_angle": knee_angle,
        }

    def _on_enter_active(self):
        return "Pulling..."

    def _on_rep_complete(self, rep_analysis):
        t = self.thresh
        angles = rep_analysis["angles"]
        hip_angle = angles.get("hip_angle", rep_analysis["primary_angle"])
        knee_angle = angles.get("knee_angle", rep_analysis["secondary_angle"])

        depth_ok = hip_angle <= t["hip_angle_correct"]
        tempo_status = rep_analysis["tempo"]["status"]
        tempo_ok = tempo_status in ("ok", "unknown")

        is_correct = depth_ok and tempo_ok

        if is_correct:
            feedback = "Good rep!"
        elif not depth_ok:
            feedback = f"Hinge deeper ({hip_angle:.0f}° > {t['hip_angle_correct']}° needed)"
        elif tempo_status == "bounced_out":
            feedback = "Control the lift - don't jerk"
        else:
            feedback = "Slow down the lowering phase"

        extra_data = {"hip_angle": hip_angle, "knee_angle": knee_angle}
        return is_correct, feedback, extra_data

    def get_angle_labels(self):
        return [("Hip", self.hip_angle), ("Knee", self.knee_angle)]

    def get_stats_for_api(self):
        d = super().get_stats_for_api()
        d["hip_angle"] = round(self.hip_angle, 1)
        d["knee_angle"] = round(self.knee_angle, 1)
        return d


class BenchAnalyzer(ExerciseAnalyzer):
    """
    Analyzes bench press form from a side view.
    Primary angle: shoulder-elbow-wrist (elbow bend) — large when extended, small at bottom.
    Secondary angle: shoulder-hip-ankle (body flatness on bench).
    Also checks hip-shoulder-elbow (elbow flare / glenohumeral position).
    """

    NEUTRAL_STATE = "up"
    ACTIVE_STATE = "down"
    BUFFER_START = BUFFER_BENCH_START
    BUFFER_END = BUFFER_BENCH_END

    def __init__(self, mode="beginner", on_rep_complete=None):
        super().__init__(mode, on_rep_complete)
        self.elbow_angle = 0.0
        self.shoulder_angle = 0.0
        self.body_angle = 0.0
        self._shoulder_angle_reliable = True

    def _get_thresholds(self, mode):
        return BENCH_THRESHOLDS[mode]

    def reset(self):
        super().reset()
        self.elbow_angle = 0.0
        self.shoulder_angle = 0.0
        self.body_angle = 0.0
        self._shoulder_angle_reliable = True

    def _check_alignment(self, landmarks, w, h):
        # Person should be lying on bench (body horizontal). offset < 30 means upright.
        l_shoulder = get_landmark_coords_from_normalized(landmarks, LANDMARKS["left_shoulder"], w, h)
        l_hip = get_landmark_coords_from_normalized(landmarks, LANDMARKS["left_hip"], w, h)
        offset = find_offset_angle(l_shoulder, l_hip)
        if offset < 30:
            return True, "Lie flat on the bench (side view)"
        return False, ""

    def _update_angles(self, landmarks, w, h):
        l_shoulder = get_landmark_coords_from_normalized(landmarks, LANDMARKS["left_shoulder"], w, h)
        r_shoulder = get_landmark_coords_from_normalized(landmarks, LANDMARKS["right_shoulder"], w, h)
        l_elbow = get_landmark_coords_from_normalized(landmarks, LANDMARKS["left_elbow"], w, h)
        r_elbow = get_landmark_coords_from_normalized(landmarks, LANDMARKS["right_elbow"], w, h)
        l_wrist = get_landmark_coords_from_normalized(landmarks, LANDMARKS["left_wrist"], w, h)
        r_wrist = get_landmark_coords_from_normalized(landmarks, LANDMARKS["right_wrist"], w, h)
        l_hip = get_landmark_coords_from_normalized(landmarks, LANDMARKS["left_hip"], w, h)
        r_hip = get_landmark_coords_from_normalized(landmarks, LANDMARKS["right_hip"], w, h)
        l_ankle = get_landmark_coords_from_normalized(landmarks, LANDMARKS["left_ankle"], w, h)
        r_ankle = get_landmark_coords_from_normalized(landmarks, LANDMARKS["right_ankle"], w, h)

        l_elbow_angle = find_angle(l_shoulder, l_elbow, l_wrist)
        r_elbow_angle = find_angle(r_shoulder, r_elbow, r_wrist)
        elbow_angle = (l_elbow_angle + r_elbow_angle) / 2

        l_shoulder_angle = find_angle(l_hip, l_shoulder, l_elbow)
        r_shoulder_angle = find_angle(r_hip, r_shoulder, r_elbow)
        shoulder_angle = (l_shoulder_angle + r_shoulder_angle) / 2

        l_body_angle = find_angle(l_shoulder, l_hip, l_ankle)
        r_body_angle = find_angle(r_shoulder, r_hip, r_ankle)
        body_angle = (l_body_angle + r_body_angle) / 2

        elbow_h_sep = abs(l_elbow[0] - r_elbow[0]) / w
        self._shoulder_angle_reliable = elbow_h_sep > 0.08

        self.elbow_angle = elbow_angle
        self.shoulder_angle = shoulder_angle
        self.body_angle = body_angle
        self.primary_angle = elbow_angle
        self.secondary_angle = body_angle
        self._current_angles = {
            "primary": elbow_angle,
            "secondary": body_angle,
            "elbow_angle": elbow_angle,
            "shoulder_angle": shoulder_angle,
            "body_angle": body_angle,
        }

    def _on_enter_active(self):
        t = self.thresh
        body_ok = t["body_alignment_low"] <= self.body_angle <= t["body_alignment_high"]
        return "Lowering..." if body_ok else f"Keep flat on bench ({self.body_angle:.0f}°)"

    def _on_rep_complete(self, rep_analysis):
        t = self.thresh
        angles = rep_analysis["angles"]
        elbow_angle = angles.get("elbow_angle", rep_analysis["primary_angle"])
        body_angle = angles.get("body_angle", rep_analysis["secondary_angle"])
        shoulder_angle = angles.get("shoulder_angle", 0.0)

        depth_ok = elbow_angle <= t["elbow_angle_correct"]
        body_ok = t["body_alignment_low"] <= body_angle <= t["body_alignment_high"]
        shoulder_ok = (not self._shoulder_angle_reliable) or (
            t["shoulder_angle_low"] <= shoulder_angle <= t["shoulder_angle_high"]
        )
        tempo_status = rep_analysis["tempo"]["status"]
        tempo_ok = tempo_status in ("ok", "unknown")

        is_correct = depth_ok and body_ok and shoulder_ok and tempo_ok

        if is_correct:
            feedback = "Good rep!"
        elif not depth_ok:
            feedback = f"Lower the bar more ({elbow_angle:.0f}° > {t['elbow_angle_correct']}° max)"
        elif not body_ok:
            feedback = f"Keep back flat ({body_angle:.0f}°)"
        elif not shoulder_ok:
            feedback = f"Watch elbow flare ({shoulder_angle:.0f}°)"
        elif tempo_status == "bounced_out":
            feedback = "Control the press - don't bounce"
        else:
            feedback = "Slow down the descent"

        extra_data = {
            "elbow_angle": elbow_angle,
            "shoulder_angle": shoulder_angle,
            "body_angle": body_angle,
        }
        return is_correct, feedback, extra_data

    def get_angle_labels(self):
        return [
            ("Elbow", self.elbow_angle),
            ("Shoulder", self.shoulder_angle),
            ("Body", self.body_angle),
        ]

    def get_stats_for_api(self):
        d = super().get_stats_for_api()
        d["elbow_angle"] = round(self.elbow_angle, 1)
        d["shoulder_angle"] = round(self.shoulder_angle, 1)
        d["body_angle"] = round(self.body_angle, 1)
        return d
