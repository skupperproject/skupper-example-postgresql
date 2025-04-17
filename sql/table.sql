create table if not exists product (
  id    SERIAL,
  name  VARCHAR(100) NOT NULL,
  sku   CHAR(8)
);
