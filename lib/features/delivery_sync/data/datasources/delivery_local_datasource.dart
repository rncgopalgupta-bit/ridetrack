import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/delivery_record.dart';
import '../../domain/entities/sync_status.dart';

abstract class IDeliveryLocalDataSource {
  Future<void> initialize();
  Future<List<DeliveryRecord>> getAllDeliveries();
  Future<DeliveryRecord?> getDeliveryById(String id);
  Future<void> saveDelivery(DeliveryRecord delivery);
  Future<List<DeliveryRecord>> getUnsyncedDeliveries();
  Future<void> updateDeliverySyncStatus(
    String id,
    SyncStatus status, {
    int? newServerVersion,
    String? error,
  });
}

class DeliveryLocalDataSource implements IDeliveryLocalDataSource {
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, AppConstants.databaseName);

    return await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE ${AppConstants.deliveryTableName} (
            id TEXT PRIMARY KEY,
            recipient_name TEXT NOT NULL,
            address TEXT NOT NULL,
            phone TEXT NOT NULL,
            status TEXT NOT NULL,
            signature_path TEXT,
            photo_proof_path TEXT,
            completed_at TEXT,
            sync_status TEXT NOT NULL,
            local_version INTEGER NOT NULL,
            server_version INTEGER NOT NULL,
            retry_count INTEGER NOT NULL,
            sync_error TEXT
          )
        ''');

        // Seed initial delivery assignments for the field agent
        final initialDeliveries = [
          const DeliveryRecord(
            id: 'DEL-201',
            recipientName: 'Rahul Verma',
            address: 'Flat 402, Lotus Court, Connaught Place',
            phone: '+91 98765 43210',
            status: 'assigned',
            syncStatus: SyncStatus.synced,
            serverVersion: 1,
            localVersion: 1,
          ),
          const DeliveryRecord(
            id: 'DEL-202',
            recipientName: 'Sneha Patel',
            address: 'Tower B, Tech Mahindra Campus, KG Marg',
            phone: '+91 91234 56789',
            status: 'assigned',
            syncStatus: SyncStatus.synced,
            serverVersion: 1,
            localVersion: 1,
          ),
          const DeliveryRecord(
            id: 'DEL-203',
            recipientName: 'Amit Saxena',
            address: 'Shop 12, Janpath Traditional Bazaar',
            phone: '+91 99887 76655',
            status: 'assigned',
            syncStatus: SyncStatus.synced,
            serverVersion: 1,
            localVersion: 1,
          ),
        ];

        for (final item in initialDeliveries) {
          await db.insert(
            AppConstants.deliveryTableName,
            item.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      },
    );
  }

  @override
  Future<void> initialize() async {
    await database;
  }

  @override
  Future<List<DeliveryRecord>> getAllDeliveries() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.deliveryTableName,
      orderBy: 'id ASC',
    );

    return maps.map((m) => DeliveryRecord.fromMap(m)).toList();
  }

  @override
  Future<DeliveryRecord?> getDeliveryById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.deliveryTableName,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return DeliveryRecord.fromMap(maps.first);
  }

  @override
  Future<void> saveDelivery(DeliveryRecord delivery) async {
    final db = await database;
    await db.insert(
      AppConstants.deliveryTableName,
      delivery.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<DeliveryRecord>> getUnsyncedDeliveries() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.deliveryTableName,
      where: 'sync_status = ? OR sync_status = ?',
      whereArgs: [SyncStatus.pending.toDbValue(), SyncStatus.failed.toDbValue()],
    );

    return maps.map((m) => DeliveryRecord.fromMap(m)).toList();
  }

  @override
  Future<void> updateDeliverySyncStatus(
    String id,
    SyncStatus status, {
    int? newServerVersion,
    String? error,
  }) async {
    final db = await database;
    final Map<String, dynamic> values = {
      'sync_status': status.toDbValue(),
      'sync_error': error,
    };

    if (newServerVersion != null) {
      values['server_version'] = newServerVersion;
      values['local_version'] = newServerVersion;
    }

    await db.update(
      AppConstants.deliveryTableName,
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
