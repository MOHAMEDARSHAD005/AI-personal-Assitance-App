import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class TaskScreen extends StatefulWidget {
  final String? preTask;

  const TaskScreen({super.key, this.preTask});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();

    if (widget.preTask != null) {
      _controller.text = widget.preTask!;
    }
  }

  void addTask() async {
    if (_controller.text.trim().isEmpty) return;

    final box = Hive.box('tasksBox');

    await box.add({
      "title": _controller.text,
      "isDone": false,
    });

    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('tasksBox');

    return Scaffold(
      appBar: AppBar(title: const Text("Task Manager")),
      body: Column(
        children: [
          /// INPUT
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Enter task...",
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: addTask,
                )
              ],
            ),
          ),

          /// TASK LIST
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: box.listenable(),
              builder: (context, box, _) {
                if (box.isEmpty) {
                  return const Center(child: Text("No tasks yet"));
                }

                return ListView.builder(
                  itemCount: box.length,
                  itemBuilder: (context, index) {
                    final task = box.getAt(index);

                    return ListTile(
                      leading: Checkbox(
                        value: task["isDone"],
                        onChanged: (val) {
                          task["isDone"] = val;
                          box.putAt(index, task);
                        },
                      ),
                      title: Text(
                        task["title"],
                        style: TextStyle(
                          decoration: task["isDone"]
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => box.deleteAt(index),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}