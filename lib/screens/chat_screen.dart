import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'summary_screen.dart';
import 'schedule_screen.dart';

// ─────────────────────────────────────────────
//  HUGGING FACE INFERENCE API (OpenAI-compatible)
//  Model: meta-llama/Llama-3.2-1B-Instruct
//  Free tier supported ✅
// ─────────────────────────────────────────────

const String _groqUrl =
    'https://api.groq.com/openai/v1/chat/completions';
const String _groqModel = 'llama-3.3-70b-versatile';

Future<String> getAIResponseWithMemory(
  List<Map<String, String>> messages,
) async {
  final apiKey = dotenv.env['GROQ_API_KEY'] ?? '';

  if (apiKey.isEmpty) {
    return '❌ GROQ_API_KEY is missing in your .env file';
  }

  // Build OpenAI-style messages array
  final List<Map<String, String>> apiMessages = [
    {
      'role': 'system',
      'content':
          'You are a helpful personal assistant. Be concise and friendly.',
    }
  ];

  for (final msg in messages) {
    final role = msg['role'] == 'user' ? 'user' : 'assistant';
    final content = msg['text'] ?? '';
    if (content.isEmpty) continue;
    apiMessages.add({'role': role, 'content': content});
  }

  if (apiMessages.length <= 1) {
    return '⚠️ No valid message to send.';
  }

  try {
    final response = await http
        .post(
          Uri.parse(_groqUrl),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': _groqModel,
            'messages': apiMessages,
            'max_tokens': 500,
            'temperature': 0.7,
            'stream': false,
          }),
        )
        .timeout(const Duration(seconds: 60));

    debugPrint('═══ HF status=${response.statusCode} ═══');

    switch (response.statusCode) {
      case 200:
        final data = jsonDecode(response.body);
        // OpenAI-compatible response format
        final choices = data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final content =
              choices[0]['message']?['content'] as String? ?? '';
          return content.trim().isNotEmpty
              ? content.trim()
              : '⚠️ Empty response';
        }
        debugPrint('HF unexpected body: ${response.body}');
        return '⚠️ Unexpected response format';
      case 401:
        return '❌ Invalid HF token (401). Check HF_API_KEY in .env';
      case 429:
        return '⚠️ Rate limit hit. Please wait a moment and try again.';
      case 503:
        return '⏳ Model is loading, please try again in ~20 seconds.';
      case 400:
        debugPrint('HF 400: ${response.body}');
        return '❌ Bad request (400): ${response.body}';
      default:
        debugPrint('HF error: ${response.body}');
        return '❌ API Error ${response.statusCode}: ${response.body}';
    }
  } on Exception catch (e) {
    debugPrint('HF exception: $e');
    return '⚠️ Network error: $e';
  }
}

// ─────────────────────────────────────────────
//  PARSER  —  extract JSON event from AI text
// ─────────────────────────────────────────────
Map<String, dynamic>? parseEvent(String response) {
  try {
    final start = response.indexOf('{');
    final end = response.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return null;
    return jsonDecode(response.substring(start, end + 1))
        as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

// ─────────────────────────────────────────────
//  CHAT SCREEN
// ─────────────────────────────────────────────
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<Map<String, String>> messages = [];
  bool isTyping = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _loadMessages() {
    final box = Hive.box('chatBox');
    final data = box.values
        .map((e) => {
              'role': e['role'].toString(),
              'text': e['text'].toString(),
            })
        .toList();
    setState(() => messages = List<Map<String, String>>.from(data));
  }

  Future<void> _persistMessage(String role, String text) async {
    await Hive.box('chatBox').add({
      'role': role,
      'text': text,
      'time': DateTime.now().toIso8601String(),
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final userMessage = _controller.text.trim();
    if (userMessage.isEmpty) return;

    _controller.clear();
    _focusNode.requestFocus();

    setState(() {
      messages.add({'role': 'user', 'text': userMessage});
      isTyping = true;
    });

    await _persistMessage('user', userMessage);
    _scrollToBottom();

    // ── route: summarize ──
    if (userMessage.toLowerCase().contains('summarize')) {
      setState(() => isTyping = false);
      if (!mounted) return;
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const SummaryScreen()));
      return;
    }

    // ── route: schedule ──
    if (userMessage.toLowerCase().contains('schedule')) {
      final prompt =
          'Extract a calendar event from the text below and reply ONLY '
          'with valid JSON, no explanation, no markdown.\n'
          'JSON format exactly:\n'
          '{\n'
          '  "title": "<event title>",\n'
          '  "date": "<YYYY-MM-DD>",\n'
          '  "time": "<HH:MM>"\n'
          '}\n'
          'Text: $userMessage';

      final aiResponse = await getAIResponseWithMemory(
          [{'role': 'user', 'text': prompt}]);
      final parsed = parseEvent(aiResponse);

      String reply;
      if (parsed != null) {
        reply = '📅 Event created!';
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScheduleScreen(
              preTitle: parsed['title']?.toString(),
              preDate: parsed['date']?.toString(),
              preTime: parsed['time']?.toString(),
            ),
          ),
        );
      } else {
        reply =
            '❌ Could not parse event. Try: "Schedule a meeting tomorrow at 3pm"';
      }

      await _persistMessage('ai', reply);
      setState(() {
        messages.add({'role': 'ai', 'text': reply});
        isTyping = false;
      });
      _scrollToBottom();
      return;
    }

    // ── normal chat ──
    final contextMessages = messages.length > 10
        ? messages.sublist(messages.length - 10)
        : messages;

    final aiResponse = await getAIResponseWithMemory(contextMessages);

    await _persistMessage('ai', aiResponse);
    setState(() {
      messages.add({'role': 'ai', 'text': aiResponse});
      isTyping = false;
    });
    _scrollToBottom();
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Delete all messages?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Hive.box('chatBox').clear();
              setState(() => messages.clear());
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
              child: Icon(Icons.smart_toy_rounded,
                  size: 18, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Assistant',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                Text('Powered by Groq',
                    style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.grey),
            tooltip: 'Clear chat',
            onPressed: _clearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty && !isTyping
                ? const _EmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    itemCount: messages.length + (isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == messages.length && isTyping) {
                        return const _TypingIndicator();
                      }
                      final msg = messages[index];
                      return _MessageBubble(
                        text: msg['text']!,
                        isUser: msg['role'] == 'user',
                      );
                    },
                  ),
          ),
          _InputBar(
            controller: _controller,
            focusNode: _focusNode,
            isTyping: isTyping,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SUB-WIDGETS
// ─────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  const _MessageBubble({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primary
              : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 14.5,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) => _Dot(delay: i * 200)),
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ac, curve: Curves.easeInOut);
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ac.forward();
    });
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 7,
        height: 7,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.4 + 0.5 * _anim.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          Text('Start a conversation',
              style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 15,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text('Try "Schedule a meeting" or ask anything',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isTyping;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isTyping,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, -2))
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onSubmitted: (_) => onSend(),
                  enabled: !isTyping,
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  decoration: const InputDecoration(
                    hintText: 'Type a message…',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            isTyping
                ? const SizedBox(
                    width: 42,
                    height: 42,
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : InkWell(
                    onTap: onSend,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}