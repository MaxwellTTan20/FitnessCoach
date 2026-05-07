import time
import os
import cv2
import mediapipe as mp

from utils import (
    LANDMARKS, find_angle, find_offset_angle,
    get_landmark_coords_from_normalized,
)
from thresholds import OFFSET_THRESH, INACTIVE_THRESH, THRESHOLDS

BaseOptions = mp.tasks.BaseOptions
PoseLandmarker = mp.tasks.vision.PoseLandmarker
PoseLandmarkerOptions = mp.tasks.vision.PoseLandmarkerOptions
RunningMode = mp.tasks.vision.RunningMode

POSE_CONNECTIONS = mp.tasks.vision.PoseLandmarksConnections.POSE_LANDMARKS

MODEL_PATH = os.path.join(os.path.dirname(__file__), "pose_landmarker_heavy.task")


class SquatAnalyzer:
    def __init__(self, mode="beginner", on_rep_complete=None):
        self.mode = mode
        self.thresh = THRESHOLDS[mode]
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

        self.correct_count = 0
        self.incorrect_count = 0
        self.state = "standing"
        self.feedback = ""
        self.knee_angle = 0.0
        self.hip_angle = 0.0
        self.last_detection_time = time.time()

    def reset(self):
        self.correct_count = 0
        self.incorrect_count = 0
        self.state = "standing"
        self.feedback = ""
        self.knee_angle = 0.0
        self.hip_angle = 0.0

    def close(self):
        self.landmarker.close()

    def process_frame(self, frame):
        h, w, _ = frame.shape

        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)

        self.frame_timestamp_ms += 33
        results = self.landmarker.detect_for_video(mp_image, self.frame_timestamp_ms)

        if not results.pose_landmarks or len(results.pose_landmarks) == 0:
            elapsed = time.time() - self.last_detection_time
            if elapsed > INACTIVE_THRESH:
                self.reset()
            self.last_pose_landmarks = []
            return frame

        self.last_detection_time = time.time()
        landmarks = results.pose_landmarks[0]
        self.last_pose_landmarks = [
            {"x": float(lm.x), "y": float(lm.y), "z": float(getattr(lm, "z", 0.0))}
            for lm in landmarks
        ]

        self._draw_landmarks(frame, landmarks, w, h)

        l_shoulder = get_landmark_coords_from_normalized(landmarks, LANDMARKS["left_shoulder"], w, h)
        r_shoulder = get_landmark_coords_from_normalized(landmarks, LANDMARKS["right_shoulder"], w, h)
        l_hip = get_landmark_coords_from_normalized(landmarks, LANDMARKS["left_hip"], w, h)
        r_hip = get_landmark_coords_from_normalized(landmarks, LANDMARKS["right_hip"], w, h)
        l_knee = get_landmark_coords_from_normalized(landmarks, LANDMARKS["left_knee"], w, h)
        r_knee = get_landmark_coords_from_normalized(landmarks, LANDMARKS["right_knee"], w, h)
        l_ankle = get_landmark_coords_from_normalized(landmarks, LANDMARKS["left_ankle"], w, h)
        r_ankle = get_landmark_coords_from_normalized(landmarks, LANDMARKS["right_ankle"], w, h)

        offset_angle = find_offset_angle(l_shoulder, l_hip)
        if offset_angle > OFFSET_THRESH:
            self.feedback = f"Align to side view ({offset_angle:.0f}°)"
            return frame

        l_knee_angle = find_angle(l_hip, l_knee, l_ankle)
        r_knee_angle = find_angle(r_hip, r_knee, r_ankle)
        self.knee_angle = (l_knee_angle + r_knee_angle) / 2

        l_hip_angle = find_angle(l_shoulder, l_hip, l_knee)
        r_hip_angle = find_angle(r_shoulder, r_hip, r_knee)
        self.hip_angle = (l_hip_angle + r_hip_angle) / 2

        t = self.thresh
        form_ok = t["hip_angle_low"] <= self.hip_angle <= t["hip_angle_high"]

        if self.state == "standing" and self.knee_angle < t["knee_angle_low"]:
            self.state = "squatting"
            self.feedback = "Good depth!" if form_ok else f"Watch torso ({self.hip_angle:.0f}°)"

        elif self.state == "squatting" and self.knee_angle > t["knee_angle_high"]:
            if form_ok:
                self.correct_count += 1
                self.feedback = "Good rep!"
            else:
                self.incorrect_count += 1
                self.feedback = "Check torso lean"
            self.state = "standing"

            if self.on_rep_complete:
                self.on_rep_complete({
                    "rep_number": self.correct_count + self.incorrect_count,
                    "is_correct": form_ok,
                    "knee_angle": self.knee_angle,
                    "hip_angle": self.hip_angle,
                    "mode": self.mode,
                    "correct_count": self.correct_count,
                    "incorrect_count": self.incorrect_count,
                })

        return frame

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
