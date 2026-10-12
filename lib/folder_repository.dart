
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'folder.dart';

class FolderRepository {
  final DatabaseHelper helper;

  FolderRepository(this.helper);

  Future<int> insertFolder(Folder folder) async {
    final db = await helper.database;

    return await db.insert(
      DatabaseHelper.foldersTable,
      folder.toMap(),
    );
  }

  Future<List<Folder>> getAllFolders() async {
    final db = await helper.database;

    final rows = await db.query(
      DatabaseHelper.foldersTable,
      orderBy: 'name ASC',
    );

    return rows.map((row) => Folder.fromMap(row)).toList();
  }

  Future<Folder?> getFolderById(int id) async {
    final db = await helper.database;

    final rows = await db.query(
      DatabaseHelper.foldersTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return Folder.fromMap(rows.first);
  }

  Future<int> updateFolder(Folder folder) async {
    final db = await helper.database;

    if (folder.id == null) {
      throw ArgumentError('Folder ID is required for updates.');
    }

    return await db.update(
      DatabaseHelper.foldersTable,
      folder.toMap(),
      where: 'id = ?',
      whereArgs: [folder.id],
    );
  }

  Future<int> deleteFolder(int id) async {
    final db = await helper.database;

    return await db.delete(
      DatabaseHelper.foldersTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> countFolders() async {
    final db = await helper.database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM ${DatabaseHelper.foldersTable}',
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }
}
