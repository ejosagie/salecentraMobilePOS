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

      // Header
      await SunmiPrinter.printText('SaleCentra Receipt\n',
          style: SunmiStyle(
            bold: true,
            align: SunmiPrintAlign.CENTER,
            fontSize: SunmiFontSize.LG,
          ));
      await SunmiPrinter.printText('$businessName\n',
          style: SunmiStyle(
            align: SunmiPrintAlign.CENTER,
            fontSize: SunmiFontSize.MD,
          ));
      if (address.isNotEmpty) {
        await SunmiPrinter.printText('$address\n',
            style: SunmiStyle(
              align: SunmiPrintAlign.CENTER,
              fontSize: SunmiFontSize.SM,
            ));
      }
      await SunmiPrinter.printText('$phone\n',
          style: SunmiStyle(
            align: SunmiPrintAlign.CENTER,
            fontSize: SunmiFontSize.SM,
          ));
      await SunmiPrinter.line();
      await SunmiPrinter.lineWrap(1);

      // Receipt info
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      await SunmiPrinter.printText('Date: $dateStr\n',
          style: SunmiStyle(fontSize: SunmiFontSize.SM));
      await SunmiPrinter.printText('Receipt: $receiptNo\n',
          style: SunmiStyle(fontSize: SunmiFontSize.SM));
      await SunmiPrinter.printText('Cashier: $cashier\n',
          style: SunmiStyle(fontSize: SunmiFontSize.SM));
      await SunmiPrinter.line();
      await SunmiPrinter.lineWrap(1);

      // Items
      for (final item in items) {
        final name = item['name'] as String? ?? '';
        final qty = item['quantity'] as int? ?? 1;
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final lineTotal = price * qty;

        await SunmiPrinter.printText('$name\n',
            style: SunmiStyle(fontSize: SunmiFontSize.SM));
        await SunmiPrinter.printRow(cols: [
          ColumnMaker(
            text: '  ${qty}x @ ${price.toStringAsFixed(2)}',
            width: _lineWidthChars - 12,
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
      await SunmiPrinter.lineWrap(1);

      // Totals
      await SunmiPrinter.printRow(cols: [
        ColumnMaker(
          text: 'Subtotal',
          width: _lineWidthChars - 12,
          align: SunmiPrintAlign.LEFT,
        ),
        ColumnMaker(
          text: subtotal.toStringAsFixed(2),
          width: 12,
          align: SunmiPrintAlign.RIGHT,
        ),
      ]);
      if (discount > 0) {
        await SunmiPrinter.printRow(cols: [
          ColumnMaker(
            text: 'Discount',
            width: _lineWidthChars - 12,
            align: SunmiPrintAlign.LEFT,
          ),
          ColumnMaker(
            text: '-${discount.toStringAsFixed(2)}',
            width: 12,
            align: SunmiPrintAlign.RIGHT,
          ),
        ]);
      }
      await SunmiPrinter.printRow(cols: [
        ColumnMaker(
          text: 'TOTAL',
          width: _lineWidthChars - 12,
          align: SunmiPrintAlign.LEFT,
        ),
        ColumnMaker(
          text: total.toStringAsFixed(2),
          width: 12,
          align: SunmiPrintAlign.RIGHT,
        ),
      ]);

      await SunmiPrinter.line();
      await SunmiPrinter.lineWrap(1);

      // Customer info
      if (customerName != null && customerName.isNotEmpty) {
        await SunmiPrinter.printText('Customer: $customerName\n',
            style: SunmiStyle(fontSize: SunmiFontSize.SM));
      }
      if (customerPhone != null && customerPhone.isNotEmpty) {
        await SunmiPrinter.printText('Phone: $customerPhone\n',
            style: SunmiStyle(fontSize: SunmiFontSize.SM));
      }

      // Payment info
      if (paymentMethod != null) {
        await SunmiPrinter.line();
        await SunmiPrinter.lineWrap(1);
        await SunmiPrinter.printText('Payment: $paymentMethod\n',
            style: SunmiStyle(fontSize: SunmiFontSize.SM));
        if (paymentStatus != null) {
          await SunmiPrinter.printText('Status: $paymentStatus\n',
              style: SunmiStyle(fontSize: SunmiFontSize.SM));
        }
      }

      // Delivery info
      if (deliveryInfo != null) {
        await SunmiPrinter.line();
        await SunmiPrinter.lineWrap(1);
        await SunmiPrinter.printText('Delivery: $deliveryInfo\n',
            style: SunmiStyle(fontSize: SunmiFontSize.SM));
        if (trackingNo != null) {
          await SunmiPrinter.printText('Tracking: $trackingNo\n',
              style: SunmiStyle(fontSize: SunmiFontSize.SM));
        }
      }

      await SunmiPrinter.line();
      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.printText('Thank you for your business!\n',
          style: SunmiStyle(
            align: SunmiPrintAlign.CENTER,
            fontSize: SunmiFontSize.SM,
          ));
      await SunmiPrinter.lineWrap(2);

      // Commit and close the transaction — this flushes the buffer to hardware
      await SunmiPrinter.exitTransactionPrint(true);
    } catch (e) {
      if (kDebugMode) print('[ThermalPrinter] Print error: $e');
      // Try to exit transaction even on error to release the printer
      try {
        await SunmiPrinter.exitTransactionPrint(true);
      } catch (_) {}
    }
  }
}
