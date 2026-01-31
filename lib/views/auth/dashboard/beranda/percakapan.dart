import 'package:flutter/material.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/models/chat_message_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

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
        color: Color(0xFFF0F2F5), // WhatsApp-style background
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
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
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
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
                  const SizedBox(width: 6),
                  // Avatar Anda di dalam Input
                  _buildAvatar(null, isMe: true, radius: 14),
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

                  // Ikon Sticker / Emoji
                  IconButton(
                    icon: Icon(
                      _isTextEmpty
                          ? Icons.sticky_note_2_outlined
                          : Icons.sentiment_satisfied_alt_outlined,
                      color: Colors.black45,
                    ),
                    onPressed: () {},
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
                ? _buildCircleButton(
                    key: const ValueKey('mic'),
                    icon: Icons.mic_none_outlined,
                    color: Colors.white,
                    iconColor: Colors.black54,
                  )
                : _buildCircleButton(
                    key: const ValueKey('send'),
                    icon: Icons.send_rounded,
                    color: const Color(0xFF0088CC), // Biru Telegram
                    iconColor: Colors.white,
                    onPress: _sendMessage,
                  ),
          ),
        ],
      ),
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
