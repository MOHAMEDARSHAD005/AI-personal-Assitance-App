import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'task_screen.dart';
import 'summary_screen.dart';
import 'schedule_screen.dart';

/// ================== GROQ API ==================
const String _groqUrl = 'https://api.groq.com/openai/v1/chat/completions';
const String _groqModel = 'llama-3.3-70b-versatile';

Future<String> getAIResponseWithMemory(
  List<Map<String, String>> messages,
) async {
  final apiKey = dotenv.env['GROQ_API_KEY'] ?? '';

  if (apiKey.isEmpty) {
    return '❌ GROQ_API_KEY missing in .env';
  }

  final apiMessages = [
    {
      'role': 'system',
      'content': 'You are a helpful AI assistant. Be concise and clear.',
    },
  ];

  for (final msg in messages) {
    apiMessages.add({
      'role': msg['role'] == 'user' ? 'user' : 'assistant',
      'content': msg['text'] ?? '',
    });
  }

  final response = await http.post(
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
    }),
  );

  final data = jsonDecode(response.body);

  return data['choices']?[0]?['message']?['content'] ?? 'No response';
}

/// ================== PARSER ==================
Map<String, dynamic>? parseEvent(String response) {
  try {
    final start = response.indexOf('{');
    final end = response.lastIndexOf('}');
    if (start == -1 || end == -1) return null;

    return jsonDecode(response.substring(start, end + 1));
  } catch (_) {
    return null;
  }
}

/// ================== CHAT SCREEN ==================
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

  /// LOAD CHAT HISTORY (FIXED)
  void _loadMessages() {
    final box = Hive.box('chatBox');

    final data = box.values
        .map(
          (e) => {
            'role': e['role'].toString(),
            'text': e['text'].toString(),
            'time': e['time']?.toString(), // ✅ IMPORTANT FIX
          },
        )
        .toList();

    setState(() => messages = List<Map<String, String>>.from(data));
  }

  /// SAVE MESSAGE (REUSABLE)
  Future<void> _persistMessage(String role, String text) async {
    await Hive.box('chatBox').add({
      'role': role,
      'text': text,
      'time': DateTime.now().toIso8601String(), // ✅ REQUIRED FOR CHART
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

  /// SEND MESSAGE
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

    /// SUMMARIZER
    if (userMessage.toLowerCase().contains('summarize')) {
      setState(() => isTyping = false);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SummaryScreen()),
      );
      return;
    }

    /// 📝 TASK CREATION (AI)
    if (userMessage.toLowerCase().contains("task") ||
        userMessage.toLowerCase().contains("remind") ||
        userMessage.toLowerCase().contains("todo")) {
      final prompt =
          """
Extract a task from this text.
Return ONLY plain text task title.

Text: $userMessage
""";

      final aiResponse = await getAIResponseWithMemory([
        {"role": "user", "text": prompt},
      ]);

      final taskBox = Hive.box('tasksBox');

      await taskBox.add({"title": aiResponse, "isDone": false});

      await _persistMessage("ai", "✅ Task added: $aiResponse");

      setState(() {
        messages.add({"role": "ai", "text": "✅ Task added: $aiResponse"});
        isTyping = false;
      });

      _scrollToBottom();
      return;
    }

    /// SCHEDULER
    if (userMessage.toLowerCase().contains('schedule')) {
      final prompt =
          """
Extract event details and return ONLY JSON:
{
  "title": "...",
  "date": "YYYY-MM-DD",
  "time": "HH:MM"
}
Text: $userMessage
""";

      final aiResponse = await getAIResponseWithMemory([
        {'role': 'user', 'text': prompt},
      ]);

      final parsed = parseEvent(aiResponse);

      String reply;

      if (parsed != null) {
        reply = "📅 Event created!";
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScheduleScreen(
              preTitle: parsed['title'],
              preDate: parsed['date'],
              preTime: parsed['time'],
            ),
          ),
        );
      } else {
        reply = "❌ Could not understand event";
      }

      await _persistMessage('ai', reply);

      setState(() {
        messages.add({'role': 'ai', 'text': reply});
        isTyping = false;
      });

      _scrollToBottom();
      return;
    }

    /// NORMAL CHAT
    final recentMessages = messages.length > 6
        ? messages.sublist(messages.length - 6)
        : messages;

    final aiResponse = await getAIResponseWithMemory(recentMessages);

    await _persistMessage('ai', aiResponse);

    setState(() {
      messages.add({'role': 'ai', 'text': aiResponse});
      isTyping = false;
    });

    _scrollToBottom();
  }

  void _clearChat() {
    Hive.box('chatBox').clear();
    setState(() => messages.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Assistant"),
        actions: [
          IconButton(icon: const Icon(Icons.delete), onPressed: _clearChat),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: messages.length + (isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == messages.length && isTyping) {
                  return const Padding(
                    padding: EdgeInsets.all(10),
                    child: Text("AI is typing... 🤖"),
                  );
                }

                final msg = messages[index];
                final isUser = msg['role'] == 'user';

                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      msg['text']!,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          /// INPUT
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
            ],
          ),
        ],
      ),
    );
  }
}
