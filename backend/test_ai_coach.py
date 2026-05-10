import unittest

from ai_coach import AICoach, MAX_SPOKEN_FEEDBACK_WORDS, prune_spoken_feedback


def _rep_data():
    return {
        "rep_number": 1,
        "is_correct": False,
        "knee_angle": 95,
        "hip_angle": 80,
        "mode": "beginner",
        "correct_count": 0,
        "incorrect_count": 1,
        "tempo": {
            "status": "good",
            "descent_seconds": 0.8,
            "ascent_seconds": 0.5,
        },
        "tracked_side": "right",
        "tracked_metrics": {
            "torso_offset_angle": 8.2,
            "foot_pitch_angle": 12.6,
            "side_confidence": 0.91,
            "opposite_side_confidence": 0.42,
            "elbow_horizontal_separation": 0.03,
            "shoulder_angle_reliable": False,
        },
        "tracked_landmarks": {
            "shoulder": {"visibility": 0.9, "presence": 0.95},
            "hip": {"visibility": 0.92, "presence": 0.93},
            "knee": {"visibility": 0.88, "presence": 0.9},
            "ankle": {"visibility": 0.86, "presence": 0.89},
            "heel": {"visibility": 0.8, "presence": 0.82},
            "foot_index": {"visibility": 0.78, "presence": 0.81},
        },
    }


class AICoachFeedbackTest(unittest.TestCase):
    def test_get_feedback_prefers_llm_feedback(self):
        coach = AICoach.__new__(AICoach)
        coach.provider = "claude"
        coach._format_rep_data = lambda rep_data: "formatted rep"
        coach._get_claude_feedback = lambda message: "LLM says sink lower."
        coach._get_live_feedback = lambda rep_data: "Hardcoded fallback."

        self.assertEqual(coach.get_feedback(_rep_data()), "LLM says sink lower.")

    def test_get_feedback_prunes_llm_feedback(self):
        coach = AICoach.__new__(AICoach)
        coach.provider = "claude"
        coach._format_rep_data = lambda rep_data: "formatted rep"
        coach._get_claude_feedback = lambda message: (
            "Go deeper on that squat. Keep your chest tall. Drive through the floor."
        )
        coach._get_live_feedback = lambda rep_data: "Hardcoded fallback."

        self.assertEqual(
            coach.get_feedback(_rep_data()),
            "Go deeper on that squat. Keep your chest tall.",
        )

    def test_get_feedback_uses_live_feedback_when_llm_fails(self):
        coach = AICoach.__new__(AICoach)
        coach.provider = "claude"
        coach._format_rep_data = lambda rep_data: "formatted rep"
        coach._get_claude_feedback = lambda message: (_ for _ in ()).throw(
            RuntimeError("network down")
        )
        coach._get_live_feedback = lambda rep_data: "Hardcoded fallback."

        self.assertEqual(coach.get_feedback(_rep_data()), "Hardcoded fallback.")

    def test_prune_spoken_feedback_caps_words(self):
        feedback = prune_spoken_feedback(
            " ".join(f"word{index}" for index in range(MAX_SPOKEN_FEEDBACK_WORDS + 5))
        )

        self.assertLessEqual(len(feedback.split()), MAX_SPOKEN_FEEDBACK_WORDS)
        self.assertTrue(feedback.endswith("."))

    def test_squat_prompt_includes_tracked_details(self):
        coach = AICoach.__new__(AICoach)
        coach.exercise = "squat"

        prompt = coach._format_rep_data(_rep_data())

        self.assertIn("side=right", prompt)
        self.assertIn("torso vertical offset=8.20", prompt)
        self.assertIn("side-view foot pitch=12.60", prompt)
        self.assertIn("shoulder confidence=0.90", prompt)
        self.assertIn("toe-out rotation is unavailable", prompt)

    def test_pushup_prompt_includes_tracked_details(self):
        coach = AICoach.__new__(AICoach)
        coach.exercise = "pushup"

        prompt = coach._format_rep_data({
            **_rep_data(),
            "elbow_angle": 92,
            "shoulder_angle": 45,
            "body_angle": 168,
        })

        self.assertIn("Tracked details", prompt)
        self.assertIn("shoulder angle reliable=False", prompt)
        self.assertIn("elbow flare is limited", prompt)

    def test_deadlift_prompt_includes_tracked_details(self):
        coach = AICoach.__new__(AICoach)
        coach.exercise = "deadlift"

        prompt = coach._format_rep_data(_rep_data())

        self.assertIn("Tracked details", prompt)
        self.assertIn("side-view foot pitch=12.60", prompt)
        self.assertIn("toe-out rotation is unavailable", prompt)

    def test_bench_prompt_includes_tracked_details(self):
        coach = AICoach.__new__(AICoach)
        coach.exercise = "bench"

        prompt = coach._format_rep_data({
            **_rep_data(),
            "elbow_angle": 92,
            "shoulder_angle": 45,
            "body_angle": 168,
        })

        self.assertIn("Tracked details", prompt)
        self.assertIn("shoulder angle reliable=False", prompt)
        self.assertIn("elbow flare is limited", prompt)


if __name__ == "__main__":
    unittest.main()
