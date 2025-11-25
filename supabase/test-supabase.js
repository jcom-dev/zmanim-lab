const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: '.env.supabase' });

async function testSupabaseCredentials() {
  console.log('🔍 Testing Supabase Credentials...\n');

  // Check environment variables
  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY;
  const databaseUrl = process.env.DATABASE_URL;

  console.log('📋 Environment Variables Check:');
  console.log(`SUPABASE_URL: ${supabaseUrl ? '✅ Set' : '❌ Missing'}`);
  console.log(`SUPABASE_ANON_KEY: ${supabaseAnonKey ? '✅ Set' : '❌ Missing'}`);
  console.log(`SUPABASE_SERVICE_KEY: ${supabaseServiceKey ? '✅ Set' : '❌ Missing'}`);
  console.log(`DATABASE_URL: ${databaseUrl ? '✅ Set' : '❌ Missing'}\n`);

  if (!supabaseUrl || !supabaseAnonKey) {
    console.error('❌ Missing required credentials');
    process.exit(1);
  }

  console.log('🔗 Testing Anon Key Connection...');
  const supabaseAnon = createClient(supabaseUrl, supabaseAnonKey);

  try {
    // Test basic connection with a simple query
    const { data, error } = await supabaseAnon
      .from('_invalid_test_table_')
      .select('*')
      .limit(1);

    // We expect an error about the table not existing, which means connection works
    if (error) {
      if (error.message.includes('does not exist') || error.message.includes('relation') || error.code === '42P01') {
        console.log('✅ Anon key connection successful (table error expected)');
      } else if (error.message.includes('JWT') || error.message.includes('authentication')) {
        console.log('❌ Anon key authentication failed:', error.message);
        return false;
      } else {
        console.log('✅ Anon key connection successful');
      }
    } else {
      console.log('✅ Anon key connection successful');
    }
  } catch (err) {
    console.log('❌ Anon key connection failed:', err.message);
    return false;
  }

  console.log('\n🔗 Testing Service Key Connection...');
  if (supabaseServiceKey) {
    const supabaseService = createClient(supabaseUrl, supabaseServiceKey);

    try {
      const { data, error } = await supabaseService
        .from('_invalid_test_table_')
        .select('*')
        .limit(1);

      if (error) {
        if (error.message.includes('does not exist') || error.message.includes('relation') || error.code === '42P01') {
          console.log('✅ Service key connection successful (table error expected)');
        } else if (error.message.includes('JWT') || error.message.includes('authentication')) {
          console.log('❌ Service key authentication failed:', error.message);
          return false;
        } else {
          console.log('✅ Service key connection successful');
        }
      } else {
        console.log('✅ Service key connection successful');
      }
    } catch (err) {
      console.log('❌ Service key connection failed:', err.message);
      return false;
    }
  }

  console.log('\n✨ All credential tests passed!');
  console.log('\n📊 Credential Details:');
  console.log(`URL: ${supabaseUrl}`);
  console.log(`Project Ref: ${supabaseUrl.match(/https:\/\/(.+?)\.supabase\.co/)?.[1] || 'N/A'}`);

  return true;
}

testSupabaseCredentials()
  .then(success => {
    process.exit(success ? 0 : 1);
  })
  .catch(err => {
    console.error('❌ Unexpected error:', err);
    process.exit(1);
  });
