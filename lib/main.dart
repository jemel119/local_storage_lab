
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
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  List<Map<String, dynamic>> _guests = [];
  int _count = 0;
  int? _selectedId;

  bool _loading = true;
  bool _busy = false;

  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadGuests();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<bool> _refreshGuests() async {
    try {
      final guests = await widget.helper.queryAllRows();
      final count = await widget.helper.queryRowCount();

      if (!mounted) return false;

      setState(() {
        _guests = guests;
        _count = count;
        _error = null;
      });

      return true;
    } catch (error, stackTrace) {
      debugPrint('Failed to load guests: $error\n$stackTrace');

      if (!mounted) return false;

      setState(() {
        _error = 'Could not load guests. Please try again.';
      });

      return false;
    }
  }

  Future<void> _loadGuests() async {
    if (_busy) return;

    setState(() {
      _loading = true;
      _message = null;
    });

    await _refreshGuests();

    if (!mounted) return;

    setState(() {
      _loading = false;
    });
  }

  void _editGuest(Map<String, dynamic> guest) {
    if (_busy || _loading) return;

    setState(() {
      _selectedId = guest[DatabaseHelper.columnId] as int;
      _nameController.text =
          guest[DatabaseHelper.columnName] as String;
      _ageController.text =
          '${guest[DatabaseHelper.columnAge]}';
      _message = null;
    });

    _formKey.currentState?.reset();
  }

  void _cancelEdit() {
    if (_busy || _loading) return;

    setState(() {
      _selectedId = null;
      _nameController.clear();
      _ageController.clear();
      _message = 'Edit canceled. No changes were saved.';
    });

    _formKey.currentState?.reset();
  }

  Future<void> _saveGuest() async {
    if (_busy || _loading) return;
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text.trim());

    if (age == null) return;

    final selectedId = _selectedId;

    setState(() {
      _busy = true;
      _message = null;
    });

    bool writeSucceeded = false;
    String? resultMessage;

    try {
      if (selectedId == null) {
        final insertedId = await widget.helper.insert({
          DatabaseHelper.columnName: name,
          DatabaseHelper.columnAge: age,
        });

        writeSucceeded = true;
        resultMessage = 'Guest saved with ID $insertedId.';
      } else {
        final updated = await widget.helper.update({
          DatabaseHelper.columnId: selectedId,
          DatabaseHelper.columnName: name,
          DatabaseHelper.columnAge: age,
        });

        if (updated == 1) {
          writeSucceeded = true;
          resultMessage =
              'Guest ID $selectedId updated. Rows affected: $updated.';
        } else if (updated == 0) {
          resultMessage =
              'Guest ID $selectedId was not found. Rows affected: 0.';
        } else {
          resultMessage =
              'Unexpected update result: $updated rows affected.';
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to save guest: $error\n$stackTrace');
      resultMessage = 'Could not save guest. Please try again.';
    }

    if (!mounted) return;

    if (writeSucceeded) {
      _nameController.clear();
      _ageController.clear();
      _formKey.currentState!.reset();

      setState(() {
        _selectedId = null;
      });
    }

    final refreshed = await _refreshGuests();

    if (!mounted) return;

    setState(() {
      _message = refreshed
          ? resultMessage
          : writeSucceeded
              ? '$resultMessage Refresh failed. Tap Refresh.'
              : '$resultMessage Could not refresh the list.';
      _busy = false;
    });
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
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    enabled: !_busy && !_loading,
                    decoration: const InputDecoration(
                      labelText: 'Guest Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a guest name.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ageController,
                    enabled: !_busy && !_loading,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Guest Age',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final age = int.tryParse(value?.trim() ?? '');

                      if (age == null || age < 0 || age > 130) {
                        return 'Enter a whole-number age from 0 to 130.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed:
                            (_busy || _loading) ? null : _saveGuest,
                        child: Text(
                          _selectedId == null
                              ? 'Add Guest'
                              : 'Save Changes',
                        ),
                      ),
                      if (_selectedId != null) ...[
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed:
                              (_busy || _loading) ? null : _cancelEdit,
                          child: const Text('Cancel Edit'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Guest Count: $_count'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: (_busy || _loading) ? null : _loadGuests,
              child: const Text('Refresh'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!),
            ],
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
                                  title: Text(
                                    '${guest[DatabaseHelper.columnName]}',
                                  ),
                                  subtitle: Text(
                                    'ID: ${guest[DatabaseHelper.columnId]} | '
                                    'Age: ${guest[DatabaseHelper.columnAge]}',
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.edit),
                                    tooltip: 'Edit guest',
                                    onPressed: (_busy || _loading)
                                        ? null
                                        : () => _editGuest(guest),
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
