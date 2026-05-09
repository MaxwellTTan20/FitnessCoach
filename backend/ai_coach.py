"""
AI Coach - unified interface for Claude and OpenAI coaching feedback.
"""
import os
from typing import Literal

SYSTEM_PROMPT = """You are a concise fitness coach providing real-time voice feedback during squat exercises.

When given rep data, provide 1-2 sentences of helpful, encouraging feedback. Focus on:
- Acknowledging good form when depth and torso position are correct
- Correcting shallow depth (knee angle too high at bottom)
- Correcting excessive forward lean (hip angle out of range)
- Noting rushed descent if under 0.5 seconds
- Noting bouncing out of the bottom if ascent is under 0.3 seconds

Keep responses SHORT (under 25 words) since they will be spoken aloud during exercise.
Never use bullet points or lists. Speak naturally as a coach would."""


class AICoach:
    """Unified interface for AI coaching feedback using Claude or OpenAI."""

    def __init__(
        self,
        provider: Literal["claude", "openai"] = "claude",
        api_key: str | None = None,
    ):
        self.provider = provider

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
        user_message = self._format_rep_data(rep_data)
        try:
            if self.provider == "claude":
                return self._get_claude_feedback(user_message)
            else:
                return self._get_openai_feedback(user_message)
        except Exception as e:
            print(f"AI Coach error: {e}")
            return "Good rep! Keep it up." if rep_data.get("is_correct") else "Watch your form on the next one."

    def _format_rep_data(self, rep_data: dict) -> str:
        tempo = rep_data.get("tempo", {})
        descent = tempo.get("descent_seconds", 0)
        ascent = tempo.get("ascent_seconds", 0)
        return f"""Rep #{rep_data['rep_number']} completed:
- Form: {"CORRECT" if rep_data['is_correct'] else "INCORRECT"}
- Knee angle at depth: {rep_data['knee_angle']:.0f} degrees
- Hip/torso angle at depth: {rep_data['hip_angle']:.0f} degrees
- Tempo: {descent:.1f}s descent, {ascent:.1f}s ascent
- Mode: {rep_data['mode']}
- Session stats: {rep_data['correct_count']} correct, {rep_data['incorrect_count']} incorrect

Provide brief coaching feedback for this rep."""

    def _get_claude_feedback(self, user_message: str) -> str:
        response = self.client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=100,
            system=SYSTEM_PROMPT,
            messages=[{"role": "user", "content": user_message}],
        )
        return response.content[0].text

    def _get_openai_feedback(self, user_message: str) -> str:
        response = self.client.chat.completions.create(
            model="gpt-4o-mini",
            max_tokens=100,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": user_message},
            ],
        )
        return response.choices[0].message.content
