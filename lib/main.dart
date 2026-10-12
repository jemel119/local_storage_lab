
import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'folder.dart';
import 'folder_repository.dart';
import 'card_screen.dart';

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
    if (_busy || _loading && _guests.isNotEmpty) return;

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
      _nameController.text = guest[DatabaseHelper.columnName] as String;
      _ageController.text = '${guest[DatabaseHelper.columnAge]}';
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

  Future<void> _deleteGuest(Map<String, dynamic> guest) async {
    if (_busy || _loading) return;

    final id = guest[DatabaseHelper.columnId] as int;
    final name = guest[DatabaseHelper.columnName] as String;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Guest'),
          content: Text(
            'Are you sure you want to delete $name (ID: $id)?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true || _busy || _loading) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    bool deleteSucceeded = false;
    String? resultMessage;

    try {
      final deleted = await widget.helper.delete(id);

      if (deleted == 1) {
        deleteSucceeded = true;
        resultMessage =
            'Guest ID $id deleted. Rows affected: $deleted.';
      } else if (deleted == 0) {
        resultMessage =
            'Guest ID $id was not found. Rows affected: 0.';
      } else {
        resultMessage =
            'Unexpected delete result: $deleted rows affected.';
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to delete guest: $error\n$stackTrace');
      resultMessage = 'Could not delete guest. Please try again.';
    }

    if (!mounted) return;

    if (deleteSucceeded && _selectedId == id) {
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
          : deleteSucceeded
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
        actions: [
          IconButton(
            icon: const Icon(Icons.folder),
            tooltip: 'Manage Folders',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FolderScreen(helper: widget.helper),
                ),
              );
            },
          ),
        ],
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
                        onPressed: (_busy || _loading) ? null : _saveGuest,
                        child: Text(
                          _selectedId == null ? 'Add Guest' : 'Save Changes',
                        ),
                      ),
                      if (_selectedId != null) ...[
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: (_busy || _loading) ? null : _cancelEdit,
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
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        tooltip: 'Edit guest',
                                        onPressed: (_busy || _loading)
                                            ? null
                                            : () => _editGuest(guest),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        tooltip: 'Delete guest',
                                        onPressed: (_busy || _loading)
                                            ? null
                                            : () => _deleteGuest(guest),
                                      ),
                                    ],
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

class FolderScreen extends StatefulWidget {
  final DatabaseHelper helper;

  const FolderScreen({super.key, required this.helper});

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  late final FolderRepository _repository;

  List<Folder> _folders = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    _repository = FolderRepository(widget.helper);
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    if (_busy) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final folders = await _repository.getAllFolders();

      if (!mounted) return;

      setState(() {
        _folders = folders;
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to load folders: $error\n$stackTrace');

      if (!mounted) return;

      setState(() {
        _error = 'Could not load folders.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _showFolderDialog({Folder? folder}) async {
    if (_busy || _loading) return;

    final controller = TextEditingController(text: folder?.name ?? '');
    final formKey = GlobalKey<FormState>();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(folder == null ? 'New Folder' : 'Rename Folder'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Folder Name',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Folder name is required.';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, controller.text.trim());
                }
              },
              child: Text(folder == null ? 'Create' : 'Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!mounted || name == null || _busy || _loading) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    bool saved = false;
    String resultMessage;

    try {
      if (folder == null) {
        final id = await _repository.insertFolder(
          Folder(
            name: name,
            createdAt: DateTime.now().toIso8601String(),
          ),
        );
        saved = true;
        resultMessage = 'Folder created with ID $id.';
      } else {
        final affected = await _repository.updateFolder(
          Folder(
            id: folder.id,
            name: name,
            createdAt: folder.createdAt,
          ),
        );
        saved = affected == 1;
        resultMessage = 'Folder update affected $affected row(s).';
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to save folder: $error\n$stackTrace');
      resultMessage = 'Could not save folder. Check for duplicate names.';
    }

    if (!mounted) return;

    bool refreshed = false;

    try {
      final folders = await _repository.getAllFolders();
      if (!mounted) return;
      setState(() {
        _folders = folders;
        _error = null;
      });
      refreshed = true;
    } catch (error, stackTrace) {
      debugPrint('Failed to refresh folders: $error\n$stackTrace');
    }

    if (!mounted) return;

    setState(() {
      _busy = false;
      _message = refreshed
          ? resultMessage
          : saved
              ? '$resultMessage Refresh failed.'
              : '$resultMessage Could not refresh folders.';
    });
  }

  Future<void> _deleteFolder(Folder folder) async {
    if (_busy || _loading) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text(
          'Delete "${folder.name}" and all cards inside it?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true || _busy || _loading) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    bool deleted = false;
    String resultMessage;

    try {
      final affected = await _repository.deleteFolder(folder.id!);
      deleted = affected == 1;
      resultMessage = 'Folder deletion affected $affected row(s).';
    } catch (error, stackTrace) {
      debugPrint('Failed to delete folder: $error\n$stackTrace');
      resultMessage = 'Could not delete folder.';
    }

    if (!mounted) return;

    bool refreshed = false;

    try {
      final folders = await _repository.getAllFolders();
      if (!mounted) return;
      setState(() {
        _folders = folders;
        _error = null;
      });
      refreshed = true;
    } catch (error, stackTrace) {
      debugPrint('Failed to refresh folders: $error\n$stackTrace');
    }

    if (!mounted) return;

    setState(() {
      _busy = false;
      _message = refreshed
          ? resultMessage
          : deleted
              ? '$resultMessage Refresh failed.'
              : '$resultMessage Could not refresh folders.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Folders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh folders',
            onPressed: (_busy || _loading) ? null : _loadFolders,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: (_busy || _loading) ? null : () => _showFolderDialog(),
        tooltip: 'Add folder',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          if (_message != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_message!),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _folders.isEmpty
                        ? const Center(child: Text('No folders yet'))
                        : ListView.builder(
                            itemCount: _folders.length,
                            itemBuilder: (context, index) {
                              final folder = _folders[index];

                              return ListTile(
                                leading: const Icon(Icons.folder),
                                title: Text(folder.name),
                                subtitle: Text('ID: ${folder.id}'),
                                onTap: (_busy || _loading)
                                    ? null
                                    : () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => CardScreen(
                                              helper: widget.helper,
                                              folder: folder,
                                            ),
                                          ),
                                        );
                                      },
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      tooltip: 'Rename folder',
                                      onPressed: (_busy || _loading)
                                          ? null
                                          : () => _showFolderDialog(
                                                folder: folder,
                                              ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      tooltip: 'Delete folder',
                                      onPressed: (_busy || _loading)
                                          ? null
                                          : () => _deleteFolder(folder),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
