import unittest

from analyzer import serialize_landmark


class FakeLandmark:
    x = 0.25
    y = 0.5
    z = -0.125
    visibility = 0.875
    presence = 0.75


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


if __name__ == "__main__":
    unittest.main()
