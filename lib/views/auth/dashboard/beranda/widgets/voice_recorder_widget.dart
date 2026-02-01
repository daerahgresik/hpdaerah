import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;

/// Modern Voice Recorder Widget seperti Telegram
/// Fitur:
/// - Tahan untuk rekam
/// - Geser kiri untuk batal
/// - Geser atas untuk lock (hands-free recording)
/// - Waveform visualization
/// - Pause/Resume saat locked

class VoiceRecorderOverlay extends StatefulWidget {
  final VoidCallback onCancel;
  final Function(int durationSeconds) onSend;
  final Offset startPosition;

  const VoiceRecorderOverlay({
    super.key,
    required this.onCancel,
    required this.onSend,
    required this.startPosition,
  });

  @override
  State<VoiceRecorderOverlay> createState() => VoiceRecorderOverlayState();
}

class VoiceRecorderOverlayState extends State<VoiceRecorderOverlay>
    with TickerProviderStateMixin {
  // Recording state
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  bool _isLocked = false;
  bool _isPaused = false;

  // Slide detection
  double _slideX = 0;
  double _slideY = 0;
  bool _shouldCancel = false;

  // Animations
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _lockController;
  late Animation<double> _pulseAnimation;

  // Waveform data (simulated audio levels)
  final List<double> _waveformData = [];
  final int _maxWaveformBars = 50;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startRecording();
  }

  void _initAnimations() {
    // Pulse animation for mic button
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Wave animation for waveform
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat();

    // Lock animation
    _lockController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  void _startRecording() {
    HapticFeedback.mediumImpact();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          _recordingSeconds++;
          // Add simulated waveform data
          _waveformData.add(math.Random().nextDouble() * 0.8 + 0.2);
          if (_waveformData.length > _maxWaveformBars) {
            _waveformData.removeAt(0);
          }
        });
      }
    });

    // Simulate waveform updates more frequently
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_isPaused && !_shouldCancel) {
        setState(() {
          _waveformData.add(math.Random().nextDouble() * 0.8 + 0.2);
          if (_waveformData.length > _maxWaveformBars) {
            _waveformData.removeAt(0);
          }
        });
      }
    });
  }

  void onPanUpdate(DragUpdateDetails details) {
    if (_isLocked) return;

    setState(() {
      _slideX += details.delta.dx;
      _slideY += details.delta.dy;

      // Check for cancel (slide left)
      _shouldCancel = _slideX < -100;

      // Check for lock (slide up)
      if (_slideY < -80 && !_isLocked) {
        _lockRecording();
      }
    });
  }

  void onPanEnd() {
    if (_isLocked) return;

    if (_shouldCancel) {
      _cancelRecording();
    } else {
      // Released without locking = send
      _sendRecording();
    }
  }

  void _lockRecording() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isLocked = true;
    });
    _lockController.forward();
  }

  void _togglePause() {
    HapticFeedback.lightImpact();
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  void _cancelRecording() {
    HapticFeedback.lightImpact();
    _recordingTimer?.cancel();
    widget.onCancel();
  }

  void _sendRecording() {
    HapticFeedback.mediumImpact();
    _recordingTimer?.cancel();
    widget.onSend(_recordingSeconds);
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _pulseController.dispose();
    _waveController.dispose();
    _lockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return _buildLockedUI();
    }
    return _buildSlideUI();
  }

  /// UI saat sedang slide (belum locked)
  Widget _buildSlideUI() {
    final cancelOpacity = (_slideX.abs() / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Cancel indicator
          Opacity(
            opacity: cancelOpacity,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.delete, color: Colors.red, size: 24),
            ),
          ),

          // Recording bar
          Expanded(
            child: Container(
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Recording indicator
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.5),
                              blurRadius: 8 * _pulseAnimation.value,
                              spreadRadius: 2 * _pulseAnimation.value,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),

                  // Timer
                  Text(
                    _formatTime(_recordingSeconds),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_left, color: Colors.grey, size: 20),
                  const SizedBox(width: 4),

                  // Slide hint
                  Expanded(
                    child: Text(
                      'Geser untuk membatalkan',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Lock button indicator
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final slideUpProgress = (-_slideY / 80).clamp(0.0, 1.0);
              return Transform.scale(
                scale: 1.0 + (slideUpProgress * 0.3),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: slideUpProgress > 0.5
                          ? [const Color(0xFF4CAF50), const Color(0xFF2E7D32)]
                          : [const Color(0xFF0088CC), const Color(0xFF0066AA)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            (slideUpProgress > 0.5
                                    ? Colors.green
                                    : const Color(0xFF0088CC))
                                .withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    slideUpProgress > 0.5 ? Icons.lock : Icons.mic,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// UI saat sudah locked (hands-free recording)
  Widget _buildLockedUI() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Waveform + Timer bar
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0088CC).withValues(alpha: 0.1),
                    const Color(0xFF0088CC).withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFF0088CC).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  // Recording dot
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _isPaused ? Colors.orange : Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: _isPaused
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.red.withValues(alpha: 0.5),
                                    blurRadius: 6 * _pulseAnimation.value,
                                  ),
                                ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),

                  // Timer
                  Text(
                    _formatTime(_recordingSeconds),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Waveform visualization
                  Expanded(child: _buildWaveform()),

                  const SizedBox(width: 8),

                  // Cancel text button
                  GestureDetector(
                    onTap: _cancelRecording,
                    child: const Text(
                      'Batal',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Pause button
          GestureDetector(
            onTap: _togglePause,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(
                _isPaused ? Icons.play_arrow : Icons.pause,
                color: const Color(0xFF0088CC),
                size: 24,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Send button
          GestureDetector(
            onTap: _sendRecording,
            child: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0088CC), Color(0xFF0066AA)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x400088CC),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_upward,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Waveform visualization widget
  Widget _buildWaveform() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = 3.0;
        final barSpacing = 2.0;
        final maxBars = (constraints.maxWidth / (barWidth + barSpacing))
            .floor();

        // Get the last N bars that fit
        final displayData = _waveformData.length > maxBars
            ? _waveformData.sublist(_waveformData.length - maxBars)
            : _waveformData;

        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: List.generate(displayData.length, (index) {
            final height = displayData[index] * 24;
            return Padding(
              padding: EdgeInsets.only(right: barSpacing),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: barWidth,
                height: height.clamp(4.0, 24.0),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFF0088CC,
                  ).withValues(alpha: 0.6 + (displayData[index] * 0.4)),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Voice Message Bubble Widget - untuk menampilkan pesan suara yang sudah terkirim
class VoiceMessageBubble extends StatefulWidget {
  final int durationSeconds;
  final bool isMe;
  final String time;
  final List<double>? waveformData;

  const VoiceMessageBubble({
    super.key,
    required this.durationSeconds,
    required this.isMe,
    required this.time,
    this.waveformData,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  bool _isPlaying = false;
  double _playProgress = 0.0;

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // Generate random waveform if not provided
  List<double> get _waveform {
    if (widget.waveformData != null) return widget.waveformData!;
    // Generate consistent pseudo-random waveform based on duration
    final random = math.Random(widget.durationSeconds);
    return List.generate(30, (_) => random.nextDouble() * 0.7 + 0.3);
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        // Simulate playback progress
        _simulatePlayback();
      }
    });
  }

  void _simulatePlayback() async {
    final totalMs = widget.durationSeconds * 1000;
    final steps = 50;
    final stepDuration = totalMs ~/ steps;

    for (int i = 0; i <= steps && _isPlaying; i++) {
      await Future.delayed(Duration(milliseconds: stepDuration));
      if (mounted && _isPlaying) {
        setState(() {
          _playProgress = i / steps;
        });
      }
    }

    if (mounted) {
      setState(() {
        _isPlaying = false;
        _playProgress = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = widget.isMe ? const Color(0xFFD9FDD3) : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: widget.isMe
              ? const Radius.circular(16)
              : const Radius.circular(4),
          bottomRight: widget.isMe
              ? const Radius.circular(4)
              : const Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play button
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.isMe
                      ? [const Color(0xFF4CAF50), const Color(0xFF2E7D32)]
                      : [const Color(0xFF0088CC), const Color(0xFF0066AA)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Waveform and time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Waveform
                SizedBox(
                  height: 24,
                  child: Row(
                    children: List.generate(_waveform.length, (index) {
                      final isPlayed =
                          index / _waveform.length <= _playProgress;
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 0.5),
                          height: _waveform[index] * 24,
                          decoration: BoxDecoration(
                            color: isPlayed
                                ? (widget.isMe
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFF0088CC))
                                : Colors.grey[400],
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 4),

                // Duration and time
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          _formatTime(widget.durationSeconds),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: widget.isMe
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFF0088CC),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      widget.time,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
