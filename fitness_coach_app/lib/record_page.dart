import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'session_summary.dart';
import 'user_profile.dart';

// --- Config (edit these to change behaviour) ---
const String _kAnthropicKey =
    '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';
const String _kElevenLabsKey =
    'sk_906b72eb783432101589d45a07007c281af45967b331a44b';
// Arnold voice ID (free tier). To change: pick another ID from backend/voice.py VOICES dict.
const String _kElevenLabsVoiceId = 'VR6AewLTigWG4xSOukaG';
const String _kServerUrl = 'http://localhost:5000'; // change to your Mac's IP when on a real device
const String _kProvider = 'claude';

const List<List<int>> _poseConnections = [
  [0, 1], [1, 2], [2, 3], [3, 7],
  [0, 4], [4, 5], [5, 6], [6, 8],
  [11, 12], [11, 23], [12, 24], [23, 24],
  [11, 13], [13, 15], [15, 17], [15, 19], [15, 21],
  [12, 14], [14, 16], [16, 18], [16, 20], [16, 22],
  [23, 25], [25, 27], [27, 29], [27, 31],
  [24, 26], [26, 28], [28, 30], [28, 32],
];

class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  List<CameraDescription> _cameras = [];
  CameraLensDirection _currentLensDirection = CameraLensDirection.back;
  String? _errorMessage;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isSpeaking = false;

  bool _isProcessing = false;
  bool _frameInFlight = false;
  Uint8List? _annotatedImage;
  List<Offset> _poseLandmarks = [];
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
  String get _selectedExercise => AppProfile.exercises[AppProfile.instance.selectedExerciseIndex];

  @override
  void initState() {
    super.initState();
    AudioPlayer.global.setAudioContext(AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {AVAudioSessionOptions.mixWithOthers},
      ),
    ));
    _loadSavedServerUrl().then((_) => _initializeCamera()).then((_) => _autoConfigureBackend());
  }

  Future<void> _loadSavedServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('server_url');
    if (saved != null && saved.isNotEmpty) {
      setState(() => _serverUrl = saved);
    }
  }

  Future<void> _initializeCamera({
    CameraLensDirection direction = CameraLensDirection.back,
  }) async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _errorMessage = 'No available cameras found.');
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
      await _initializeControllerFuture;

      if (mounted) {
        setState(() => _currentLensDirection = selected.lensDirection);
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
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
      await _controller?.stopImageStream();
      setState(() {
        _isProcessing = false;
        _frameInFlight = false;
      });
      await Future.delayed(const Duration(milliseconds: 200));
    }

    await _initializeCamera(direction: newDir);

    if (wasProcessing && mounted) {
      setState(() => _isProcessing = true);
      _controller!.startImageStream(_handleFrame);
    }
  }

  void _startProcessing() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() => _isProcessing = true);
    _controller!.startImageStream(_handleFrame);
  }

  // Merges the current live stats into _sessionExerciseStats before a switch or finish.
  void _flushCurrentExerciseStats() {
    final correct = (_stats['correct_count'] as num? ?? 0).toInt();
    final incorrect = (_stats['incorrect_count'] as num? ?? 0).toInt();
    if (correct == 0 && incorrect == 0) return;
    final existing = _sessionExerciseStats[_selectedExercise] ??
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
    if (_isProcessing) _stopProcessing();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionSummaryPage(exerciseStats: snapshot),
      ),
    );
  }

  void _stopProcessing() {
    _controller?.stopImageStream();
    setState(() {
      _isProcessing = false;
      _frameInFlight = false;
      _annotatedImage = null;
      _poseLandmarks = [];
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
      clean.setRange(y * width * 4, (y + 1) * width * 4, plane.bytes, y * stride);
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
      debugPrint('📷 format=${cameraImage.format.group} '
          'size=${cameraImage.width}x${cameraImage.height} '
          'stride=${cameraImage.planes[0].bytesPerRow} '
          'planes=${cameraImage.planes.length}');
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

      final response = await http
          .post(
            Uri.parse('$_serverUrl/process_frame'),
            headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
            body: jsonEncode({'image': base64Encode(jpegBytes)}),
          )
          .timeout(const Duration(seconds: 5));

      if (!mounted || !_isProcessing) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final annotatedBytes = base64Decode(data['annotated_image'] as String);
        final newStats = data['stats'] as Map<String, dynamic>;
        final landmarksJson = (data['landmarks'] as List<dynamic>?) ?? [];

        final landmarks = landmarksJson.map<Offset>((raw) {
          final lm = raw as Map<String, dynamic>;
          return Offset(
            (lm['x'] as num).toDouble(),
            (lm['y'] as num).toDouble(),
          );
        }).toList();

        if (mounted) {
          setState(() {
            _annotatedImage = annotatedBytes;
            _stats = newStats;
            _poseLandmarks = landmarks;
          });
        }

        final aiFeedback = data['ai_feedback'] as String? ?? '';
        if (aiFeedback.isNotEmpty) {
          _speakFeedback(aiFeedback);
        }
      }
    } catch (_) {
      // Network errors; keep the stream going.
    }
  }

  Future<void> _speakFeedback(String text) async {
    if (text.isEmpty || _isSpeaking) return;
    _isSpeaking = true;
    try {
      final response = await http
          .post(
            Uri.parse(
                'https://api.elevenlabs.io/v1/text-to-speech/$_kElevenLabsVoiceId'),
            headers: {
              'xi-api-key': _kElevenLabsKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'text': text,
              'model_id': 'eleven_turbo_v2_5',
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/tts_feedback.mp3');
        await file.writeAsBytes(response.bodyBytes);
        await _audioPlayer.play(DeviceFileSource(file.path));
      } else {
        debugPrint('[TTS] ElevenLabs ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[TTS] Error: $e');
    } finally {
      _isSpeaking = false;
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
            headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
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
              ? 'AI: ${data['provider']} + ElevenLabs (phone)'
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
      backgroundColor: const Color(0xFF11253C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'On a real phone use your Mac\'s local IP (e.g. http://192.168.1.x:8080)',
                style: TextStyle(color: Colors.white54, fontSize: 12),
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
                      ? 'http://localhost:5000'
                      : serverCtrl.text.trim();
                  setState(() {
                    _serverUrl = url;
                    _provider = providerCtrl.text.trim();
                    _anthropicKey = anthropicCtrl.text.trim();
                    _openAiKey = openAiCtrl.text.trim();
                  });
                  SharedPreferences.getInstance()
                      .then((p) => p.setString('server_url', url));
                  _configureBackend(
                    provider: _provider.isEmpty ? null : _provider,
                    anthropicKey: _anthropicKey.isEmpty ? null : _anthropicKey,
                    openaiKey: _openAiKey.isEmpty ? null : _openAiKey,
                  );
                  Navigator.of(ctx).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
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

  Widget _configField(
      TextEditingController ctrl, String label, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: Colors.white70),
          hintStyle: const TextStyle(color: Colors.white30),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_isProcessing) _controller?.stopImageStream();
    _controller?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmall = screenSize.width < 400;

    return Scaffold(
      backgroundColor: const Color(0xFF0E1E31),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Record', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
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
                            anthropicKey: _anthropicKey.isEmpty ? null : _anthropicKey,
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
                                ? Colors.cyanAccent.withValues(alpha: 0.15)
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: selected
                                  ? Colors.cyanAccent
                                  : Colors.white24,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            exercise,
                            style: TextStyle(
                              color: selected ? Colors.cyanAccent : Colors.white70,
                              fontSize: isSmall ? 13 : 14,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
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
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _backendStatus,
                      style: TextStyle(
                          color: Colors.white60,
                          fontSize: isSmall ? 11 : 13),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isSmall ? 10 : 14),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1C3350), Color(0xFF0F2340)],
                    ),
                    border: Border.all(color: Colors.white24, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.35),
                        blurRadius: 28,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildMainDisplay(),
                        if (_poseLandmarks.isNotEmpty && !_isProcessing)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _PosePainter(
                                  poseLandmarks: _poseLandmarks),
                            ),
                          ),
                        Positioned(
                          left: isSmall ? 12 : 20,
                          top: isSmall ? 12 : 20,
                          child: _Badge(
                            icon: Icons.camera,
                            label: _isProcessing ? 'Analyzing' : 'Live Feed',
                            color: _isProcessing
                                ? Colors.cyanAccent
                                    .withValues(alpha: 0.2)
                                : Colors.white24,
                          ),
                        ),
                        Positioned(
                          right: isSmall ? 12 : 20,
                          top: isSmall ? 12 : 20,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmall ? 10 : 14,
                              vertical: isSmall ? 6 : 8,
                            ),
                            decoration: BoxDecoration(
                              color: (_stats['is_in_rep'] as bool? ?? false)
                                  ? const Color.fromRGBO(0, 200, 100, 0.8)
                                  : Colors.white24,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              (_stats['is_in_rep'] as bool? ?? false)
                                  ? 'In Rep'
                                  : 'Ready',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: isSmall ? 12 : 14,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: isSmall ? 12 : 20,
                          bottom: isSmall ? 12 : 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _repCountText('✓ ${_stats['correct_count']}',
                                  Colors.greenAccent, isSmall),
                              const SizedBox(height: 4),
                              _repCountText('✗ ${_stats['incorrect_count']}',
                                  Colors.redAccent, isSmall),
                            ],
                          ),
                        ),
                        Positioned(
                          right: isSmall ? 12 : 20,
                          bottom: isSmall ? 12 : 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              GestureDetector(
                                onTap: _flipCamera,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: const BoxDecoration(
                                    color: Colors.white24,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.flip_camera_ios,
                                      color: Colors.white,
                                      size: isSmall ? 20 : 24),
                                ),
                              ),
                              if ((_stats['current_feedback'] as String?)
                                      ?.isNotEmpty ==
                                  true) ...[
                                const SizedBox(height: 8),
                                Container(
                                  constraints:
                                      const BoxConstraints(maxWidth: 180),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isSmall ? 10 : 14,
                                    vertical: isSmall ? 8 : 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    _stats['current_feedback'] as String,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isSmall ? 11 : 13),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: isSmall ? 10 : 14),
              // ── Stats row ────────────────────────────────────────────
              Row(
                children: [
                  ..._buildAngleChips(),
                  if ((_stats['current_feedback'] as String?)?.isNotEmpty == true) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _stats['current_feedback'] as String,
                        style: TextStyle(
                          color: Colors.cyanAccent,
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
                      backgroundColor:Color.fromARGB(255, 137, 9, 9),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmall ? 20 : 28,
                        vertical: isSmall ? 12 : 14,
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                    ),
                    child: Text('Finish Session')
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed:
                        _isProcessing ? _stopProcessing : _startProcessing,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isProcessing ? Colors.redAccent : Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmall ? 20 : 28,
                        vertical: isSmall ? 12 : 14,
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
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
        _StatChip(label: 'State', value: state.isEmpty ? 'up' : state, highlight: isInRep),
      ];
    }

    // Squat (default)
    return [
      _StatChip(label: 'Knee', value: _angleDisplay('knee_angle')),
      gap,
      _StatChip(label: 'Hip', value: _angleDisplay('hip_angle')),
      gap,
      _StatChip(label: 'State', value: state.isEmpty ? 'standing' : state, highlight: isInRep),
    ];
  }

  Widget _buildMainDisplay() {
    // Always show annotated frame while processing (no flash between frames).
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
            child: CircularProgressIndicator(color: Color(0xFF8BB8F5)),
          );
        },
      );
    }

    return const Center(
      child: CircularProgressIndicator(color: Color(0xFF8BB8F5)),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Unable to access the camera.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _repCountText(String text, Color color, bool isSmall) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 8 : 12, vertical: isSmall ? 4 : 6),
      decoration: BoxDecoration(
          color: Colors.black45, borderRadius: BorderRadius.circular(10)),
      child: Text(
        text,
        style: TextStyle(
            color: color,
            fontSize: isSmall ? 14 : 16,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _StatChip({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight ? Colors.cyanAccent.withValues(alpha: 0.15) : Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight ? Colors.cyanAccent.withValues(alpha: 0.6) : Colors.white24,
        ),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label  ',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: highlight ? Colors.cyanAccent : Colors.white,
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

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Badge(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(18)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ],
      ),
    );
  }
}


class _PosePainter extends CustomPainter {
  final List<Offset> poseLandmarks;

  const _PosePainter({required this.poseLandmarks});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.85)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = Colors.pinkAccent.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;

    for (final conn in _poseConnections) {
      final si = conn[0];
      final ei = conn[1];
      if (si < poseLandmarks.length && ei < poseLandmarks.length) {
        canvas.drawLine(
          Offset(poseLandmarks[si].dx * size.width,
              poseLandmarks[si].dy * size.height),
          Offset(poseLandmarks[ei].dx * size.width,
              poseLandmarks[ei].dy * size.height),
          linePaint,
        );
      }
    }

    for (final lm in poseLandmarks) {
      canvas.drawCircle(
          Offset(lm.dx * size.width, lm.dy * size.height), 5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PosePainter old) =>
      old.poseLandmarks != poseLandmarks;
}
