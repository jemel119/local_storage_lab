# Activity 09: SQLite Folder and Card Organizer

**Student:** Jeremy Henry-Atohengbe  
**Level:** Graduate  
**Project:** `local_storage_lab`  
**Framework:** Flutter / Dart  
**Database:** SQLite (`sqflite`)

## Project Overview

This project extends Activity 08's Fall Festival Guest Roster by adding a folder and card organizer using SQLite.

The application supports guest management, folder management, and card management while preserving the original guest database through a version 1 to version 2 schema migration.

## Features

### Guest Roster: Activity 08

- Add guests with a name and age.
- View guests and their database IDs.
- Edit existing guests.
- Delete guests with confirmation.
- Display the total guest count.
- Validate guest names and ages.
- Refresh records from SQLite.

### Folder Management: Activity 09

- Create folders.
- Display saved folders.
- Rename existing folders.
- Delete folders with confirmation.
- Prevent empty folder names.
- Enforce unique folder names through SQLite.

### Card Management: Activity 09

- Create cards inside folders.
- Display cards belonging to the selected folder.
- Edit card information.
- Delete cards with confirmation.
- Store card titles, suits, notes, and optional image references.
- Display suit-specific icons and a fallback when no image is provided.

## Database Structure

The application uses the existing `MyDatabase.db` SQLite database.

### Version 1 — Activity 08

**Table:** `my_table`

| Column | Type |
|---|---|
| `_id` | INTEGER PRIMARY KEY |
| `name` | TEXT NOT NULL |
| `age` | INTEGER NOT NULL |

### Version 2: Activity 09

**Table:** `folders`

| Column | Type |
|---|---|
| `id` | INTEGER PRIMARY KEY AUTOINCREMENT |
| `name` | TEXT NOT NULL UNIQUE |
| `created_at` | TEXT NOT NULL |

**Table:** `cards`

| Column | Type |
|---|---|
| `id` | INTEGER PRIMARY KEY AUTOINCREMENT |
| `title` | TEXT NOT NULL |
| `suit` | TEXT NOT NULL |
| `notes` | TEXT NOT NULL DEFAULT '' |
| `image_ref` | TEXT (nullable) |
| `folder_id` | INTEGER NOT NULL |

The `cards.folder_id` column references `folders.id`.

Foreign keys are enabled using:

```sql
PRAGMA foreign_keys = ON;
```

The relationship uses:

```sql
FOREIGN KEY (folder_id)
REFERENCES folders(id)
ON DELETE CASCADE
```

An index on `cards(folder_id)` supports folder-specific card queries.

## Database Migration

The database version was increased from 1 to 2.

For an existing Activity 08 installation, the upgrade creates the new `folders` and `cards` tables without dropping the original `my_table`.

For a fresh installation, the database creation process creates all three tables.

The migration is designed to preserve existing guest records and their IDs.

## Project Files

| File | Purpose |
|---|---|
| `lib/main.dart` | Guest roster and folder management screens |
| `lib/database_helper.dart` | SQLite initialization, migration, and guest CRUD |
| `lib/folder.dart` | Typed folder model |
| `lib/card_model.dart` | Typed card model |
| `lib/folder_repository.dart` | Folder database operations |
| `lib/card_repository.dart` | Card database operations |
| `lib/card_screen.dart` | Card management interface |
| `test/widget_test.dart` | Basic placeholder test |

## Running the Application

Install Flutter and connect an Android device.

From the project directory, run:

```powershell
flutter pub get
flutter analyze
flutter run
```


## Testing

The following behaviors should be verified on an Android device:

1. Existing Activity 08 guests remain after migration.
2. Folder creation, renaming, and deletion work.
3. Empty and duplicate folder names are rejected.
4. Cards can be created, edited, and deleted.
5. Cards are displayed in their correct folders.
6. Canceling a deletion leaves records unchanged.
7. Deleting a folder removes its cards through cascading deletion.
8. Unrelated folders and cards remain unchanged.
9. Data persists after force-stopping and reopening the application.

Actual test outcomes are recorded in `evidence/test_results.md`.

The default Flutter widget test has been replaced with a basic placeholder. It does not validate SQLite functionality; database behavior must be tested separately.

## Screenshot Evidence

Screenshots are stored in the `evidence/` directory.

| Screenshot | Purpose |
|---|---|
| `T1_before.png` | Guest records before migration |
| `T2_cards.png` | Saved cards inside a folder |
| `T4_after.png` | Original guest records after migration and restart |


## Implementation Notes

- All application data is stored locally in SQLite.
- Database operations use repository classes for folders and cards.
- SQL queries use parameterized arguments where applicable.
- Existing guest data is preserved by the migration design.
- Foreign-key cascading deletion maintains folder/card relationships.
- No cloud storage is required.
