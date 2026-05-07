import React from 'react';
import { Routes, Route, Link } from 'react-router-dom';
import ProductList from './pages/ProductList.js';
import ProductDetail from './pages/ProductDetail.js';
import Cart from './pages/Cart.js';
import PlaceOrder from './pages/PlaceOrder.js';

const navStyle: React.CSSProperties = {
  display: 'flex',
  gap: '1.5rem',
  padding: '1rem 2rem',
  borderBottom: '1px solid #e0e0e0',
  backgroundColor: '#f8f9fa',
  alignItems: 'center',
};

const linkStyle: React.CSSProperties = {
  textDecoration: 'none',
  color: '#333',
  fontWeight: 500,
};

const titleStyle: React.CSSProperties = {
  margin: 0,
  fontSize: '1.2rem',
  fontWeight: 700,
  marginRight: 'auto',
};

export default function App() {
  return (
    <div style={{ fontFamily: 'system-ui, sans-serif', color: '#333' }}>
      <nav style={navStyle}>
        <h1 style={titleStyle}>
          <Link to="/" style={{ ...linkStyle, color: '#111' }}>
            Store
          </Link>
        </h1>
        <Link to="/" style={linkStyle}>
          Products
        </Link>
        <Link to="/cart" style={linkStyle}>
          Cart
        </Link>
      </nav>
      <main style={{ padding: '2rem', maxWidth: '960px', margin: '0 auto' }}>
        <Routes>
          <Route path="/" element={<ProductList />} />
          <Route path="/products/:id" element={<ProductDetail />} />
          <Route path="/cart" element={<Cart />} />
          <Route path="/order" element={<PlaceOrder />} />
        </Routes>
      </main>
    </div>
  );
}
