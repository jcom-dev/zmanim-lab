package services

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"os"

	"github.com/clerk/clerk-sdk-go/v2"
	clerkInvitation "github.com/clerk/clerk-sdk-go/v2/invitation"
	clerkUser "github.com/clerk/clerk-sdk-go/v2/user"
)

type ClerkService struct {
	initialized bool
}

func NewClerkService() (*ClerkService, error) {
	secretKey := os.Getenv("CLERK_SECRET_KEY")
	if secretKey == "" {
		return nil, fmt.Errorf("CLERK_SECRET_KEY environment variable is not set")
	}

	// Set the Clerk secret key globally
	clerk.SetKey(secretKey)

	return &ClerkService{
		initialized: true,
	}, nil
}

// CreatePublisherUser creates a new Clerk user with publisher role and sends invitation
func (s *ClerkService) CreatePublisherUser(ctx context.Context, email, name, organization string) (string, error) {
	// Create user with publisher role in public metadata
	publicMetadata := map[string]interface{}{
		"role":         "publisher",
		"organization": organization,
	}

	// Convert metadata to JSON
	metadataJSON, err := json.Marshal(publicMetadata)
	if err != nil {
		return "", fmt.Errorf("failed to marshal metadata: %w", err)
	}

	// Create the user
	params := &clerkUser.CreateParams{
		EmailAddresses:          &[]string{email},
		FirstName:               clerk.String(name),
		PublicMetadata:          clerk.JSONRawMessage(metadataJSON),
		SkipPasswordRequirement: clerk.Bool(true),
		SkipPasswordChecks:      clerk.Bool(true),
	}

	user, err := clerkUser.Create(ctx, params)
	if err != nil {
		return "", fmt.Errorf("failed to create Clerk user: %w", err)
	}

	slog.Info("clerk user created", "user_id", user.ID, "email", email, "role", "publisher")

	return user.ID, nil
}

// SendInvitation sends an invitation email to a user
func (s *ClerkService) SendInvitation(ctx context.Context, email string) error {
	// Create public metadata for the invitation
	publicMetadata := map[string]interface{}{
		"role": "publisher",
	}

	metadataJSON, err := json.Marshal(publicMetadata)
	if err != nil {
		return fmt.Errorf("failed to marshal metadata: %w", err)
	}

	webURL := os.Getenv("WEB_URL")
	if webURL == "" {
		webURL = "http://localhost:3001"
	}

	// Create an invitation
	params := &clerkInvitation.CreateParams{
		EmailAddress:   email,
		PublicMetadata: clerk.JSONRawMessage(metadataJSON),
		RedirectURL:    clerk.String(webURL + "/sign-up"),
	}

	invitation, err := clerkInvitation.Create(ctx, params)
	if err != nil {
		return fmt.Errorf("failed to create invitation: %w", err)
	}

	slog.Info("clerk invitation sent", "email", email, "invitation_id", invitation.ID)
	return nil
}

// UpdateUserMetadata updates a user's public metadata
func (s *ClerkService) UpdateUserMetadata(ctx context.Context, clerkUserID string, metadata map[string]interface{}) error {
	metadataJSON, err := json.Marshal(metadata)
	if err != nil {
		return fmt.Errorf("failed to marshal metadata: %w", err)
	}

	params := &clerkUser.UpdateMetadataParams{
		PublicMetadata: clerk.JSONRawMessage(metadataJSON),
	}

	_, err = clerkUser.UpdateMetadata(ctx, clerkUserID, params)
	if err != nil {
		return fmt.Errorf("failed to update user metadata: %w", err)
	}

	return nil
}

// DeleteUser deletes a Clerk user
func (s *ClerkService) DeleteUser(ctx context.Context, clerkUserID string) error {
	_, err := clerkUser.Delete(ctx, clerkUserID)
	if err != nil {
		return fmt.Errorf("failed to delete Clerk user: %w", err)
	}

	slog.Info("clerk user deleted", "user_id", clerkUserID)
	return nil
}
