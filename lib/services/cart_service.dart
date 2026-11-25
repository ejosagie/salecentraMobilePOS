import '../models/sale.dart';

/// Global cart state shared across the POS session.
///
/// The cart lives for the duration of the logged-in session so it survives
/// navigating away from the sales screen (prevents losing a sale in progress),
/// and is cleared on logout so it never leaks into another user's session.
class CartService {
  CartService._internal();

  static final CartService instance = CartService._internal();

  List<CartItem> cart = [];
  List<HeldCart> heldCarts = [];

  /// Clears the cart and any held carts. Called on logout.
  void clear() {
    cart.clear();
    heldCarts.clear();
  }
}
