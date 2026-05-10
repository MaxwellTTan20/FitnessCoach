import unittest

from analyzer import (
    choose_reliable_squat_side,
    serialize_landmark,
    side_profile_confidence,
    summarize_side_landmarks,
)


class FakeLandmark:
    def __init__(
        self,
        x=0.25,
        y=0.5,
        z=-0.125,
        visibility=0.875,
        presence=0.75,
    ):
        self.x = x
        self.y = y
        self.z = z
        self.visibility = visibility
        self.presence = presence


class LandmarkSerializationTest(unittest.TestCase):
    def test_serialize_landmark_preserves_precision_and_confidence(self):
        self.assertEqual(
            serialize_landmark(FakeLandmark()),
            {
                "x": 0.25,
                "y": 0.5,
                "z": -0.125,
                "visibility": 0.875,
                "presence": 0.75,
            },
        )

    def test_choose_reliable_squat_side_prefers_visible_side(self):
        landmarks = [FakeLandmark() for _ in range(33)]
        for index in (12, 24, 26, 28):
            landmarks[index] = FakeLandmark(visibility=0.95, presence=0.95)
        for index in (11, 23, 25, 27):
            landmarks[index] = FakeLandmark(visibility=0.35, presence=0.35)

        self.assertEqual(choose_reliable_squat_side(landmarks), "right")
        self.assertGreater(
            side_profile_confidence(landmarks, "right"),
            side_profile_confidence(landmarks, "left"),
        )

    def test_choose_reliable_squat_side_keeps_previous_side_inside_hysteresis(self):
        landmarks = [FakeLandmark(visibility=0.8, presence=0.8) for _ in range(33)]
        for index in (12, 24, 26, 28):
            landmarks[index] = FakeLandmark(visibility=0.84, presence=0.84)

        self.assertEqual(
            choose_reliable_squat_side(landmarks, previous_side="left"),
            "left",
        )

    def test_summarize_side_landmarks_includes_foot_points(self):
        landmarks = [FakeLandmark() for _ in range(33)]

        summary = summarize_side_landmarks(landmarks, "left")

        self.assertIn("heel", summary)
        self.assertIn("foot_index", summary)
        self.assertEqual(summary["foot_index"]["x"], 0.25)


if __name__ == "__main__":
    unittest.main()
