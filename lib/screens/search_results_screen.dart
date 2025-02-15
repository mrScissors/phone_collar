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
          ? Center(child: Text('No results found.'))
          : ListView.builder(
        itemCount: results.length,
        itemBuilder: (context, index) {
          final log = results[index];
          final name = log.name ?? 'Unknown';
          final number = log.phone ?? 'No Number';

          return ListTile(
            title: Text(name),
            subtitle: Text(number),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.call, color: Colors.green),
                  onPressed: () => _makePhoneCall(number),
                ),
                IconButton(
                  icon: Icon(Icons.message, color: Colors.blue),
                  onPressed: () => _sendMessage(number),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _makePhoneCall(String number) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: number,
    );
    await launchUrl(launchUri);
  }

  void _sendMessage(String number) async {
    final Uri launchUri = Uri(
      scheme: 'sms',
      path: number,
    );
    await launchUrl(launchUri);
  }
}
