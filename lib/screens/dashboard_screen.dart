import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'chat_screen.dart';
import 'schedule_screen.dart';
import 'summary_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chatBox = Hive.box('chatBox');
    final eventBox = Hive.box('eventsBox');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// 📊 STATS CARDS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCard(
                  title: "Chats",
                  value: chatBox.length.toString(),
                  icon: Icons.chat,
                  color: Colors.blue,
                ),
                _buildCard(
                  title: "Events",
                  value: eventBox.length.toString(),
                  icon: Icons.calendar_today,
                  color: Colors.green,
                ),
              ],
            ),

            const SizedBox(height: 20),

            /// 🚀 QUICK ACTIONS
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Quick Actions",
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),

            const SizedBox(height: 10),

            _buildActionButton(
              context,
              "Open Chat",
              Icons.chat,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatScreen()),
              ),
            ),

            _buildActionButton(
              context,
              "Schedule Event",
              Icons.calendar_today,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScheduleScreen()),
              ),
            ),

            _buildActionButton(
              context,
              "Summarize Email",
              Icons.email,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SummaryScreen()),
              ),
            ),

            const SizedBox(height: 20),

            /// 📅 RECENT EVENTS
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Recent Events",
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: ValueListenableBuilder(
                valueListenable: eventBox.listenable(),
                builder: (context, box, _) {
                  if (box.isEmpty) {
                    return const Center(child: Text("No events yet"));
                  }

                  return ListView.builder(
                    itemCount: box.length,
                    itemBuilder: (context, index) {
                      final event = box.getAt(index);

                      return ListTile(
                        leading: const Icon(Icons.event),
                        title: Text(event['title']),
                        subtitle: Text(
                          "${event['date']} • ${event['time']}",
                        ),
                      );
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

  /// 📊 CARD
  Widget _buildCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(title),
          ],
        ),
      ),
    );
  }

  /// 🚀 BUTTON
  Widget _buildActionButton(
    BuildContext context,
    String text,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
        ),
      ),
    );
  }
}