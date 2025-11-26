-- Migration: Publisher Requests and Invitations
-- Epic 2: Publisher User Management & Dashboard
-- Stories: 2-9 (Registration), 2-10 (Invitations), 2-11 (Email), 2-12 (Profile)

-- Publisher Registration Requests
CREATE TABLE IF NOT EXISTS publisher_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    organization TEXT NOT NULL,
    email TEXT NOT NULL,
    website TEXT,
    description TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending', -- pending, approved, rejected
    rejection_reason TEXT,
    reviewed_by TEXT, -- admin clerk_user_id
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_publisher_requests_status ON publisher_requests(status);
CREATE UNIQUE INDEX IF NOT EXISTS idx_publisher_requests_email_pending
    ON publisher_requests(email) WHERE status = 'pending';

-- Publisher Team Invitations
CREATE TABLE IF NOT EXISTS publisher_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publisher_id UUID REFERENCES publishers(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    token TEXT UNIQUE NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending', -- pending, accepted, expired, cancelled
    invited_by TEXT NOT NULL, -- clerk_user_id of inviter
    expires_at TIMESTAMPTZ NOT NULL, -- 7 days from creation
    accepted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_publisher_invitations_token ON publisher_invitations(token);
CREATE INDEX IF NOT EXISTS idx_publisher_invitations_publisher ON publisher_invitations(publisher_id);
CREATE INDEX IF NOT EXISTS idx_publisher_invitations_email ON publisher_invitations(email, publisher_id);

-- Password Reset Tokens
CREATE TABLE IF NOT EXISTS password_reset_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL UNIQUE,
    token TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_token ON password_reset_tokens(token);
CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_email ON password_reset_tokens(email);
