import React, { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import { getProduct, type Product, type CartItem } from '../api.js';

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

export default function ProductDetail() {
  const { id } = useParams<{ id: string }>();
  const [product, setProduct] = useState<Product | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [added, setAdded] = useState(false);

  useEffect(() => {
    if (!id) return;
    getProduct(parseInt(id, 10))
      .then(setProduct)
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, [id]);

  function addToCart() {
    if (!product) return;
    const cart = getCart();
    const existing = cart.find((item) => item.productId === product.id);
    if (existing) {
      existing.quantity += 1;
    } else {
      cart.push({
        productId: product.id,
        name: product.name,
        price: product.price,
        quantity: 1,
      });
    }
    saveCart(cart);
    setAdded(true);
    setTimeout(() => setAdded(false), 2000);
  }

  if (loading) return <p>Loading product...</p>;
  if (error) return <p style={{ color: 'red' }}>Error: {error}</p>;
  if (!product) return <p>Product not found.</p>;

  return (
    <div>
      <Link to="/" style={{ color: '#0066cc', textDecoration: 'none', fontSize: '0.9rem' }}>
        &larr; Back to Products
      </Link>

      <div style={{ marginTop: '1.5rem' }}>
        <div
          style={{
            width: '100%',
            height: '200px',
            backgroundColor: '#f0f0f0',
            borderRadius: '8px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: '#999',
            fontSize: '0.9rem',
            marginBottom: '1.5rem',
          }}
        >
          Image placeholder
        </div>

        <h2 style={{ margin: '0 0 0.5rem 0' }}>{product.name}</h2>
        <p
          style={{
            fontSize: '1.5rem',
            fontWeight: 600,
            color: '#2a7d2e',
            margin: '0 0 1rem 0',
          }}
        >
          ${product.price}
        </p>
        <p style={{ color: '#555', lineHeight: 1.6 }}>{product.description}</p>

        <button
          onClick={addToCart}
          style={{
            backgroundColor: added ? '#2a7d2e' : '#0066cc',
            color: 'white',
            border: 'none',
            padding: '0.75rem 1.5rem',
            borderRadius: '6px',
            fontSize: '1rem',
            cursor: 'pointer',
            marginTop: '1rem',
          }}
        >
          {added ? 'Added to Cart!' : 'Add to Cart'}
        </button>
      </div>
    </div>
  );
}
