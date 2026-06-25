# Update Notes

---

## ✅ DONE — v1.0.12 (Build 15)

### Customer Info on Sales & Receipts
- Added optional Customer Name, Phone, and Address fields to the sales entry screen (owner and staff).
- Customer search: as the user types a name, matching existing customers are shown and can be selected to auto-fill details.
- Customer info is sent with each sale record and saved to the backend.
- New customers are automatically added to the customers table when a name and phone are provided.
- Receipts now display customer info (name, phone, address) when provided.
- Staff receipts show the business logo, business details, and staff name.
- Files updated: `lib/screens/sales/sales_screen.dart`, `lib/services/pdf_service.dart`, `lib/models/sale.dart`, `lib/services/remote_database_service.dart`

### Backend API Updates
- `POST /api/sales` now accepts `customer_name`, `customer_phone`, and `customer_address`.
- New customers are automatically saved to the `customers` table during sale recording.
- Added `GET /api/customers/search` endpoint for customer name/phone search.
- Files updated: `api/app.py`, `modules/database.py`

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

### Competitive Edge
**Bumpa and Kwiksell do not offer bank credit notifications.** This is a powerful differentiator for SaleCentra — Nigerian business owners constantly need to verify that customer transfers have landed before releasing goods. Currently they check their bank apps manually. SaleCentra will bring this directly into the app.

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

---

## 🔜 PLANNED — Multi-Staff Add-On Module

### Concept
Allow business owners to add **multiple staff members** for sales entry. Currently limited to 1 staff member with a toggle on/off. This planned update introduces tiered add-ons for more staff capacity, managed entirely through a backend admin dashboard.

### Plan Tiers
| Plan | Staff Limit | Price | Activation |
|---|---|---|---|
| **Basic** (default) | 1 staff | Free | Automatic |
| **Pro** | Up to 3 staff | ₦3,000/month | Manual admin activation |
| **Business** | Unlimited staff | ₦8,000/month | Manual admin activation |

### Staff Login — No UI Changes
- **Current login flow is preserved exactly.** Staff continue to log in using:
  1. Owner's business email
  2. Staff name (exact match)
  3. Staff passcode/PIN
- No dropdown lists, no separate staff login screen, no new authentication patterns
- The existing `sales_entry_staff_name` + `sales_entry_password_hash` pattern is simply expanded to support multiple entries via a `staff` table

### Staff Management (Business Owner Only)
- Accessed via **Settings → Business Settings → Manage Staff**
- Owner can:
  - View current staff list and active plan badge (e.g. "Pro — 2/3 staff used")
  - Add new staff (name + 4-digit PIN)
  - Edit staff name or PIN
  - Deactivate/remove staff
- "Add Staff" button is **disabled with a tooltip** if the plan limit is reached
- "Upgrade Plan" button opens browser to `salecentra.com/pricing` for add-on request

### Backend Changes
- New `staff` table: `id`, `user_id`, `name`, `pin_hash`, `is_active`, `created_at`
- Migration: auto-convert existing single-staff users (`sales_entry_enabled=1`) into one `staff` record
- New columns on `users`: `plan_tier` (basic/pro/business), `staff_limit` (1 / 3 / -1)
- Staff login endpoint validates name + PIN against `staff` table instead of a single stored hash
- Sale recording uses existing `entered_by_staff_name` field — no schema change needed

### Admin Activation Flow
1. User goes to `salecentra.com/pricing` and selects Pro or Business plan
2. User pays via agreed channel and sends confirmation
3. SaleCentra admin logs into the **Admin Dashboard** (protected web portal)
4. Admin searches user by email → sees current plan: Basic
5. Admin clicks **Activate Pro** or **Activate Business**
6. User's app immediately unlocks the additional staff slots on next login/session refresh

### Payment Page (salecentra.com)
- Simple pricing table showing Basic vs Pro vs Business
- "Request Add-On" form: name, email, phone, selected plan
- Form submits to admin notification (email/Slack/DB)
- No automated payment gateway initially — manual confirmation and activation

### Reports & Analytics Impact
- Sales History and Reports screens gain a **"Filter by Staff"** dropdown (visible only when plan tier is Pro or Business)
- Reports show per-staff sales breakdown for Business plan users
- Basic plan users see no change — everything remains as-is

### Files to Create/Update (Flutter App)
- `lib/screens/settings/business_settings_screen.dart` — expand staff management UI to support multiple staff
- `lib/screens/settings/staff_settings_screen.dart` — add plan badge, staff list, add/edit/deactivate actions, upgrade button
- `lib/services/remote_database_service.dart` — new staff CRUD endpoints, fetch plan tier
- `lib/screens/sales/sales_screen.dart` — if multiple staff exist, show a simple selector before completing sale (owner only, staff mode already handled)
- `lib/screens/sales/sales_history_screen.dart` — add "Filter by Staff" when plan tier > basic
- `lib/screens/reports/reports_screen.dart` — per-staff breakdown for Pro/Business plans

### Files to Create/Update (Flask Backend)
- Migration: `staff` table, `plan_tier` + `staff_limit` columns on `users`
- Auto-migrate existing single-staff configuration into `staff` table
- CRUD endpoints: `GET/POST/PUT/DELETE /api/staff`
- Staff login validation endpoint
- Admin-only endpoints: `POST /api/admin/activate-plan` to update `plan_tier` and `staff_limit`
- Ensure all staff-related endpoints check `staff_limit` before allowing creation

---

## 🔜 PLANNED — WhatsApp Business Integration (Paid Add-On)

### Competitive Edge
**Bumpa and Kwiksell do not have deep WhatsApp integration.** Nigerian business owners run almost entirely on WhatsApp — it's where customers ask for prices, place orders, and send payment screenshots. SaleCentra will bridge the gap between the app and WhatsApp commerce by using the **official WhatsApp Business API** (not just `wa.me` deep links), enabling true two-way automation.

### Concept
WhatsApp Business Integration is an **optional paid add-on** that connects SaleCentra to the **WhatsApp Cloud API**. This turns the business's WhatsApp number into an intelligent sales channel — customers can message the business, and SaleCentra automatically handles replies, order creation, payment confirmation, and receipts. The business owner monitors everything from inside SaleCentra without manually typing on WhatsApp.

### Pricing Model
- **₦5,000/month** for WhatsApp API integration
- Covers **unlimited incoming messages** + **1,000 outgoing messages/month**
- Additional outgoing messages: ₦2/message
- Managed manually by SaleCentra admin — activation via Admin Dashboard after payment confirmation
- WhatsApp Cloud API itself is free; Meta only charges per conversation (free for first 1,000/month)

---

### What the WhatsApp Business API Makes Possible (Beyond Simple Sharing)

#### Phase 1: Outbound Notifications (Owner → Customer)
These work immediately after API connection:

| Feature | How It Works | Value |
|---|---|---|
| **Payment Confirmation** | When a sale is completed, customer automatically receives a WhatsApp message: *"Hi [Name], your payment of ₦5,000 to [Business] has been received. Thank you!"* | Instant trust, no need for customer to ask "Did you get my money?" |
| **Order Ready / Pickup Alert** | When order is packed, auto-message: *"Your order #1234 is ready for pickup at [Address]."* | Reduces "is my order ready?" inquiries |
| **Low Stock Alert to Owner** | When inventory hits reorder level, WhatsApp message sent to owner: *"Stock Alert: Product X is down to 5 units."* | Prevents stockouts |
| **Daily Sales Summary** | Every evening at 8pm, owner gets WhatsApp summary: *"Today's sales: ₦45,000. 12 transactions. Top product: XYZ."* | Owner stays informed without opening app |
| **Debt Reminder** | Overdue debt triggers auto-message to customer: *"Friendly reminder: Your balance of ₦10,000 is due today."* | Reduces manual follow-up |

#### Phase 2: Two-Way Customer Commerce (Customer → Business → Auto-Reply)
Customer sends a WhatsApp message to the business number. SaleCentra's webhook receives it and auto-responds:

| Customer Sends | SaleCentra Auto-Replies With | Action Taken |
|---|---|---|
| `price` or `menu` | Formatted product catalog with prices | None — informational |
| `order 2 Product ABC` | *"Order received: 2 × Product ABC = ₦10,000. Reply PAY to confirm."* | Creates **draft order** in SaleCentra |
| `pay` or `confirm` | *"Please send payment to [Account Number]. Reply DONE when paid."* | Marks order as **awaiting payment** |
| `[payment screenshot]` | OCR reads amount, matches to pending order: *"Payment of ₦10,000 confirmed. Order #1234 is complete!"* | Marks order **paid**, updates inventory |
| `track 1234` | *"Order #1234: Packed → Shipped → Delivered (today 2pm)"* | Shows order status |
| `help` | List of commands: price, order, track, support | None — informational |

**Result:** Customers place orders, pay, and get confirmations entirely via WhatsApp. The business owner only intervenes for exceptions. SaleCentra becomes the backend brain.

#### Phase 3: Interactive Messages (Rich UI Inside WhatsApp)
The API supports buttons, lists, and carousels — not just plain text:

- **Product carousel:** Customer sees 3 products with images, prices, and "Add to Cart" buttons
- **Quick reply buttons:** "Pay Now" | "Cancel" | "Modify Order"
- **List picker:** Customer taps "Browse Categories" → sees scrollable list: Clothing, Shoes, Accessories
- **Location request:** "Share your delivery location" → customer sends pin → saved to order

#### Phase 4: Staff Assignment via WhatsApp
- Customer sends complaint: *"My order arrived damaged"*
- SaleCentra auto-assigns to a staff member via internal notification
- Staff replies from SaleCentra app → customer gets WhatsApp response
- Owner sees full chat thread inside SaleCentra

---

### Architecture

```
Customer WhatsApp Message
        ↓
   Meta WhatsApp Servers
        ↓
   Webhook → Flask API (/api/whatsapp/webhook)
        ↓
   SaleCentra processes intent (price/order/pay/help)
        ↓
   Auto-reply sent back via WhatsApp Cloud API
        ↓
   Customer receives reply in WhatsApp
```

**Components:**
- **Meta Business Account** — one per SaleCentra business user
- **WhatsApp Business Phone Number** — the business's actual WhatsApp number
- **Webhook endpoint** in Flask: `POST /api/whatsapp/webhook` — receives all incoming messages
- **Message templates** — pre-approved by Meta for outbound notifications (payment confirmation, reminders, etc.)
- **Conversation-based pricing** — Meta charges per 24-hour conversation window, not per message

---

### What the Business Owner Sees Inside SaleCentra

A new **"WhatsApp Inbox"** screen in the app:
- List of recent customer WhatsApp conversations
- Unread count badge
- Tap a chat → see full message history
- Ability to reply manually or trigger auto-reply templates
- Filter: All | Unread | Orders | Support

**Dashboard widget:**
- "WhatsApp Orders Today: 12"
- "Pending Confirmations: 3"
- "Revenue from WhatsApp: ₦45,000"

---

### Admin Activation Flow
1. User pays ₦5,000 and sends confirmation
2. Admin activates add-on from Admin Dashboard
3. Admin guides user to connect their WhatsApp Business number via Meta Business Manager
4. User verifies phone number via OTP
5. Webhook URL configured to point to SaleCentra VPS
6. Message templates submitted to Meta for approval (payment confirmation, order alerts, etc.)
7. Once approved → full two-way commerce begins

---

### Non-Subscriber State
- WhatsApp Inbox screen shows locked state with pricing
- No webhook registered for user's phone number
- Customer messages to the business go unanswered by SaleCentra (owner must reply manually on WhatsApp)

---

### Files to Create/Update (Flutter App)
- New screen: `lib/screens/whatsapp/whatsapp_inbox_screen.dart` — customer chat list + conversation view
- `lib/screens/dashboard/dashboard_screen.dart` — WhatsApp orders widget + unread badge
- `lib/screens/sales/sales_screen.dart` — show "Orders from WhatsApp" section
- `lib/services/whatsapp_service.dart` — send/receive messages, parse intents, OCR screenshots
- `lib/services/remote_database_service.dart` — fetch WhatsApp conversation history, order status

### Files to Create/Update (Flask Backend)
- `POST /api/whatsapp/webhook` — incoming message handler from Meta
- `POST /api/whatsapp/send` — outgoing message sender
- New tables: `whatsapp_conversations`, `whatsapp_orders` (links to existing sales/customers)
- Message template management (submit to Meta, track approval status)
- Intent parser: classify incoming messages as price_query, order_intent, payment_confirmation, support
- OCR integration for payment screenshot reading (optional, Phase 2)
- Admin endpoints to activate WhatsApp add-on and manage templates
