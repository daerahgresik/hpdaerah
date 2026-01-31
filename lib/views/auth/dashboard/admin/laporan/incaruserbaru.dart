import 'package:flutter/material.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/services/auto_qr_service.dart';

class IncarUserBaruPage extends StatefulWidget {
  final UserModel user;
  const IncarUserBaruPage({super.key, required this.user});

  @override
  State<IncarUserBaruPage> createState() => _IncarUserBaruPageState();
}

class _IncarUserBaruPageState extends State<IncarUserBaruPage> {
  final ScrollController _scrollController = ScrollController();
  final _service = AutoQrService.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "TERMINAL AUTO QR",
          style: TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.greenAccent,
        actions: [
          ValueListenableBuilder<List<String>>(
            valueListenable:
                _service.logsNotifier, // Dummy listen just to rebuild if needed
            builder: (context, logs, _) {
              return Switch(
                value: _service.isActive,
                onChanged: (val) {
                  setState(() {
                    // Force rebuild UI state switch
                    _service.toggle();
                  });
                },
                activeColor: Colors.greenAccent,
                inactiveThumbColor: Colors.red,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[900],
            child: ValueListenableBuilder(
              valueListenable: _service.logsNotifier,
              builder: (context, logs, _) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat(
                      'STATUS',
                      _service.isActive ? "RUNNING BG" : "STOPPED",
                      _service.isActive ? Colors.greenAccent : Colors.red,
                    ),
                    _buildStat('LOGS', "${logs.length}", Colors.white),
                    _buildStat('ENGINE', "v4.0 (Global)", Colors.cyan),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1, color: Colors.greenAccent),
          Expanded(
            child: ValueListenableBuilder<List<String>>(
              valueListenable: _service.logsNotifier,
              builder: (context, logs, _) {
                // Auto Scroll
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    return Text(
                      logs[index],
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 10,
            fontFamily: 'monospace',
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
