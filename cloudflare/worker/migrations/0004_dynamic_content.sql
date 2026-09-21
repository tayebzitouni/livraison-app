ALTER TABLE users ADD COLUMN address TEXT NOT NULL DEFAULT '';
ALTER TABLE users ADD COLUMN avatar_url TEXT;
ALTER TABLE products ADD COLUMN media_url TEXT;
ALTER TABLE products ADD COLUMN media_type TEXT NOT NULL DEFAULT 'image' CHECK(media_type IN('image','video'));
ALTER TABLE products ADD COLUMN ingredients TEXT NOT NULL DEFAULT '';
ALTER TABLE products ADD COLUMN allergens TEXT NOT NULL DEFAULT '';
ALTER TABLE products ADD COLUMN preparation_minutes INTEGER NOT NULL DEFAULT 15;
ALTER TABLE products ADD COLUMN calories INTEGER;
ALTER TABLE orders ADD COLUMN client_confirmed_at TEXT;

UPDATE orders SET client_confirmed_at=created_at WHERE status='delivered';

CREATE TABLE IF NOT EXISTS categories(
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  kind TEXT NOT NULL CHECK(kind IN('meal','grocery')),
  active INTEGER NOT NULL DEFAULT 1,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_by TEXT REFERENCES users(id),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(name,kind)
);

CREATE TABLE IF NOT EXISTS notifications(
  id TEXT PRIMARY KEY,
  recipient_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'info',
  order_id TEXT REFERENCES orders(id) ON DELETE CASCADE,
  event_key TEXT NOT NULL,
  is_read INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(recipient_id,event_key)
);

CREATE INDEX IF NOT EXISTS notifications_recipient_idx ON notifications(recipient_id,is_read,created_at);

INSERT OR IGNORE INTO categories(id,name,kind,sort_order) VALUES
 ('cat-healthy','Healthy','meal',10),
 ('cat-pasta','Pâtes','meal',20),
 ('cat-burgers','Burgers','meal',30),
 ('cat-pizza','Pizza','meal',40),
 ('cat-desserts','Desserts','meal',50),
 ('cat-fresh','Frais','grocery',10),
 ('cat-bakery','Boulangerie','grocery',20),
 ('cat-drinks','Boissons','grocery',30),
 ('cat-home','Maison','grocery',40);
