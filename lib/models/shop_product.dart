class ShopProduct {
  final String id;
  final String? inventoryId;
  final String name;
  final String description;
  final double price;
  final int stock;
  final String? imageUrl;
  final String? imageUrl2;
  final String? imageUrl3;
  final bool isActive;
  final int sortOrder;
  final String? createdAt;

  ShopProduct({
    required this.id,
    this.inventoryId,
    required this.name,
    this.description = '',
    required this.price,
    this.stock = 0,
    this.imageUrl,
    this.imageUrl2,
    this.imageUrl3,
    this.isActive = true,
    this.sortOrder = 0,
    this.createdAt,
  });

  bool get isOutOfStock => stock <= 0;

  factory ShopProduct.fromMap(Map<String, dynamic> map) {
    final isActiveRaw = map['is_active'];
    final isActive = isActiveRaw is bool
        ? isActiveRaw
        : (isActiveRaw is int ? isActiveRaw == 1 : true);
    return ShopProduct(
      id: map['id'] as String,
      inventoryId: map['inventory_id'] as String?,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      imageUrl: map['image_url'] as String?,
      imageUrl2: map['image_url_2'] as String?,
      imageUrl3: map['image_url_3'] as String?,
      isActive: isActive,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'stock': stock,
      'image_url': imageUrl,
      'image_url_2': imageUrl2,
      'image_url_3': imageUrl3,
      'is_active': isActive,
      'sort_order': sortOrder,
    };
  }

  ShopProduct copyWith({
    String? name,
    String? description,
    double? price,
    int? stock,
    String? imageUrl,
    String? imageUrl2,
    String? imageUrl3,
    bool? isActive,
    int? sortOrder,
  }) {
    return ShopProduct(
      id: id,
      inventoryId: inventoryId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrl2: imageUrl2 ?? this.imageUrl2,
      imageUrl3: imageUrl3 ?? this.imageUrl3,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
    );
  }
}
