import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'offline_models.dart';

class OfflineDatabaseService {
  OfflineDatabaseService._private();
  static final OfflineDatabaseService instance = OfflineDatabaseService._private();

  static const _rulesKey = 'sight_cached_rules';
  static const _calibrationKey = 'sight_calibration_constant';
  static const _gamificationKey = 'sight_gamification_state';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  Database? _database;
  bool _initialized = false;
  Future<void>? _initializing;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    final initializing = _initializing;
    if (initializing != null) {
      await initializing;
      return;
    }

    _initializing = _initializeInternal();
    try {
      await _initializing;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _initializeInternal() async {
    if (_initialized) {
      return;
    }

    if (kIsWeb) {
      _initialized = true;
      return;
    }

    final databasePath = await getDatabasesPath();
    final path = p.join(databasePath, 'sight_local.db');
    _database = await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.rawQuery('PRAGMA journal_mode=WAL');
      },
    );
    _initialized = true;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE raw_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        childId INTEGER,
        type TEXT NOT NULL,
        value REAL NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE curated_batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        childId INTEGER,
        windowStart INTEGER NOT NULL,
        windowEnd INTEGER NOT NULL,
        averageBlinkRate REAL,
        averageDistanceCm REAL,
        strainEvents INTEGER NOT NULL DEFAULT 0,
        screenTimeMinutes INTEGER NOT NULL DEFAULT 0,
        eventCount INTEGER NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        syncState TEXT NOT NULL DEFAULT 'pending',
        retryCount INTEGER NOT NULL DEFAULT 0,
        lastError TEXT,
        lastSyncAttemptAt INTEGER,
        remoteId TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE child_inventory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        childId INTEGER,
        itemKey TEXT NOT NULL,
        itemName TEXT NOT NULL,
        cost INTEGER NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        acquiredAt INTEGER NOT NULL,
        syncState TEXT NOT NULL DEFAULT 'pending',
        remoteId TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _addColumnIfMissing(db, 'raw_events', 'childId', 'INTEGER');

      await _addColumnIfMissing(db, 'curated_batches', 'childId', 'INTEGER');
      await _addColumnIfMissing(db, 'curated_batches', 'strainEvents', 'INTEGER NOT NULL DEFAULT 0');
      await _addColumnIfMissing(db, 'curated_batches', 'screenTimeMinutes', 'INTEGER NOT NULL DEFAULT 0');
      await _addColumnIfMissing(db, 'curated_batches', 'syncState', "TEXT NOT NULL DEFAULT 'pending'");
      await _addColumnIfMissing(db, 'curated_batches', 'retryCount', 'INTEGER NOT NULL DEFAULT 0');
      await _addColumnIfMissing(db, 'curated_batches', 'lastError', 'TEXT');
      await _addColumnIfMissing(db, 'curated_batches', 'lastSyncAttemptAt', 'INTEGER');
      await _addColumnIfMissing(db, 'curated_batches', 'remoteId', 'TEXT');

      await _addColumnIfMissing(db, 'child_inventory', 'childId', 'INTEGER');
      await _addColumnIfMissing(db, 'child_inventory', 'syncState', "TEXT NOT NULL DEFAULT 'pending'");
      await _addColumnIfMissing(db, 'child_inventory', 'remoteId', 'TEXT');
    }
  }

  Future<void> _addColumnIfMissing(Database db, String tableName, String columnName, String definition) async {
    final tableInfo = await db.rawQuery('PRAGMA table_info($tableName)');
    final exists = tableInfo.any((row) => row['name'] == columnName);
    if (exists) {
      return;
    }

    await db.execute('ALTER TABLE $tableName ADD COLUMN $columnName $definition');
  }

  Database get _db {
    final database = _database;
    if (database == null) {
      throw StateError('OfflineDatabaseService not initialized');
    }
    return database;
  }

  Future<void> saveCalibrationConstant(double constant) async {
    await initialize();
    await _secureStorage.write(key: _calibrationKey, value: constant.toString());
  }

  Future<double?> loadCalibrationConstant() async {
    await initialize();
    final value = await _secureStorage.read(key: _calibrationKey);
    return double.tryParse(value ?? '');
  }

  Future<void> saveCachedRules(CachedRules rules) async {
    await initialize();
    await _secureStorage.write(key: _rulesKey, value: jsonEncode(rules.toJson()));
  }

  Future<CachedRules?> loadCachedRules() async {
    await initialize();
    final raw = await _secureStorage.read(key: _rulesKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return CachedRules.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveGamificationState(GamificationState state) async {
    await initialize();
    await _secureStorage.write(key: _gamificationKey, value: jsonEncode(state.toJson()));
  }

  Future<GamificationState?> loadGamificationState() async {
    await initialize();
    final raw = await _secureStorage.read(key: _gamificationKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return GamificationState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<int> insertRawEvent(LocalMetricEvent event) async {
    await initialize();
    return _db.insert('raw_events', event.toMap()..remove('id'));
  }

  Future<List<LocalMetricEvent>> loadRawEventsSince(DateTime start) async {
    await initialize();
    final rows = await _db.query(
      'raw_events',
      where: 'timestamp >= ?',
      whereArgs: [start.millisecondsSinceEpoch],
      orderBy: 'timestamp ASC',
    );
    return rows.map(LocalMetricEvent.fromMap).toList(growable: false);
  }

  Future<int> deleteRawEventsBefore(DateTime cutoff) async {
    await initialize();
    return _db.delete(
      'raw_events',
      where: 'timestamp < ?',
      whereArgs: [cutoff.millisecondsSinceEpoch],
    );
  }

  Future<int> insertCuratedBatch(CuratedMetricBatch batch) async {
    await initialize();
    return _db.insert('curated_batches', batch.toMap()..remove('id'));
  }

  Future<List<CuratedMetricBatch>> loadPendingBatches() async {
    await initialize();
    final rows = await _db.query(
      'curated_batches',
      where: 'syncState != ? OR syncState IS NULL',
      whereArgs: [SyncState.synced.key],
      orderBy: 'windowEnd ASC',
    );
    return rows.map(CuratedMetricBatch.fromMap).toList(growable: false);
  }

  /// Load curated batches for a specific child within a date range
  Future<List<CuratedMetricBatch>> loadBatchesForChild(int childId, DateTime start, DateTime end) async {
    await initialize();
    final rows = await _db.query(
      'curated_batches',
      where: 'childId = ? AND windowEnd >= ? AND windowStart <= ?',
      whereArgs: [childId, start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'windowEnd ASC',
    );
    return rows.map(CuratedMetricBatch.fromMap).toList(growable: false);
  }

  Future<int> markBatchSynced(int id, {String? remoteId}) async {
    await initialize();
    return _db.update(
      'curated_batches',
      {
        'synced': 1,
        'syncState': SyncState.synced.key,
        'lastError': null,
        'lastSyncAttemptAt': DateTime.now().millisecondsSinceEpoch,
        'remoteId': remoteId,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> markBatchSyncAttempt(int id, {required int retryCount}) async {
    await initialize();
    return _db.update(
      'curated_batches',
      {
        'retryCount': retryCount,
        'lastSyncAttemptAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> markBatchSyncFailed(int id, {required int retryCount, required String error}) async {
    await initialize();
    return _db.update(
      'curated_batches',
      {
        'syncState': SyncState.failed.key,
        'retryCount': retryCount,
        'lastError': error,
        'lastSyncAttemptAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> addInventoryItem({
    int? childId,
    required String itemKey,
    required String itemName,
    required int cost,
  }) async {
    await initialize();
    return _db.insert('child_inventory', {
      'childId': childId,
      'itemKey': itemKey,
      'itemName': itemName,
      'cost': cost,
      'quantity': 1,
      'acquiredAt': DateTime.now().millisecondsSinceEpoch,
      'syncState': SyncState.pending.key,
    });
  }
}