import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'user_profile.dart';

const _kFeedsPerCharacter = 10; // feeds to advance one character
const _kTotalCharacters = 10; // capybara_1 … capybara_10
const _kGoldenStart = _kFeedsPerCharacter * (_kTotalCharacters - 1); // 450
const _kFullyGolden = 777;

enum _CapyState { idle, mouthOpen, chewing }

class CapybaraCard extends StatefulWidget {
  const CapybaraCard({super.key});

  @override
  State<CapybaraCard> createState() => _CapybaraCardState();
}

class _CapybaraCardState extends State<CapybaraCard> {
  _CapyState _capyState = _CapyState.idle;
  int _chewFrame = 0; // 0=C3, 1=C4, 2=C5
  int _chewRepeat = 0;
  Timer? _chewTimer;

  final _hearts = <_HeartData>[];
  int _nextHeartId = 0;
  final _rng = math.Random();

  // Read live from AppProfile so updates from sessions reflect immediately.
  int get _grassBalance => AppProfile.instance.grassBalance;
  int get _feedCount => AppProfile.instance.capybaraFeedCount;

  int get _characterNum =>
      (_feedCount ~/ _kFeedsPerCharacter).clamp(0, _kTotalCharacters - 1) + 1;
  int get _xpInLevel => _feedCount % _kFeedsPerCharacter;
  double get _goldenIntensity => _feedCount < _kGoldenStart
      ? 0.0
      : ((_feedCount - _kGoldenStart) / (_kFullyGolden - _kGoldenStart)).clamp(
          0.0,
          1.0,
        );
  bool get _isGolden => _feedCount >= _kGoldenStart;
  double get _levelProgress =>
      _isGolden ? _goldenIntensity : _xpInLevel / _kFeedsPerCharacter;

  @override
  void dispose() {
    _chewTimer?.cancel();
    super.dispose();
  }

  // ── Capybara image ────────────────────────────────────────────────────────

  String get _capyImage {
    switch (_capyState) {
      case _CapyState.idle:
        return 'lib/images/capybaras/capybara_$_characterNum/C1.png';
      case _CapyState.mouthOpen:
        return 'lib/images/capybaras/capybara_$_characterNum/C2.png';
      case _CapyState.chewing:
        return 'lib/images/capybaras/capybara_$_characterNum/C${3 + _chewFrame}.png';
    }
  }

  // ── Drag handlers ─────────────────────────────────────────────────────────

  void _onDragStart() {
    if (_capyState == _CapyState.idle) {
      setState(() => _capyState = _CapyState.mouthOpen);
    }
  }

  void _onDragCancelled() {
    if (_capyState == _CapyState.mouthOpen) {
      setState(() => _capyState = _CapyState.idle);
    }
  }

  // ── Feeding ───────────────────────────────────────────────────────────────

  void _onFeed() {
    if (_grassBalance <= 0 || _capyState == _CapyState.chewing) return;
    AppProfile.instance.grassBalance--;
    AppProfile.instance.capybaraFeedCount++;
    setState(() {
      _capyState = _CapyState.chewing;
      _chewFrame = 0;
      _chewRepeat = 0;
    });
    _spawnHearts();
    _scheduleChew();
    AppProfile.instance.saveCapybara().ignore();
  }

  void _scheduleChew() {
    _chewTimer?.cancel();
    _chewTimer = Timer(const Duration(milliseconds: 360), _advanceChew);
  }

  void _advanceChew() {
    if (!mounted) return;
    setState(() {
      _chewFrame++;
      if (_chewFrame >= 3) {
        _chewFrame = 0;
        _chewRepeat++;
      }
    });
    if (_chewRepeat < 2) {
      _scheduleChew();
    } else {
      setState(() => _capyState = _CapyState.idle);
    }
  }

  // ── Hearts ────────────────────────────────────────────────────────────────

  void _spawnHearts() {
    final count = 5 + _rng.nextInt(3);
    for (int i = 0; i < count; i++) {
      final id = _nextHeartId++;
      setState(() {
        _hearts.add(
          _HeartData(
            id: id,
            dx: (_rng.nextDouble() - 0.5) * 64,
            delay: Duration(milliseconds: i * 90),
          ),
        );
      });
    }
  }

  void _removeHeart(int id) {
    if (mounted) setState(() => _hearts.removeWhere((h) => h.id == id));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final canDrag = _grassBalance > 0 && _capyState == _CapyState.idle;

    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Background
            Positioned.fill(
              child: Image.asset(
                'lib/images/capybaras/background.jpg',
                fit: BoxFit.cover,
              ),
            ),
            // Gradient overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.30),
                      Colors.black.withValues(alpha: 0.10),
                      Colors.black.withValues(alpha: 0.50),
                    ],
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ─────────────────────────────────────────────
                  Row(
                    children: [
                      const Text(
                        'Feed Your Capybara',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          shadows: [
                            Shadow(blurRadius: 6, color: Colors.black54),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _isGolden
                              ? Color.lerp(
                                  Colors.amber,
                                  const Color(0xFFFFD700),
                                  _goldenIntensity,
                                )!
                              : Colors.amber.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _feedCount >= _kFullyGolden
                              ? '⭐ MAX'
                              : 'Lv. $_characterNum',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // ── Interactive area ────────────────────────────────────
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Capybara (DragTarget)
                        Expanded(
                          flex: 3,
                          child: DragTarget<bool>(
                            onAcceptWithDetails: (_) => _onFeed(),
                            builder: (_, candidateData, _) {
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  Builder(
                                    builder: (_) {
                                      final intensity = _goldenIntensity;
                                      Widget img = AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 60,
                                        ),
                                        child: Image.asset(
                                          _capyImage,
                                          key: ValueKey(_capyImage),
                                          height: 140,
                                          fit: BoxFit.contain,
                                        ),
                                      );
                                      if (intensity > 0) {
                                        img = ColorFiltered(
                                          colorFilter: ColorFilter.mode(
                                            Color.lerp(
                                              Colors.white,
                                              const Color(0xFFFFD700),
                                              intensity,
                                            )!,
                                            BlendMode.modulate,
                                          ),
                                          child: img,
                                        );
                                      }
                                      return img;
                                    },
                                  ),
                                  if (candidateData.isNotEmpty)
                                    Positioned.fill(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: Colors.greenAccent
                                                .withValues(alpha: 0.7),
                                            width: 2.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ..._hearts.map(
                                    (h) => _HeartWidget(
                                      key: ValueKey(h.id),
                                      dx: h.dx,
                                      delay: h.delay,
                                      onDone: () => _removeHeart(h.id),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Grass pot column
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Grass counter
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '🌿',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '×$_grassBalance',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Draggable pot
                            if (canDrag)
                              Draggable<bool>(
                                data: true,
                                onDragStarted: _onDragStart,
                                onDraggableCanceled: (_, _) =>
                                    _onDragCancelled(),
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: Image.asset(
                                    'lib/images/capybaras/grass.png',
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: 0.35,
                                  child: Image.asset(
                                    'lib/images/capybaras/grass_pot.png',
                                    height: 78,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                child: Image.asset(
                                  'lib/images/capybaras/grass_pot.png',
                                  height: 78,
                                  fit: BoxFit.contain,
                                ),
                              )
                            else
                              Opacity(
                                opacity: 0.4,
                                child: Image.asset(
                                  'lib/images/capybaras/grass_pot.png',
                                  height: 78,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            if (_grassBalance == 0)
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  'Do reps to\nearn 🌿',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 9,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // ── Progress bar ────────────────────────────────────────
                  Row(
                    children: [
                      Text(
                        _isGolden ? '⭐' : 'Lv.$_characterNum',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _levelProgress,
                            backgroundColor: Colors.white24,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _isGolden
                                  ? Color.lerp(
                                      Colors.amber,
                                      const Color(0xFFFFD700),
                                      _goldenIntensity,
                                    )!
                                  : Colors.amber,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isGolden
                            ? '$_feedCount / $_kFullyGolden feeds'
                            : '$_xpInLevel / $_kFeedsPerCharacter feeds',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Heart data ────────────────────────────────────────────────────────────────

class _HeartData {
  final int id;
  final double dx;
  final Duration delay;
  const _HeartData({required this.id, required this.dx, required this.delay});
}

// ── Floating heart widget ─────────────────────────────────────────────────────

class _HeartWidget extends StatefulWidget {
  final double dx;
  final Duration delay;
  final VoidCallback onDone;
  const _HeartWidget({
    required this.dx,
    required this.delay,
    required this.onDone,
    super.key,
  });

  @override
  State<_HeartWidget> createState() => _HeartWidgetState();
}

class _HeartWidgetState extends State<_HeartWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _dy;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 35),
    ]).animate(_ctrl);
    _dy = Tween<double>(
      begin: 0.0,
      end: -88.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward().whenComplete(widget.onDone);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Transform.translate(
        offset: Offset(widget.dx, _dy.value),
        child: Opacity(
          opacity: _opacity.value.clamp(0.0, 1.0),
          child: const Text('❤️', style: TextStyle(fontSize: 22)),
        ),
      ),
    );
  }
}
