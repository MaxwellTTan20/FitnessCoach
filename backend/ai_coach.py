"""
AI Coach - unified interface for Claude and OpenAI coaching feedback.
Exercise-specific system prompts and rep data formatting.
"""
import os
from typing import Literal

EXERCISE_SYSTEM_PROMPTS = {
    "squat": """You are a concise fitness coach providing real-time voice feedback during squat exercises.

When given rep data, provide 1-2 sentences of helpful, encouraging feedback. Focus on:
- Acknowledging good form when depth and torso position are correct
- Correcting shallow depth (knee angle too high at bottom)
- Correcting excessive forward lean (hip angle out of range)
- Noting rushed descent if under 0.5 seconds
- Noting bouncing out of the bottom if ascent is under 0.3 seconds

Keep responses SHORT (under 25 words) since they will be spoken aloud during exercise.
Never use bullet points or lists. Speak naturally as a coach would.""",

    "pushup": """You are a concise fitness coach providing real-time voice feedback during push-up exercises.

When given rep data, provide 1-2 sentences of helpful, encouraging feedback. Focus on:
- Acknowledging good form when depth and body alignment are correct
- Correcting insufficient depth (elbow angle too high at bottom)
- Correcting hip sag or piking (body alignment angle out of range)
- Correcting elbow flare (glenohumeral/shoulder angle out of range)
- Noting rushed descent or bouncing out of the bottom

Keep responses SHORT (under 25 words) since they will be spoken aloud during exercise.
Never use bullet points or lists. Speak naturally as a coach would.""",

    "deadlift": """You are a concise fitness coach providing real-time voice feedback during deadlift exercises.

When given rep data, provide 1-2 sentences of helpful, encouraging feedback. Focus on:
- Acknowledging good form when hip hinge depth is sufficient
- Correcting insufficient hip hinge (hip angle too high at bottom — not bending over enough)
- Noting if the lowering phase was too fast (rushed descent)
- Noting if the pull was jerky or uncontrolled (fast ascent)

Keep responses SHORT (under 25 words) since they will be spoken aloud during exercise.
Never use bullet points or lists. Speak naturally as a coach would.""",

    "bench": """You are a concise fitness coach providing real-time voice feedback during bench press exercises.

When given rep data, provide 1-2 sentences of helpful, encouraging feedback. Focus on:
- Acknowledging good form when depth and body position are correct
- Correcting insufficient depth (elbow angle too high — bar not lowered enough)
- Correcting back arch / not lying flat (body alignment out of range)
- Correcting excessive elbow flare (glenohumeral/shoulder angle out of range)
- Noting rushed descent or bouncing the bar off the chest

Keep responses SHORT (under 25 words) since they will be spoken aloud during exercise.
Never use bullet points or lists. Speak naturally as a coach would.""",
}


class AICoach:
    """Unified interface for AI coaching feedback using Claude or OpenAI."""

    def __init__(
        self,
        provider: Literal["claude", "openai"] = "claude",
        api_key: str | None = None,
        exercise: str = "squat",
    ):
        self.provider = provider
        self.exercise = exercise
        self.system_prompt = EXERCISE_SYSTEM_PROMPTS.get(
            exercise, EXERCISE_SYSTEM_PROMPTS["squat"]
        )

        if provider == "claude":
            self.api_key = api_key or os.environ.get("ANTHROPIC_API_KEY")
            if not self.api_key:
                raise ValueError("Anthropic API key required. Set ANTHROPIC_API_KEY env var or pass api_key.")
            import anthropic
            self.client = anthropic.Anthropic(api_key=self.api_key)
        elif provider == "openai":
            self.api_key = api_key or os.environ.get("OPENAI_API_KEY")
            if not self.api_key:
                raise ValueError("OpenAI API key required. Set OPENAI_API_KEY env var or pass api_key.")
            import openai
            self.client = openai.OpenAI(api_key=self.api_key)
        else:
            raise ValueError(f"Unknown provider: {provider}. Use 'claude' or 'openai'.")

    def get_feedback(self, rep_data: dict) -> str:
        """Get coaching feedback for a completed rep."""
        live_feedback = self._get_live_feedback(rep_data)
        if live_feedback:
            return live_feedback

        user_message = self._format_rep_data(rep_data)
        try:
            if self.provider == "claude":
                return self._get_claude_feedback(user_message)
            else:
                return self._get_openai_feedback(user_message)
        except Exception as e:
            print(f"AI Coach error: {e}")
            return "Good rep." if rep_data.get("is_correct") else "Fix form."

    def _get_live_feedback(self, rep_data: dict) -> str:
        if self.exercise == "pushup":
            return self._get_pushup_live_feedback(rep_data)
        return self._get_squat_live_feedback(rep_data)

    def _get_squat_live_feedback(self, rep_data: dict) -> str:
        if rep_data.get("is_correct"):
            return "Good rep."

        tempo_status = rep_data.get("tempo", {}).get("status")
        if tempo_status == "rushed_descent":
            return "Slow down."
        if tempo_status == "bounced_out":
            return "Control the ascent."

        knee_angle = rep_data.get("knee_angle", 0)
        hip_angle = rep_data.get("hip_angle", 0)
        if hip_angle < 50:
            return "Chest up."
        if hip_angle > 120:
            return "Sit back."
        if knee_angle > 75:
            return "Sink lower."
        return "Fix form."

    def _get_pushup_live_feedback(self, rep_data: dict) -> str:
        if rep_data.get("is_correct"):
            return "Good rep."

        tempo_status = rep_data.get("tempo", {}).get("status")
        if tempo_status == "rushed_descent":
            return "Slow down."
        if tempo_status == "bounced_out":
            return "Control the press."

        elbow_angle = rep_data.get("elbow_angle", 0)
        body_angle = rep_data.get("body_angle", 180)
        shoulder_angle = rep_data.get("shoulder_angle", 0)
        if body_angle < 150:
            return "Stay straight."
        if elbow_angle > 90:
            return "Go lower."
        if shoulder_angle > 90:
            return "Tuck elbows."
        return "Fix form."

    def _format_rep_data(self, rep_data: dict) -> str:
        if self.exercise == "pushup":
            return self._format_pushup_rep(rep_data)
        if self.exercise == "deadlift":
            return self._format_deadlift_rep(rep_data)
        if self.exercise == "bench":
            return self._format_bench_rep(rep_data)
        return self._format_squat_rep(rep_data)

    def _format_squat_rep(self, rep_data: dict) -> str:
        tempo = rep_data.get("tempo", {})
        descent = tempo.get("descent_seconds")
        ascent = tempo.get("ascent_seconds")
        tempo_status = tempo.get("status", "unknown")
        descent_str = f"{descent:.1f}s" if descent is not None else "?"
        ascent_str = f"{ascent:.1f}s" if ascent is not None else "?"
        tempo_str = f"{descent_str} descent, {ascent_str} ascent ({tempo_status})"

        return f"""Rep #{rep_data['rep_number']} completed:
- Form: {"CORRECT" if rep_data['is_correct'] else "INCORRECT"}
- Knee angle at depth: {rep_data.get('knee_angle', 0):.0f} degrees
- Hip/torso angle at depth: {rep_data.get('hip_angle', 0):.0f} degrees
- Tempo: {tempo_str}
- Mode: {rep_data['mode']}
- Session stats: {rep_data['correct_count']} correct, {rep_data['incorrect_count']} incorrect

Provide brief coaching feedback for this rep."""

    def _format_pushup_rep(self, rep_data: dict) -> str:
        tempo = rep_data.get("tempo", {})
        descent = tempo.get("descent_seconds")
        ascent = tempo.get("ascent_seconds")
        tempo_status = tempo.get("status", "unknown")
        descent_str = f"{descent:.1f}s" if descent is not None else "?"
        ascent_str = f"{ascent:.1f}s" if ascent is not None else "?"
        tempo_str = f"{descent_str} descent, {ascent_str} ascent ({tempo_status})"

        return f"""Rep #{rep_data['rep_number']} completed:
- Form: {"CORRECT" if rep_data['is_correct'] else "INCORRECT"}
- Elbow angle at bottom: {rep_data.get('elbow_angle', 0):.0f} degrees
- Shoulder/glenohumeral angle: {rep_data.get('shoulder_angle', 0):.0f} degrees
- Body alignment angle: {rep_data.get('body_angle', 0):.0f} degrees
- Tempo: {tempo_str}
- Mode: {rep_data['mode']}
- Session stats: {rep_data['correct_count']} correct, {rep_data['incorrect_count']} incorrect

Provide brief coaching feedback for this rep."""

    def _format_deadlift_rep(self, rep_data: dict) -> str:
        tempo = rep_data.get("tempo", {})
        descent = tempo.get("descent_seconds")
        ascent = tempo.get("ascent_seconds")
        tempo_status = tempo.get("status", "unknown")
        descent_str = f"{descent:.1f}s" if descent is not None else "?"
        ascent_str = f"{ascent:.1f}s" if ascent is not None else "?"
        tempo_str = f"{descent_str} lower, {ascent_str} pull ({tempo_status})"

        return f"""Rep #{rep_data['rep_number']} completed:
- Form: {"CORRECT" if rep_data['is_correct'] else "INCORRECT"}
- Hip hinge angle at bottom: {rep_data.get('hip_angle', 0):.0f} degrees (lower = deeper hinge)
- Knee angle at bottom: {rep_data.get('knee_angle', 0):.0f} degrees
- Tempo: {tempo_str}
- Mode: {rep_data['mode']}
- Session stats: {rep_data['correct_count']} correct, {rep_data['incorrect_count']} incorrect

Provide brief coaching feedback for this rep."""

    def _format_bench_rep(self, rep_data: dict) -> str:
        tempo = rep_data.get("tempo", {})
        descent = tempo.get("descent_seconds")
        ascent = tempo.get("ascent_seconds")
        tempo_status = tempo.get("status", "unknown")
        descent_str = f"{descent:.1f}s" if descent is not None else "?"
        ascent_str = f"{ascent:.1f}s" if ascent is not None else "?"
        tempo_str = f"{descent_str} descent, {ascent_str} press ({tempo_status})"

        return f"""Rep #{rep_data['rep_number']} completed:
- Form: {"CORRECT" if rep_data['is_correct'] else "INCORRECT"}
- Elbow angle at bottom: {rep_data.get('elbow_angle', 0):.0f} degrees
- Shoulder/elbow flare angle: {rep_data.get('shoulder_angle', 0):.0f} degrees
- Body alignment (flat on bench): {rep_data.get('body_angle', 0):.0f} degrees
- Tempo: {tempo_str}
- Mode: {rep_data['mode']}
- Session stats: {rep_data['correct_count']} correct, {rep_data['incorrect_count']} incorrect

Provide brief coaching feedback for this rep."""

    def _get_claude_feedback(self, user_message: str) -> str:
        response = self.client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=100,
            system=self.system_prompt,
            messages=[{"role": "user", "content": user_message}],
        )
        return response.content[0].text

    def _get_openai_feedback(self, user_message: str) -> str:
        response = self.client.chat.completions.create(
            model="gpt-4o-mini",
            max_tokens=100,
            messages=[
                {"role": "system", "content": self.system_prompt},
                {"role": "user", "content": user_message},
            ],
        )
        return response.choices[0].message.content
