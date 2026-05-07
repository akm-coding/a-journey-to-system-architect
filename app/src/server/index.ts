import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import healthRouter from './routes/health.js';
import productsRouter from './routes/products.js';
import ordersRouter from './routes/orders.js';
import cartRouter from './routes/cart.js';

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Health check -- mounted BEFORE other routes so it is always accessible
// Mounted at root (not /api) so load balancers and CI health checks can hit /health directly
app.use(healthRouter);

// Mount API routes
app.use('/api/products', productsRouter);
app.use('/api/orders', ordersRouter);
app.use('/api/cart', cartRouter);

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`API running on port ${PORT}`);
});

export default app;
