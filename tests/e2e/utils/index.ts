/**
 * Test Utilities Index
 *
 * Central export for all test utilities.
 * Import from '../utils' in test files.
 */

// Clerk Authentication
export {
  createTestAdmin,
  createTestPublisher,
  createTestUser,
  loginAsAdmin,
  loginAsPublisher,
  loginAsUser,
  cleanupTestUsers,
  clearUserCache,
  getTestPassword,
  getTestEmailDomain,
} from './clerk-auth';

// Database Fixtures
export {
  createTestPublisherEntity,
  createTestAlgorithm,
  createTestCoverage,
  getTestCity,
  createFullTestPublisher,
  cleanupTestData,
  clearEntityCache,
  getTestPrefix,
} from './test-fixtures';

// Email Testing (MailSlurp)
export {
  createTestInbox,
  createNamedInbox,
  waitForEmail,
  waitForEmailWithSubject,
  getEmails,
  getEmailContent,
  extractLinksFromEmail,
  extractLinkContaining,
  waitForInvitationEmail,
  waitForPasswordResetEmail,
  waitForApprovalEmail,
  deleteInbox,
  cleanupAllInboxes,
  clearInbox,
  isMailSlurpConfigured,
  getMailSlurpClient,
} from './email-testing';

// Cleanup Utilities
export {
  runFullCleanup,
  clearAllCaches,
  cleanupDatabaseOnly,
  cleanupClerkOnly,
} from './cleanup';

// Re-export existing helpers
export { BASE_URL, TIMEOUTS, sleep, pages, selectors, testData } from '../helpers/mcp-playwright';
