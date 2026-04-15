import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'risk_provider.dart';

class RiskEventsScreen extends StatefulWidget {
  final int userId;

  const RiskEventsScreen({super.key, required this.userId});

  @override
  State<RiskEventsScreen> createState() => _RiskEventsScreenState();
}

class _RiskEventsScreenState extends State<RiskEventsScreen> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_loaded) {
      _loaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<RiskProvider>().load(widget.userId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RiskProvider>();

    if (provider.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            provider.error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: provider.events.isEmpty
          ? const Center(child: Text('No risk events yet'))
          : ListView.separated(
              itemCount: provider.events.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) {
                final event = provider.events[index];
                final date = DateFormat('dd MMM yyyy, HH:mm').format(
                  DateTime.parse(event.createdAt),
                );

                return Card(
                  child: ListTile(
                    title: Text('${event.band} • ${event.decision}'),
                    subtitle: Text('Score: ${event.score}\n$date'),
                    isThreeLine: true,
                    trailing: const Icon(Icons.shield),
                  ),
                );
              },
            ),
    );
  }
}