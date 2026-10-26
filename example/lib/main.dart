import 'package:flutter/material.dart';
import 'package:cidan/cidan.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Option 1: Run CIDAN directly as the standalone application
  runApp(cidan.application());
}

/// Demonstrates embedding CIDAN inside an existing host application
class HostAppExample extends StatelessWidget {
  const HostAppExample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Host Banking App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
        useMaterial3: true,
      ),
      home: const HostHomeScreen(),
    );
  }
}

class HostHomeScreen extends StatelessWidget {
  const HostHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enterprise Portal'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.account_balance_rounded,
                size: 64,
                color: Color(0xFF4F46E5),
              ),
              const SizedBox(height: 16),
              const Text(
                'Enterprise Banking Dashboard',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Launch the CIDAN Regulatory Ingestion & Validation AI Suite below:',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  // Navigate to CIDAN in embedded mode
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => cidan.application(standalone: false),
                    ),
                  );
                },
                icon: const Icon(Icons.shield_rounded),
                label: const Text('Open CIDAN Compliance AI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
