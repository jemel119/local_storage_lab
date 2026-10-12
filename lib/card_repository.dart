
import 'package:sqflite/sqflite.dart';

import 'card_model.dart';
import 'database_helper.dart';

class CardRepository {
  final DatabaseHelper helper;

  CardRepository(this.helper);

  Future<int> insertCard(CardModel card) async {
    final db = await helper.database;

    return await db.insert(
      DatabaseHelper.cardsTable,
      card.toMap(),
    );
  }

  Future<List<CardModel>> getAllCards() async {
    final db = await helper.database;

    final rows = await db.query(
      DatabaseHelper.cardsTable,
      orderBy: 'id ASC',
    );

    return rows.map((row) => CardModel.fromMap(row)).toList();
  }

  Future<List<CardModel>> getCardsByFolder(int folderId) async {
    final db = await helper.database;

    final rows = await db.query(
      DatabaseHelper.cardsTable,
      where: 'folder_id = ?',
      whereArgs: [folderId],
      orderBy: 'id ASC',
    );

    return rows.map((row) => CardModel.fromMap(row)).toList();
  }

  Future<CardModel?> getCardById(int id) async {
    final db = await helper.database;

    final rows = await db.query(
      DatabaseHelper.cardsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return CardModel.fromMap(rows.first);
  }

  Future<int> updateCard(CardModel card) async {
    final db = await helper.database;

    if (card.id == null) {
      throw ArgumentError('Card ID is required for updates.');
    }

    return await db.update(
      DatabaseHelper.cardsTable,
      card.toMap(),
      where: 'id = ?',
      whereArgs: [card.id],
    );
  }

  Future<int> deleteCard(int id) async {
    final db = await helper.database;

    return await db.delete(
      DatabaseHelper.cardsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> countCards() async {
    final db = await helper.database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM ${DatabaseHelper.cardsTable}',
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countCardsByFolder(int folderId) async {
    final db = await helper.database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM ${DatabaseHelper.cardsTable} '
      'WHERE folder_id = ?',
      [folderId],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }
}
