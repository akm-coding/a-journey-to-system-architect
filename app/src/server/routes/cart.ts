import { Router } from "express";

const router = Router();

// GET /api/cart/info -- explain that cart is client-side
router.get("/info", (_req, res) => {
  res.json({
    message:
      "Cart is stored client-side in localStorage. No authentication means no server-side cart. This is intentional for this phase.",
    storage: "localStorage",
    key: "cart",
    format: "[{ productId, name, price, quantity }]",
  });
});

export default router;
