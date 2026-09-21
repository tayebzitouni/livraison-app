CREATE TABLE IF NOT EXISTS platform_settings(
  id INTEGER PRIMARY KEY CHECK(id=1),
  commission_percent INTEGER NOT NULL DEFAULT 10 CHECK(commission_percent BETWEEN 0 AND 100),
  delivery_fee INTEGER NOT NULL DEFAULT 200 CHECK(delivery_fee>=0)
);
INSERT OR IGNORE INTO platform_settings(id,commission_percent,delivery_fee) VALUES(1,10,200);
ALTER TABLE products ADD COLUMN approval_status TEXT NOT NULL DEFAULT 'approved' CHECK(approval_status IN('pending','approved','rejected'));
ALTER TABLE orders ADD COLUMN commission_percent INTEGER NOT NULL DEFAULT 10;
ALTER TABLE orders ADD COLUMN commission_amount INTEGER NOT NULL DEFAULT 0;
UPDATE orders SET commission_amount=ROUND(food_total*commission_percent/100.0);
UPDATE orders SET commission_amount=(SELECT amount FROM wallet_entries WHERE order_id=orders.id AND entry_type='commission' LIMIT 1)
WHERE EXISTS(SELECT 1 FROM wallet_entries WHERE order_id=orders.id AND entry_type='commission');
