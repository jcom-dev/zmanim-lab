# Credentials Setup Guide

This guide explains how to securely provide credentials and API keys for the Zmanim Lab project without exposing sensitive information.

## 🔐 Security Best Practices

**IMPORTANT:** Never commit credentials to version control. We'll use environment files that are gitignored.

---

## Supabase Credentials

### What I Need:

1. **Project URL** - Your Supabase project URL (safe to share)
2. **Anon Key** - Public anonymous key (safe to share)
3. **Service Role Key** - Backend service key (keep secret)
4. **Database Password** - PostgreSQL password (keep secret)

### How to Get Them:

1. Go to your Supabase project dashboard
2. Click on **Settings** → **API**
3. You'll see:
   - **Project URL**: `https://xxxxx.supabase.co`
   - **anon/public key**: `eyJhbG...` (starts with eyJ)
   - **service_role key**: `eyJhbG...` (different, also starts with eyJ)

4. For database password:
   - Go to **Settings** → **Database**
   - Look for **Connection String** or **Database Password**

### How to Provide:

**Option 1: Create Local Environment File (Recommended)**

Create a file `.env.supabase` in the project root:

```bash
# .env.supabase
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
DATABASE_URL=postgresql://postgres:your-password@db.your-project.supabase.co:5432/postgres
```

**Option 2: Share via Secure Method**

If you want me to help configure:
1. Copy your credentials to a text file
2. Share via a secure method:
   - Use a password-protected file
   - Use a temporary secure link (like https://privatebin.net)
   - Share in a private message (not in public chat)

---

## Fly.io Credentials

### What I Need:

1. **Fly API Token** - For deployment access
2. **App Name** - Your Fly.io app name (if created)

### How to Get Them:

**Get API Token:**

```bash
# Login to Fly.io
fly auth login

# Generate a token
fly tokens create deploy

# OR get existing token
fly auth token
```

**Get App Name:**

```bash
# If you haven't created an app yet:
fly apps create zmanim-lab-api

# List your apps:
fly apps list
```

### How to Provide:

Create `.env.fly` in project root:

```bash
# .env.fly
FLY_API_TOKEN=fo1_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
FLY_APP_NAME=zmanim-lab-api
```

---

## Upstash Redis (Optional - for caching)

### What I Need:

1. **Redis REST URL** - Your Upstash Redis URL
2. **Redis Token** - Authentication token

### How to Get Them:

1. Go to https://console.upstash.com
2. Create a new Redis database (free tier)
3. Copy the credentials shown:
   - **UPSTASH_REDIS_REST_URL**: `https://xxxxx.upstash.io`
   - **UPSTASH_REDIS_REST_TOKEN**: `AXXXXxxxxx...`

### How to Provide:

Create `.env.redis` in project root:

```bash
# .env.redis
REDIS_URL=https://your-redis.upstash.io
REDIS_TOKEN=AXXXXxxxxxxxxxxxxxxxxx
```

---

## Complete Setup File Structure

After setting up, your project should have:

```
zmanim-lab/
├── .env.supabase    # Supabase credentials (gitignored)
├── .env.fly         # Fly.io credentials (gitignored)
├── .env.redis       # Redis credentials (gitignored)
├── .gitignore       # Includes .env* files
└── ...
```

---

## .gitignore Update

Make sure your `.gitignore` includes:

```gitignore
# Environment files
.env
.env.*
.env.local
.env.production
.env.development
.env.supabase
.env.fly
.env.redis

# Don't ignore example files
!.env.example
!.env.*.example
```

---

## What Happens Next?

Once you provide the credentials:

1. **I'll configure the backend** with proper environment variables
2. **Set up database migrations** and apply the schema to your Supabase
3. **Configure Fly.io deployment** with your app name and token
4. **Set up Redis caching** if you provide Upstash credentials
5. **Create deployment scripts** that use these credentials securely

---

## Quick Setup Commands

Once credentials are in place, I can help you run:

```bash
# 1. Apply Supabase schema
supabase db push

# 2. Deploy backend to Fly.io
fly deploy

# 3. Deploy frontend to Vercel
vercel --prod

# 4. Test the deployment
curl https://your-fly-app.fly.dev/health
```

---

## Alternative: Manual Configuration

If you prefer to keep credentials completely private, I can:

1. **Provide all the code and configuration files**
2. **Give you step-by-step instructions** to run locally
3. **You manually set the environment variables** on your machine
4. **You manually deploy** using your own credentials

This is the most secure approach if you're not comfortable sharing any credentials.

---

## Security Checklist

- [ ] Never commit `.env` files to Git
- [ ] Use different keys for development and production
- [ ] Rotate API keys periodically
- [ ] Use Supabase RLS policies to restrict database access
- [ ] Set up rate limiting on API endpoints
- [ ] Enable 2FA on Supabase and Fly.io accounts
- [ ] Use secrets management for CI/CD (GitHub Secrets)

---

## Need Help?

Let me know which approach you prefer:

**Option A:** Share credentials securely (I'll configure everything)
**Option B:** Keep credentials private (I'll provide instructions, you configure)
**Option C:** Hybrid (I'll configure non-sensitive parts, you handle secrets)

I'm ready to proceed with whichever method you're comfortable with! 🚀
