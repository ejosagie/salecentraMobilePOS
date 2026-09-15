import 'package:flutter/foundation.dart';
import 'package:sunmi_printer_plus/column_maker.dart';
import 'package:sunmi_printer_plus/enums.dart';
import 'package:sunmi_printer_plus/sunmi_style.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';

class ThermalPrinterService {
  static const int _lineWidthChars = 32;
  static bool _bindLock = false;

  /// Bind to the Sunmi printer. In v3.x, bindingPrinter() actually works.
  /// Must be called before every print job.
  static Future<bool> _bind() async {
    if (_bindLock) return true;
    _bindLock = true;
    try {
      final bound = await SunmiPrinter.bindingPrinter() ?? false;
      if (kDebugMode) {
        print('[ThermalPrinter] Printer bound: $bound');
      }
      _bindLock = false;
      return bound;
    } catch (e) {
      _bindLock = false;
      if (kDebugMode) {
        print('[ThermalPrinter] Binding failed: $e');
      }
      return false;
    }
  }

  static Future<bool> isSunmiDevice() async {
    return await _bind();
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
    final isSunmi = await _bind();
    if (!isSunmi) {
      if (kDebugMode) print('[ThermalPrinter] No Sunmi printer available');
      return;
    }

    try {
      await SunmiPrinter.initPrinter();
      await SunmiPrinter.startTransactionPrint(true);

      final sm = SunmiStyle(fontSize: SunmiFontSize.SM);
      final smBold = SunmiStyle(fontSize: SunmiFontSize.SM, bold: true);
      final smCenter = SunmiStyle(fontSize: SunmiFontSize.SM, align: SunmiPrintAlign.CENTER);
      final smBoldCenter = SunmiStyle(fontSize: SunmiFontSize.SM, bold: true, align: SunmiPrintAlign.CENTER);

      // Header — always print business info
      await SunmiPrinter.printText('SaleCentra\n', style: smBoldCenter);
      await SunmiPrinter.printText('${businessName.isEmpty ? 'N/A' : businessName}\n', style: smCenter);
      if (address.isNotEmpty) {
        await SunmiPrinter.printText('$address\n', style: smCenter);
      }
      await SunmiPrinter.printText('${phone.isEmpty ? 'N/A' : phone}\n', style: smCenter);
      await SunmiPrinter.line();

      // Receipt info
      final now = DateTime.now();
      final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      await SunmiPrinter.printText('Date: $dateStr\n', style: sm);
      await SunmiPrinter.printText('Receipt: $receiptNo\n', style: sm);
      await SunmiPrinter.printText('Cashier: $cashier\n', style: sm);
      await SunmiPrinter.line();

      // Items — single row per item: name on left, qty x price on right
      for (final item in items) {
        final name = item['name'] as String? ?? '';
        final qty = item['quantity'] as int? ?? 1;
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final lineTotal = price * qty;

        await SunmiPrinter.printRow(cols: [
          ColumnMaker(
            text: '${qty}x $name',
            width: 20,
            align: SunmiPrintAlign.LEFT,
          ),
          ColumnMaker(
            text: lineTotal.toStringAsFixed(2),
            width: 12,
            align: SunmiPrintAlign.RIGHT,
          ),
        ]);
      }

      await SunmiPrinter.line();

      // Totals
      await SunmiPrinter.printRow(cols: [
        ColumnMaker(text: 'Subtotal', width: 20, align: SunmiPrintAlign.LEFT),
        ColumnMaker(text: subtotal.toStringAsFixed(2), width: 12, align: SunmiPrintAlign.RIGHT),
      ]);
      if (discount > 0) {
        await SunmiPrinter.printRow(cols: [
          ColumnMaker(text: 'Discount', width: 20, align: SunmiPrintAlign.LEFT),
          ColumnMaker(text: '-${discount.toStringAsFixed(2)}', width: 12, align: SunmiPrintAlign.RIGHT),
        ]);
      }
      await SunmiPrinter.printRow(cols: [
        ColumnMaker(text: 'TOTAL', width: 20, align: SunmiPrintAlign.LEFT),
        ColumnMaker(text: total.toStringAsFixed(2), width: 12, align: SunmiPrintAlign.RIGHT),
      ]);

      await SunmiPrinter.line();

      // Customer info
      if (customerName != null && customerName.isNotEmpty) {
        await SunmiPrinter.printText('Customer: $customerName\n', style: sm);
      }
      if (customerPhone != null && customerPhone.isNotEmpty) {
        await SunmiPrinter.printText('Phone: $customerPhone\n', style: sm);
      }

      // Payment info
      if (paymentMethod != null) {
        await SunmiPrinter.line();
        await SunmiPrinter.printText('Payment: $paymentMethod\n', style: sm);
        if (paymentStatus != null) {
          await SunmiPrinter.printText('Status: $paymentStatus\n', style: sm);
        }
      }

      // Delivery info
      if (deliveryInfo != null) {
        await SunmiPrinter.line();
        await SunmiPrinter.printText('Delivery: $deliveryInfo\n', style: sm);
        if (trackingNo != null) {
          await SunmiPrinter.printText('Tracking: $trackingNo\n', style: sm);
        }
      }

      await SunmiPrinter.line();
      await SunmiPrinter.printText('Thank you!\n', style: smCenter);
      await SunmiPrinter.lineWrap(2);

      await SunmiPrinter.exitTransactionPrint(true);
    } catch (e) {
      if (kDebugMode) print('[ThermalPrinter] Print error: $e');
      try {
        await SunmiPrinter.exitTransactionPrint(true);
      } catch (_) {}
    }
  }
}
