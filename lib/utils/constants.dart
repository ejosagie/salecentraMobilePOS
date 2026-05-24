class AppConstants {
  static const String appName = 'SaleCentra';
  static const String appTagline = 'Smart Sales Made Simple';
  static const String helpCenterUrl = 'https://salecentra.com/customer_tickets/';
  static const String contactSupportUrl = 'https://salecentra.com/customer_tickets/';
  
  // Currency symbols
  static const Map<String, String> currencySymbols = {
    'NGN': '₦',
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'KES': 'KSh',
    'GHS': '₵',
    'ZAR': 'R',
    'XOF': 'CFA',
    'XAF': 'FCFA',
    'UGX': 'USh',
    'TZS': 'TSh',
    'ETB': 'Br',
    'DZD': 'دج',
    'MAD': 'DH',
    'EGP': '£E',
    'AED': 'د.إ',
    'SAR': '﷼',
    'INR': '₹',
    'PKR': '₨',
    'CAD': 'C\$',
    'AUD': 'A\$',
    'JPY': '¥',
    'CNY': '¥',
    'BRL': 'R\$',
    'MXN': 'Mex\$',
  };

  // Industries
  static const List<String> industries = [
    'Retail',
    'Restaurant/Food',
    'Fashion/Clothing',
    'Electronics',
    'Pharmacy',
    'Supermarket/Grocery',
    'Beauty/Cosmetics',
    'Hardware/Building Materials',
    'Auto Parts',
    'Books/Stationery',
    'Jewelry/Accessories',
    'Home Appliances',
    'Furniture',
    'Mobile Phones/Gadgets',
    'Other',
  ];

  // African countries with currencies
  static const Map<String, String> countries = {
    'Nigeria': 'NGN',
    'Kenya': 'KES',
    'Ghana': 'GHS',
    'South Africa': 'ZAR',
    'Ivory Coast': 'XOF',
    'Cameroon': 'XAF',
    'Uganda': 'UGX',
    'Tanzania': 'TZS',
    'Ethiopia': 'ETB',
    'Algeria': 'DZD',
    'Morocco': 'MAD',
    'Egypt': 'EGP',
  };

  static const List<String> expenseCategories = [
    'Rent',
    'Utilities',
    'Salaries',
    'Supplies',
    'Marketing',
    'Transportation',
    'Maintenance',
    'Insurance',
    'Taxes',
    'Other',
  ];
}
