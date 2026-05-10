import math
import cv2
import numpy as np
import mediapipe as mp

# MediaPipe Pose landmark indices we care about
# Full list: https://developers.google.com/mediapipe/solutions/vision/pose_landmarker
LANDMARKS = {
    "nose": 0,
    "left_shoulder": 11,
    "right_shoulder": 12,
    "left_elbow": 13,
    "right_elbow": 14,
    "left_wrist": 15,
    "right_wrist": 16,
    "left_hip": 23,
    "right_hip": 24,
    "left_knee": 25,
    "right_knee": 26,
    "left_ankle": 27,
    "right_ankle": 28,
    "left_heel": 29,
    "right_heel": 30,
    "left_foot_index": 31,
    "right_foot_index": 32,
}


def find_angle(p1, p2, p3):
    """
    Compute the angle at p2 formed by the line segments p1-p2 and p3-p2.
    Each point is (x, y). Returns degrees in [0, 180].

    Example: find_angle(hip, knee, ankle) gives the knee bend angle.
    """
    x1, y1 = p1
    x2, y2 = p2
    x3, y3 = p3

    # Vectors from p2 to p1 and p2 to p3
    v1 = (x1 - x2, y1 - y2)
    v2 = (x3 - x2, y3 - y2)

    # atan2-based angle: robust to all quadrants
    angle1 = math.atan2(v1[1], v1[0])
    angle2 = math.atan2(v2[1], v2[0])

    angle = abs(math.degrees(angle1 - angle2))
    if angle > 180:
        angle = 360 - angle
    return angle


def find_offset_angle(p1, p2):
    """
    Compute the angle of the line p1->p2 relative to the vertical (y-axis).
    Used to check if the person is roughly aligned (side view offset check).
    Returns degrees. 0 means perfectly vertical, 90 means horizontal.
    """
    x1, y1 = p1
    x2, y2 = p2
    return abs(math.degrees(math.atan2(x2 - x1, y2 - y1)))


def get_landmark_coords(landmarks, idx, w, h):
    """
    Extract (x, y) pixel coords — legacy mp.solutions API.
    landmarks is results.pose_landmarks.landmark (list with .x, .y)
    """
    lm = landmarks[idx]
    return int(lm.x * w), int(lm.y * h)


def get_landmark_coords_from_normalized(landmarks, idx, w, h):
    """
    Extract (x, y) pixel coords — new mp.tasks API.
    landmarks is results.pose_landmarks[0] (list of NormalizedLandmark).
    """
    lm = landmarks[idx]
    return int(lm.x * w), int(lm.y * h)


def draw_text_with_bg(frame, text, pos, font_scale=0.7, color=(255, 255, 255),
                      bg_color=(0, 0, 0), thickness=2, padding=5):
    """Draw text with a filled background rectangle for readability."""
    font = cv2.FONT_HERSHEY_SIMPLEX
    (tw, th), baseline = cv2.getTextSize(text, font, font_scale, thickness)
    x, y = pos
    cv2.rectangle(frame, (x - padding, y - th - padding),
                  (x + tw + padding, y + baseline + padding), bg_color, -1)
    cv2.putText(frame, text, (x, y), font, font_scale, color, thickness)
