CREATE INDEX CONCURRENTLY IF NOT EXISTS orders_customer_created_idx ON orders(customer_id, created_at DESC);
CREATE INDEX CONCURRENTLY IF NOT EXISTS outbox_unpublished_idx ON outbox_events(occurred_at) WHERE published_at IS NULL;
