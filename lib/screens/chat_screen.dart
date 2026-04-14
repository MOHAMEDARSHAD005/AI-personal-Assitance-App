import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<String> getAIResponse(String message) async {
  final apiKey = dotenv.env['API_KEY'];

  final url = Uri.parse(
    "https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=$apiKey",
  );

  final response = await http.post(
    url,
    headers: {
      "Content-Type": "application/json",
    },
    body: jsonEncode({
      "contents": [
        {
          "role": "user",
          "parts": [
            {"text": message}
          ]
        }
      ]
    }),
  );

  print("STATUS: ${response.statusCode}");
  print("BODY: ${response.body}");

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data["candidates"]?[0]?["content"]?["parts"]?[0]?["text"] ??
        "No response";
  } else {
    return "Error: ${response.body}";
  }
}
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  List<Map<String, String>> messages = [];

  bool isTyping = false;

  void sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    String userMessage = _controller.text.trim();

    setState(() {
      messages.add({"role": "user", "text": userMessage});
      isTyping = true;
    });

    _controller.clear();
    scrollToBottom();

    // 🔥 REAL API CALL
    String aiResponse = await getAIResponse(userMessage);

    setState(() {
      messages.add({"role": "ai", "text": aiResponse});
      isTyping = false;
    });

    scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Assistant")),
      body: Column(
        children: [
          // Chat messages
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
                        vertical: 5,
                        horizontal: 10,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUser ? Colors.blue : Colors.grey.shade300,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(12),
                          topRight: const Radius.circular(12),
                          bottomLeft: isUser
                              ? const Radius.circular(12)
                              : const Radius.circular(0),
                          bottomRight: isUser
                              ? const Radius.circular(0)
                              : const Radius.circular(12),
                        ),
                      ),
                      child: Text(
                        msg["text"]!,
                        style: TextStyle(
                          color: isUser
                              ? Colors.white
                              : const Color.fromARGB(255, 127, 45, 45),
                        ),
                      ),
                    ),
                  );
                }),

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

          // Input field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: Colors.grey[200],
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Type a message...",
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

