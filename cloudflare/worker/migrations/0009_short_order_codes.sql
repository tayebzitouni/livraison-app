-- Human-friendly order references: #1000, #1001, ...
CREATE TABLE IF NOT EXISTS order_counter (
  id INTEGER PRIMARY KEY CHECK(id=1),
  next_value INTEGER NOT NULL CHECK(next_value>=1000)
);

INSERT OR IGNORE INTO order_counter(id,next_value) VALUES(1,1000);
