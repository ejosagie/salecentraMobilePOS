import 'package:flutter/foundation.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';

class ThermalPrinterService {
  static bool _initialized = false;
  static bool _isSunmiDevice = false;

  static Future<bool> _init() async {
    if (_initialized) return _isSunmiDevice;
    try {
      // bindingPrinter is deprecated but still the way to check for Sunmi hardware
      // ignore: deprecated_member_use
      _isSunmiDevice = await SunmiPrinter.bindingPrinter() ?? false;
      _initialized = true;
      if (kDebugMode) {
        print('[ThermalPrinter] Sunmi device: $_isSunmiDevice');
      }
      return _isSunmiDevice;
    } catch (e) {
      _initialized = true;
      _isSunmiDevice = false;
      if (kDebugMode) {
        print('[ThermalPrinter] Not a Sunmi device: $e');
      }
      return false;
    }
  }

  static Future<bool> isSunmiDevice() async {
    return await _init();
  }

  static Future<void> printReceipt({
    required String businessName,
    required String address,
    required String phone,
    required String receiptNo,
    required String cashier,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double total,
    String? customerName,
    String? customerPhone,
    String? paymentMethod,
    String? paymentStatus,
    String? deliveryInfo,
    String? trackingNo,
  }) async {
    final isSunmi = await _init();
    if (!isSunmi) {
      if (kDebugMode) print('[ThermalPrinter] No Sunmi printer available');
      return;
    }

    try {
      // Header
      await SunmiPrinter.printText('SaleCentra Receipt\n',
          style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.CENTER, fontSize: 36));
      await SunmiPrinter.printText('$businessName\n',
          style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 24));
      if (address.isNotEmpty) {
        await SunmiPrinter.printText('$address\n',
            style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 18));
      }
      await SunmiPrinter.printText('$phone\n',
          style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 18));
      await SunmiPrinter.line(type: '*');
      await SunmiPrinter.lineWrap(1);

      // Receipt info
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      await SunmiPrinter.printText('Date: $dateStr\n',
          style: SunmiTextStyle(fontSize: 18));
      await SunmiPrinter.printText('Receipt: $receiptNo\n',
          style: SunmiTextStyle(fontSize: 18));
      await SunmiPrinter.printText('Cashier: $cashier\n',
          style: SunmiTextStyle(fontSize: 18));
      await SunmiPrinter.line(type: '-');
      await SunmiPrinter.lineWrap(1);

      // Items
      for (final item in items) {
        final name = item['name'] as String? ?? '';
        final qty = item['quantity'] as int? ?? 1;
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final lineTotal = price * qty;

        await SunmiPrinter.printText('$name\n',
            style: SunmiTextStyle(fontSize: 18));
        await SunmiPrinter.printText(
            '  x$qty  ${lineTotal.toStringAsFixed(2)}\n',
            style: SunmiTextStyle(fontSize: 18));
      }

      await SunmiPrinter.line(type: '-');
      await SunmiPrinter.lineWrap(1);

      // Totals
      await SunmiPrinter.printText(
          'Subtotal: ${subtotal.toStringAsFixed(2)}\n',
          style: SunmiTextStyle(fontSize: 18));
      if (discount > 0) {
        await SunmiPrinter.printText(
            'Discount: -${discount.toStringAsFixed(2)}\n',
            style: SunmiTextStyle(fontSize: 18));
      }
      await SunmiPrinter.printText(
          'TOTAL: ${total.toStringAsFixed(2)}\n',
          style: SunmiTextStyle(bold: true, fontSize: 28));

      await SunmiPrinter.line(type: '-');
      await SunmiPrinter.lineWrap(1);

      // Customer info
      if (customerName != null && customerName.isNotEmpty) {
        await SunmiPrinter.printText('Customer: $customerName\n',
            style: SunmiTextStyle(fontSize: 18));
      }
      if (customerPhone != null && customerPhone.isNotEmpty) {
        await SunmiPrinter.printText('Phone: $customerPhone\n',
            style: SunmiTextStyle(fontSize: 18));
      }

      // Payment info
      if (paymentMethod != null) {
        await SunmiPrinter.line(type: '-');
        await SunmiPrinter.lineWrap(1);
        await SunmiPrinter.printText('Payment: $paymentMethod\n',
            style: SunmiTextStyle(fontSize: 18));
        if (paymentStatus != null) {
          await SunmiPrinter.printText('Status: $paymentStatus\n',
              style: SunmiTextStyle(fontSize: 18));
        }
      }

      // Delivery info
      if (deliveryInfo != null) {
        await SunmiPrinter.line(type: '-');
        await SunmiPrinter.lineWrap(1);
        await SunmiPrinter.printText('Delivery: $deliveryInfo\n',
            style: SunmiTextStyle(fontSize: 18));
        if (trackingNo != null) {
          await SunmiPrinter.printText('Tracking: $trackingNo\n',
              style: SunmiTextStyle(fontSize: 18));
        }
      }

      await SunmiPrinter.line(type: '-');
      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.printText('Thank you for your business!\n',
          style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 18));
      await SunmiPrinter.lineWrap(2);
      await SunmiPrinter.cutPaper();
    } catch (e) {
      if (kDebugMode) print('[ThermalPrinter] Print error: $e');
    }
  }
}
