# Flutter App Changes — Sales, Customer Info & Receipt

This document outlines the changes needed in the Flutter mobile app to match the new features implemented on the web (Streamlit) version.

---

## Summary of New Backend Behavior

The API now:
- Accepts optional `customer_name`, `customer_phone`, `customer_address` on each sale record
- Saves new customers to the `customers` table if they don't already exist
- Returns customer fields in sales data (`get_sales` responses)
- The `logo_base64` is already sent on login — no API changes needed

---

## 1. Daily Sales Entry — Optional Customer Info

### What to add:
- An **optional expandable section** or toggle below the item selection (before "Record Sale" button)
- Fields: Customer Name, Phone, Email (optional), Address (optional)
- If customer name is entered, search existing customers via API (optional UX improvement)
- All fields are optional — sale can still be submitted without any customer info

### API call change:
When recording a sale, include the optional fields in each sale line POST:

```json
{
  "item": "Product A",
  "quantity": 2,
  "price": 1500.00,
  "discount": 0,
  "customer_name": "John Doe",
  "customer_phone": "08012345678",
  "customer_address": "12 Main Street, Lagos"
}
```

If no customer info, simply omit the fields or send empty strings.

### Customer save logic:
After sale is recorded, if `customer_name` and `customer_phone` are provided:
- Call `POST /api/customers/add` (or similar) to save to the customers table
- Only save if customer doesn't already exist (check by name or phone)

> **Note:** If no customer endpoint exists yet in the Flask API, one needs to be created. Currently customer save is handled server-side on the Streamlit web version only.

---

## 2. Receipt Generation — Include Customer Info

### Current behavior:
- POS receipt shows: logo, business name/address, receipt no, date, time, staff, items, total

### New behavior:
- If customer info was entered, the receipt should also show:
  - **Customer:** [name]
  - **Phone:** [phone] (if provided)
  - **Address:** [address] (if provided)
- Position: between the Date/Time/Staff section and the items table

### Receipt layout (after staff line):
```
─────────────────────────
Date          20 Jun 2025
Time          10:30 AM
Staff         John
─────────────────────────
Customer      Jane Smith
Phone         08098765432
Address       5 Broad St, Abuja
─────────────────────────
Item   Qty   Unit   Total
...
```

If no customer info was entered, this section is simply not shown (same as before).

---

## 3. Staff Sales Entry — Receipt with Business Logo & Staff Name

The staff sales entry screen must also generate a full POS receipt after sale completion.

### Receipt must include:
- **Business logo** (from `logo_base64` returned on login)
- **Business name & address**
- **Receipt number** (sale ID)
- **Date & Time**
- **Staff name** (the logged-in staff member who recorded the sale)
- **Customer info** (if entered — same optional fields as section 1)
- **Items table** (item, qty, unit price, discount, total)
- **Grand total**
- **"Powered by SaleCentra"** footer

### Receipt layout:
```
[Business Logo]
Business Name
Business Address
─────────────────────────
SALECENTRA POS RECEIPT
Receipt No: SALE-ABC123
─────────────────────────
Date          20 Jun 2025
Time          10:30 AM
Staff         Mary
─────────────────────────
Customer      Jane Smith      (if provided)
Phone         08098765432     (if provided)
Address       5 Broad St      (if provided)
─────────────────────────
Item   Qty   Unit   Disc  Total
Shoe    2    5000   0     10000
─────────────────────────
TOTAL                     ₦10,000.00
─────────────────────────
Powered by SaleCentra
```

### Key notes:
- The staff name comes from the login session (`sales_entry_staff_name`)
- Logo is available as `logo_base64` in the user object returned at login
- After recording the sale, show the receipt immediately with a **Download PDF** button
- A **"New Sale"** button should clear all inputs and dismiss the receipt

---

## 4. API Endpoints Reference

| Action | Method | Endpoint | Notes |
|--------|--------|----------|-------|
| Record sale | POST | `/api/sales/record` | Now accepts optional `customer_name`, `customer_phone`, `customer_address` |
| Get sales | GET | `/api/sales?user_id=...` | Response now includes customer fields |
| Add customer | POST | `/api/customers/add` | May need to be created — see note below |
| Search customers | GET | `/api/customers/search?user_id=...&term=...` | May need to be created |

---

## 5. API Endpoints That May Need to Be Created

The web version handles customer save/search internally via direct DB access. For the Flutter app to have the same functionality, these API endpoints may need to be added to `api/app.py`:

### POST `/api/customers/add`
```json
Request:
{
  "user_id": "...",
  "name": "Jane Smith",
  "phone": "08098765432",
  "email": "jane@email.com",  // optional
  "address": "5 Broad St"     // optional
}

Response:
{ "customer_id": "uuid-here", "message": "Customer added" }
```

### GET `/api/customers/search`
```
GET /api/customers/search?user_id=...&term=Jane

Response:
{ "customers": [ { "id": "...", "name": "Jane Smith", "phone": "...", ... } ] }
```

---

## 6. No Changes Needed

- Login API — already returns `logo_base64`
- Inventory API — unchanged
- Stock update — unchanged (handled server-side on sale record)

---

## Priority

| Task | Priority |
|------|----------|
| Add optional customer fields to sale entry UI (owner & staff) | High |
| Save customer info on sale record (API call) | High |
| Show customer info on POS receipt (owner & staff) | High |
| Staff receipt with business logo + staff name | High |
| New Sale button to reset form after sale | High |
| Create customer add/search API endpoints | High (blocker for above) |
