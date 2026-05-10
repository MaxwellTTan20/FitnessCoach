import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'movement_lab_theme.dart';
import 'session_summary.dart';
import 'user_profile.dart';
import 'workout_state.dart';

// --- Config (edit these to change behaviour) ---
const String _kAnthropicKey = '';
const String _kServerUrl = 'http://127.0.0.1:8080';
const String _kProvider = 'claude';
const Duration _kWebCaptureInterval = Duration(milliseconds: 50);

const List<List<int>> _poseConnections = [
  [0, 1],
  [1, 2],
  [2, 3],
  [3, 7],
  [0, 4],
  [4, 5],
  [5, 6],
  [6, 8],
  [11, 12],
  [11, 23],
  [12, 24],
  [23, 24],
  [11, 13],
  [13, 15],
  [15, 17],
  [15, 19],
  [15, 21],
  [12, 14],
  [14, 16],
  [16, 18],
  [16, 20],
  [16, 22],
  [23, 25],
  [25, 27],
  [27, 29],
  [27, 31],
  [24, 26],
  [26, 28],
  [28, 30],
  [28, 32],
];

class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  List<CameraDescription> _cameras = [];
  CameraLensDirection _currentLensDirection = CameraLensDirection.back;
  String? _errorMessage;

  bool _isProcessing = false;
  bool _frameInFlight = false;
  Timer? _webFrameTimer;
  DateTime? _lastFrameLogAt;
  Uint8List? _annotatedImage;
  List<Offset> _poseLandmarks = [];
  Size? _poseFrameSize;
  late final AnimationController _hudController;
  String _liveCue = '';
  int _repPulseToken = 0;
  Map<String, dynamic> _stats = {
    'correct_count': 0,
    'incorrect_count': 0,
    'current_feedback': '',
    'is_in_rep': false,
    'knee_angle': 0.0,
    'hip_angle': 0.0,
    'state': 'standing',
  };
  // Accumulates per-exercise counts across the whole session.
  // Key: exercise name, Value: {correct, incorrect}
  Map<String, Map<String, int>> _sessionExerciseStats = {};
  String _serverUrl = _kServerUrl;
  String _provider = _kProvider;
  String _anthropicKey = _kAnthropicKey;
  String _openAiKey = '';
  String _backendStatus = 'Connecting to backend...';
  String get _selectedExercise =>
      AppProfile.exercises[AppProfile.instance.selectedExerciseIndex];

  @override
  void initState() {
    super.initState();
    _hudController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _loadSavedServerUrl()
        .then((_) => _initializeCamera())
        .then((_) => _autoConfigureBackend());
  }

  Future<void> _loadSavedServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('server_url');
    if (saved != null && saved.isNotEmpty) {
      final oldDefaultUrl =
          saved == 'http://localhost:5000' ||
          saved == 'http://127.0.0.1:5001' ||
          saved == 'http://172.23.31.255:5000' ||
          saved == 'http://172.23.31.255:5001';
      final url = oldDefaultUrl ? _kServerUrl : saved;
      if (url != saved) {
        await prefs.setString('server_url', url);
      }
      setState(() => _serverUrl = url);
    }
  }

  Future<void> _initializeCamera({
    CameraLensDirection direction = CameraLensDirection.back,
  }) async {
    try {
      debugPrint('📷 _initializeCamera: requesting availableCameras()');
      _cameras = await availableCameras();
      debugPrint('📷 availableCameras returned ${_cameras.length} entries');
      if (_cameras.isEmpty) {
        setState(
          () => _errorMessage =
              'No available cameras found. Check System Settings → Privacy & Security → Camera and grant permission to this app.',
        );
        return;
      }

      final selected = _cameras.firstWhere(
        (c) => c.lensDirection == direction,
        orElse: () => _cameras.first,
      );

      await _controller?.dispose();

      _controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.bgra8888,
      );

      _initializeControllerFuture = _controller!.initialize();
      try {
        await _initializeControllerFuture;
      } catch (initErr, st) {
        debugPrint('📷 CameraController.initialize failed: $initErr\n$st');
        setState(
          () => _errorMessage =
              'Unable to initialize the camera. Check permissions and that no other app is using the camera. Error: $initErr',
        );
        return;
      }

      if (mounted) {
        setState(() => _currentLensDirection = selected.lensDirection);
      }
    } catch (e, st) {
      debugPrint('📷 availableCameras() threw: $e\n$st');
      setState(
        () => _errorMessage =
            'Camera initialization failed: $e. Check System Settings → Privacy & Security → Camera and grant access to this app.',
      );
    }
  }

  Future<void> _autoConfigureBackend() async {
    await _configureBackend(
      provider: _provider,
      anthropicKey: _anthropicKey,
      openaiKey: null,
      exercise: _selectedExercise,
    );
  }

  Future<void> _flipCamera() async {
    final newDir = _currentLensDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    final wasProcessing = _isProcessing;
    if (_isProcessing) {
      _webFrameTimer?.cancel();
      _webFrameTimer = null;
      if (!kIsWeb) {
        await _controller?.stopImageStream();
      }
      setState(() {
        _isProcessing = false;
        _frameInFlight = false;
      });
      await Future.delayed(const Duration(milliseconds: 200));
    }

    await _initializeCamera(direction: newDir);

    if (wasProcessing && mounted) {
      setState(() => _isProcessing = true);
      if (kIsWeb) {
        _startWebCaptureLoop();
      } else {
        _controller!.startImageStream(_handleFrame);
      }
    }
  }

  void _startProcessing() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (kIsWeb) {
      setState(() => _isProcessing = true);
      _startWebCaptureLoop();
      return;
    }
    setState(() => _isProcessing = true);
    _controller!.startImageStream(_handleFrame);
  }

  void _startWebCaptureLoop() {
    _webFrameTimer?.cancel();
    _captureWebFrame();
    _webFrameTimer = Timer.periodic(
      _kWebCaptureInterval,
      (_) => _captureWebFrame(),
    );
  }

  // Merges the current live stats into _sessionExerciseStats before a switch or finish.
  void _flushCurrentExerciseStats() {
    final correct = (_stats['correct_count'] as num? ?? 0).toInt();
    final incorrect = (_stats['incorrect_count'] as num? ?? 0).toInt();
    if (correct == 0 && incorrect == 0) return;
    final existing =
        _sessionExerciseStats[_selectedExercise] ??
        {'correct': 0, 'incorrect': 0};
    _sessionExerciseStats[_selectedExercise] = {
      'correct': existing['correct']! + correct,
      'incorrect': existing['incorrect']! + incorrect,
    };
  }

  void _finishSession() {
    _flushCurrentExerciseStats();
    final snapshot = Map<String, Map<String, int>>.from(_sessionExerciseStats);
    _sessionExerciseStats = {};
    WorkoutState.instance.activeWorkout = null;
    if (_isProcessing) _stopProcessing();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionSummaryPage(exerciseStats: snapshot),
      ),
    );
  }

  void _stopProcessing() {
    _webFrameTimer?.cancel();
    _webFrameTimer = null;
    if (!kIsWeb) {
      _controller?.stopImageStream();
    }
    setState(() {
      _isProcessing = false;
      _frameInFlight = false;
      _annotatedImage = null;
      _poseLandmarks = [];
      _poseFrameSize = null;
      _liveCue = '';
      _stats = {
        'correct_count': 0,
        'incorrect_count': 0,
        'current_feedback': '',
        'is_in_rep': false,
        'state': 'standing',
      };
    });
    http.post(Uri.parse('$_serverUrl/reset')).ignore();
  }

  Uint8List _encodeFrame(CameraImage cameraImage) {
    final plane = cameraImage.planes[0];
    final width = cameraImage.width;
    final height = cameraImage.height;
    final stride = plane.bytesPerRow;

    // Always copy row-by-row into a fresh buffer.
    // plane.bytes can be a slice of a larger ByteBuffer, so plane.bytes.buffer
    // starts at the wrong offset and corrupts colors. This guarantees offset 0.
    final clean = Uint8List(width * height * 4);
    for (var y = 0; y < height; y++) {
      clean.setRange(
        y * width * 4,
        (y + 1) * width * 4,
        plane.bytes,
        y * stride,
      );
    }

    var image = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: clean.buffer,
      numChannels: 4,
      order: img.ChannelOrder.bgra,
    );

    // The stream delivers 480×640 (already portrait) — only rotate if landscape.
    if (image.width > image.height) {
      image = img.copyRotate(image, angle: -90);
    }
    if (_currentLensDirection == CameraLensDirection.front) {
      image = img.flipHorizontal(image);
    }

    image = img.copyResize(image, width: 320);
    return img.encodeJpg(image, quality: 60);
  }

  bool _didLogFormat = false;
  void _handleFrame(CameraImage cameraImage) {
    if (!_didLogFormat) {
      _didLogFormat = true;
      debugPrint(
        '📷 format=${cameraImage.format.group} '
        'size=${cameraImage.width}x${cameraImage.height} '
        'stride=${cameraImage.planes[0].bytesPerRow} '
        'planes=${cameraImage.planes.length}',
      );
    }
    if (_frameInFlight || !_isProcessing || !mounted) return;
    _frameInFlight = true;
    _processFrame(cameraImage).whenComplete(() {
      if (mounted) _frameInFlight = false;
    });
  }

  Future<void> _processFrame(CameraImage cameraImage) async {
    try {
      final jpegBytes = _encodeFrame(cameraImage);

      if (!mounted || !_isProcessing) return;

      await _sendJpegFrame(jpegBytes);
    } catch (_) {
      // Network errors; keep the stream going.
    }
  }

  Future<void> _captureWebFrame() async {
    if (_frameInFlight || !_isProcessing || !mounted || _controller == null) {
      return;
    }
    _frameInFlight = true;
    final frameStartedAt = DateTime.now();
    try {
      final file = await _controller!.takePicture();
      final captureMs = DateTime.now()
          .difference(frameStartedAt)
          .inMilliseconds;
      final bytes = await file.readAsBytes();
      final readMs =
          DateTime.now().difference(frameStartedAt).inMilliseconds - captureMs;
      if (!mounted || !_isProcessing) return;
      final networkStartedAt = DateTime.now();
      await _sendJpegFrame(bytes);
      final totalMs = DateTime.now().difference(frameStartedAt).inMilliseconds;
      final networkMs = DateTime.now()
          .difference(networkStartedAt)
          .inMilliseconds;
      _logFrameTiming(
        'web capture=${captureMs}ms read=${readMs}ms '
        'network=${networkMs}ms total=${totalMs}ms',
      );
    } catch (e) {
      if (mounted && _isProcessing) {
        setState(() {
          _backendStatus = 'Frame capture failed: $e';
        });
      }
    } finally {
      if (mounted) _frameInFlight = false;
    }
  }

  void _logFrameTiming(String message) {
    final now = DateTime.now();
    final last = _lastFrameLogAt;
    if (last != null && now.difference(last).inSeconds < 2) return;
    _lastFrameLogAt = now;
    debugPrint('📷 frame timing: $message');
  }

  Future<void> _sendJpegFrame(Uint8List jpegBytes) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_serverUrl/process_frame'),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: jsonEncode({
              'image': base64Encode(jpegBytes),
              'include_annotated': !kIsWeb,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (!mounted || !_isProcessing) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final annotatedImage = data['annotated_image'];
        final newStats = data['stats'] as Map<String, dynamic>;
        final landmarksJson = (data['landmarks'] as List<dynamic>?) ?? [];
        final aiFeedback = (data['ai_feedback'] as String?) ?? '';
        final frameWidth = (data['frame_width'] as num?)?.toDouble();
        final frameHeight = (data['frame_height'] as num?)?.toDouble();

        final landmarks = landmarksJson.map<Offset>((raw) {
          final lm = raw as Map<String, dynamic>;
          return Offset(
            (lm['x'] as num).toDouble(),
            (lm['y'] as num).toDouble(),
          );
        }).toList();

        if (mounted) {
          setState(() {
            if (annotatedImage is String) {
              _annotatedImage = base64Decode(annotatedImage);
            }
            final previousTotal =
                (_stats['correct_count'] as num? ?? 0).toInt() +
                (_stats['incorrect_count'] as num? ?? 0).toInt();
            final nextTotal =
                (newStats['correct_count'] as num? ?? 0).toInt() +
                (newStats['incorrect_count'] as num? ?? 0).toInt();
            if (nextTotal > previousTotal) {
              _repPulseToken++;
            }
            _stats = newStats;
            _poseLandmarks = landmarks;
            _poseFrameSize = frameWidth != null && frameHeight != null
                ? Size(frameWidth, frameHeight)
                : null;
            final statsCue = (newStats['current_feedback'] as String?) ?? '';
            if (aiFeedback.isNotEmpty) {
              _liveCue = aiFeedback;
            } else if (statsCue.isNotEmpty) {
              _liveCue = statsCue;
            }
          });
        }

        if (aiFeedback.isNotEmpty) {
          final preview = aiFeedback.length > 50
              ? '${aiFeedback.substring(0, 50)}...'
              : aiFeedback;
          debugPrint('📷 AI Feedback received: $preview');
        }
      } else {
        setState(() {
          _backendStatus = 'Frame analysis failed: ${response.statusCode}';
        });
      }
    } catch (e) {
      if (mounted && _isProcessing) {
        setState(() {
          _backendStatus =
              'Frame analysis unreachable — check backend URL and port';
        });
      }
      // Network errors; keep the stream going.
    }
  }

  Future<void> _configureBackend({
    String? provider,
    String? anthropicKey,
    String? openaiKey,
    String? exercise,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_serverUrl/configure'),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: jsonEncode({
              'provider': provider,
              'anthropic_key': anthropicKey,
              'openai_key': openaiKey,
              'exercise': exercise ?? _selectedExercise,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _backendStatus = data['provider'] != null
              ? 'AI: ${data['provider']} + backend voice'
              : 'Backend connected (no AI provider)';
        });
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _backendStatus =
              'Config failed: ${data['error'] ?? response.reasonPhrase}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _backendStatus =
              'Backend unreachable — set your server IP in settings';
        });
      }
    }
  }

  void _showBackendConfig() {
    final serverCtrl = TextEditingController(text: _serverUrl);
    final providerCtrl = TextEditingController(text: _provider);
    final anthropicCtrl = TextEditingController(text: _anthropicKey);
    final openAiCtrl = TextEditingController(text: _openAiKey);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MovementLabColors.porcelain,
      shape: const RoundedRectangleBorder(),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Backend configuration',
                style: TextStyle(
                  color: MovementLabColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'On a real phone use your Mac\'s local IP (e.g. http://192.168.1.x:8080)',
                style: TextStyle(color: MovementLabColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              _configField(serverCtrl, 'Server URL', 'http://192.168.1.x:8080'),
              _configField(providerCtrl, 'AI provider', 'claude or openai'),
              _configField(anthropicCtrl, 'Anthropic API key', ''),
              _configField(openAiCtrl, 'OpenAI API key', ''),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  final url = serverCtrl.text.trim().isEmpty
                      ? _kServerUrl
                      : serverCtrl.text.trim();
                  setState(() {
                    _serverUrl = url;
                    _provider = providerCtrl.text.trim();
                    _anthropicKey = anthropicCtrl.text.trim();
                    _openAiKey = openAiCtrl.text.trim();
                  });
                  SharedPreferences.getInstance().then(
                    (p) => p.setString('server_url', url),
                  );
                  _configureBackend(
                    provider: _provider.isEmpty ? null : _provider,
                    anthropicKey: _anthropicKey.isEmpty ? null : _anthropicKey,
                    openaiKey: _openAiKey.isEmpty ? null : _openAiKey,
                  );
                  Navigator.of(ctx).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: MovementLabColors.graphite,
                  foregroundColor: MovementLabColors.white,
                  shape: const RoundedRectangleBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(double.infinity, 0),
                ),
                child: const Text('Save & connect'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _configField(TextEditingController ctrl, String label, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: MovementLabColors.ink),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: MovementLabColors.muted),
          hintStyle: const TextStyle(color: MovementLabColors.muted),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _webFrameTimer?.cancel();
    _hudController.dispose();
    if (_isProcessing && !kIsWeb) {
      _controller?.stopImageStream();
    }
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmall = screenSize.width < 400;

    return Scaffold(
      backgroundColor: MovementLabColors.porcelain,
      appBar: AppBar(
        title: const Text('Movement capture'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showBackendConfig,
            tooltip: 'Backend settings',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isSmall ? 12.0 : 18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: AppProfile.exercises.asMap().entries.map((entry) {
                    final i = entry.key;
                    final exercise = entry.value;
                    final selected = _selectedExercise == exercise;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          _flushCurrentExerciseStats();
                          AppProfile.instance.setExercise(i).ignore();
                          setState(() {
                            _stats = {
                              'correct_count': 0,
                              'incorrect_count': 0,
                              'current_feedback': '',
                              'is_in_rep': false,
                              'state': 'standing',
                            };
                          });
                          _configureBackend(
                            provider: _provider,
                            anthropicKey: _anthropicKey.isEmpty
                                ? null
                                : _anthropicKey,
                            openaiKey: _openAiKey.isEmpty ? null : _openAiKey,
                            exercise: AppProfile.exercises[i],
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmall ? 14 : 18,
                            vertical: isSmall ? 8 : 10,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? MovementLabColors.tealSoft
                                : MovementLabColors.white,
                            border: Border.all(
                              color: selected
                                  ? MovementLabColors.trackTeal
                                  : MovementLabColors.lineStrong,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            exercise,
                            style: TextStyle(
                              color: selected
                                  ? MovementLabColors.trackTeal
                                  : MovementLabColors.muted,
                              fontSize: isSmall ? 13 : 14,
                              fontWeight: selected
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _backendStatus.startsWith('AI:')
                          ? MovementLabColors.correct
                          : MovementLabColors.tempo,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _backendStatus,
                      style: TextStyle(
                        color: MovementLabColors.muted,
                        fontSize: isSmall ? 11 : 13,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isSmall ? 10 : 14),
              Expanded(
                child: AnimatedBuilder(
                  animation: _hudController,
                  builder: (context, _) {
                    final isInRep = _stats['is_in_rep'] as bool? ?? false;
                    final borderColor = isInRep
                        ? MovementLabColors.correct
                        : _isProcessing
                        ? MovementLabColors.trackTeal
                        : MovementLabColors.graphite;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      decoration: BoxDecoration(
                        color: MovementLabColors.paper,
                        border: Border.all(color: borderColor, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: borderColor.withValues(alpha: 0.18),
                            blurRadius: _isProcessing ? 30 : 20,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildMainDisplay(),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _CaptureHudPainter(
                                    progress: _hudController.value,
                                    isProcessing: _isProcessing,
                                    isInRep: isInRep,
                                  ),
                                ),
                              ),
                            ),
                            if (_poseLandmarks.isNotEmpty)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _PosePainter(
                                    poseLandmarks: _poseLandmarks,
                                    sourceSize: _poseFrameSize,
                                  ),
                                ),
                              ),
                            Positioned(
                              left: isSmall ? 12 : 20,
                              top: isSmall ? 12 : 20,
                              child: _LiveStatusBadge(
                                isProcessing: _isProcessing,
                                isInRep: isInRep,
                              ),
                            ),
                            Positioned(
                              right: isSmall ? 12 : 20,
                              top: isSmall ? 12 : 20,
                              child: _PhaseBadge(
                                isInRep: isInRep,
                                label: isInRep ? 'IN REP' : 'READY',
                              ),
                            ),
                            Positioned(
                              left: isSmall ? 12 : 20,
                              bottom: isSmall ? 12 : 20,
                              child: _RepScoreboard(
                                correct: (_stats['correct_count'] as num? ?? 0)
                                    .toInt(),
                                incorrect:
                                    (_stats['incorrect_count'] as num? ?? 0)
                                        .toInt(),
                                pulseToken: _repPulseToken,
                                isSmall: isSmall,
                              ),
                            ),
                            Positioned(
                              right: isSmall ? 12 : 20,
                              bottom: isSmall ? 12 : 20,
                              child: _HudIconButton(
                                icon: Icons.flip_camera_ios,
                                onTap: _flipCamera,
                                tooltip: 'Flip camera',
                              ),
                            ),
                            Positioned(
                              left: isSmall ? 12 : 20,
                              right: isSmall ? 12 : 20,
                              bottom: isSmall ? 76 : 84,
                              child: _CueToast(
                                cue: _liveCue,
                                isActive: _isProcessing,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: isSmall ? 10 : 14),
              // ── Stats row ────────────────────────────────────────────
              Row(
                children: [
                  ..._buildAngleChips(),
                  if ((_stats['current_feedback'] as String?)?.isNotEmpty ==
                      true) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _stats['current_feedback'] as String,
                        style: TextStyle(
                          color: MovementLabColors.trackTeal,
                          fontSize: isSmall ? 12 : 13,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: isSmall ? 10 : 12),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _finishSession,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MovementLabColors.correction,
                      foregroundColor: MovementLabColors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmall ? 20 : 28,
                        vertical: isSmall ? 12 : 14,
                      ),
                      shape: const RoundedRectangleBorder(),
                    ),
                    child: Text('Finish Session'),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _isProcessing
                        ? _stopProcessing
                        : _startProcessing,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isProcessing
                          ? MovementLabColors.correction
                          : MovementLabColors.correct,
                      foregroundColor: MovementLabColors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmall ? 20 : 28,
                        vertical: isSmall ? 12 : 14,
                      ),
                      shape: const RoundedRectangleBorder(),
                    ),
                    child: Text(
                      _isProcessing ? 'Stop' : 'Start',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _angleDisplay(String key) {
    final val = _stats[key] as num?;
    if (val == null || val == 0) return '—';
    return '${val.toStringAsFixed(0)}°';
  }

  List<Widget> _buildAngleChips() {
    final isInRep = _stats['is_in_rep'] as bool? ?? false;
    final state = (_stats['state'] as String?) ?? '';
    const gap = SizedBox(width: 8);

    if (_selectedExercise == 'Push-up') {
      return [
        _StatChip(label: 'Elbow', value: _angleDisplay('elbow_angle')),
        gap,
        _StatChip(label: 'Body', value: _angleDisplay('body_angle')),
        gap,
        _StatChip(
          label: 'State',
          value: state.isEmpty ? 'up' : state,
          highlight: isInRep,
        ),
      ];
    }

    // Squat (default)
    return [
      _StatChip(label: 'Knee', value: _angleDisplay('knee_angle')),
      gap,
      _StatChip(label: 'Hip', value: _angleDisplay('hip_angle')),
      gap,
      _StatChip(
        label: 'State',
        value: state.isEmpty ? 'standing' : state,
        highlight: isInRep,
      ),
    ];
  }

  Widget _buildMainDisplay() {
    if (kIsWeb) {
      return _buildCameraPreview();
    }

    if (_isProcessing && _annotatedImage != null) {
      final annotated = Image.memory(
        _annotatedImage!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
        child: annotated,
      );
    }

    return _buildCameraPreview();
  }

  Widget _buildCameraPreview() {
    if (_initializeControllerFuture != null) {
      return FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.done &&
              _controller != null &&
              _controller!.value.isInitialized) {
            return CameraPreview(_controller!);
          }
          if (snap.hasError || _errorMessage != null) {
            return _buildErrorState();
          }
          return const Center(
            child: CircularProgressIndicator(
              color: MovementLabColors.trackTeal,
            ),
          );
        },
      );
    }

    return const Center(
      child: CircularProgressIndicator(color: MovementLabColors.trackTeal),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: MovementLabColors.correction,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Unable to access the camera.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MovementLabColors.graphite,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _StatChip({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight ? MovementLabColors.tealSoft : MovementLabColors.white,
        border: Border.all(
          color: highlight
              ? MovementLabColors.trackTeal
              : MovementLabColors.lineStrong,
        ),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label  ',
              style: const TextStyle(
                color: MovementLabColors.muted,
                fontSize: 11,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: highlight
                    ? MovementLabColors.trackTeal
                    : MovementLabColors.graphite,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveStatusBadge extends StatelessWidget {
  final bool isProcessing;
  final bool isInRep;

  const _LiveStatusBadge({required this.isProcessing, required this.isInRep});

  @override
  Widget build(BuildContext context) {
    final label = isInRep
        ? 'Tracking rep'
        : isProcessing
        ? 'Analyzing'
        : 'Live feed';
    final icon = isInRep
        ? Icons.bolt
        : isProcessing
        ? Icons.sensors
        : Icons.videocam_outlined;
    final accent = isInRep
        ? MovementLabColors.correct
        : isProcessing
        ? MovementLabColors.trackTeal
        : MovementLabColors.graphite;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: MovementLabColors.white.withValues(alpha: 0.94),
        border: Border.all(color: accent, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingDot(color: accent, active: isProcessing),
          const SizedBox(width: 8),
          Icon(icon, color: accent, size: 16),
          const SizedBox(width: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Text(
              label,
              key: ValueKey(label),
              style: const TextStyle(
                color: MovementLabColors.graphite,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatelessWidget {
  final Color color;
  final bool active;

  const _PulsingDot({required this.color, required this.active});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: active ? 1 : 0),
      duration: const Duration(milliseconds: 360),
      builder: (context, value, child) {
        return Container(
          width: 8 + (value * 3),
          height: 8 + (value * 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: active ? 0.95 : 0.45),
            boxShadow: [
              if (active)
                BoxShadow(
                  color: color.withValues(alpha: 0.42),
                  blurRadius: 12,
                  spreadRadius: 1 + value,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PhaseBadge extends StatelessWidget {
  final bool isInRep;
  final String label;

  const _PhaseBadge({required this.isInRep, required this.label});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isInRep
            ? MovementLabColors.correctSoft.withValues(alpha: 0.96)
            : MovementLabColors.white.withValues(alpha: 0.94),
        border: Border.all(
          color: isInRep
              ? MovementLabColors.correct
              : MovementLabColors.lineStrong,
          width: isInRep ? 1.5 : 1,
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        child: Text(
          label,
          key: ValueKey(label),
          style: TextStyle(
            color: isInRep
                ? MovementLabColors.correct
                : MovementLabColors.graphite,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _RepScoreboard extends StatelessWidget {
  final int correct;
  final int incorrect;
  final int pulseToken;
  final bool isSmall;

  const _RepScoreboard({
    required this.correct,
    required this.incorrect,
    required this.pulseToken,
    required this.isSmall,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(pulseToken),
      tween: Tween(begin: 1.08, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          alignment: Alignment.bottomLeft,
          child: child,
        );
      },
      child: Container(
        padding: EdgeInsets.all(isSmall ? 8 : 10),
        decoration: BoxDecoration(
          color: MovementLabColors.white.withValues(alpha: 0.94),
          border: Border.all(color: MovementLabColors.graphite),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ScoreCell(
              icon: Icons.check,
              value: correct,
              color: MovementLabColors.correct,
              isSmall: isSmall,
            ),
            Container(
              width: 1,
              height: isSmall ? 24 : 30,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: MovementLabColors.line,
            ),
            _ScoreCell(
              icon: Icons.close,
              value: incorrect,
              color: MovementLabColors.correction,
              isSmall: isSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreCell extends StatelessWidget {
  final IconData icon;
  final int value;
  final Color color;
  final bool isSmall;

  const _ScoreCell({
    required this.icon,
    required this.value,
    required this.color,
    required this.isSmall,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: isSmall ? 16 : 18),
        const SizedBox(width: 5),
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: isSmall ? 18 : 22,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _HudIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _HudIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: MovementLabColors.white.withValues(alpha: 0.94),
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              border: Border.all(color: MovementLabColors.graphite),
            ),
            child: Icon(icon, color: MovementLabColors.graphite, size: 22),
          ),
        ),
      ),
    );
  }
}

class _CueToast extends StatelessWidget {
  final String cue;
  final bool isActive;

  const _CueToast({required this.cue, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final visible = isActive && cue.trim().isNotEmpty;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.16),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: visible
          ? Center(
              key: ValueKey(cue),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 340),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: MovementLabColors.graphite.withValues(alpha: 0.92),
                  border: Border.all(color: MovementLabColors.white, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.graphic_eq,
                      color: MovementLabColors.tempo,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        cue,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: MovementLabColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(key: ValueKey('empty-cue')),
    );
  }
}

class _CaptureHudPainter extends CustomPainter {
  final double progress;
  final bool isProcessing;
  final bool isInRep;

  const _CaptureHudPainter({
    required this.progress,
    required this.isProcessing,
    required this.isInRep,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final accent = isInRep
        ? MovementLabColors.correct
        : isProcessing
        ? MovementLabColors.trackTeal
        : MovementLabColors.lineStrong;
    final linePaint = Paint()
      ..color = accent.withValues(alpha: isProcessing ? 0.42 : 0.24)
      ..strokeWidth = 1;
    final strongPaint = Paint()
      ..color = accent.withValues(alpha: isProcessing ? 0.86 : 0.5)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.square;

    const corner = 30.0;
    const inset = 12.0;
    final right = size.width - inset;
    final bottom = size.height - inset;

    canvas.drawLine(
      const Offset(inset, inset),
      const Offset(inset + corner, inset),
      strongPaint,
    );
    canvas.drawLine(
      const Offset(inset, inset),
      const Offset(inset, inset + corner),
      strongPaint,
    );
    canvas.drawLine(
      Offset(right, inset),
      Offset(right - corner, inset),
      strongPaint,
    );
    canvas.drawLine(
      Offset(right, inset),
      Offset(right, inset + corner),
      strongPaint,
    );
    canvas.drawLine(
      Offset(inset, bottom),
      Offset(inset + corner, bottom),
      strongPaint,
    );
    canvas.drawLine(
      Offset(inset, bottom),
      Offset(inset, bottom - corner),
      strongPaint,
    );
    canvas.drawLine(
      Offset(right, bottom),
      Offset(right - corner, bottom),
      strongPaint,
    );
    canvas.drawLine(
      Offset(right, bottom),
      Offset(right, bottom - corner),
      strongPaint,
    );

    for (double x = inset + 18; x < right; x += 28) {
      canvas.drawLine(Offset(x, inset), Offset(x, inset + 7), linePaint);
      canvas.drawLine(Offset(x, bottom), Offset(x, bottom - 7), linePaint);
    }
    for (double y = inset + 18; y < bottom; y += 28) {
      canvas.drawLine(Offset(inset, y), Offset(inset + 7, y), linePaint);
      canvas.drawLine(Offset(right, y), Offset(right - 7, y), linePaint);
    }

    if (!isProcessing) return;

    final scanY = inset + ((bottom - inset) * progress);
    final scanPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          accent.withValues(alpha: 0),
          accent.withValues(alpha: 0.45),
          accent.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(inset, scanY - 20, right - inset, 40));
    canvas.drawRect(
      Rect.fromLTWH(inset, scanY - 20, right - inset, 40),
      scanPaint,
    );
    canvas.drawLine(Offset(inset, scanY), Offset(right, scanY), strongPaint);
  }

  @override
  bool shouldRepaint(covariant _CaptureHudPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.isProcessing != isProcessing ||
      oldDelegate.isInRep != isInRep;
}

class _PosePainter extends CustomPainter {
  final List<Offset> poseLandmarks;
  final Size? sourceSize;

  const _PosePainter({required this.poseLandmarks, required this.sourceSize});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = MovementLabColors.trackTeal.withValues(alpha: 0.88)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = MovementLabColors.correction.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;

    Offset mapLandmark(Offset landmark) {
      final source = sourceSize;
      if (source == null || source.width <= 0 || source.height <= 0) {
        return Offset(landmark.dx * size.width, landmark.dy * size.height);
      }

      final sourceAspect = source.width / source.height;
      final targetAspect = size.width / size.height;
      if (sourceAspect > targetAspect) {
        final fittedWidth = size.height * sourceAspect;
        final left = (size.width - fittedWidth) / 2;
        return Offset(
          left + landmark.dx * fittedWidth,
          landmark.dy * size.height,
        );
      }

      final fittedHeight = size.width / sourceAspect;
      final top = (size.height - fittedHeight) / 2;
      return Offset(landmark.dx * size.width, top + landmark.dy * fittedHeight);
    }

    for (final conn in _poseConnections) {
      final si = conn[0];
      final ei = conn[1];
      if (si < poseLandmarks.length && ei < poseLandmarks.length) {
        canvas.drawLine(
          mapLandmark(poseLandmarks[si]),
          mapLandmark(poseLandmarks[ei]),
          linePaint,
        );
      }
    }

    for (final lm in poseLandmarks) {
      canvas.drawCircle(mapLandmark(lm), 5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PosePainter old) =>
      old.poseLandmarks != poseLandmarks || old.sourceSize != sourceSize;
}
