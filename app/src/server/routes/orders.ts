import { Router } from 'express';
import { eq } from 'drizzle-orm';
import { db } from '../db/index.js';
import { orders, orderItems, products } from '../db/schema.js';

const router = Router();

interface OrderItemInput {
  productId: number;
  quantity: number;
}

// POST /api/orders -- create order with items
router.post('/', async (req, res) => {
  try {
    const { items } = req.body as { items: OrderItemInput[] };

    if (!items || !Array.isArray(items) || items.length === 0) {
      res.status(400).json({ error: 'Order must include at least one item' });
      return;
    }

    // Validate items have required fields
    for (const item of items) {
      if (!item.productId || !item.quantity || item.quantity < 1) {
        res.status(400).json({ error: 'Each item must have a valid productId and quantity' });
        return;
      }
    }

    // Look up product prices
    const foundProducts = await db.select().from(products);
    const productMap = new Map(foundProducts.map((p) => [p.id, p]));

    // Verify all products exist and calculate total
    let totalAmount = 0;
    const itemsWithPrice: { productId: number; quantity: number; price: number }[] = [];

    for (const item of items) {
      const product = productMap.get(item.productId);
      if (!product) {
        res.status(400).json({ error: `Product with ID ${item.productId} not found` });
        return;
      }
      const price = parseFloat(product.price);
      totalAmount += price * item.quantity;
      itemsWithPrice.push({
        productId: item.productId,
        quantity: item.quantity,
        price,
      });
    }

    // Create the order
    const [order] = await db
      .insert(orders)
      .values({ totalAmount: totalAmount.toFixed(2) })
      .returning();

    // Create order items
    const insertedItems = await db
      .insert(orderItems)
      .values(
        itemsWithPrice.map((item) => ({
          orderId: order.id,
          productId: item.productId,
          quantity: item.quantity,
          price: item.price.toFixed(2),
        })),
      )
      .returning();

    res.status(201).json({
      ...order,
      items: insertedItems,
    });
  } catch (err) {
    console.error('Error creating order:', err);
    res.status(500).json({ error: 'Failed to create order' });
  }
});

// GET /api/orders/:id -- return order with items
router.get('/:id', async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    if (isNaN(id)) {
      res.status(400).json({ error: 'Invalid order ID' });
      return;
    }

    const [order] = await db.select().from(orders).where(eq(orders.id, id));

    if (!order) {
      res.status(404).json({ error: 'Order not found' });
      return;
    }

    const items = await db.select().from(orderItems).where(eq(orderItems.orderId, id));

    res.json({ ...order, items });
  } catch (err) {
    console.error('Error fetching order:', err);
    res.status(500).json({ error: 'Failed to fetch order' });
  }
});

export default router;
