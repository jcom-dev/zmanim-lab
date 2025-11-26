#!/usr/bin/env node
/**
 * Simple migration runner for Supabase
 * Usage: node scripts/run-migration.js <migration-file.sql>
 */

const { Client } = require('/home/coder/workspace/zmanim-lab/web/node_modules/pg');
const fs = require('fs');
const path = require('path');

async function runMigration(migrationFile) {
  // Load environment
  const envPath = path.join(__dirname, '..', '.env.supabase');
  if (fs.existsSync(envPath)) {
    const envContent = fs.readFileSync(envPath, 'utf8');
    envContent.split('\n').forEach(line => {
      const [key, ...valueParts] = line.split('=');
      if (key && valueParts.length > 0) {
        process.env[key.trim()] = valueParts.join('=').trim();
      }
    });
  }

  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) {
    console.error('DATABASE_URL not found in .env.supabase');
    process.exit(1);
  }

  // Read migration file
  const migrationPath = path.resolve(migrationFile);
  if (!fs.existsSync(migrationPath)) {
    console.error(`Migration file not found: ${migrationPath}`);
    process.exit(1);
  }

  const sql = fs.readFileSync(migrationPath, 'utf8');
  console.log(`Running migration: ${path.basename(migrationPath)}`);

  // Connect and run
  const client = new Client({
    connectionString: databaseUrl,
    ssl: { rejectUnauthorized: false }
  });

  try {
    await client.connect();
    console.log('Connected to database');

    await client.query(sql);
    console.log('Migration completed successfully!');
  } catch (error) {
    console.error('Migration failed:', error.message);
    if (error.detail) console.error('Detail:', error.detail);
    process.exit(1);
  } finally {
    await client.end();
  }
}

const migrationFile = process.argv[2];
if (!migrationFile) {
  console.error('Usage: node scripts/run-migration.js <migration-file.sql>');
  process.exit(1);
}

runMigration(migrationFile);
