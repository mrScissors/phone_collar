import 'package:flutter/material.dart';

class ProgressDialog extends StatelessWidget {
  final ValueNotifier<double> progressNotifier;

  const ProgressDialog({super.key, required this.progressNotifier});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Loading contacts"),
      content: ValueListenableBuilder<double>(
        valueListenable: progressNotifier,
        builder: (context, value, child) {
          final percentage = (value * 100).toStringAsFixed(1);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: value),
              const SizedBox(height: 10),
              Text("$percentage% completed"),
            ],
          );
        },
      ),
    );
  }
}
