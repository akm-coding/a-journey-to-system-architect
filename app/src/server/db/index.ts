import 'dotenv/config';
import { drizzle } from 'drizzle-orm/node-postgres';
import * as schema from './schema.js';

if (!process.env.DATABASE_URL) {
  console.warn('WARNING: DATABASE_URL is not set. Database queries will fail at runtime.');
}

export const db = drizzle(process.env.DATABASE_URL!, { schema });
