"""
Downloads the MediaPipe Pose Landmarker model.
Run once: python download_model.py
"""
import urllib.request
import os

MODEL_URL = "https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_heavy/float16/1/pose_landmarker_heavy.task"
MODEL_PATH = os.path.join(os.path.dirname(__file__), "pose_landmarker_heavy.task")

if os.path.exists(MODEL_PATH):
    print(f"Model already exists: {MODEL_PATH}")
else:
    print(f"Downloading pose landmarker model...")
    urllib.request.urlretrieve(MODEL_URL, MODEL_PATH)
    print(f"Saved to: {MODEL_PATH}")
