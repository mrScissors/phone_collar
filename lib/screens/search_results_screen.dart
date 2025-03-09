import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SearchResultsScreen extends StatelessWidget {
  final List<dynamic> results;

  SearchResultsScreen({required this.results});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search Results'),
      ),
      body: results.isEmpty
          ? Center(child: Text('No results found, try syncing contacts.'))
          : ListView.builder(
        itemCount: results.length,
        itemBuilder: (context, index) {
          final log = results[index];
          final name = log.name ?? 'Unknown';
          // Ensure phoneNumbers is a List<String> and filter out blank or "na" values
          final List<String> numbers = (log.phoneNumbers is List<String>)
              ? (log.phoneNumbers as List<String>)
              .where((number) =>
          number.trim().isNotEmpty &&
              number.trim().toLowerCase() != 'na' &&

              number != "<NA>")
              .toList()
              : [];

          final numberDisplay =
          numbers.isEmpty ? 'No Number' : numbers.join(', ');

          return ListTile(
            title: Text(name),
            subtitle: Text(numberDisplay),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.call, color: Colors.green),
                  onPressed: () => _makePhoneCall(context, numbers),
                ),
                IconButton(
                  icon: Icon(Icons.message, color: Colors.blue),
                  onPressed: () => _sendMessage(context, numbers),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _makePhoneCall(BuildContext context, List<String> numbers) async {
    if (numbers.isEmpty) return;
    if (numbers.length == 1) {
      final Uri launchUri = Uri(
        scheme: 'tel',
        path: numbers.first,
      );
      await launchUrl(launchUri);
    } else {
      final selectedNumber = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Select Number to Call'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: numbers.map((number) {
                return ListTile(
                  title: Text(number),
                  onTap: () => Navigator.of(context).pop(number),
                );
              }).toList(),
            ),
          );
        },
      );
      if (selectedNumber != null) {
        final Uri launchUri = Uri(
          scheme: 'tel',
          path: selectedNumber,
        );
        await launchUrl(launchUri);
      }
    }
  }

  void _sendMessage(BuildContext context, List<String> numbers) async {
    if (numbers.isEmpty) return;
    if (numbers.length == 1) {
      final Uri launchUri = Uri(
        scheme: 'sms',
        path: numbers.first,
      );
      await launchUrl(launchUri);
    } else {
      final selectedNumber = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Select Number to Message'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: numbers.map((number) {
                return ListTile(
                  title: Text(number),
                  onTap: () => Navigator.of(context).pop(number),
                );
              }).toList(),
            ),
          );
        },
      );
      if (selectedNumber != null) {
        final Uri launchUri = Uri(
          scheme: 'sms',
          path: selectedNumber,
        );
        await launchUrl(launchUri);
      }
    }
  }
}
