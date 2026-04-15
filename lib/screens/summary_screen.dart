import 'package:flutter/material.dart';
import 'chat_screen.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final TextEditingController _controller = TextEditingController();

  String summary = "";
  bool isLoading = false;
void summarizeText() async {
  if (_controller.text.trim().isEmpty) return;

  setState(() {
    isLoading = true;
  });

  try {
    String prompt =
        "Summarize the following email in a short and clear way:\n\n${_controller.text}";

    String aiResponse = await getAIResponseWithMemory([
      {"role": "user", "text": prompt}
    ]);

    setState(() {
      summary = aiResponse;
      isLoading = false;
    });
  } catch (e) {
    setState(() {
      summary = "Error summarizing email 😢";
      isLoading = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Email Summarizer")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: "Paste your email here...",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: summarizeText,
              child: const Text("Summarize"),
            ),

            const SizedBox(height: 20),

            if (isLoading) const CircularProgressIndicator(),

            if (summary.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.grey.shade200,
                child: Text(summary),
              ),
          ],
        ),
      ),
    );
  }
}