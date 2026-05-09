# Movement Lab Visual Identity Design

## Goal

Create a distinct UI/UX direction for Lift & Flow that avoids the generic AI-fitness look: no neon gradient dark mode, no glassmorphism dashboard, no oversized rounded card stack, and no template-like "vibecoded" styling.

## Product Context

Lift & Flow is a Flutter mobile app backed by a Flask pose-analysis server. The app sends camera frames to the backend, receives annotated frames, form stats, landmarks, and AI coach feedback, then shows live exercise guidance and session summaries.

## Recommended Direction

The design direction is **Movement Lab**: a biomechanical training interface that feels like a sports-science instrument. The app should make the user's body motion the primary visual object, with joint angles, calibration ticks, rep states, and short coaching cues as the supporting system.

## Visual System

- Surfaces: light porcelain and paper-line backgrounds.
- Primary text: graphite, not pure black unless high contrast is needed.
- Tracking accent: deep teal for pose overlays, analysis focus, and selected training states.
- Correct state: muted green.
- Correction state: clay red.
- Tempo state: ochre yellow.
- Shape language: squared instrument panels, hard calibration marks, precise borders, and restrained shadows.
- Typography: functional athletic sans for content, mono-style labels for metrics and diagnostic states.

## Core Screens

1. **Home Readiness**
   - Shows readiness score, planned work, and next training focus.
   - Should feel like a daily movement report, not a marketing home screen.

2. **Live Coach**
   - Camera surface is the hero.
   - Uses calibration corners, skeleton overlay, angle labels, rep state chips, and concise AI coaching.
   - Beginner mode should show fewer diagnostic labels; pro mode can expose denser angle/tempo details.

3. **Session Summary**
   - Shows form accuracy, total reps, correct reps, fixes, rep timeline, and one next-focus recommendation.
   - Report should make progress legible immediately after a set.

## Implementation Notes For Later Flutter Work

- Keep existing product scope and navigation intact.
- Redesign presentation only: Auth, Home, Workouts, Record, Stats, Profile, and Session Summary remain the app structure.
- Move away from broad background gradients and dark panels.
- Use analyzer data as the visual system: angles, state, correct/incorrect counts, and current feedback.
- Keep all secrets out of frontend code during implementation.

## Preview Artifact

The local preview is at:

`design/movement-lab/index.html`
