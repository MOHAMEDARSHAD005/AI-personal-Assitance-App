import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

class ScheduleScreen extends StatefulWidget {
  final String? preTitle;
  final String? preDate;
  final String? preTime;

  const ScheduleScreen({
    super.key,
    this.preTitle,
    this.preDate,
    this.preTime,
  });

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final TextEditingController titleController = TextEditingController();

  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  @override
  void initState() {
    super.initState();

    if (widget.preTitle != null) {
      titleController.text = widget.preTitle!;
    }

    if (widget.preDate != null) {
      selectedDate = DateTime.tryParse(widget.preDate!);
    }

    if (widget.preTime != null) {
      final parts = widget.preTime!.split(":");

      if (parts.length == 2) {
        selectedTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    }
  }

  void pickDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );

    if (date != null) {
      setState(() {
        selectedDate = date;
      });
    }
  }

  void pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time != null) {
      setState(() {
        selectedTime = time;
      });
    }
  }

  void saveEvent() async {
    if (titleController.text.isEmpty ||
        selectedDate == null ||
        selectedTime == null) return;

    final box = Hive.box('eventsBox');

    final event = {
      "title": titleController.text,
      "date": DateFormat('dd MMM yyyy').format(selectedDate!),
      "time": selectedTime!.format(context),
    };

    await box.add(event);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Event Saved ✅")),
    );

    titleController.clear();

    setState(() {
      selectedDate = null;
      selectedTime = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('eventsBox');

    return Scaffold(
      appBar: AppBar(title: const Text("Schedule Event")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: "Event Title",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: pickDate,
              child: Text(
                selectedDate == null
                    ? "Select Date"
                    : DateFormat('dd MMM yyyy').format(selectedDate!),
              ),
            ),

            ElevatedButton(
              onPressed: pickTime,
              child: Text(
                selectedTime == null
                    ? "Select Time"
                    : selectedTime!.format(context),
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: saveEvent,
              child: const Text("Save Event"),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: ValueListenableBuilder<Box>(
                valueListenable: box.listenable(),
                builder: (context, box, _) {
                  if (box.isEmpty) {
                    return const Center(child: Text("No events yet"));
                  }

                  return ListView.builder(
                    itemCount: box.length,
                    itemBuilder: (context, index) {
                      final event = box.getAt(index);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: ListTile(
                          title: Text(event['title']),
                          subtitle: Text(
                            "${event['date']} • ${event['time']}",
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              box.deleteAt(index);
                            },
                          ),
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

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }
}