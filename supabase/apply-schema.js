const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: '.env.supabase' });

async function applySchema() {
  console.log('🚀 Applying database schema to Supabase...\n');

  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY;

  if (!supabaseUrl || !supabaseServiceKey) {
    console.error('❌ Missing Supabase credentials');
    process.exit(1);
  }

  // Create Supabase client with service role key (bypasses RLS)
  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  // Read the migration SQL file
  const schemaPath = path.join(__dirname, 'supabase/migrations/20240001_initial_schema.sql');

  if (!fs.existsSync(schemaPath)) {
    console.error('❌ Migration file not found:', schemaPath);
    process.exit(1);
  }

  const schemaSql = fs.readFileSync(schemaPath, 'utf8');

  console.log('📄 Migration file loaded');
  console.log('📊 Executing SQL statements...\n');

  try {
    // Execute the SQL using Supabase's RPC or direct query
    // Note: For complex migrations with multiple statements, we need to use the database URL directly
    const { Client } = require('pg');
    const dns = require('dns');

    // Force IPv4 preference
    dns.setDefaultResultOrder('ipv4first');

    const databaseUrl = process.env.DATABASE_URL;
    if (!databaseUrl) {
      console.error('❌ DATABASE_URL not found in .env.supabase');
      process.exit(1);
    }

    const client = new Client({
      connectionString: databaseUrl,
      // Additional connection options to prefer IPv4
      options: '-c default_transaction_isolation=read-committed',
    });

    await client.connect();
    console.log('✅ Connected to database');

    // Execute the schema
    await client.query(schemaSql);
    console.log('✅ Schema applied successfully!\n');

    // Verify tables were created
    const { rows } = await client.query(`
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'public'
      AND table_type = 'BASE TABLE'
      ORDER BY table_name;
    `);

    console.log('📋 Created tables:');
    rows.forEach(row => {
      console.log(`  ✓ ${row.table_name}`);
    });

    await client.end();
    console.log('\n✨ Database schema setup complete!');

  } catch (error) {
    console.error('❌ Error applying schema:', error.message);
    if (error.stack) {
      console.error('\nStack trace:');
      console.error(error.stack);
    }
    process.exit(1);
  }
}

applySchema();
