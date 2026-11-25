import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sale.dart';

/// Global cart state shared across the POS session.
///
/// The cart lives for the duration of the logged-in session so it survives
/// navigating away from the sales screen (prevents losing a sale in progress),
/// and is cleared on logout so it never leaks into another user's session.
/// The cart is also persisted locally so a crash, reboot, or app kill doesn't
/// lose a sale in progress.
class CartService {
  CartService._internal();

  static final CartService instance = CartService._internal();

  static const String _cartKey = 'cart_items';
  static const String _heldCartsKey = 'held_carts';

  /// Held carts older than this are discarded on load.
  static const int heldCartMaxAgeDays = 7;

  List<CartItem> cart = [];
  List<HeldCart> heldCarts = [];

  /// Restores the cart and held carts saved from a previous session.
  /// Held carts older than [heldCartMaxAgeDays] are discarded.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final cartJson = prefs.getString(_cartKey);
    final heldJson = prefs.getString(_heldCartsKey);
    cart = cartJson == null
        ? []
        : (jsonDecode(cartJson) as List)
            .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
            .toList();
    heldCarts = heldJson == null
        ? []
        : (jsonDecode(heldJson) as List)
            .map((e) => HeldCart.fromJson(e as Map<String, dynamic>))
            .toList();

    // Discard stale held carts so they don't pile up on a busy terminal.
    final cutoff = DateTime.now().subtract(const Duration(days: heldCartMaxAgeDays));
    final before = heldCarts.length;
    heldCarts.removeWhere((h) => h.heldAt.isBefore(cutoff));
    if (heldCarts.length != before) {
      await save();
    }
  }

  /// Persists the current cart and held carts so a crash or reboot
  /// doesn't lose a sale in progress.
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cartKey, jsonEncode(cart.map((e) => e.toJson()).toList()));
    await prefs.setString(_heldCartsKey, jsonEncode(heldCarts.map((e) => e.toJson()).toList()));
  }

  /// Clears the cart and any held carts. Called on logout.
  Future<void> clear() async {
    cart.clear();
    heldCarts.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cartKey);
    await prefs.remove(_heldCartsKey);
  }
}
