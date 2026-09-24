BEGIN;
CREATE TABLE IF NOT EXISTS orders (
  id uuid PRIMARY KEY,
  customer_id uuid NOT NULL,
  status text NOT NULL CHECK (status IN ('pending','confirmed','cancelled')),
  total_cents bigint NOT NULL CHECK (total_cents >= 0),
  created_at timestamptz NOT NULL DEFAULT now()
);
COMMIT;
