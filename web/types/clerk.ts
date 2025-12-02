/**
 * Clerk Public Metadata Types
 *
 * Shared type definitions for Clerk user metadata used across the application.
 * Use these instead of inline type assertions.
 *
 * @example
 * const metadata = user.publicMetadata as ClerkPublicMetadata;
 * if (metadata.role === 'admin') { ... }
 */

/**
 * User roles in the system
 */
export type UserRole = 'admin' | 'publisher' | 'user';

/**
 * Public metadata structure stored in Clerk user profiles
 */
export interface ClerkPublicMetadata {
  /** User's role in the system */
  role?: UserRole;
  /** List of publisher IDs this user has access to */
  publisher_access_list?: string[];
  /** Primary publisher ID for users with multiple publishers */
  primary_publisher_id?: string;
}

/**
 * Type guard to check if user has admin role
 */
export function isAdmin(metadata: ClerkPublicMetadata): boolean {
  return metadata.role === 'admin';
}

/**
 * Type guard to check if user has publisher role
 */
export function isPublisher(metadata: ClerkPublicMetadata): boolean {
  return metadata.role === 'publisher';
}

/**
 * Type guard to check if user has publisher access
 */
export function hasPublisherAccess(metadata: ClerkPublicMetadata): boolean {
  return (metadata.publisher_access_list?.length || 0) > 0;
}
