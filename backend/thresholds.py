# Angle thresholds for exercise form analysis.
# "active_angle_low/high" are the generic state-machine keys used by ExerciseAnalyzer.
# All other keys are exercise-specific and consumed by the subclass form checks.

# Offset angle: if the shoulder-hip line deviates more than this from vertical,
# the person isn't in side-view squat position.
OFFSET_THRESH = 35.0

# Inactivity threshold in seconds: if no pose detected for this long, reset counters.
INACTIVE_THRESH = 15.0

# --- Squat thresholds ---
# Primary angle: hip-knee-ankle (knee bend).
# State machine: enter "squatting" when knee < active_angle_low, exit when knee > active_angle_high.
SQUAT_THRESHOLDS = {
    "beginner": {
        "active_angle_low": 110,    # enter squatting state (was 90 — too strict for partial squats)
        "active_angle_high": 160,   # exit squatting state
        "knee_angle_correct": 95,   # rep is deep enough only if deepest knee angle <= this
        "hip_angle_low": 50,        # shoulder-hip-knee torso lean range
        "hip_angle_high": 120,
        "min_descent_seconds": 0.4, # descent faster than this = rushed
        "min_ascent_seconds": 0.2,  # ascent faster than this = bounced
    },
    "pro": {
        "active_angle_low": 80,
        "active_angle_high": 160,
        "knee_angle_correct": 60,
        "hip_angle_low": 30,
        "hip_angle_high": 110,
        "min_descent_seconds": 0.5,
        "min_ascent_seconds": 0.2,
    },
}

# --- Push-up thresholds ---
# Primary angle: shoulder-elbow-wrist (elbow bend).
# Secondary angle: shoulder-hip-ankle (body alignment / plank straightness).
# Tertiary angle: hip-shoulder-elbow (glenohumeral / upper-arm position).
PUSHUP_THRESHOLDS = {
    "beginner": {
        "active_angle_low": 110,       # enter "down" state when elbow < 100°
        "active_angle_high": 145,      # exit "down" state (rep complete) when elbow > 145°
        "elbow_angle_correct": 90,     # must reach 90° or below at bottom for good depth
        "body_alignment_low": 150,     # shoulder-hip-ankle plank angle range
        "body_alignment_high": 180,
        "shoulder_angle_low": 15,      # hip-shoulder-elbow glenohumeral angle range
        "shoulder_angle_high": 90,
        "min_descent_seconds": 0.3,
        "min_ascent_seconds": 0.25,
    },
    "pro": {
        "active_angle_low": 100,
        "active_angle_high": 145,
        "elbow_angle_correct": 75,
        "body_alignment_low": 155,
        "body_alignment_high": 180,
        "shoulder_angle_low": 15,
        "shoulder_angle_high": 85,
        "min_descent_seconds": 0.4,
        "min_ascent_seconds": 0.25,
    },
}

# --- Deadlift thresholds ---
# Primary angle: shoulder-hip-knee (hip hinge).
# State machine: enter "pulling" when hip < active_angle_low, exit when hip > active_angle_high.
DEADLIFT_THRESHOLDS = {
    "beginner": {
        "active_angle_low": 120,    # enter pulling state
        "active_angle_high": 160,   # exit pulling state (rep complete)
        "hip_angle_correct": 80,    # must hinge to at least this deep at bottom
        "min_descent_seconds": 0.5,
        "min_ascent_seconds": 0.3,
    },
    "pro": {
        "active_angle_low": 110,
        "active_angle_high": 155,
        "hip_angle_correct": 65,
        "min_descent_seconds": 0.6,
        "min_ascent_seconds": 0.4,
    },
}

# --- Bench press thresholds ---
# Primary angle: shoulder-elbow-wrist (elbow bend).
# Secondary angle: shoulder-hip-ankle (body flatness on bench).
# Tertiary angle: hip-shoulder-elbow (elbow flare / glenohumeral position).
BENCH_THRESHOLDS = {
    "beginner": {
        "active_angle_low": 110,       # enter "down" state
        "active_angle_high": 145,      # exit "down" state (rep complete)
        "elbow_angle_correct": 90,     # must lower to 90° or below
        "body_alignment_low": 150,     # shoulder-hip-ankle flat-on-bench range
        "body_alignment_high": 180,
        "shoulder_angle_low": 20,      # hip-shoulder-elbow elbow flare range
        "shoulder_angle_high": 90,
        "min_descent_seconds": 0.4,
        "min_ascent_seconds": 0.3,
    },
    "pro": {
        "active_angle_low": 100,
        "active_angle_high": 145,
        "elbow_angle_correct": 75,
        "body_alignment_low": 155,
        "body_alignment_high": 180,
        "shoulder_angle_low": 15,
        "shoulder_angle_high": 85,
        "min_descent_seconds": 0.5,
        "min_ascent_seconds": 0.35,
    },
}

# --- Rep buffer window thresholds ---
# These control when the trajectory buffer starts/stops capturing frames.
# Separate from the state machine thresholds above.

# Squat buffer
BUFFER_KNEE_START = 165.0   # start buffering when knee angle drops below this
BUFFER_KNEE_END = 170.0     # stop buffering when knee angle rises above this (after rep)

# Push-up buffer
BUFFER_PUSHUP_START = 155.0  # start buffering when elbow angle drops below this
BUFFER_PUSHUP_END = 160.0    # stop buffering when elbow angle rises above this (after rep)

# Deadlift buffer (hip angle drops as they hinge forward)
BUFFER_DEADLIFT_START = 165.0  # start buffering when hip angle drops below this
BUFFER_DEADLIFT_END = 170.0    # stop buffering when hip angle rises above this

# Bench buffer (elbow angle drops as bar descends)
BUFFER_BENCH_START = 155.0   # start buffering when elbow angle drops below this
BUFFER_BENCH_END = 160.0     # stop buffering when elbow angle rises above this

# If buffering for this many seconds without entering the active state, discard.
BUFFER_TIMEOUT_SECONDS = 5.0
