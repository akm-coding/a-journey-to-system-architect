import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import type { CartItem } from '../api.js';

const CART_KEY = 'cart';

function getCart(): CartItem[] {
  try {
    return JSON.parse(localStorage.getItem(CART_KEY) || '[]');
  } catch {
    return [];
  }
}

function saveCart(cart: CartItem[]): void {
  localStorage.setItem(CART_KEY, JSON.stringify(cart));
}

export default function Cart() {
  const [cart, setCart] = useState<CartItem[]>(getCart());
  const navigate = useNavigate();

  function removeItem(productId: number) {
    const updated = cart.filter((item) => item.productId !== productId);
    saveCart(updated);
    setCart(updated);
  }

  function updateQuantity(productId: number, quantity: number) {
    if (quantity < 1) return;
    const updated = cart.map((item) =>
      item.productId === productId ? { ...item, quantity } : item,
    );
    saveCart(updated);
    setCart(updated);
  }

  const total = cart.reduce((sum, item) => sum + parseFloat(item.price) * item.quantity, 0);

  if (cart.length === 0) {
    return (
      <div>
        <h2>Cart</h2>
        <p>Your cart is empty.</p>
        <Link to="/" style={{ color: '#0066cc', textDecoration: 'none' }}>
          Browse Products
        </Link>
      </div>
    );
  }

  return (
    <div>
      <h2>Cart</h2>
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
            <th style={{ padding: '0.75rem 0' }}>Price</th>
            <th style={{ padding: '0.75rem 0' }}>Quantity</th>
            <th style={{ padding: '0.75rem 0' }}>Subtotal</th>
            <th style={{ padding: '0.75rem 0' }}></th>
          </tr>
        </thead>
        <tbody>
          {cart.map((item) => (
            <tr key={item.productId} style={{ borderBottom: '1px solid #e0e0e0' }}>
              <td style={{ padding: '0.75rem 0' }}>{item.name}</td>
              <td style={{ padding: '0.75rem 0' }}>${item.price}</td>
              <td style={{ padding: '0.75rem 0' }}>
                <input
                  type="number"
                  min="1"
                  value={item.quantity}
                  onChange={(e) => updateQuantity(item.productId, parseInt(e.target.value, 10))}
                  style={{
                    width: '60px',
                    padding: '0.25rem',
                    border: '1px solid #ccc',
                    borderRadius: '4px',
                  }}
                />
              </td>
              <td style={{ padding: '0.75rem 0', fontWeight: 600 }}>
                ${(parseFloat(item.price) * item.quantity).toFixed(2)}
              </td>
              <td style={{ padding: '0.75rem 0' }}>
                <button
                  onClick={() => removeItem(item.productId)}
                  style={{
                    background: 'none',
                    border: 'none',
                    color: '#cc0000',
                    cursor: 'pointer',
                    fontSize: '0.9rem',
                  }}
                >
                  Remove
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
        }}
      >
        <p style={{ fontSize: '1.25rem', fontWeight: 700 }}>Total: ${total.toFixed(2)}</p>
        <button
          onClick={() => navigate('/order')}
          style={{
            backgroundColor: '#0066cc',
            color: 'white',
            border: 'none',
            padding: '0.75rem 1.5rem',
            borderRadius: '6px',
            fontSize: '1rem',
            cursor: 'pointer',
          }}
        >
          Place Order
        </button>
      </div>
    </div>
  );
}
