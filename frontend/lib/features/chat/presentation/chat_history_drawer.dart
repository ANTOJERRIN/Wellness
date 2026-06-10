import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../providers/chat_provider.dart';

class ChatHistoryDrawer extends ConsumerStatefulWidget {
  const ChatHistoryDrawer({super.key});

  @override
  ConsumerState<ChatHistoryDrawer> createState() => _ChatHistoryDrawerState();
}

class _ChatHistoryDrawerState extends ConsumerState<ChatHistoryDrawer> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final res = await ref.read(dioProvider).get("/chat/sessions");
      if (res.statusCode == 200) {
        setState(() {
          _sessions = List<Map<String, dynamic>>.from(res.data);
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF1E293B),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF334155)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history, color: Color(0xFF10B981)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Chat History",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Your previous sessions",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.grey, size: 20),
                    onPressed: _loadSessions,
                  ),
                ],
              ),
            ),

            // New Chat button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    ref.read(chatProvider.notifier).startNewSession();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text("New Chat",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),

            // Sessions list
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF10B981)))
                  : _sessions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline,
                                  color: Colors.grey.shade700, size: 40),
                              const SizedBox(height: 12),
                              const Text(
                                "No previous sessions",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          itemCount: _sessions.length,
                          itemBuilder: (context, index) {
                            final session = _sessions[index];
                            final title = session["title"] ??
                                "Chat Session ${index + 1}";
                            final createdAt = session["createdAt"] ?? "";

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.chat_bubble_outline,
                                    color: Color(0xFF10B981), size: 18),
                              ),
                              title: Text(
                                title,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                _formatDate(createdAt),
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 11),
                              ),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              onTap: () {
                                final sessionId = session["sessionId"] ?? "";
                                if (sessionId.isNotEmpty) {
                                  ref
                                      .read(chatProvider.notifier)
                                      .loadSession(sessionId);
                                  Navigator.pop(context);
                                }
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final now = DateTime.now();
      if (dt.day == now.day &&
          dt.month == now.month &&
          dt.year == now.year) {
        return "Today at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
      }
      return "${dt.day}/${dt.month}/${dt.year}";
    } catch (_) {
      return isoDate;
    }
  }
}

