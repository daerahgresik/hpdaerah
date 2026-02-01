import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:math' as math;
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/models/chat_message_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:image_picker/image_picker.dart';

/// Menampilkan Modal Bottom Sheet untuk Percakapan
void showPercakapanModal(BuildContext context, UserModel user) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ChatModalContent(user: user),
  );
}

class ChatModalContent extends StatefulWidget {
  final UserModel user;

  const ChatModalContent({super.key, required this.user});

  @override
  State<ChatModalContent> createState() => _ChatModalContentState();
}

class _ChatModalContentState extends State<ChatModalContent> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _selectedScope = 'desa'; // Default scope
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  RealtimeChannel? _subscription;
  bool _isTextEmpty = true;
  final ImagePicker _picker = ImagePicker();

  // Voice Recording State
  bool _isVoiceRecording = false;
  bool _isVoiceLocked = false;
  bool _isVoicePaused = false;
  int _voiceRecordingSeconds = 0;
  Timer? _voiceRecordingTimer;
  final List<double> _waveformData = [];
  Offset _voiceStartPosition = Offset.zero;
  double _slideX = 0;
  double _slideY = 0;
  bool _shouldCancelVoice = false;

  // Cache for current room ID
  String? get _currentRoomId {
    switch (_selectedScope) {
      case 'daerah':
        return widget.user.orgDaerahId;
      case 'desa':
        return widget.user.orgDesaId;
      case 'kelompok':
        return widget.user.orgKelompokId;
      default:
        return null;
    }
  }

  String get _scopeTitle {
    switch (_selectedScope) {
      case 'daerah':
        return "Chat Daerah";
      case 'desa':
        return "Chat Desa";
      case 'kelompok':
        return "Chat Kelompok";
      default:
        return "Chat";
    }
  }

  String get _scopeSubtitle {
    switch (_selectedScope) {
      case 'daerah':
        return widget.user.daerahName ?? "Lingkup Daerah";
      case 'desa':
        return widget.user.desaName ?? "Lingkup Desa";
      case 'kelompok':
        return widget.user.kelompokName ?? "Lingkup Kelompok";
      default:
        return "";
    }
  }

  @override
  void initState() {
    super.initState();
    // Daftarkan locale Bahasa Indonesia untuk format waktu
    timeago.setLocaleMessages('id', timeago.IdMessages());

    // Listener untuk mendeteksi perubahan ketikan (Mic vs Send)
    _messageController.addListener(() {
      final isNowEmpty = _messageController.text.trim().isEmpty;
      if (isNowEmpty != _isTextEmpty) {
        setState(() => _isTextEmpty = isNowEmpty);
      }
    });

    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _voiceRecordingTimer?.cancel();
    _unsubscribe();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    if (_currentRoomId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    try {
      // Use Join to get user details (Nama and Foto Profil)
      final response = await _supabase
          .from('chat_messages')
          .select('*, users(nama, foto_profil)')
          .eq('room_id', _currentRoomId!)
          .order('created_at', ascending: true)
          .limit(100);

      final data = response as List<dynamic>;
      if (mounted) {
        setState(() {
          _messages = data.map((e) => ChatMessage.fromJson(e)).toList();
          _isLoading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });

        _subscribe();
      }
    } catch (e) {
      debugPrint('Error loading messages: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribe() {
    _unsubscribe();

    if (_currentRoomId == null) return;

    _subscription = _supabase
        .channel('chat_room_$_currentRoomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: _currentRoomId!,
          ),
          callback: (payload) async {
            // Realtime doesn't join automatically, so we fetch sender details manually
            final rawMsg = payload.newRecord;
            final senderId = rawMsg['sender_id'];

            String? name;
            String? photo;

            // If it's the current user, we already have the data
            if (senderId == widget.user.id) {
              name = widget.user.nama;
              photo = widget.user.fotoProfil;
            } else {
              // Fetch user info for the incoming message
              final userRes = await _supabase
                  .from('users')
                  .select('nama, foto_profil')
                  .eq('id', senderId)
                  .maybeSingle();

              name = userRes?['nama'];
              photo = userRes?['foto_profil'];
            }

            final newMessage = ChatMessage.fromJson({
              ...rawMsg,
              'users': {'nama': name, 'foto_profil': photo},
            });

            if (mounted) {
              setState(() {
                _messages.add(newMessage);
              });
              _scrollToBottom();
            }
          },
        )
        .subscribe();
  }

  void _unsubscribe() {
    if (_subscription != null) {
      _supabase.removeChannel(_subscription!);
      _subscription = null;
    }
  }

  void _handleScopeChange(String scope) {
    if (scope == _selectedScope) return;
    setState(() {
      _selectedScope = scope;
      _messages.clear();
    });
    _loadMessages();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_currentRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Anda belum terdaftar di ${getScopeName(_selectedScope)}. Hubungi Admin.",
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _messageController.clear();

    try {
      await _supabase.from('chat_messages').insert({
        'room_id': _currentRoomId,
        'sender_id': widget.user.id,
        'content': text,
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal mengirim pesan: $e")));
    }
  }

  String getScopeName(String scope) {
    if (scope == 'daerah') return "Daerah";
    if (scope == 'desa') return "Desa";
    return "Kelompok";
  }

  // Fitur Attachment - Pilih Gambar
  Future<void> _pickAttachment() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAttachmentOption(
              icon: Icons.photo_library,
              title: 'Galeri',
              color: const Color(0xFF9C27B0),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (image != null) {
                  _showAttachmentPreview(image);
                }
              },
            ),
            const SizedBox(height: 12),
            _buildAttachmentOption(
              icon: Icons.camera_alt,
              title: 'Kamera',
              color: const Color(0xFF2196F3),
              onTap: () async {
                Navigator.pop(context);
                final XFile? photo = await _picker.pickImage(
                  source: ImageSource.camera,
                );
                if (photo != null) {
                  _showAttachmentPreview(photo);
                }
              },
            ),
            const SizedBox(height: 12),
            _buildAttachmentOption(
              icon: Icons.insert_drive_file,
              title: 'Dokumen',
              color: const Color(0xFFFF9800),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fitur dokumen akan segera hadir!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAttachmentPreview(XFile file) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gambar dipilih: ${file.name}'),
        action: SnackBarAction(
          label: 'Kirim',
          textColor: const Color(0xFF0088CC),
          onPressed: () {
            // TODO: Upload dan kirim gambar
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Upload gambar akan segera hadir!')),
            );
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ===== MODERN VOICE RECORDING =====

  void _startVoiceRecording(Offset globalPosition) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isVoiceRecording = true;
      _isVoiceLocked = false;
      _isVoicePaused = false;
      _voiceRecordingSeconds = 0;
      _waveformData.clear();
      _voiceStartPosition = globalPosition;
      _slideX = 0;
      _slideY = 0;
      _shouldCancelVoice = false;
    });

    // Start timer
    _voiceRecordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isVoicePaused && mounted) {
        setState(() {
          _voiceRecordingSeconds++;
        });
      }
    });

    // Simulate waveform data
    Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (!mounted || !_isVoiceRecording) {
        timer.cancel();
        return;
      }
      if (!_isVoicePaused && !_shouldCancelVoice) {
        setState(() {
          _waveformData.add(math.Random().nextDouble() * 0.7 + 0.3);
          if (_waveformData.length > 50) {
            _waveformData.removeAt(0);
          }
        });
      }
    });
  }

  void _updateVoiceRecording(Offset globalPosition) {
    if (!_isVoiceRecording || _isVoiceLocked) return;

    final deltaX = globalPosition.dx - _voiceStartPosition.dx;
    final deltaY = globalPosition.dy - _voiceStartPosition.dy;

    setState(() {
      _slideX = deltaX;
      _slideY = deltaY;
      _shouldCancelVoice = deltaX < -100;

      // Lock if swiped up
      if (deltaY < -80 && !_isVoiceLocked) {
        _lockVoiceRecording();
      }
    });
  }

  void _endVoiceRecording() {
    if (_isVoiceLocked) return; // Don't end if locked

    if (_shouldCancelVoice) {
      _cancelVoiceRecording();
    } else {
      _sendVoiceMessage();
    }
  }

  void _lockVoiceRecording() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isVoiceLocked = true;
    });
  }

  void _toggleVoicePause() {
    HapticFeedback.lightImpact();
    setState(() {
      _isVoicePaused = !_isVoicePaused;
    });
  }

  void _cancelVoiceRecording() {
    HapticFeedback.lightImpact();
    _voiceRecordingTimer?.cancel();
    setState(() {
      _isVoiceRecording = false;
      _isVoiceLocked = false;
      _voiceRecordingSeconds = 0;
      _waveformData.clear();
    });
  }

  void _sendVoiceMessage() {
    HapticFeedback.mediumImpact();
    _voiceRecordingTimer?.cancel();
    final duration = _voiceRecordingSeconds;

    setState(() {
      _isVoiceRecording = false;
      _isVoiceLocked = false;
      _voiceRecordingSeconds = 0;
    });

    if (duration > 0) {
      // TODO: Actually send voice message to server
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('Pesan suara ${_formatVoiceTime(duration)} terkirim!'),
            ],
          ),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  String _formatVoiceTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 500,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFEEEEEE), // Light grey background
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          // Percakapan JPG background overlay
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: Opacity(
                opacity: 0.15,
                child: Image.asset(
                  'assets/images/bg percakapan.jpg',
                  fit: BoxFit.cover,
                  repeat: ImageRepeat.repeat,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
          // Main content
          Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg.senderId == widget.user.id;
                          return _buildWhatsappBubble(msg, isMe);
                        },
                      ),
              ),
              _buildInputArea(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A5F2D).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.groups,
                      color: Color(0xFF1A5F2D),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _scopeTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          _scopeSubtitle,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildScopeTab("Daerah", "daerah"),
                  const SizedBox(width: 8),
                  _buildScopeTab("Desa", "desa"),
                  const SizedBox(width: 8),
                  _buildScopeTab("Kelompok", "kelompok"),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScopeTab(String label, String value) {
    bool isSelected = value == _selectedScope;
    return Expanded(
      child: GestureDetector(
        onTap: () => _handleScopeChange(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1A5F2D) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? const Color(0xFF1A5F2D) : Colors.grey[300]!,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            "Belum ada pesan di $_scopeTitle",
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Mulai obrolan dengan warga lainnya!",
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatsappBubble(ChatMessage msg, bool isMe) {
    final timeStr =
        "${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}";

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMe) _buildAvatar(msg),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      msg.senderName ?? "Warga",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A5F2D),
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFFD9FDD3) : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: isMe
                          ? const Radius.circular(12)
                          : Radius.zero,
                      bottomRight: isMe
                          ? Radius.zero
                          : const Radius.circular(12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 48, bottom: 2),
                        child: Text(
                          msg.content,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isMe) _buildAvatar(msg, isMe: true),
        ],
      ),
    );
  }

  Widget _buildAvatar(
    ChatMessage? msg, {
    bool isMe = false,
    double radius = 16,
  }) {
    final photo = isMe ? widget.user.fotoProfil : msg?.senderPhoto;
    final initials = isMe
        ? (widget.user.nama.isNotEmpty ? widget.user.nama[0] : "A")
        : (msg?.senderName?.isNotEmpty == true ? msg!.senderName![0] : "?");

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[300],
      backgroundImage: (photo != null && photo.isNotEmpty)
          ? NetworkImage(photo)
          : null,
      child: (photo == null || photo.isEmpty)
          ? Text(
              initials,
              style: TextStyle(
                fontSize: radius * 0.75,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            )
          : null,
    );
  }

  Widget _buildInputArea() {
    // Wrap dengan Listener untuk mendeteksi pointer up saat recording
    return Listener(
      onPointerUp: (_) {
        // Jika sedang recording dan belum locked, end recording
        if (_isVoiceRecording && !_isVoiceLocked) {
          _endVoiceRecording();
        }
      },
      onPointerMove: (event) {
        // Update posisi saat recording
        if (_isVoiceRecording && !_isVoiceLocked) {
          _updateVoiceRecording(event.position);
        }
      },
      child: _isVoiceRecording
          ? _buildVoiceRecordingUI()
          : _buildNormalInputUI(),
    );
  }

  /// UI input normal (tidak sedang recording)
  Widget _buildNormalInputUI() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 8,
      ).copyWith(bottom: MediaQuery.of(context).viewInsets.bottom + 12),
      color: Colors.transparent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 1. Tombol Lampiran (Paperclip)
          _buildCircleButton(
            icon: Icons.attach_file,
            color: Colors.white,
            iconColor: Colors.black54,
            onPress: _pickAttachment,
          ),
          const SizedBox(width: 8),

          // 2. Bar Input Utama (Rounded Pill)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  // Avatar Anda di dalam Input
                  _buildAvatar(null, isMe: true, radius: 20),
                  const SizedBox(width: 8),

                  // Bidang Teks
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      maxLines: 5,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: "Pesan",
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                      style: const TextStyle(fontSize: 16),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 3. Tombol Mic atau Kirim
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: _isTextEmpty
                ? Listener(
                    key: const ValueKey('mic'),
                    onPointerDown: (event) {
                      _startVoiceRecording(event.position);
                    },
                    child: _buildCircleButton(
                      icon: Icons.mic_none_outlined,
                      color: Colors.white,
                      iconColor: Colors.black54,
                    ),
                  )
                : _buildCircleButton(
                    key: const ValueKey('send'),
                    icon: Icons.send_rounded,
                    color: const Color(0xFF0088CC),
                    iconColor: Colors.white,
                    onPress: _sendMessage,
                  ),
          ),
        ],
      ),
    );
  }

  /// UI saat sedang voice recording
  Widget _buildVoiceRecordingUI() {
    if (_isVoiceLocked) {
      return _buildLockedRecordingUI();
    }
    return _buildSlideRecordingUI();
  }

  /// UI recording dengan slide gesture
  Widget _buildSlideRecordingUI() {
    final cancelOpacity = (_slideX.abs() / 100).clamp(0.0, 1.0);
    final lockProgress = ((-_slideY) / 80).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 8,
      ).copyWith(bottom: MediaQuery.of(context).viewInsets.bottom + 12),
      child: Row(
        children: [
          // Cancel indicator
          AnimatedOpacity(
            duration: const Duration(milliseconds: 100),
            opacity: cancelOpacity,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 24,
              ),
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
                  // Pulse recording indicator
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.8, end: 1.2),
                    duration: const Duration(milliseconds: 600),
                    builder: (context, value, child) {
                      return Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.5),
                              blurRadius: 8 * value,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),

                  // Timer
                  Text(
                    _formatVoiceTime(_voiceRecordingSeconds),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_left, color: Colors.grey, size: 18),

                  // Slide hint
                  Expanded(
                    child: Text(
                      'Geser untuk membatalkan',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Lock/Mic button with slide up indicator
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Lock indicator
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: lockProgress > 0.2 ? 1.0 : 0.0,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    lockProgress > 0.7 ? Icons.lock : Icons.lock_open,
                    color: lockProgress > 0.7
                        ? const Color(0xFF4CAF50)
                        : Colors.grey,
                    size: 18,
                  ),
                ),
              ),
              // Mic button
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: lockProgress > 0.5
                        ? [const Color(0xFF4CAF50), const Color(0xFF2E7D32)]
                        : [const Color(0xFF0088CC), const Color(0xFF0066AA)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          (lockProgress > 0.5
                                  ? Colors.green
                                  : const Color(0xFF0088CC))
                              .withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  lockProgress > 0.5 ? Icons.lock : Icons.mic,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// UI saat recording terkunci (hands-free mode)
  Widget _buildLockedRecordingUI() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 8,
      ).copyWith(bottom: MediaQuery.of(context).viewInsets.bottom + 12),
      child: Row(
        children: [
          // Waveform + Timer bar
          Expanded(
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0088CC).withValues(alpha: 0.08),
                    const Color(0xFF0088CC).withValues(alpha: 0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: const Color(0xFF0088CC).withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  // Recording dot with pulse
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.5, end: 1.0),
                    duration: const Duration(milliseconds: 500),
                    builder: (context, value, _) {
                      return Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _isVoicePaused ? Colors.orange : Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: _isVoicePaused
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.red.withValues(
                                      alpha: 0.5 * value,
                                    ),
                                    blurRadius: 6 * value,
                                  ),
                                ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),

                  // Timer
                  Text(
                    _formatVoiceTime(_voiceRecordingSeconds),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Waveform visualization
                  Expanded(child: _buildWaveformVisualization()),

                  // Cancel button
                  GestureDetector(
                    onTap: _cancelVoiceRecording,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Batal',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Pause/Resume button
          GestureDetector(
            onTap: _toggleVoicePause,
            child: Container(
              width: 46,
              height: 46,
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
                _isVoicePaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: const Color(0xFF0088CC),
                size: 26,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Send button
          GestureDetector(
            onTap: _sendVoiceMessage,
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
                    color: Color(0x500088CC),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_upward_rounded,
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
  Widget _buildWaveformVisualization() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const barWidth = 3.0;
        const barSpacing = 2.0;
        final maxBars = (constraints.maxWidth / (barWidth + barSpacing))
            .floor();

        final displayData = _waveformData.length > maxBars
            ? _waveformData.sublist(_waveformData.length - maxBars)
            : _waveformData;

        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: List.generate(displayData.length, (index) {
            final height = displayData[index] * 28;
            return Padding(
              padding: const EdgeInsets.only(right: barSpacing),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                width: barWidth,
                height: height.clamp(4.0, 28.0),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFF0088CC,
                  ).withValues(alpha: 0.5 + (displayData[index] * 0.5)),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildCircleButton({
    Key? key,
    required IconData icon,
    required Color color,
    required Color iconColor,
    VoidCallback? onPress,
  }) {
    return Container(
      key: key,
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onPress ?? () {},
          child: Icon(icon, color: iconColor, size: 24),
        ),
      ),
    );
  }
}
