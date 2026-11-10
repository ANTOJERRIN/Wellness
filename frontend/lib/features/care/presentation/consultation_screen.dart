import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/care_api.dart';

class ConsultationScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> consultation;
  final bool doctor;
  final bool preview;
  const ConsultationScreen({
    super.key,
    required this.consultation,
    required this.doctor,
    this.preview = false,
  });
  @override
  ConsumerState<ConsultationScreen> createState() => _ConsultationState();
}

class _ConsultationState extends ConsumerState<ConsultationScreen> {
  final _message = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = widget.consultation['status'] as String;
    if (widget.preview) {
      _messages = [
        {
          'senderName': 'Dr. Alex (sample)',
          'content':
              'Thank you for your request. What would you like to discuss about your wellness routine?',
          'isOwn': widget.doctor,
        },
      ];
      _loading = false;
    } else {
      Future.microtask(_load);
    }
  }

  Future<void> _load() async {
    try {
      final rows = await ref
          .read(careApiProvider)
          .messages(widget.consultation['id'] as String);
      if (mounted) {
        setState(() {
          _messages = rows;
          _loading = false;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = careError(error);
          _loading = false;
        });
      }
    }
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty || text.length > 4000 || _busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(careApiProvider)
          .send(widget.consultation['id'] as String, text);
      if (!mounted) return;
      _message.clear();
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = careError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setStatus(String status) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(careApiProvider)
          .status(widget.consultation['id'] as String, status);
      if (mounted) {
        setState(() {
          _status = status;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = careError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.preview && !ref.watch(authProvider).isAuthenticated) {
      return const AuthScreen();
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.doctor
              ? widget.consultation['patientName'] as String
              : widget.consultation['doctorName'] as String,
        ),
        actions: [
          if (!widget.preview)
            IconButton(
              tooltip: 'Refresh messages',
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.preview)
                      const Text(
                        'Sample conversation · Read-only review preview',
                        style: TextStyle(color: Colors.amber),
                      ),
                    Text(
                      widget.consultation['reason'] as String,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('Status: ${_status.replaceAll('_', ' ')}'),
                    const Text(
                      'For urgent symptoms, contact local emergency services. Messages are not monitored continuously.',
                    ),
                    if (widget.doctor && !widget.preview && _status != 'closed')
                      Wrap(
                        spacing: 12,
                        children: [
                          if (_status == 'requested')
                            OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () => _setStatus('in_progress'),
                              child: const Text('Accept request'),
                            ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _setStatus('closed'),
                            child: const Text('Close consultation'),
                          ),
                        ],
                      ),
                    if (_error != null)
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.orange),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'No messages yet. Start the conversation below.',
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final row = _messages[index];
                          return Align(
                            alignment: row['isOwn'] == true
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 620),
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        row['senderName'] as String,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      SelectableText(row['content'] as String),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (!widget.preview && _status != 'closed')
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _message,
                          enabled: !_busy,
                          maxLength: 4000,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Message your care team',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: 'Send message',
                        onPressed: _busy ? null : _send,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              if (_status == 'closed')
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'This consultation is closed. Its messages remain available to you.',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
