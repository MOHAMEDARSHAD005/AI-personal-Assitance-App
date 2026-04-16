import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

import 'chat_screen.dart';
import 'schedule_screen.dart';
import 'summary_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  /// 📊 REAL CHAT DATA (LAST 7 DAYS)
  List<int> getChatData() {
    final box = Hive.box('chatBox');

    List<int> counts = List.filled(7, 0);
    DateTime now = DateTime.now();

    for (var msg in box.values) {
      if (msg['time'] == null) continue;

      DateTime msgTime = DateTime.parse(msg['time']);
      int diff = now.difference(msgTime).inDays;

      if (diff >= 0 && diff < 7) {
        counts[6 - diff]++;
      }
    }

    return counts;
  }

  /// 📈 BAR CHART
  Widget buildChart() {
    final data = getChatData();
    final now = DateTime.now();

    final days = List.generate(7, (index) {
      final date = now.subtract(Duration(days: 6 - index));
      return ["S", "M", "T", "W", "T", "F", "S"][date.weekday % 7];
    });

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      days[value.toInt()],
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(7, (index) {
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: data[index].toDouble(),
                  width: 16,
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

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
            /// 📊 STATS
            Row(
              children: [
                _buildCard(
                  title: "Chats",
                  value: chatBox.length.toString(),
                  icon: Icons.chat,
                  color: Colors.blue,
                ),
                const SizedBox(width: 10),
                _buildCard(
                  title: "Events",
                  value: eventBox.length.toString(),
                  icon: Icons.calendar_today,
                  color: Colors.green,
                ),
              ],
            ),

            const SizedBox(height: 20),

            /// 🚀 ACTIONS
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

            /// 📈 CHART
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Chat Activity (Last 7 Days)",
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),

            const SizedBox(height: 10),

            buildChart(),

            const SizedBox(height: 20),

            /// 📅 EVENTS
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