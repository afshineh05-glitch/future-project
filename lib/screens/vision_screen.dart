import 'package:flutter/material.dart';

class VisionScreen extends StatefulWidget {
  const VisionScreen({super.key});

  @override
  State<VisionScreen> createState() => _VisionScreenState();
}

class _VisionScreenState extends State<VisionScreen> {
  final List<Map<String, dynamic>> goals = [
    {
      'title': 'Learn Flutter',
      'done': false,
    },
    {
      'title': 'Build Future Project',
      'done': false,
    },
    {
      'title': 'Launch MVP',
      'done': false,
    },
  ];

  void addGoal() {
    final TextEditingController controller = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Goal'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter your goal',
            ),
            onSubmitted: (_) {
              saveGoal(controller, dialogContext);
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                saveGoal(controller, dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    ).whenComplete(controller.dispose);
  }

  void saveGoal(
    TextEditingController controller,
    BuildContext dialogContext,
  ) {
    final String title = controller.text.trim();

    if (title.isEmpty) {
      return;
    }

    setState(() {
      goals.add({
        'title': title,
        'done': false,
      });
    });

    Navigator.pop(dialogContext);
  }

  void toggleGoal(int index, bool? value) {
    setState(() {
      goals[index]['done'] = value ?? false;
    });
  }

  void deleteGoal(int index) {
    setState(() {
      goals.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Vision'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: addGoal,
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'My Goals',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          if (goals.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(
                child: Text(
                  'No goals yet.\nTap + to add your first goal.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white60,
                  ),
                ),
              ),
            )
          else
            ...goals.asMap().entries.map((entry) {
              final int index = entry.key;
              final Map<String, dynamic> goal = entry.value;

              final String title = goal['title'] as String;
              final bool isDone = goal['done'] as bool;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Checkbox(
                    value: isDone,
                    onChanged: (value) {
                      toggleGoal(index, value);
                    },
                  ),
                  title: Text(
                    title,
                    style: TextStyle(
                      decoration:
                          isDone ? TextDecoration.lineThrough : null,
                      color: isDone ? Colors.white54 : Colors.white,
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: 'Delete goal',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: () {
                      deleteGoal(index);
                    },
                  ),
                ),
              );
            }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}