import os
from typing import Literal

class AICoach:
    """Manages AI interactions for coaching feedback using Anthropic or OpenAI."""

    def __init__(
        self,
        provider: Literal["claude", "openai"] = "claude",
        api_key: str | None = None,
        exercise: str = "squat",
    ):
        self.provider = provider
        self.exercise = exercise
        self.api_key = api_key

        if not provider:
            return  # Will use fallback logic

        if provider == "claude":
            self.api_key = api_key or os.environ.get("ANTHROPIC_API_KEY")
            if not self.api_key:
                raise ValueError("Anthropic API key required for claude provider.")
            import anthropic
            self.client = anthropic.Anthropic(api_key=self.api_key)
        elif provider == "openai":
            self.api_key = api_key or os.environ.get("OPENAI_API_KEY")
            if not self.api_key:
                raise ValueError("OpenAI API key required for openai provider.")
            import openai
            self.client = openai.OpenAI(api_key=self.api_key)
        else:
            raise ValueError(f"Unknown provider: {provider}. Use 'claude' or 'openai'.")

    def get_feedback(self, rep_data: dict) -> str:
        """Get coaching feedback for a completed rep."""
        user_message = self._format_rep_data(rep_data)
        
        if self.provider:
            try:
                if self.provider == "claude":
                    return self._get_claude_feedback(user_message)
                else:
                    return self._get_openai_feedback(user_message)
            except Exception as e:
                print(f"AI Coach error: {e}")
                
        # Fallback to local logic if no provider or LLM fails
        live_feedback = self._get_live_feedback(rep_data)
        if live_feedback:
            return live_feedback

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
            return "Get lower."

        return ""

    def _get_pushup_live_feedback(self, rep_data: dict) -> str:
        if rep_data.get("is_correct"):
            return "Good rep."

        tempo_status = rep_data.get("tempo", {}).get("status")
        if tempo_status == "rushed_descent":
            return "Control the descent."
        if tempo_status == "bounced_out":
            return "Don't bounce."

        elbow_angle = rep_data.get("elbow_angle", 0)
        if elbow_angle > 110:
            return "Lower chest to floor."

        return ""

    @property
    def system_prompt(self) -> str:
        return f"""You are an elite fitness coach specializing in the {self.exercise}.
Analyze the rep data and provide exactly one short sentence of actionable feedback (max 6 words).
If the rep is CORRECT, give brief encouragement or reinforce what went well.
If INCORRECT, state the specific cue to fix it based on the angles.
Focus on safety and mechanical efficiency. Keep it punchy and direct."""

    def _format_rep_data(self, rep_data: dict) -> str:
        if self.exercise == "pushup":
            return self._format_pushup_rep(rep_data)
        return self._format_squat_rep(rep_data)

    def _format_squat_rep(self, rep_data: dict) -> str:
        tempo = rep_data.get("tempo", {})
        tempo_str = f"Eccentric {tempo.get('eccentric_ms', 0)}ms, Concentric {tempo.get('concentric_ms', 0)}ms"

        return f"""Rep #{rep_data['rep_number']} completed:
- Form: {"CORRECT" if rep_data['is_correct'] else "INCORRECT"}
- Max knee flexion: {rep_data.get('knee_angle', 0):.0f} degrees
- Min hip angle: {rep_data.get('hip_angle', 0):.0f} degrees
- Tempo: {tempo_str}
- Mode: {rep_data['mode']}
- Session stats: {rep_data['correct_count']} correct, {rep_data['incorrect_count']} incorrect

Provide brief coaching feedback for this rep."""

    def _format_pushup_rep(self, rep_data: dict) -> str:
        tempo = rep_data.get("tempo", {})
        tempo_str = f"Eccentric {tempo.get('eccentric_ms', 0)}ms, Concentric {tempo.get('concentric_ms', 0)}ms"

        return f"""Rep #{rep_data['rep_number']} completed:
- Form: {"CORRECT" if rep_data['is_correct'] else "INCORRECT"}
- Elbow angle at bottom: {rep_data.get('elbow_angle', 0):.0f} degrees
- Shoulder/glenohumeral angle: {rep_data.get('shoulder_angle', 0):.0f} degrees
- Body alignment angle: {rep_data.get('body_angle', 0):.0f} degrees
- Tempo: {tempo_str}
- Mode: {rep_data['mode']}
- Session stats: {rep_data['correct_count']} correct, {rep_data['incorrect_count']} incorrect

Provide brief coaching feedback for this rep."""

    def _get_claude_feedback(self, user_message: str) -> str:
        response = self.client.messages.create(
            model="claude-3-5-sonnet-latest",
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
