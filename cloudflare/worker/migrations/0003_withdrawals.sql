CREATE TABLE IF NOT EXISTS withdrawal_requests(
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL REFERENCES users(id),
  amount INTEGER NOT NULL CHECK(amount>0),
  status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN('pending','approved','rejected','paid')),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS withdrawals_owner_idx ON withdrawal_requests(owner_id,status,created_at);
