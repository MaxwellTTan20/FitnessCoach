import unittest

from ai_coach import AICoach


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
    }


class AICoachFeedbackTest(unittest.TestCase):
    def test_get_feedback_prefers_llm_feedback(self):
        coach = AICoach.__new__(AICoach)
        coach.provider = "claude"
        coach._format_rep_data = lambda rep_data: "formatted rep"
        coach._get_claude_feedback = lambda message: "LLM says sink lower."
        coach._get_live_feedback = lambda rep_data: "Hardcoded fallback."

        self.assertEqual(coach.get_feedback(_rep_data()), "LLM says sink lower.")

    def test_get_feedback_uses_live_feedback_when_llm_fails(self):
        coach = AICoach.__new__(AICoach)
        coach.provider = "claude"
        coach._format_rep_data = lambda rep_data: "formatted rep"
        coach._get_claude_feedback = lambda message: (_ for _ in ()).throw(
            RuntimeError("network down")
        )
        coach._get_live_feedback = lambda rep_data: "Hardcoded fallback."

        self.assertEqual(coach.get_feedback(_rep_data()), "Hardcoded fallback.")


if __name__ == "__main__":
    unittest.main()
