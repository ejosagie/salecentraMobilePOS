class ShopSettings {
  final String? id;
  final String slug;
  final String name;
  final String description;
  final String phone;
  final String whatsappNumber;
  final String email;
  final String address;
  final String bankName;
  final String bankAccountName;
  final String bankAccountNumber;
  final String currency;
  final String currencySymbol;
  final String themeColor;
  final bool isActive;
  final bool shopEnabled;
  final String subscriptionStatus;
  final String? subscriptionStartDate;
  final String? subscriptionEndDate;
  final int productLimit;

  ShopSettings({
    this.id,
    required this.slug,
    required this.name,
    this.description = '',
    this.phone = '',
    this.whatsappNumber = '',
    this.email = '',
    this.address = '',
    this.bankName = '',
    this.bankAccountName = '',
    this.bankAccountNumber = '',
    this.currency = 'XAF',
    this.currencySymbol = 'FCFA',
    this.themeColor = '#0066ff',
    this.isActive = false,
    this.shopEnabled = false,
    this.subscriptionStatus = 'inactive',
    this.subscriptionStartDate,
    this.subscriptionEndDate,
    this.productLimit = 10,
  });

  factory ShopSettings.fromMap(Map<String, dynamic> map) {
    final shop = map['shop'] as Map<String, dynamic>?;
    // shop_enabled may come as bool (from API) or int (from DB)
    final shopEnabledRaw = map['shop_enabled'];
    final shopEnabled = shopEnabledRaw is bool
        ? shopEnabledRaw
        : (shopEnabledRaw is int ? shopEnabledRaw == 1 : false);
    // is_active may come as int (from DB) or bool (from API)
    final isActiveRaw = shop?['is_active'];
    final isActive = isActiveRaw is bool
        ? isActiveRaw
        : (isActiveRaw is int ? isActiveRaw == 1 : false);
    // product_limit may be int or missing
    final productLimitRaw = map['shop_product_limit'];
    final productLimit = productLimitRaw is int
        ? productLimitRaw
        : (productLimitRaw is num ? productLimitRaw.toInt() : 10);
    return ShopSettings(
      id: shop?['id'],
      slug: (shop?['slug'] as String?) ?? map['shop_slug'] as String? ?? '',
      name: (shop?['name'] as String?) ?? '',
      description: (shop?['description'] as String?) ?? '',
      phone: (shop?['phone'] as String?) ?? '',
      whatsappNumber: (shop?['whatsapp_number'] as String?) ?? '',
      email: (shop?['email'] as String?) ?? '',
      address: (shop?['address'] as String?) ?? '',
      bankName: (shop?['bank_name'] as String?) ?? '',
      bankAccountName: (shop?['bank_account_name'] as String?) ?? '',
      bankAccountNumber: (shop?['bank_account_number'] as String?) ?? '',
      currency: (shop?['currency'] as String?) ?? 'XAF',
      currencySymbol: (shop?['currency_symbol'] as String?) ?? 'FCFA',
      themeColor: (map['shop_theme_color'] as String?) ?? '#0066ff',
      isActive: isActive,
      shopEnabled: shopEnabled,
      subscriptionStatus: (map['shop_subscription_status'] as String?) ?? 'inactive',
      subscriptionStartDate: map['shop_subscription_start_date'] as String?,
      subscriptionEndDate: map['shop_subscription_end_date'] as String?,
      productLimit: productLimit,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'slug': slug,
      'name': name,
      'description': description,
      'phone': phone,
      'whatsapp_number': whatsappNumber,
      'email': email,
      'address': address,
      'bank_name': bankName,
      'bank_account_name': bankAccountName,
      'bank_account_number': bankAccountNumber,
      'currency': currency,
      'currency_symbol': currencySymbol,
      'is_active': isActive,
      'shop_enabled': shopEnabled,
      'theme_color': themeColor,
    };
  }

  ShopSettings copyWith({
    String? slug,
    String? name,
    String? description,
    String? phone,
    String? whatsappNumber,
    String? email,
    String? address,
    String? bankName,
    String? bankAccountName,
    String? bankAccountNumber,
    String? currency,
    String? currencySymbol,
    String? themeColor,
    bool? isActive,
    bool? shopEnabled,
    String? subscriptionStatus,
    String? subscriptionStartDate,
    String? subscriptionEndDate,
    int? productLimit,
  }) {
    return ShopSettings(
      id: id,
      slug: slug ?? this.slug,
      name: name ?? this.name,
      description: description ?? this.description,
      phone: phone ?? this.phone,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      email: email ?? this.email,
      address: address ?? this.address,
      bankName: bankName ?? this.bankName,
      bankAccountName: bankAccountName ?? this.bankAccountName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      currency: currency ?? this.currency,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      themeColor: themeColor ?? this.themeColor,
      isActive: isActive ?? this.isActive,
      shopEnabled: shopEnabled ?? this.shopEnabled,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionStartDate: subscriptionStartDate ?? this.subscriptionStartDate,
      subscriptionEndDate: subscriptionEndDate ?? this.subscriptionEndDate,
      productLimit: productLimit ?? this.productLimit,
    );
  }
}
