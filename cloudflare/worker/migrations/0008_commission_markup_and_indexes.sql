-- A restaurant's entered price is the amount they receive. The platform
-- commission is added on top for meals only. Grocery customer prices are
-- chosen directly by the administrator and must never be percentage-derived.
UPDATE products
SET retail_price=wholesale_price + CAST(ROUND(
  wholesale_price * (
    SELECT commission_percent FROM platform_settings WHERE id=1
  ) / 100.0
) AS INTEGER)
WHERE kind='meal';

-- Index the paths used by every refresh. These are safe for existing data and
-- materially reduce catalogue, wallet and order-history query time.
CREATE INDEX IF NOT EXISTS order_items_order_idx ON order_items(order_id);
CREATE INDEX IF NOT EXISTS products_visibility_idx ON products(active,approval_status,created_at);
CREATE INDEX IF NOT EXISTS products_owner_idx ON products(owner_id,created_at);
CREATE INDEX IF NOT EXISTS wallet_owner_idx ON wallet_entries(owner_id,created_at);
CREATE INDEX IF NOT EXISTS users_role_active_idx ON users(role,active);
