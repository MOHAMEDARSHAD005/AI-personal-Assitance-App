import 'package:flutter/material.dart';
import 'chat_screen.dart'; // imports getAIResponseWithMemory

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final TextEditingController _controller = TextEditingController();

  String summary = '';
  bool isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _summarizeText() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      isLoading = true;
      summary = '';
    });

    final prompt =
        'Summarize the following email in 3-5 concise bullet points. '
        'Be clear and highlight the key action items:\n\n$text';

    final aiResponse = await getAIResponseWithMemory([
      {'role': 'user', 'text': prompt}
    ]);

    setState(() {
      summary = aiResponse;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text('Email Summarizer',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Input card ──
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: TextField(
                controller: _controller,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: 'Paste your email here…',
                  hintStyle: TextStyle(color: Colors.grey),
                  contentPadding: EdgeInsets.all(16),
                  border: InputBorder.none,
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── Summarize button ──
            ElevatedButton.icon(
              onPressed: isLoading ? null : _summarizeText,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Summarize with Claude'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 20),

            // ── Result ──
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (summary.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.summarize,
                            size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Text('Summary',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(summary,
                        style: const TextStyle(
                            fontSize: 14.5, height: 1.5)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}