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
        return f"""You are an elite, direct fitness coach for {self.exercise}.
Analyze the provided rep data and give punchy, personalized feedback.
RULES:
1. MAXIMUM 10 WORDS.
2. NO EXPLANATIONS. Be direct.
3. Be encouraging but corrective.
4. Use the provided metrics (angles, tempo) to give specific advice."""

    def _format_rep_data(self, rep_data: dict) -> str:
        if self.exercise == "pushup":
            return self._format_pushup_rep(rep_data)
        return self._format_squat_rep(rep_data)

    def _format_squat_rep(self, rep_data: dict) -> str:
        tempo = rep_data.get("tempo", {})
        tempo_str = f"Eccentric {tempo.get('eccentric_ms', 0)}ms, Concentric {tempo.get('concentric_ms', 0)}ms"
        
        knee_angle = rep_data.get("knee_angle", 180)
        hip_angle = rep_data.get("hip_angle", 180)
        
        # Add hints for the LLM
        depth_hint = "Good depth" if knee_angle <= 115 else "Shallow"
        torso_hint = "Good torso" if 25 <= hip_angle <= 120 else "Leaning too much"
        tempo_hint = tempo.get("status", "Good tempo")

        return f"""Rep #{rep_data['rep_number']} completed:
- Status: {"CORRECT" if rep_data['is_correct'] else "INCORRECT"}
- Knee Angle: {knee_angle:.0f}° ({depth_hint})
- Hip Angle: {hip_angle:.0f}° ({torso_hint})
- Tempo: {tempo_str} ({tempo_hint})
- Mode: {rep_data['mode']}

Provide short, punchy coaching for this rep."""

    def _format_pushup_rep(self, rep_data: dict) -> str:
        tempo = rep_data.get("tempo", {})
        tempo_str = f"Eccentric {tempo.get('eccentric_ms', 0)}ms, Concentric {tempo.get('concentric_ms', 0)}ms"

        return f"""Rep #{rep_data['rep_number']} completed:
- Status: {"CORRECT" if rep_data['is_correct'] else "INCORRECT"}
- Elbow angle at bottom: {rep_data.get('elbow_angle', 0):.0f}°
- Shoulder angle: {rep_data.get('shoulder_angle', 0):.0f}°
- Body alignment: {rep_data.get('body_angle', 0):.0f}°
- Tempo: {tempo_str} ({tempo.get('status', 'Good')})
- Mode: {rep_data['mode']}

Provide short, punchy coaching for this rep."""

    def _get_claude_feedback(self, user_message: str) -> str:
        response = self.client.messages.create(
            model="claude-haiku-4-5-20251001",
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
