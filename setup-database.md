# Database Setup Instructions

Your Supabase credentials test passed successfully! ✅

However, due to network connectivity constraints, you'll need to apply the database schema manually through the Supabase dashboard.

## Step 1: Access Supabase SQL Editor

1. Go to https://supabase.com/dashboard
2. Select your project: **bwyrcnimgpiwrngxvser**
3. Click on "SQL Editor" in the left sidebar

## Step 2: Apply Database Schema

Copy the entire contents of the file `supabase/migrations/20240001_initial_schema.sql` and paste it into the SQL Editor, then click "Run".

Alternatively, you can run this command to output the schema:

```bash
cat supabase/migrations/20240001_initial_schema.sql
```

## Step 3: Verify Tables Were Created

After running the schema, execute this query in the SQL Editor to verify:

```sql
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_type = 'BASE TABLE'
ORDER BY table_name;
```

You should see these tables:
- algorithms
- audit_logs
- calculation_cache
- coverage_areas
- geographic_regions
- publishers
- user_profiles
- user_subscriptions

## Step 4: Apply Seed Data

After the schema is created, you can apply the seed data from `supabase/seed.sql` (which we'll create next).

## Next Steps

Once the schema is applied:
1. ✅ Test Supabase connection (COMPLETED)
2. 🔄 Apply database schema (IN PROGRESS - manual step needed)
3. ⏳ Set up seed data
4. ⏳ Create Go backend structure
5. ⏳ Build enhanced Next.js frontend
6. ✅ Fly.io deployment configured (https://zmanim-lab.fly.dev/)

## Supabase Dashboard Quick Links

- Project URL: https://bwyrcnimgpiwrngxvser.supabase.co
- Dashboard: https://supabase.com/dashboard/project/bwyrcnimgpiwrngxvser
- SQL Editor: https://supabase.com/dashboard/project/bwyrcnimgpiwrngxvser/sql/new
- Table Editor: https://supabase.com/dashboard/project/bwyrcnimgpiwrngxvser/editor
