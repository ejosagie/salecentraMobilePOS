# Update Notes

---

## ✅ DONE — v1.0.11 (Build 14)

### Grouped Multi-Item Receipts
- Implemented grouped receipt generation. All cart items in one sale now produce a single PDF receipt instead of one per item.
- Receipt lists each item, quantity, unit price, discount, and line total with a grand total.
- Files updated: `lib/screens/sales/sales_screen.dart`, `lib/services/pdf_service.dart`

### iOS Receipt Sharing Fix
- Fixed PlatformException `sharePositionOrigin` error on iPhone/iPad when sharing receipts.
- Added `sharePositionOrigin` to all share calls in `PdfService._sharePdf`.
- Applies to both Android and iOS since the share flow is shared Flutter code.

### Discount on Sales
- Added per-item discount entry for both owner and staff during sales.
- Discounts displayed on receipts clearly.
- Files updated: `lib/screens/sales/sales_screen.dart`, `lib/services/pdf_service.dart`

### Inventory Monetary Value on Dashboard
- Quick Overview now shows the total monetary value of remaining inventory.
- Calculated as sum of (stock × selling price) for all inventory items.
- File updated: `lib/screens/dashboard/dashboard_screen.dart`

### iOS App Store Compliance
- Removed Create Account button on iOS login screen; replaced with neutral text directing users to salecentra.com.
- Replaced upgrade/subscription links on iOS with neutral info dialogs.
- Updated subscription dialog message across Settings, More, Dashboard, and Account Status screens.
- Files updated: `login_screen.dart`, `settings_screen.dart`, `more_screen.dart`, `dashboard_screen.dart`, `account_status_screen.dart`

---

## 🔜 PLANNED — Bank Credit Notification (Paid Add-On)

### Concept
Bank credit notification is an **optional paid add-on** for SaleCentra business owners. When subscribed, incoming bank payments are shown as notifications inside the app so the owner (and optionally staff) can manually validate sales against received payments. Users who have not subscribed see the notification icon in a locked/unavailable state.

### Pricing Model
- **₦5,000/month** for up to **200 transaction confirmations**
- When the 200 confirmations or the monthly period is exhausted, the service pauses
- Users must renew to continue receiving bank credit notifications
- This add-on is managed manually by the SaleCentra admin — not automated

### User Flow (Subscriber)
1. User sees the bank notification icon in the app (locked state if not subscribed)
2. User taps icon → sees add-on pricing and a request/pay prompt
3. User pays ₦5,000 through the agreed channel
4. SaleCentra admin is automatically notified with: user's name, email, and payment confirmation
5. Admin logs into the **SaleCentra Admin Dashboard** and sends a unique bank connection URL to the user's email
6. User clicks the link → Mono Connect widget opens in a web browser
7. User authenticates with their bank account via Mono
8. Connection is established and managed on the Admin Dashboard
9. When a payment arrives → Mono webhook → Flask → push notification to user's app
10. Notification counter tracks usage (e.g. "187/200 confirmations used")
11. When limit is reached or month ends → service pauses → user sees "subscription expired" state in app

### User Flow (Non-Subscriber)
- Bank notification icon is visible in the app but shows a locked/unavailable state
- Tapping it shows the add-on pricing and a prompt to subscribe
- No bank data is fetched or shown

### Architecture
- One Mono developer account for the entire SaleCentra platform
- Bank connections managed exclusively on the **SaleCentra Admin Dashboard** (separate web portal)
- Flask stores per-user Mono token, confirmation count, and subscription expiry
- Webhook from Mono → Flask → push notification (FCM) to user's app
- No in-app bank connection flow — connection is done via emailed URL only
- No auto-matching to sales — manual validation only

### SaleCentra Admin Dashboard Requirements
- View all active add-on subscribers with their email, connection status, confirmations used, and expiry
- Send bank connection URL to a user's email with one click
- Manually activate/deactivate a user's bank notification subscription
- View incoming webhooks/transaction log per user
- Track confirmation usage across all users

### Mono Pricing (verified June 2026 from mono.co)
- **Starter plan:** NGN 100,000/month — capped at 350 unique connected accounts, 50 free sync calls/month
- **Business plan:** NGN 150,000/month — capped at 700 unique connected accounts, 100 free sync calls/month
- **Real-time/on-demand sync:** NGN 50 per call after free allowance
- **Widget customisation:** NGN 50,000 one-time fee (optional)
- ⚠️ At ₦5,000/month add-on pricing, you need 20+ paying subscribers just to cover the base plan, before per-call sync costs
- ⚠️ Pull-to-refresh costs stack up quickly at NGN 50/call — example: 10 users × 3 refreshes/day × 30 days = 900 calls − 50 free = 850 paid calls = NGN 42,500 extra on top of the base plan — must limit refresh frequency per user

### ⚠️ Pricing Decision Required Before Building
- The ₦5,000/month add-on price is not sustainable with Mono's plan costs
- Options to reconsider:
  1. **Raise add-on to ₦15,000–₦20,000/month** and strictly limit daily refresh count
  2. **Use SMS forwarding for Android** (near zero cost) — iOS users directed to salecentra.com
  3. **Hybrid** — SMS forwarding for Android, Mono only for iOS at higher price point
- Decision must be made before development begins to avoid rework

### UI & Access Requirements
- Bank credit notifications have their **own dedicated notification icon** in the app bar, separate from the existing activity bell. Use a distinct icon (e.g. bank or payment symbol).
- The existing activity notification bell remains completely unchanged.
- In **staff settings**, add a toggle for the owner to allow/disallow staff from seeing bank credit notifications on the sales entry screen.
- Toggle OFF (default): owner visibility only.
- Toggle ON: staff can also see incoming bank credit notifications to help validate payments during sales.

### Notification Refresh & Display
- Transactions are **not pushed in real-time to a persistent list** — the screen refreshes on demand.
- When the user opens or pulls to refresh the bank notification screen, the app fetches the latest data from Flask (which in turn pulls from Mono).
- The screen shows the **last 5 credit transactions** on the connected bank account — amount, sender name/reference, date and time.
- No pagination needed for now — just the most recent 5.

### Non-Subscriber State (Platform-Specific)
- **iOS users** — when tapping the bank notification icon, show a static message: "To manage your confirmation notification subscription, go to salecentra.com"
- **Android users** — when tapping the bank notification icon, take them directly to the subscribe/add-on section within the app where they can request the add-on
- This follows the same iOS compliance pattern already used elsewhere in the app

### Files to Create/Update (Flutter App)
- `lib/screens/dashboard/dashboard_screen.dart` — add bank notification icon in app bar
- New screen: `lib/screens/bank/bank_notifications_screen.dart` — show credit notifications or locked state
- `lib/screens/settings/staff_settings_screen.dart` — add staff bank notification visibility toggle
- `lib/screens/sales/sales_screen.dart` — conditionally show bank notifications for staff if toggle is on
- `lib/services/remote_database_service.dart` — fetch bank notification data and subscription status

### Files to Create/Update (Flask Backend)
- New webhook endpoint for Mono transaction events
- Store `mono_account_id`, `bank_addon_active`, `bank_confirmations_used`, `bank_addon_expiry`, `staff_bank_notify` per user
- Admin API endpoints to manage subscriptions and send onboarding URLs
- FCM push notification trigger on new transaction webhook
