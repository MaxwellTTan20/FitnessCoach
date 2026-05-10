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
        """Get coaching feedback for a completed rep exclusively from the LLM."""
        if not self.provider:
            return ""

        user_message = self._format_rep_data(rep_data)
        
        try:
            if self.provider == "claude":
                return self._get_claude_feedback(user_message)
            else:
                return self._get_openai_feedback(user_message)
        except Exception as e:
            print(f"AI Coach error: {e}")
            return ""

    @property
    def system_prompt(self) -> str:
        return f"""You are an elite, direct fitness coach for {self.exercise}.
Analyze the provided rep data and give punchy, personalized feedback.
RULES:
1. MAXIMUM 10 WORDS.
2. NO EXPLANATIONS. Be direct.
3. Be encouraging but corrective.
4. Use the provided metrics (angles, tempo) to give specific advice.
5. VARY YOUR RESPONSES. Never say the exact same phrase twice. Focus on a different aspect of the form (e.g. depth, tempo, chest) each time, even if the rep is marked correct.
6. If the rep is perfect, you can just praise the specific angle or tempo that was best."""

    def _format_rep_data(self, rep_data: dict) -> str:
        if self.exercise == "pushup":
            return self._format_pushup_rep(rep_data)
        return self._format_squat_rep(rep_data)

    def _format_squat_rep(self, rep_data: dict) -> str:
        tempo = rep_data.get("tempo", {})
        tempo_str = f"Eccentric {tempo.get('eccentric_ms', 0)}ms, Concentric {tempo.get('concentric_ms', 0)}ms"
        
        knee_angle = rep_data.get("knee_angle", 180)
        hip_angle = rep_data.get("hip_angle", 180)
        
        # Add hints for the LLM based on tightened thresholds
        depth_hint = "Parallel Depth" if knee_angle <= 90 else ("Close to Parallel" if knee_angle <= 105 else "Shallow")
        torso_hint = "Good torso" if 40 <= hip_angle <= 120 else "Leaning too much"
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

        elbow_angle = rep_data.get('elbow_angle', 180)
        shoulder_angle = rep_data.get('shoulder_angle', 0)
        body_angle = rep_data.get('body_angle', 180)
        
        depth_hint = "Good depth (90° or less)" if elbow_angle <= 90 else "Shallow (Didn't reach 90°)"
        body_hint = "Good plank alignment" if 150 <= body_angle <= 180 else "Sagging hips or piking"
        shoulder_hint = "Good arm position" if 15 <= shoulder_angle <= 90 else "Flared elbows"

        return f"""Rep #{rep_data['rep_number']} completed:
- Status: {"CORRECT" if rep_data['is_correct'] else "INCORRECT"}
- Elbow angle at bottom: {elbow_angle:.0f}° ({depth_hint})
- Shoulder angle: {shoulder_angle:.0f}° ({shoulder_hint})
- Body alignment: {body_angle:.0f}° ({body_hint})
- Tempo: {tempo_str} ({tempo.get('status', 'Good')})
- Mode: {rep_data['mode']}

Provide short, punchy coaching for this rep."""

    def _get_claude_feedback(self, user_message: str) -> str:
        response = self.client.messages.create(
            model="claude-haiku-4-5-20251001",
            max_tokens=100,
            system=self.system_prompt,
            messages=[{"role": "user", "content": user_message}],
            temperature=0.7,
        )
        return response.content[0].text

    def _get_openai_feedback(self, user_message: str) -> str:
        response = self.client.chat.completions.create(
            model="claude-sonnet-4-5-20251101",
            max_tokens=100,
            temperature=0.7,
            messages=[
                {"role": "system", "content": self.system_prompt},
                {"role": "user", "content": user_message},
            ],
        )
        return response.choices[0].message.content
