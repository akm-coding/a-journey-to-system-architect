import React, { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { getProducts, type Product } from "../api.js";

const gridStyle: React.CSSProperties = {
  display: "grid",
  gridTemplateColumns: "repeat(auto-fill, minmax(250px, 1fr))",
  gap: "1.5rem",
};

const cardStyle: React.CSSProperties = {
  border: "1px solid #e0e0e0",
  borderRadius: "8px",
  padding: "1.5rem",
  display: "flex",
  flexDirection: "column",
  gap: "0.5rem",
};

const priceStyle: React.CSSProperties = {
  fontSize: "1.25rem",
  fontWeight: 600,
  color: "#2a7d2e",
};

export default function ProductList() {
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getProducts()
      .then(setProducts)
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <p>Loading products...</p>;
  if (error) return <p style={{ color: "red" }}>Error: {error}</p>;
  if (products.length === 0) return <p>No products found.</p>;

  return (
    <div>
      <h2>Products</h2>
      <div style={gridStyle}>
        {products.map((product) => (
          <div key={product.id} style={cardStyle}>
            <h3 style={{ margin: 0 }}>{product.name}</h3>
            <p style={priceStyle}>${product.price}</p>
            <p
              style={{
                color: "#666",
                fontSize: "0.9rem",
                flex: 1,
                margin: 0,
              }}
            >
              {product.description?.slice(0, 100)}
              {(product.description?.length ?? 0) > 100 ? "..." : ""}
            </p>
            <Link
              to={`/products/${product.id}`}
              style={{
                color: "#0066cc",
                textDecoration: "none",
                fontWeight: 500,
              }}
            >
              View Details
            </Link>
          </div>
        ))}
      </div>
    </div>
  );
}
