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

// GetUser retrieves a Clerk user by ID
func (s *ClerkService) GetUser(ctx context.Context, clerkUserID string) (*clerk.User, error) {
	user, err := clerkUser.Get(ctx, clerkUserID)
	if err != nil {
		return nil, fmt.Errorf("failed to get Clerk user: %w", err)
	}
	return user, nil
}

// GetUserPublicMetadata retrieves and parses a user's public metadata
func (s *ClerkService) GetUserPublicMetadata(ctx context.Context, clerkUserID string) (map[string]interface{}, error) {
	user, err := s.GetUser(ctx, clerkUserID)
	if err != nil {
		return nil, err
	}

	metadata := make(map[string]interface{})
	if user.PublicMetadata != nil {
		if err := json.Unmarshal(user.PublicMetadata, &metadata); err != nil {
			slog.Warn("failed to unmarshal user public metadata", "user_id", clerkUserID, "error", err)
			// Return empty map rather than error - metadata might be empty/invalid
			return make(map[string]interface{}), nil
		}
	}
	return metadata, nil
}

// AddPublisherToUser adds a publisher ID to a user's publisher_access_list
// If the user doesn't have publisher role, it sets it
func (s *ClerkService) AddPublisherToUser(ctx context.Context, clerkUserID, publisherID string) error {
	// Get current metadata
	metadata, err := s.GetUserPublicMetadata(ctx, clerkUserID)
	if err != nil {
		return fmt.Errorf("failed to get user metadata: %w", err)
	}

	// Get or create publisher_access_list
	var accessList []string
	if existing, ok := metadata["publisher_access_list"].([]interface{}); ok {
		for _, v := range existing {
			if s, ok := v.(string); ok {
				accessList = append(accessList, s)
			}
		}
	}

	// Check if publisher is already in list
	for _, id := range accessList {
		if id == publisherID {
			slog.Debug("publisher already in user access list", "user_id", clerkUserID, "publisher_id", publisherID)
			return nil // Already has access
		}
	}

	// Add new publisher to list
	accessList = append(accessList, publisherID)
	metadata["publisher_access_list"] = accessList
	metadata["role"] = "publisher"

	// Set primary_publisher_id if this is the first publisher
	if _, hasPrimary := metadata["primary_publisher_id"]; !hasPrimary {
		metadata["primary_publisher_id"] = publisherID
	}

	// Update user metadata
	if err := s.UpdateUserMetadata(ctx, clerkUserID, metadata); err != nil {
		return fmt.Errorf("failed to update user metadata: %w", err)
	}

	slog.Info("publisher added to user access list",
		"user_id", clerkUserID,
		"publisher_id", publisherID,
		"total_publishers", len(accessList))

	return nil
}

// RemovePublisherFromUser removes a publisher ID from a user's publisher_access_list
// If no publishers remain, the role is reverted to "user"
func (s *ClerkService) RemovePublisherFromUser(ctx context.Context, clerkUserID, publisherID string) error {
	// Get current metadata
	metadata, err := s.GetUserPublicMetadata(ctx, clerkUserID)
	if err != nil {
		return fmt.Errorf("failed to get user metadata: %w", err)
	}

	// Get current publisher_access_list
	var accessList []string
	if existing, ok := metadata["publisher_access_list"].([]interface{}); ok {
		for _, v := range existing {
			if s, ok := v.(string); ok {
				accessList = append(accessList, s)
			}
		}
	}

	// Find and remove the publisher
	var newAccessList []string
	found := false
	for _, id := range accessList {
		if id == publisherID {
			found = true
		} else {
			newAccessList = append(newAccessList, id)
		}
	}

	if !found {
		slog.Debug("publisher not in user access list", "user_id", clerkUserID, "publisher_id", publisherID)
		return nil // Publisher wasn't in list
	}

	// Update metadata
	if len(newAccessList) == 0 {
		// No publishers left - revert to regular user
		metadata["role"] = "user"
		delete(metadata, "publisher_access_list")
		delete(metadata, "primary_publisher_id")
	} else {
		metadata["publisher_access_list"] = newAccessList

		// If we removed the primary publisher, set a new one
		if primary, ok := metadata["primary_publisher_id"].(string); ok && primary == publisherID {
			metadata["primary_publisher_id"] = newAccessList[0]
		}
	}

	// Update user metadata
	if err := s.UpdateUserMetadata(ctx, clerkUserID, metadata); err != nil {
		return fmt.Errorf("failed to update user metadata: %w", err)
	}

	slog.Info("publisher removed from user access list",
		"user_id", clerkUserID,
		"publisher_id", publisherID,
		"remaining_publishers", len(newAccessList))

	return nil
}

// SendPublisherInvitation sends an invitation email with publisher context
// When the user accepts, they will have the publisher in their access list
func (s *ClerkService) SendPublisherInvitation(ctx context.Context, email, publisherID string) error {
	// Create public metadata for the invitation
	publicMetadata := map[string]interface{}{
		"role":                  "publisher",
		"publisher_access_list": []string{publisherID},
		"primary_publisher_id":  publisherID,
	}

	metadataJSON, err := json.Marshal(publicMetadata)
	if err != nil {
		return fmt.Errorf("failed to marshal metadata: %w", err)
	}

	webURL := os.Getenv("WEB_URL")
	if webURL == "" {
		webURL = "http://localhost:3001"
	}

	// Create an invitation with publisher context
	params := &clerkInvitation.CreateParams{
		EmailAddress:   email,
		PublicMetadata: clerk.JSONRawMessage(metadataJSON),
		RedirectURL:    clerk.String(fmt.Sprintf("%s/publisher/dashboard", webURL)),
	}

	invitation, err := clerkInvitation.Create(ctx, params)
	if err != nil {
		return fmt.Errorf("failed to create invitation: %w", err)
	}

	slog.Info("publisher invitation sent",
		"email", email,
		"publisher_id", publisherID,
		"invitation_id", invitation.ID)

	return nil
}

// CreatePublisherUserDirectly creates a Clerk user directly with publisher metadata
// This bypasses the invitation flow and works with Restricted mode
// The user will receive a password reset email to set up their account
func (s *ClerkService) CreatePublisherUserDirectly(ctx context.Context, email, name, publisherID string) (*clerk.User, error) {
	// Create public metadata for the user
	publicMetadata := map[string]interface{}{
		"role":                  "publisher",
		"publisher_access_list": []string{publisherID},
		"primary_publisher_id":  publisherID,
	}

	metadataJSON, err := json.Marshal(publicMetadata)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal metadata: %w", err)
	}

	// Create the user directly
	params := &clerkUser.CreateParams{
		EmailAddresses:          &[]string{email},
		FirstName:               clerk.String(name),
		PublicMetadata:          clerk.JSONRawMessage(metadataJSON),
		SkipPasswordRequirement: clerk.Bool(true),
	}

	user, err := clerkUser.Create(ctx, params)
	if err != nil {
		return nil, fmt.Errorf("failed to create user: %w", err)
	}

	slog.Info("publisher user created directly",
		"email", email,
		"user_id", user.ID,
		"publisher_id", publisherID)

	return user, nil
}

// GetUserByEmail finds a Clerk user by email address
// Returns nil if user not found (not an error)
func (s *ClerkService) GetUserByEmail(ctx context.Context, email string) (*clerk.User, error) {
	params := &clerkUser.ListParams{
		EmailAddresses: []string{email},
	}

	users, err := clerkUser.List(ctx, params)
	if err != nil {
		return nil, fmt.Errorf("failed to search for user: %w", err)
	}

	if users == nil || len(users.Users) == 0 {
		return nil, nil // User not found
	}

	return users.Users[0], nil
}

// PublisherUserInfo represents a user linked to a publisher
type PublisherUserInfo struct {
	ClerkUserID string  `json:"clerk_user_id"`
	Email       string  `json:"email"`
	Name        string  `json:"name"`
	ImageURL    string  `json:"image_url,omitempty"`
	CreatedAt   int64   `json:"created_at"`
}

// GetUsersWithPublisherAccess returns all users who have access to a specific publisher
// Note: This requires iterating through users since Clerk doesn't support metadata queries directly
func (s *ClerkService) GetUsersWithPublisherAccess(ctx context.Context, publisherID string) ([]PublisherUserInfo, error) {
	var result []PublisherUserInfo

	// List all users
	// Note: In production with many users, consider caching or using a database to track user-publisher relationships
	params := &clerkUser.ListParams{}

	users, err := clerkUser.List(ctx, params)
	if err != nil {
		return nil, fmt.Errorf("failed to list users: %w", err)
	}

	if users == nil {
		return result, nil
	}

	for _, user := range users.Users {
		if user.PublicMetadata == nil {
			continue
		}

		var metadata map[string]interface{}
		if err := json.Unmarshal(user.PublicMetadata, &metadata); err != nil {
			continue
		}

		// Check if user has this publisher in their access list
		accessList, ok := metadata["publisher_access_list"].([]interface{})
		if !ok {
			continue
		}

		hasAccess := false
		for _, id := range accessList {
			if idStr, ok := id.(string); ok && idStr == publisherID {
				hasAccess = true
				break
			}
		}

		if hasAccess {
			// Get primary email
			email := ""
			if len(user.EmailAddresses) > 0 {
				email = user.EmailAddresses[0].EmailAddress
			}

			// Get name
			name := ""
			if user.FirstName != nil {
				name = *user.FirstName
			}
			if user.LastName != nil {
				if name != "" {
					name += " "
				}
				name += *user.LastName
			}

			// Get image URL safely
			imageURL := ""
			if user.ImageURL != nil {
				imageURL = *user.ImageURL
			}

			result = append(result, PublisherUserInfo{
				ClerkUserID: user.ID,
				Email:       email,
				Name:        name,
				ImageURL:    imageURL,
				CreatedAt:   user.CreatedAt,
			})
		}
	}

	return result, nil
}
