import 'dotenv/config';
import { drizzle } from 'drizzle-orm/node-postgres';
import { products } from './schema.js';

const db = drizzle(process.env.DATABASE_URL!);

const sampleProducts = [
  {
    name: 'Wireless Bluetooth Headphones',
    description:
      'Over-ear noise-cancelling headphones with 30-hour battery life and premium sound quality.',
    price: '79.99',
    imageUrl: null,
  },
  {
    name: 'Mechanical Keyboard',
    description:
      'Compact 75% layout mechanical keyboard with hot-swappable switches and RGB backlighting.',
    price: '129.99',
    imageUrl: null,
  },
  {
    name: 'USB-C Hub Adapter',
    description: '7-in-1 USB-C hub with HDMI, USB 3.0, SD card reader, and 100W power delivery.',
    price: '34.99',
    imageUrl: null,
  },
  {
    name: 'Portable SSD 1TB',
    description:
      'External solid state drive with 1050MB/s read speed and rugged aluminum enclosure.',
    price: '89.99',
    imageUrl: null,
  },
  {
    name: 'Webcam HD 1080p',
    description:
      'Full HD webcam with auto-focus, dual microphones, and adjustable mount for monitors.',
    price: '49.99',
    imageUrl: null,
  },
  {
    name: 'Desk LED Lamp',
    description:
      'Adjustable LED desk lamp with 5 brightness levels, color temperature control, and USB charging port.',
    price: '39.99',
    imageUrl: null,
  },
  {
    name: 'Ergonomic Mouse',
    description: 'Vertical ergonomic wireless mouse with 6 buttons and adjustable DPI up to 4000.',
    price: '29.99',
    imageUrl: null,
  },
  {
    name: 'Monitor Stand Riser',
    description:
      'Bamboo monitor stand with storage drawer and cable management slots. Supports up to 50 lbs.',
    price: '44.99',
    imageUrl: null,
  },
];

async function seed() {
  console.log('Seeding products...');
  const inserted = await db.insert(products).values(sampleProducts).returning();
  console.log(`Inserted ${inserted.length} products:`);
  for (const product of inserted) {
    console.log(`  - ${product.name} ($${product.price})`);
  }
  console.log('Seeding complete.');
  process.exit(0);
}

seed().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
