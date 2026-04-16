import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'summary_screen.dart';
import 'schedule_screen.dart';

/// ================== AI WITH MEMORY ==================
Future<String> getAIResponseWithMemory(
  List<Map<String, String>> messages,
) async {
  final apiKey = dotenv.env['API_KEY'];

  final url = Uri.parse(
    "https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=$apiKey",
  );

  // 🔥 Limit memory
  final recentMessages = messages.length > 6
      ? messages.sublist(messages.length - 6)
      : messages;

  final formattedMessages = recentMessages.map((msg) {
    return {
      "role": msg["role"] == "user" ? "user" : "model",
      "parts": [
        {"text": msg["text"]}
      ],
    };
  }).toList();

  final response = await http.post(
    url,
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "contents": formattedMessages,
    }),
  );

  final data = jsonDecode(response.body);

  return data["candidates"]?[0]?["content"]?["parts"]?[0]?["text"] ??
      "No response";
}

/// ================== PARSER ==================
Map<String, dynamic>? parseEvent(String response) {
  try {
    final start = response.indexOf('{');
    final end = response.lastIndexOf('}');

    if (start == -1 || end == -1) return null;

    String jsonString = response.substring(start, end + 1);
    return jsonDecode(jsonString);
  } catch (e) {
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

  List<Map<String, String>> messages = [];
  bool isTyping = false;

  /// INIT
  @override
  void initState() {
    super.initState();
    loadMessages();
  }

  /// LOAD CHAT HISTORY
  void loadMessages() {
    final box = Hive.box('chatBox');
    final savedMessages = box.values.toList();

    setState(() {
      messages = List<Map<String, String>>.from(savedMessages);
    });
  }

  /// SCROLL
  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  /// SEND MESSAGE
  void sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    String userMessage = _controller.text.trim();
    final chatBox = Hive.box('chatBox');

    // ✅ USER MESSAGE
    setState(() {
      messages.add({"role": "user", "text": userMessage});
      isTyping = true;
    });

    await chatBox.add({
      "role": "user",
      "text": userMessage,
      "time": DateTime.now().toIso8601String(),
    });

    _controller.clear();
    scrollToBottom();

    /// 📧 SUMMARIZER
    if (userMessage.toLowerCase().contains("summarize")) {
      setState(() => isTyping = false);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SummaryScreen()),
      );
      return;
    }

    /// 📅 SCHEDULER
    if (userMessage.toLowerCase().contains("schedule")) {
      String prompt = """
Extract event details from this text and return ONLY JSON like this:
{
  "title": "...",
  "date": "YYYY-MM-DD",
  "time": "HH:MM"
}

Text: $userMessage
""";

      try {
        String aiResponse = await getAIResponseWithMemory([
          {"role": "user", "text": prompt}
        ]);

        final parsed = parseEvent(aiResponse);

        if (parsed != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ScheduleScreen(
                preTitle: parsed["title"],
                preDate: parsed["date"],
                preTime: parsed["time"],
              ),
            ),
          );

          await chatBox.add({
            "role": "ai",
            "text": "📅 Event extracted successfully!",
            "time": DateTime.now().toIso8601String(),
          });

          setState(() {
            messages.add({
              "role": "ai",
              "text": "📅 Event extracted successfully!",
            });
          });
        } else {
          await chatBox.add({
            "role": "ai",
            "text": "❌ Could not understand event",
            "time": DateTime.now().toIso8601String(),
          });

          setState(() {
            messages.add({
              "role": "ai",
              "text": "❌ Could not understand event",
            });
          });
        }
      } catch (e) {
        await chatBox.add({
          "role": "ai",
          "text": "⚠️ Error processing event",
          "time": DateTime.now().toIso8601String(),
        });

        setState(() {
          messages.add({
            "role": "ai",
            "text": "⚠️ Error processing event",
          });
        });
      }

      setState(() => isTyping = false);
      scrollToBottom();
      return;
    }

    /// 🤖 NORMAL CHAT
    try {
      String aiResponse = await getAIResponseWithMemory(messages);

      await chatBox.add({
        "role": "ai",
        "text": aiResponse,
        "time": DateTime.now().toIso8601String(),
      });

      setState(() {
        messages.add({"role": "ai", "text": aiResponse});
      });
    } catch (e) {
      await chatBox.add({
        "role": "ai",
        "text": "Something went wrong 😢",
        "time": DateTime.now().toIso8601String(),
      });

      setState(() {
        messages.add({
          "role": "ai",
          "text": "Something went wrong 😢",
        });
      });
    }

    setState(() => isTyping = false);
    scrollToBottom();
  }

  /// UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Assistant"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              Hive.box('chatBox').clear();
              setState(() => messages.clear());
            },
          )
        ],
      ),
      body: Column(
        children: [
          /// CHAT LIST
          Expanded(
            child: ListView(
              controller: _scrollController,
              children: [
                ...messages.map((msg) {
                  final isUser = msg["role"] == "user";

                  return Align(
                    alignment: isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 5, horizontal: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUser ? Colors.blue : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        msg["text"]!,
                        style: TextStyle(
                          color: isUser ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  );
                }).toList(),

                if (isTyping)
                  const Padding(
                    padding: EdgeInsets.all(10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text("AI is typing... 🤖"),
                    ),
                  ),
              ],
            ),
          ),

          /// INPUT
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: Colors.grey[200],
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => sendMessage(),
                    decoration: const InputDecoration(
                      hintText: "Type a message...",
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: sendMessage,
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  /// CLEANUP
  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}