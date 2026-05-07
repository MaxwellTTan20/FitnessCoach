# Angle thresholds for squat analysis.
# These define what counts as "correct" vs "incorrect" form.

# Offset angle: if the shoulder-hip line deviates more than this from vertical,
# the person isn't properly aligned with the camera (side view expected).
OFFSET_THRESH = 35.0

# Inactivity threshold in seconds: if no pose detected for this long, reset counters.
INACTIVE_THRESH = 15.0

# --- Squat depth thresholds ---
# The key angle is hip-knee-ankle. A full squat brings this angle low.
# We also check hip angle (shoulder-hip-knee) for torso lean.

THRESHOLDS = {
    "beginner": {
        # Hip-knee-ankle angle below this = squat is deep enough
        "knee_angle_low": 80,    # below this = in squat position
        "knee_angle_high": 160,  # above this = standing
        # Shoulder-hip-knee angle range for acceptable torso lean
        "hip_angle_low": 50,
        "hip_angle_high": 120,
    },
    "pro": {
        "knee_angle_low": 60,    # pro requires deeper squat
        "knee_angle_high": 160,
        "hip_angle_low": 30,
        "hip_angle_high": 110,
    },
}
