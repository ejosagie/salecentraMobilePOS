# Update Notes

## Planned Improvement: Grouped Multi-Item Receipts

### Current behavior
- When a sale is completed with multiple cart items, the app records each item as a separate sale record.
- Receipt generation currently creates one receipt per individual sale item.
- On mobile share flows, this can make it appear as if only one item was included in the receipt, especially when multiple share actions are triggered back-to-back.

### Impact
- Sales recording is not blocked.
- Inventory reduction should still work correctly for each item.
- Backend/server data is likely correct.
- The issue is mainly receipt presentation and sharing UX.
- Some iPhones are able to share receipts successfully, while others cannot share receipts reliably.
- This may be related to differences in iOS version, device behavior, installed sharing apps, or how repeated share actions are handled.

### Recommended future fix
- Add support for one grouped receipt containing all cart items from the completed checkout.
- Use a shared transaction/receipt ID for all items sold together.
- Update the receipt PDF template to list each item, quantity, unit price, and line total.
- Show one grand total for the entire transaction.
- Make sales history able to view/share a grouped receipt instead of only a single sale item.
- Because the receipt generation/share flow is implemented in the shared Flutter app code, this fix should improve the behavior for both Android and iOS versions.
- The fix should also reduce sharing problems by triggering one receipt share action instead of several separate receipt share actions.

### Likely files to update later
- `lib/screens/sales/sales_screen.dart`
- `lib/services/pdf_service.dart`
- `lib/models/sale.dart`
- `lib/screens/sales/sales_history_screen.dart`
- Possibly backend sales API/database if grouped transaction IDs need to be stored server-side.

### Release recommendation
- Do not rush this as an emergency hotfix while marketing is active.
- Include it in the next planned app update to avoid unnecessary App Store / Play Store review delays.
