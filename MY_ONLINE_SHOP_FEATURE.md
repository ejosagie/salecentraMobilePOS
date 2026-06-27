# My Online Shop Feature

## Overview
A dedicated section in the mobile app for managing the online storefront functionality. This feature groups all shop-related settings, product management, and subscription options in one accessible location.

## Structure

### Navigation Path
**More Screen** → **My online Shop** → Tabbed Screen

### Tabs/Sections

1. **Shop Settings**
   - Theme color picker
   - Shop name
   - Shop description
   - Contact information (phone, WhatsApp, email, address)
   - Payment details (bank name, account name, account number)
   - Currency settings (currency code and symbol)
   - Shop slug (URL-friendly name, auto-generated from business name but editable)
   - Shop URL display (https://salecentra.com/shop/{slug})
   - Shop enabled toggle (separate from "shop is live" - controls overall shop visibility)
   - Shop is live toggle (is_active - controls whether shop is accessible)
   - Save button with success notification

2. **Products**
   - Select products from existing inventory (not creating new products)
   - Toggle products on/off for storefront visibility (per-product active toggle)
   - Edit product descriptions for storefront display
   - Set custom prices for storefront (optional, defaults to inventory price)
   - Manage stock status (in stock/out of stock)
   - Product images from inventory (limit: 3 images per product)
   - Sort order (numeric, controls display order on storefront)
   - Bulk enable/disable for storefront
   - Product slot counter for trial/inactive users (max 10 products)
   - Edit mode form for updating product details

3. **Subscription**
   - Current plan status (trial, active, inactive)
   - Product limit indicator (10 for trial/inactive, unlimited for active)
   - Upgrade option
   - **Platform-specific behavior:**
     - **Android:** Button linking to `https://salecentra.com/subscribe/` with instructions to select "Shop Addons"
     - **iOS:** Text directing to `https://salecentra.com/` for subscription management (account status screen)

4. **Orders**
   - View customer orders from storefront
   - Order status filter (All, Pending, Completed, Cancelled)
   - Order details (customer name, items, total, date, status)
   - Complete order action
   - Cancel/reject order action
   - Order contact information

5. **Preview**
   - Link to view the live storefront
   - Opens storefront in browser (Safari on iOS, default browser on Android)
   - Shows shop slug/URL for sharing

## Platform-Specific Considerations

### Android
- Direct in-app browser or external browser for subscription page
- Full access to Paystack payment flow
- Can complete subscription entirely within the app

### iOS
- Due to App Store subscription policies, subscription management is handled via web
- Users are directed to the web dashboard at `https://salecentra.com/`
- Subscription status syncs back to the app after web completion
- Preview link works via Safari or in-app web view

## Image Upload Architecture

**Flutter does NOT connect directly to Google Cloud Storage.** The upload flow is:

1. **Flutter app** selects image from device (image picker)
2. **Flutter app** uploads image to VPS API endpoint (`POST /api/shop_product_image`)
3. **VPS API** receives image, validates and resizes it
4. **VPS API** calls `upload_shop_image()` from `utils/gcs_images.py`
5. **GCS upload** happens on VPS via gcloud CLI (already authenticated)
6. **VPS API** returns the GCS public URL to Flutter
7. **Flutter app** displays the image and stores the URL

**Image Management:**
- **View:** Fetch product data from API which includes image URLs (img1_url, img2_url, img3_url)
- **Replace:** Upload new image via API → old image deleted from GCS → new image uploaded → new URL returned
- **Delete:** Call API endpoint (`DELETE /api/shop_product_image`) → image deleted from GCS → URL cleared from database
- **Update:** Same as replace - upload new image to overwrite existing slot

**API Endpoints for Images:**
- `POST /api/shop_product_image` - Upload image (multipart/form-data with user_id, inventory_id, image_index, file)
- `DELETE /api/shop_product_image` - Delete image (user_id, inventory_id, image_index)

**Image Storage Details:**
- Bucket: `salecentrastorefrontimages` (public GCS bucket)
- Path: `shop-images/{user_id}/{inventory_id}_{image_index}.jpg`
- Max size: 10 MB per image
- Auto-resize: Max 800x800, converted to JPEG
- Limit: 3 images per product (slots 1, 2, 3)

## API Integration

### Endpoints Used
- `GET /api/shop_settings` - Fetch current shop settings
- `POST /api/shop_settings` - Save shop settings
- `GET /api/inventory` - Fetch inventory products
- `GET /api/shop_products` - Fetch products enabled for storefront
- `POST /api/shop_products` - Enable inventory product for storefront with description
- `PUT /api/shop_products/{id}` - Update storefront product details (description, price, stock status, sort order, active toggle)
- `DELETE /api/shop_products/{id}` - Disable product from storefront
- `POST /api/shop_product_image` - Upload product image (multipart/form-data)
- `DELETE /api/shop_product_image` - Delete product image
- `GET /api/shop_orders` - Fetch shop orders with optional status filter
- `POST /api/shop_orders/{id}/complete` - Mark order as completed
- `POST /api/shop_orders/{id}/cancel` - Cancel/reject order
- `GET /api/shop_subscription_status` - Get subscription status

### Data Models

#### Shop Settings
```dart
class ShopSettings {
  String slug;
  String name;
  String description;
  String phone;
  String whatsappNumber;
  String email;
  String address;
  String bankName;
  String bankAccountName;
  String bankAccountNumber;
  String currency;
  String currencySymbol;
  String themeColor;
  bool isActive;
}
```

#### Shop Product (Inventory product enabled for storefront)
```dart
class ShopProduct {
  String id; // inventory product ID
  String name; // from inventory
  String description; // storefront-specific description
  double price; // storefront price (can override inventory price)
  String imageUrl; // from inventory
  int stock; // from inventory
  bool isOutOfStock; // calculated from stock
  bool isEnabled; // whether visible on storefront
  DateTime createdAt; // when enabled for storefront
  DateTime updatedAt; // last storefront update
}
```

## Implementation Checklist

- [ ] Add "My online Shop" menu item to More screen
- [ ] Create `shop_screen.dart` with tab navigation
- [ ] Implement Shop Settings tab with form
- [ ] Implement Products tab with CRUD operations
- [ ] Implement Subscription tab with platform-specific messaging
- [ ] Implement Preview tab with storefront link
- [ ] Add API service methods for shop data
- [ ] Add theme color picker component
- [ ] Add image upload for products
- [ ] Test on Android (subscription flow)
- [ ] Test on iOS (web redirect flow)
- [ ] Test storefront preview on both platforms

## UI/UX Guidelines

### More Screen
- Use shop/store icon for menu item
- Position near other account-related options
- Clear, descriptive label: "My online Shop"

### Shop Screen
- Tab-based navigation at top
- Active tab highlighted with theme color
- Save buttons clearly visible
- Loading states for API calls
- Error handling with user-friendly messages

### Subscription Tab
- Clear visual indicator of current status
- Product limit progress bar (e.g., "7/10 products used")
- Upgrade button prominent for trial/inactive users
- Platform-specific instructions clearly displayed

## Future Enhancements

- Shop analytics (views, clicks, sales)
- Order management from mobile app
- Customer management
- Promotional banner management
- Bulk product upload
- QR code generator for shop sharing
- Push notifications for new orders

## Admin Announcements System

### Overview
An in-app announcement system that allows admins to send messages to all users. Users see announcements as banners on the dashboard when they log in. This is fully compliant with iOS policies as it's an in-app UI feature, not push notifications.

### Flutter Implementation

**Location:**
- Dashboard screen (`lib/screens/dashboard/dashboard_screen.dart`)
- Announcement banner positioned after subscription status banner (high visibility)

**Behavior:**
- Fetch announcements from API on app launch/dashboard load
- Show banner if user hasn't dismissed the announcement yet (checked via API)
- Dismissible with "X" button or swipe
- Call API to dismiss announcement (stores in database, syncs across platforms)
- Only show active announcements (based on start/end dates)

**UI Components:**
- Banner with info/warning/success color based on priority
- Title and message text
- Dismiss button

### Streamlit Web Dashboard Implementation

**Location:** `app.py` (main Streamlit dashboard)

**Placement:**
- Add announcement banner at the top of the main dashboard, after the user info section
- High visibility for all web users

**Behavior:**
- Fetch announcements from database on page load
- Show banner if user hasn't dismissed the announcement yet
- Dismissible with a "Dismiss" button
- Store dismissed announcement IDs in `announcement_dismissals` table
- Only show active announcements (based on start/end dates and is_active flag)

**UI Components:**
- `st.info()`, `st.warning()`, `st.success()`, or `st.error()` based on priority
- Title and message displayed
- Dismiss button that calls dismiss_announcement() and reruns

**Implementation Example:**
```python
# In app.py, after user info section
def show_announcements(user_id):
    announcements = get_active_announcements_for_user(user_id)
    if announcements:
        for ann in announcements:
            priority_to_st = {
                'info': st.info,
                'warning': st.warning,
                'success': st.success,
                'error': st.error
            }
            display_func = priority_to_st.get(ann['priority'], st.info)
            
            with display_func.container():
                st.markdown(f"**{ann['title']}**")
                st.markdown(ann['message'])
                
                if st.button("Dismiss", key=f"dismiss_{ann['id']}"):
                    dismiss_announcement(user_id, ann['id'])
                    st.rerun()
```

### API Endpoints

- `GET /api/announcements` - Fetch active announcements
  - Returns: list of announcements with id, title, message, priority, start_date, end_date
- `POST /api/announcements/{id}/dismiss` - Mark announcement as dismissed for user
  - Body: `{ "user_id": "..." }`

### Database Schema

**New table: `announcements`**
```sql
CREATE TABLE announcements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    priority TEXT DEFAULT 'info', -- 'info', 'warning', 'success', 'error'
    start_date TEXT NOT NULL, -- ISO datetime
    end_date TEXT NOT NULL, -- ISO datetime
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    created_by INTEGER, -- Admin user id
    is_active INTEGER DEFAULT 1
);
```

**New table: `announcement_dismissals`**
```sql
CREATE TABLE announcement_dismissals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    announcement_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    dismissed_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (announcement_id) REFERENCES announcements(id),
    FOREIGN KEY (user_id) REFERENCES users(id),
    UNIQUE(announcement_id, user_id)
);
```

### Streamlit Admin Management Changes

**Location:** `utils/admin_management.py`

**New Section:** Add "📢 Announcements" expander in admin panel

**Features:**
1. **Create Announcement**
   - Title input
   - Message textarea
   - Priority dropdown (Info, Warning, Success, Error)
   - Start date picker
   - End date picker
   - Save button

2. **Active Announcements List**
   - Table showing all active announcements
   - Columns: Title, Priority, Start Date, End Date, Created At
   - Edit button (modify details)
   - Deactivate button (set is_active = 0)
   - View dismissal stats (number of users who dismissed)

3. **Announcement History**
   - List of past/inactive announcements
   - Reactivate button (set is_active = 1)
   - Delete button (permanently remove)

**Database Functions to Add:**
- `create_announcement(title, message, priority, start_date, end_date, created_by)`
- `get_active_announcements()` - Returns announcements where current date is between start/end and is_active=1
- `get_all_announcements()` - Returns all announcements for admin view
- `update_announcement(id, ...)` - Update announcement details
- `deactivate_announcement(id)` - Set is_active = 0
- `delete_announcement(id)` - Permanently delete
- `dismiss_announcement(user_id, announcement_id)` - Record dismissal
- `get_announcement_dismissal_count(announcement_id)` - Stats for admin

**UI Example:**
```python
with st.expander("📢 Announcements", expanded=False):
    tab_create, tab_active, tab_history = st.tabs(["Create", "Active", "History"])

    with tab_create:
        # Form to create new announcement
        pass

    with tab_active:
        # List active announcements with edit/deactivate buttons
        pass

    with tab_history:
        # List past announcements with reactivate/delete buttons
        pass
```

### Priority Colors

- **Info:** Blue (#0066ff) - General announcements
- **Warning:** Orange/Amber - Important but not critical
- **Success:** Green - Positive news, feature launches
- **Error:** Red - Critical alerts, urgent notices
