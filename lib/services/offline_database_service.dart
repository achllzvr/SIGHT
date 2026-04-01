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
      version: 1,
      onCreate: _onCreate,
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
        type TEXT NOT NULL,
        value REAL NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE curated_batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        windowStart INTEGER NOT NULL,
        windowEnd INTEGER NOT NULL,
        averageBlinkRate REAL,
        averageDistanceCm REAL,
        eventCount INTEGER NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE child_inventory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        itemKey TEXT NOT NULL,
        itemName TEXT NOT NULL,
        cost INTEGER NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        acquiredAt INTEGER NOT NULL
      )
    ''');
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
    final rows = await _db.query('curated_batches', where: 'synced = 0', orderBy: 'windowEnd ASC');
    return rows.map(CuratedMetricBatch.fromMap).toList(growable: false);
  }

  Future<int> markBatchSynced(int id) async {
    await initialize();
    return _db.update('curated_batches', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> addInventoryItem({
    required String itemKey,
    required String itemName,
    required int cost,
  }) async {
    await initialize();
    return _db.insert('child_inventory', {
      'itemKey': itemKey,
      'itemName': itemName,
      'cost': cost,
      'quantity': 1,
      'acquiredAt': DateTime.now().millisecondsSinceEpoch,
    });
  }
}