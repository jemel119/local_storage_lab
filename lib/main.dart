
import 'package:flutter/material.dart';
import 'database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final helper = DatabaseHelper();

  try {
    await helper.init();
  } catch (error, stackTrace) {
    debugPrint('Database initialization failed: $error\n$stackTrace');

    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Could not open local storage. Restart the app and check the logs.',
            ),
          ),
        ),
      ),
    );
    return;
  }

  runApp(DirectoryApp(helper: helper));
}

class DirectoryApp extends StatelessWidget {
  final DatabaseHelper helper;

  const DirectoryApp({super.key, required this.helper});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fall Festival Roster',
      debugShowCheckedModeBanner: false,
      home: DirectoryScreen(helper: helper),
    );
  }
}

class DirectoryScreen extends StatefulWidget {
  final DatabaseHelper helper;

  const DirectoryScreen({super.key, required this.helper});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  List<Map<String, dynamic>> _guests = [];
  int _count = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGuests();
  }

  Future<void> _loadGuests() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final guests = await widget.helper.queryAllRows();
      final count = await widget.helper.queryRowCount();

      if (!mounted) return;

      setState(() {
        _guests = guests;
        _count = count;
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to load guests: $error\n$stackTrace');

      if (!mounted) return;

      setState(() {
        _error = 'Could not load guests. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fall Festival Roster'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Guest Count: $_count'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _loadGuests,
              child: const Text('Refresh'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : _guests.isEmpty
                          ? const Center(
                              child: Text('No festival guests yet'),
                            )
                          : ListView.builder(
                              itemCount: _guests.length,
                              itemBuilder: (context, index) {
                                final guest = _guests[index];

                                return ListTile(
                                  title: Text('${guest[DatabaseHelper.columnName]}'),
                                  subtitle: Text(
                                    'ID: ${guest[DatabaseHelper.columnId]} | '
                                    'Age: ${guest[DatabaseHelper.columnAge]}',
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
