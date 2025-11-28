#!/usr/bin/env node
/**
 * Get a Test Token for API Testing
 *
 * This script uses the Clerk Backend SDK to:
 * 1. List existing users with publisher role
 * 2. Get or create a session token for testing
 *
 * Usage:
 *   node scripts/get-test-token.js
 *
 * Requires:
 *   CLERK_SECRET_KEY environment variable
 */

const https = require('https');

const CLERK_SECRET_KEY = process.env.CLERK_SECRET_KEY;

if (!CLERK_SECRET_KEY) {
  console.error('Error: CLERK_SECRET_KEY environment variable is required');
  console.error('Run: source api/.env && node scripts/get-test-token.js');
  process.exit(1);
}

// Colors for console output
const colors = {
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  reset: '\x1b[0m'
};

const log = {
  info: (msg) => console.log(`${colors.blue}${msg}${colors.reset}`),
  success: (msg) => console.log(`${colors.green}${msg}${colors.reset}`),
  warn: (msg) => console.log(`${colors.yellow}${msg}${colors.reset}`),
  error: (msg) => console.log(`${colors.red}${msg}${colors.reset}`),
  plain: (msg) => console.log(msg)
};

/**
 * Make a request to the Clerk API
 */
function clerkApi(method, path, data = null) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'api.clerk.com',
      port: 443,
      path: `/v1${path}`,
      method: method,
      headers: {
        'Authorization': `Bearer ${CLERK_SECRET_KEY}`,
        'Content-Type': 'application/json',
      }
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(body);
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(parsed);
          } else {
            reject({ status: res.statusCode, body: parsed });
          }
        } catch {
          reject({ status: res.statusCode, body });
        }
      });
    });

    req.on('error', reject);

    if (data) {
      req.write(JSON.stringify(data));
    }

    req.end();
  });
}

async function listUsers() {
  log.info('Fetching users from Clerk...\n');

  const response = await clerkApi('GET', '/users?limit=100');

  return response.map(user => ({
    id: user.id,
    email: user.email_addresses?.[0]?.email_address || 'no-email',
    role: user.public_metadata?.role || null,
    publisherAccess: user.public_metadata?.publisher_access_list || [],
  }));
}

async function listSessions(userId) {
  log.info(`\nFetching sessions for user ${userId}...`);

  const response = await clerkApi('GET', `/sessions?user_id=${userId}`);
  return response;
}

async function getSessionToken(sessionId) {
  log.info(`Getting token for session ${sessionId}...`);

  // Clerk's default template
  const response = await clerkApi('POST', `/sessions/${sessionId}/tokens`);
  return response.jwt;
}

async function createSignInToken(userId) {
  log.info(`\nCreating sign-in token for user ${userId}...`);

  const response = await clerkApi('POST', '/sign_in_tokens', {
    user_id: userId,
    expires_in_seconds: 3600,
  });

  return response.token;
}

async function main() {
  log.info('========================================');
  log.info('Zmanim Lab - Get Test Token');
  log.info('========================================');
  log.plain('');

  try {
    // List all users
    const users = await listUsers();

    log.plain('Available users:');
    log.plain('================');

    for (const user of users) {
      const roleStr = user.role ? `[${user.role}]` : '[no role]';
      const accessStr = user.publisherAccess.length > 0
        ? `publishers: ${user.publisherAccess.join(', ')}`
        : '';
      log.plain(`  ${user.email} ${roleStr} ${accessStr}`);
    }
    log.plain('');

    // Find a user with publisher or admin role
    const targetUser = users.find(u => u.role === 'publisher' || u.role === 'admin');

    if (!targetUser) {
      log.warn('No user with publisher or admin role found.');
      log.plain('\nTo create a test user with publisher role:');
      log.plain('1. Sign up on the web app at http://localhost:3001');
      log.plain('2. Go to Clerk Dashboard and add publicMetadata: { "role": "publisher" }');
      process.exit(0);
    }

    log.success(`Found user with ${targetUser.role} role: ${targetUser.email}`);

    // Try to get existing sessions
    const sessions = await listSessions(targetUser.id);

    const activeSession = sessions.find(s => s.status === 'active');

    if (activeSession) {
      log.success(`Found active session: ${activeSession.id}`);

      const token = await getSessionToken(activeSession.id);

      log.plain('');
      log.info('========================================');
      log.success('JWT TOKEN (use this for API testing):');
      log.info('========================================');
      log.plain(token);
      log.info('========================================');
      log.plain('');
      log.plain('Test command:');
      log.success(`node scripts/test-auth.js "${token.substring(0, 50)}..." "http://localhost:8080"`);
      log.plain('');
      log.plain('Full command (copy this):');
      log.plain(`node scripts/test-auth.js "${token}" "http://localhost:8080"`);
    } else {
      log.warn('No active session found. Creating a sign-in token...');

      const signInToken = await createSignInToken(targetUser.id);

      log.plain('');
      log.info('========================================');
      log.plain('Sign-in Token Created');
      log.info('========================================');
      log.plain('');
      log.plain('To get a JWT token:');
      log.plain('1. Open browser to the web app');
      log.plain(`2. Go to: http://localhost:3001/sign-in#/sso-callback?__clerk_ticket=${signInToken}`);
      log.plain('3. You will be signed in automatically');
      log.plain('4. Open DevTools > Network tab');
      log.plain('5. Find any API request and copy the Authorization header (without "Bearer ")');
      log.plain('');
      log.plain('Or sign in manually at http://localhost:3001/sign-in');
    }

  } catch (error) {
    log.error(`Error: ${error?.message || JSON.stringify(error)}`);
    if (error?.body) {
      log.error(`Details: ${JSON.stringify(error.body, null, 2)}`);
    }
    process.exit(1);
  }
}

main();
