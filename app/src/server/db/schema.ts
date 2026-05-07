import { integer, pgTable, varchar, text, numeric, timestamp } from 'drizzle-orm/pg-core';

export const products = pgTable('products', {
  id: integer().primaryKey().generatedAlwaysAsIdentity(),
  name: varchar({ length: 255 }).notNull(),
  description: text(),
  price: numeric({ precision: 10, scale: 2 }).notNull(),
  imageUrl: varchar('image_url', { length: 500 }),
});

export const orders = pgTable('orders', {
  id: integer().primaryKey().generatedAlwaysAsIdentity(),
  status: varchar({ length: 50 }).notNull().default('pending'),
  totalAmount: numeric('total_amount', { precision: 10, scale: 2 }).notNull(),
  createdAt: timestamp('created_at').defaultNow(),
});

export const orderItems = pgTable('order_items', {
  id: integer().primaryKey().generatedAlwaysAsIdentity(),
  orderId: integer('order_id')
    .notNull()
    .references(() => orders.id),
  productId: integer('product_id')
    .notNull()
    .references(() => products.id),
  quantity: integer().notNull(),
  price: numeric({ precision: 10, scale: 2 }).notNull(),
});
