const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: '.env.supabase' });

async function applySeedData() {
  console.log('🌱 Applying seed data to Supabase...\n');

  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY;

  if (!supabaseUrl || !supabaseServiceKey) {
    console.error('❌ Missing Supabase credentials');
    process.exit(1);
  }

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
    options: '-c default_transaction_isolation=read-committed',
  });

  try {
    await client.connect();
    console.log('✅ Connected to database');

    // Read the seed SQL file
    const seedPath = path.join(__dirname, 'supabase/seed.sql');

    if (!fs.existsSync(seedPath)) {
      console.error('❌ Seed file not found:', seedPath);
      process.exit(1);
    }

    const seedSql = fs.readFileSync(seedPath, 'utf8');
    console.log('📄 Seed file loaded');

    // Execute the seed data
    console.log('🌱 Inserting seed data...\n');
    await client.query(seedSql);
    console.log('✅ Seed data applied successfully!\n');

    // Verify data was inserted
    const verifyQueries = [
      { name: 'Geographic Regions', query: 'SELECT COUNT(*) FROM geographic_regions' },
      { name: 'Publishers', query: 'SELECT COUNT(*) FROM publishers' },
      { name: 'Algorithms', query: 'SELECT COUNT(*) FROM algorithms' },
      { name: 'Coverage Areas', query: 'SELECT COUNT(*) FROM coverage_areas' }
    ];

    console.log('📊 Verification:');
    for (const { name, query } of verifyQueries) {
      const { rows } = await client.query(query);
      console.log(`  ✓ ${name}: ${rows[0].count} records`);
    }

    await client.end();
    console.log('\n✨ Seed data setup complete!');

  } catch (error) {
    console.error('❌ Error applying seed data:', error.message);
    if (error.stack) {
      console.error('\nStack trace:');
      console.error(error.stack);
    }
    process.exit(1);
  }
}

applySeedData();
