import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_service.dart';
import 'remote_database_service.dart';
import 'offline_service.dart';
import '../models/inventory.dart';

class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  final _dbService = DatabaseService();
  final _remoteService = RemoteDatabaseService();
  StreamSubscription<bool>? _connectivitySub;
  bool _isSyncing = false;
  void Function(int)? onSyncComplete;

  /// Start listening for connectivity changes and auto-sync when online.
  void startAutoSync() {
    _connectivitySub?.cancel();
    _connectivitySub = ConnectivityService.onConnectivityChanged.listen((online) {
      if (online) {
        syncOfflineSales();
      }
    });
    // Also try syncing on startup if already online
    ConnectivityService.isOnline.then((online) {
      if (online) syncOfflineSales();
    });
  }

  void stopAutoSync() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  /// Save a sale offline when network is unavailable.
  /// Each cart item is stored individually with its inventory item info.
  Future<void> saveOfflineSale({
    required String saleId,
    required String userId,
    required DateTime date,
    required String item,
    required int quantity,
    required double price,
    required double discount,
    required double total,
    required double costPrice,
    String? enteredByStaffName,
    String? entryMode,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    String? inventoryItemId,
    int? newStock,
  }) async {
    await _dbService.saveOfflineSale({
      'id': saleId,
      'user_id': userId,
      'date': date.toIso8601String(),
      'item': item,
      'quantity': quantity,
      'price': price,
      'discount': discount,
      'total': total,
      'cost_price': costPrice,
      'entered_by_staff_name': enteredByStaffName,
      'entry_mode': entryMode ?? 'owner',
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_address': customerAddress,
      'inventory_item_id': inventoryItemId,
      'new_stock': newStock,
    });

    // Update local cached inventory stock immediately
    if (inventoryItemId != null) {
      await _updateCachedStock(inventoryItemId, newStock);
    }

    if (kDebugMode) {
      print('[OfflineSync] Sale saved offline: $saleId');
    }
  }

  /// Sync all unsynced offline sales to the server.
  Future<int> syncOfflineSales() async {
    if (_isSyncing) return 0;
    _isSyncing = true;

    int syncedCount = 0;
    try {
      final unsynced = await _dbService.getUnsyncedOfflineSales();
      if (unsynced.isEmpty) return 0;

      if (kDebugMode) {
        print('[OfflineSync] Syncing ${unsynced.length} offline sales...');
      }

      for (final record in unsynced) {
        try {
          final sale = Sale(
            id: record['id'] as String,
            userId: record['user_id'] as String,
            date: DateTime.parse(record['date'] as String),
            item: record['item'] as String,
            quantity: record['quantity'] as int,
            price: (record['price'] as num).toDouble(),
            discount: (record['discount'] as num?)?.toDouble() ?? 0.0,
            total: (record['total'] as num).toDouble(),
            costPrice: (record['cost_price'] as num?)?.toDouble() ?? 0.0,
            enteredByStaffName: record['entered_by_staff_name'] as String?,
            entryMode: record['entry_mode'] as String?,
            customerName: record['customer_name'] as String?,
            customerPhone: record['customer_phone'] as String?,
            customerAddress: record['customer_address'] as String?,
          );

          await _remoteService.recordSale(sale);

          // Update inventory stock on server
          final inventoryItemId = record['inventory_item_id'] as String?;
          final newStock = record['new_stock'] as int?;
          if (inventoryItemId != null && newStock != null) {
            try {
              await _remoteService.updateStock(inventoryItemId, newStock);
            } catch (e) {
              if (kDebugMode) {
                print('[OfflineSync] Stock update failed for $inventoryItemId: $e');
              }
            }
          }

          await _dbService.markOfflineSaleSynced(sale.id);
          syncedCount++;
        } catch (e) {
          if (kDebugMode) {
            print('[OfflineSync] Failed to sync sale ${record['id']}: $e');
          }
          // Continue with next sale — don't stop on individual failures
        }
      }

      // Clean up synced records
      if (syncedCount > 0) {
        await _dbService.clearSyncedOfflineSales();
        if (kDebugMode) {
          print('[OfflineSync] Synced $syncedCount sales successfully');
        }
      }

      onSyncComplete?.call(await getPendingSyncCount());
    } finally {
      _isSyncing = false;
    }

    return syncedCount;
  }

  /// Get count of unsynced offline sales (for UI badges).
  Future<int> getPendingSyncCount() async {
    return await _dbService.getUnsyncedCount();
  }

  /// Cache inventory locally for offline access.
  Future<void> cacheInventory(String userId) async {
    try {
      final inventory = await _remoteService.getInventory(userId);
      await _dbService.cacheInventory(inventory, userId);
      if (kDebugMode) {
        print('[OfflineSync] Cached ${inventory.length} inventory items');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[OfflineSync] Failed to cache inventory: $e');
      }
    }
  }

  /// Get inventory — falls back to cached data when offline.
  Future<List<InventoryItem>> getInventoryWithFallback(String userId) async {
    final isOnline = await ConnectivityService.isOnline;
    if (isOnline) {
      try {
        final inventory = await _remoteService.getInventory(userId);
        // Cache for next offline use
        await _dbService.cacheInventory(inventory, userId);
        return inventory;
      } catch (_) {
        // Network failed — fall through to cache
      }
    }
    // Offline or network failed — use cached data
    return await _dbService.getCachedInventory(userId);
  }

  /// Update cached inventory stock locally (for immediate offline feedback).
  Future<void> _updateCachedStock(String itemId, int? newStock) async {
    if (newStock == null) return;
    try {
      final db = await _dbService.database;
      await db.update(
        'cached_inventory',
        {'stock': newStock},
        where: 'id = ?',
        whereArgs: [itemId],
      );
    } catch (e) {
      if (kDebugMode) {
        print('[OfflineSync] Failed to update cached stock: $e');
      }
    }
  }
}
