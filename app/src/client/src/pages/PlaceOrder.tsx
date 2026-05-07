import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { createOrder, type CartItem, type Order } from '../api.js';

const CART_KEY = 'cart';

function getCart(): CartItem[] {
  try {
    return JSON.parse(localStorage.getItem(CART_KEY) || '[]');
  } catch {
    return [];
  }
}

function clearCart(): void {
  localStorage.removeItem(CART_KEY);
}

export default function PlaceOrder() {
  const [cart, setCart] = useState<CartItem[]>([]);
  const [submitting, setSubmitting] = useState(false);
  const [order, setOrder] = useState<Order | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setCart(getCart());
  }, []);

  const total = cart.reduce((sum, item) => sum + parseFloat(item.price) * item.quantity, 0);

  async function handleConfirm() {
    setSubmitting(true);
    setError(null);
    try {
      const items = cart.map((item) => ({
        productId: item.productId,
        quantity: item.quantity,
      }));
      const result = await createOrder(items);
      setOrder(result);
      clearCart();
      setCart([]);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to place order');
    } finally {
      setSubmitting(false);
    }
  }

  if (order) {
    return (
      <div style={{ textAlign: 'center', padding: '2rem 0' }}>
        <h2 style={{ color: '#2a7d2e' }}>Order Confirmed!</h2>
        <p style={{ fontSize: '1.1rem' }}>
          Your order ID is <strong>#{order.id}</strong>
        </p>
        <p>
          Status: <strong>{order.status}</strong>
        </p>
        <p>
          Total: <strong>${order.totalAmount}</strong>
        </p>
        <Link
          to="/"
          style={{
            color: '#0066cc',
            textDecoration: 'none',
            fontSize: '1rem',
          }}
        >
          Continue Shopping
        </Link>
      </div>
    );
  }

  if (cart.length === 0) {
    return (
      <div>
        <h2>Place Order</h2>
        <p>Your cart is empty. Add some products first.</p>
        <Link to="/" style={{ color: '#0066cc', textDecoration: 'none' }}>
          Browse Products
        </Link>
      </div>
    );
  }

  return (
    <div>
      <h2>Order Summary</h2>

      <table
        style={{
          width: '100%',
          borderCollapse: 'collapse',
          marginBottom: '1.5rem',
        }}
      >
        <thead>
          <tr style={{ borderBottom: '2px solid #e0e0e0', textAlign: 'left' }}>
            <th style={{ padding: '0.75rem 0' }}>Product</th>
            <th style={{ padding: '0.75rem 0' }}>Qty</th>
            <th style={{ padding: '0.75rem 0' }}>Subtotal</th>
          </tr>
        </thead>
        <tbody>
          {cart.map((item) => (
            <tr key={item.productId} style={{ borderBottom: '1px solid #e0e0e0' }}>
              <td style={{ padding: '0.75rem 0' }}>{item.name}</td>
              <td style={{ padding: '0.75rem 0' }}>{item.quantity}</td>
              <td style={{ padding: '0.75rem 0', fontWeight: 600 }}>
                ${(parseFloat(item.price) * item.quantity).toFixed(2)}
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      <p style={{ fontSize: '1.25rem', fontWeight: 700 }}>Total: ${total.toFixed(2)}</p>

      {error && <p style={{ color: 'red', marginBottom: '1rem' }}>Error: {error}</p>}

      <div style={{ display: 'flex', gap: '1rem', marginTop: '1rem' }}>
        <Link
          to="/cart"
          style={{
            color: '#0066cc',
            textDecoration: 'none',
            padding: '0.75rem 1.5rem',
            border: '1px solid #0066cc',
            borderRadius: '6px',
          }}
        >
          Back to Cart
        </Link>
        <button
          onClick={handleConfirm}
          disabled={submitting}
          style={{
            backgroundColor: submitting ? '#999' : '#2a7d2e',
            color: 'white',
            border: 'none',
            padding: '0.75rem 1.5rem',
            borderRadius: '6px',
            fontSize: '1rem',
            cursor: submitting ? 'not-allowed' : 'pointer',
          }}
        >
          {submitting ? 'Placing Order...' : 'Confirm Order'}
        </button>
      </div>
    </div>
  );
}
