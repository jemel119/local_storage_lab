
import 'package:flutter/material.dart';

import 'card_model.dart';
import 'card_repository.dart';
import 'database_helper.dart';
import 'folder.dart';

class CardScreen extends StatefulWidget {
  final DatabaseHelper helper;
  final Folder folder;

  const CardScreen({
    super.key,
    required this.helper,
    required this.folder,
  });

  @override
  State<CardScreen> createState() => _CardScreenState();
}

class _CardScreenState extends State<CardScreen> {
  late final CardRepository _repository;

  List<CardModel> _cards = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _message;

  static const _suits = [
    'Hearts',
    'Diamonds',
    'Clubs',
    'Spades',
  ];

  @override
  void initState() {
    super.initState();
    _repository = CardRepository(widget.helper);
    _loadCards();
  }

  Future<bool> _refreshCards() async {
    try {
      final cards = await _repository.getCardsByFolder(widget.folder.id!);

      if (!mounted) return false;

      setState(() {
        _cards = cards;
        _error = null;
      });

      return true;
    } catch (error, stackTrace) {
      debugPrint('Failed to load cards: $error\n$stackTrace');

      if (!mounted) return false;

      setState(() {
        _error = 'Could not load cards. Please try again.';
      });

      return false;
    }
  }

  Future<void> _loadCards() async {
    if (_busy || _loading && _cards.isNotEmpty) return;

    setState(() {
      _loading = true;
      _message = null;
    });

    await _refreshCards();

    if (!mounted) return;

    setState(() {
      _loading = false;
    });
  }

  Future<void> _showCardDialog({CardModel? card}) async {
    if (_busy || _loading) return;

    final titleController = TextEditingController(text: card?.title ?? '');
    final notesController = TextEditingController(text: card?.notes ?? '');
    final imageController = TextEditingController(text: card?.imageRef ?? '');
    final formKey = GlobalKey<FormState>();

    String selectedSuit = _suits.contains(card?.suit)
        ? card!.suit
        : _suits.first;

    final result = await showDialog<CardModel>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(card == null ? 'Add Card' : 'Edit Card'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Card Title',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Card title is required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedSuit,
                        decoration: const InputDecoration(
                          labelText: 'Suit',
                        ),
                        items: _suits.map((suit) {
                          return DropdownMenuItem(
                            value: suit,
                            child: Text(suit),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedSuit = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: imageController,
                        decoration: const InputDecoration(
                          labelText: 'Image Reference (optional)',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;

                    final imageRef = imageController.text.trim();

                    Navigator.pop(
                      dialogContext,
                      CardModel(
                        id: card?.id,
                        title: titleController.text.trim(),
                        suit: selectedSuit,
                        notes: notesController.text.trim(),
                        imageRef: imageRef.isEmpty ? null : imageRef,
                        folderId: widget.folder.id!,
                      ),
                    );
                  },
                  child: Text(card == null ? 'Create' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    notesController.dispose();
    imageController.dispose();

    if (!mounted || result == null || _busy || _loading) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    bool saved = false;
    String resultMessage;

    try {
      if (card == null) {
        final id = await _repository.insertCard(result);
        saved = true;
        resultMessage = 'Card created with ID $id.';
      } else {
        final affected = await _repository.updateCard(result);
        saved = affected == 1;
        resultMessage = 'Card update affected $affected row(s).';
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to save card: $error\n$stackTrace');
      resultMessage = 'Could not save card.';
    }

    if (!mounted) return;

    final refreshed = await _refreshCards();

    if (!mounted) return;

    setState(() {
      _busy = false;
      _message = refreshed
          ? resultMessage
          : saved
              ? '$resultMessage Refresh failed. Tap Refresh.'
              : '$resultMessage Could not refresh cards.';
    });
  }

  Future<void> _deleteCard(CardModel card) async {
    if (_busy || _loading) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Card'),
          content: Text('Delete "${card.title}" (ID: ${card.id})?'),
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
        );
      },
    );

    if (!mounted || confirmed != true || _busy || _loading) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    bool deleted = false;
    String resultMessage;

    try {
      final affected = await _repository.deleteCard(card.id!);
      deleted = affected == 1;
      resultMessage = 'Card deletion affected $affected row(s).';
    } catch (error, stackTrace) {
      debugPrint('Failed to delete card: $error\n$stackTrace');
      resultMessage = 'Could not delete card.';
    }

    if (!mounted) return;

    final refreshed = await _refreshCards();

    if (!mounted) return;

    setState(() {
      _busy = false;
      _message = refreshed
          ? resultMessage
          : deleted
              ? '$resultMessage Refresh failed. Tap Refresh.'
              : '$resultMessage Could not refresh cards.';
    });
  }

  IconData _suitIcon(String suit) {
    switch (suit) {
      case 'Hearts':
        return Icons.favorite;
      case 'Diamonds':
        return Icons.diamond;
      case 'Clubs':
        return Icons.filter_vintage;
      case 'Spades':
        return Icons.park;
      default:
        return Icons.style;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh cards',
            onPressed: (_busy || _loading) ? null : _loadCards,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: (_busy || _loading)
            ? null
            : () => _showCardDialog(),
        tooltip: 'Add card',
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
                    : _cards.isEmpty
                        ? const Center(child: Text('No cards yet'))
                        : ListView.builder(
                            itemCount: _cards.length,
                            itemBuilder: (context, index) {
                              final card = _cards[index];

                              return ListTile(
                                leading: Icon(_suitIcon(card.suit)),
                                title: Text(card.title),
                                subtitle: Text(
                                  'ID: ${card.id} | Suit: ${card.suit}\n'
                                  'Notes: ${card.notes}\n'
                                  'Image: ${card.imageRef ?? 'No image'}',
                                ),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      tooltip: 'Edit card',
                                      onPressed: (_busy || _loading)
                                          ? null
                                          : () => _showCardDialog(card: card),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      tooltip: 'Delete card',
                                      onPressed: (_busy || _loading)
                                          ? null
                                          : () => _deleteCard(card),
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
