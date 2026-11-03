# Database schema (version 1)

Engine: SQLite via SQLCipher (AES-256). The passphrase is random per install and lives only in
Android Keystore-backed secure storage. Money = integer paise. Quantity = integer milli-units
(1 kg = 1000). Dates = local ISO-8601 text. Foreign keys are ON. Migrations: `AppDatabase.migrate`.

| Table | Purpose / key columns |
|---|---|
| shop_profile | single row (id = 1): owner_name, shop_name, category, phone, address, language, currency, opening_date |
| roles, permissions | role names; (role, permission, allowed) matrix. Owner-only permissions are also enforced in code |
| users | name, role, pin_hash (`iterations:PBKDF2-SHA256 hex`), pin_salt, active |
| categories | reserved (product category is stored on the product) |
| **products** | **ONE table** with `wholesale_price` and `retail_price` (independent, nullable), unit, stock_milli, min_stock_milli, alt_names, barcode, description, expiry_date, active, deleted (soft delete), created_at, updated_at |
| price_history | product_id, price_type (retail/wholesale), old_price, new_price, changed_at, changed_by. **Append-only**: triggers block UPDATE/DELETE |
| bills | bill_no (unique), totals, payment_method, customer, created_by, idem_key (unique, prevents duplicates) |
| bill_items | **price snapshot**: product_name, qty_milli, unit, unit_price, line_total, discount, tax, final_amount. product_id may become NULL; old bills never change |
| stock_movements | product_id, change_milli, balance_milli, reason (sale, purchase, stock_in, stock_out, adjustment, initial), ref, created_by |
| suppliers, purchases, purchase_items | purchases with their own unit_cost, independent of selling prices. No profit is calculated |
| audit_logs | who did what and when (price changes, wholesale views, bills, logins, backups) |
| app_settings | key/value (tax rate, auto-lock, negative stock, notification options, last backup, ...) |

Indexes: products(name, barcode, deleted+active), bills(created_at), bill_items(bill_id, product_id),
price_history(product_id), stock_movements(product_id), purchase_items(purchase_id).
