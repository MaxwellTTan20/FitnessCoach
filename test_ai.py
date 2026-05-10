import sys
import os

# Add backend to path
sys.path.append(os.path.join(os.getcwd(), 'backend'))

from ai_coach import AICoach

coach = AICoach(provider="claude", api_key="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", exercise="squat")

rep_data = {
    "is_correct": True,
    "knee_angle": 80,
    "hip_angle": 60,
    "rep_number": 1,
    "mode": "beginner",
    "correct_count": 1,
    "incorrect_count": 0,
    "tempo": {"status": "good", "eccentric_ms": 1000, "concentric_ms": 1000}
}

try:
    print("Testing get_feedback...")
    feedback = coach.get_feedback(rep_data)
    print(f"Result: {feedback}")
except Exception as e:
    print(f"Error: {e}")
