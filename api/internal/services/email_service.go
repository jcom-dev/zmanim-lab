package services

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"text/template"
)

// EmailService handles sending transactional emails via Resend
type EmailService struct {
	apiKey  string
	from    string
	domain  string
	webURL  string
	client  *http.Client
	enabled bool
}

// EmailTemplate represents the available email templates
type EmailTemplate string

const (
	TemplatePublisherInvitation EmailTemplate = "publisher-invitation"
	TemplatePublisherApproved   EmailTemplate = "publisher-approved"
	TemplatePublisherRejected   EmailTemplate = "publisher-rejected"
	TemplatePasswordReset       EmailTemplate = "password-reset"
	TemplateWelcome             EmailTemplate = "welcome"
)

// SendEmailRequest represents the Resend API request
type SendEmailRequest struct {
	From    string     `json:"from"`
	To      []string   `json:"to"`
	Subject string     `json:"subject"`
	HTML    string     `json:"html,omitempty"`
	Text    string     `json:"text,omitempty"`
	Tags    []EmailTag `json:"tags,omitempty"`
}

// EmailTag represents a tag for email categorization
type EmailTag struct {
	Name  string `json:"name"`
	Value string `json:"value"`
}

// NewEmailService creates a new EmailService instance
func NewEmailService() *EmailService {
	apiKey := os.Getenv("RESEND_API_KEY")
	from := os.Getenv("RESEND_FROM")
	domain := os.Getenv("RESEND_DOMAIN")
	webURL := os.Getenv("WEB_URL")

	if webURL == "" {
		webURL = "http://localhost:3001"
	}

	enabled := apiKey != "" && from != ""

	if enabled {
		slog.Info("email service initialized", "from", from, "domain", domain)
	} else {
		slog.Warn("email service not configured - emails will be logged but not sent",
			"has_api_key", apiKey != "",
			"has_from", from != "")
	}

	return &EmailService{
		apiKey:  apiKey,
		from:    from,
		domain:  domain,
		webURL:  webURL,
		client:  &http.Client{},
		enabled: enabled,
	}
}

// IsEnabled returns whether the email service is configured
func (s *EmailService) IsEnabled() bool {
	return s.enabled
}

// SendInvitation sends a publisher team invitation email
func (s *EmailService) SendInvitation(to, inviterName, publisherName, acceptURL string) error {
	subject := fmt.Sprintf("You've been invited to join %s on Zmanim Lab", publisherName)

	data := map[string]string{
		"inviter_name":   inviterName,
		"publisher_name": publisherName,
		"accept_url":     acceptURL,
	}

	html := s.renderTemplate(TemplatePublisherInvitation, data)
	return s.send(to, subject, html, []EmailTag{{Name: "template", Value: string(TemplatePublisherInvitation)}})
}

// SendPublisherApproved sends a welcome email to a newly approved publisher
func (s *EmailService) SendPublisherApproved(to, publisherName, dashboardURL string) error {
	subject := "Welcome to Zmanim Lab - Your Publisher Account is Ready!"

	data := map[string]string{
		"publisher_name": publisherName,
		"dashboard_url":  dashboardURL,
	}

	html := s.renderTemplate(TemplatePublisherApproved, data)
	return s.send(to, subject, html, []EmailTag{{Name: "template", Value: string(TemplatePublisherApproved)}})
}

// SendPublisherRejected sends a rejection notice to a publisher applicant
func (s *EmailService) SendPublisherRejected(to, publisherName, reason string) error {
	subject := "Zmanim Lab Publisher Application Update"

	data := map[string]string{
		"publisher_name": publisherName,
		"reason":         reason,
	}

	html := s.renderTemplate(TemplatePublisherRejected, data)
	return s.send(to, subject, html, []EmailTag{{Name: "template", Value: string(TemplatePublisherRejected)}})
}

// SendPasswordReset sends a password reset email
func (s *EmailService) SendPasswordReset(to, resetURL, expiresIn string) error {
	subject := "Reset Your Zmanim Lab Password"

	data := map[string]string{
		"reset_url":  resetURL,
		"expires_in": expiresIn,
	}

	html := s.renderTemplate(TemplatePasswordReset, data)
	return s.send(to, subject, html, []EmailTag{{Name: "template", Value: string(TemplatePasswordReset)}})
}

// SendWelcome sends a welcome email to a new user
func (s *EmailService) SendWelcome(to, userName string) error {
	subject := "Welcome to Zmanim Lab!"

	data := map[string]string{
		"user_name": userName,
		"web_url":   s.webURL,
	}

	html := s.renderTemplate(TemplateWelcome, data)
	return s.send(to, subject, html, []EmailTag{{Name: "template", Value: string(TemplateWelcome)}})
}

// send executes the email send via Resend API
func (s *EmailService) send(to, subject, html string, tags []EmailTag) error {
	// Always log the email for debugging
	slog.Info("email send requested",
		"to", to,
		"subject", subject,
		"enabled", s.enabled)

	if !s.enabled {
		slog.Warn("email service not configured, skipping actual send",
			"to", to,
			"subject", subject)
		return nil
	}

	req := SendEmailRequest{
		From:    s.from,
		To:      []string{to},
		Subject: subject,
		HTML:    html,
		Tags:    tags,
	}

	body, err := json.Marshal(req)
	if err != nil {
		return fmt.Errorf("failed to marshal email request: %w", err)
	}

	httpReq, err := http.NewRequest("POST", "https://api.resend.com/emails", bytes.NewBuffer(body))
	if err != nil {
		return fmt.Errorf("failed to create HTTP request: %w", err)
	}

	httpReq.Header.Set("Authorization", "Bearer "+s.apiKey)
	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := s.client.Do(httpReq)
	if err != nil {
		slog.Error("failed to send email via Resend", "error", err, "to", to)
		// Non-blocking - log error but don't fail the operation
		return nil
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		slog.Error("Resend API error", "status", resp.StatusCode, "to", to, "subject", subject)
		// Non-blocking - log error but don't fail the operation
		return nil
	}

	slog.Info("email sent successfully via Resend", "to", to, "subject", subject)
	return nil
}

// renderTemplate renders an email template with the provided data
func (s *EmailService) renderTemplate(templateType EmailTemplate, data map[string]string) string {
	templates := map[EmailTemplate]string{
		TemplatePublisherInvitation: `
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Join {{.publisher_name}} on Zmanim Lab</title>
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
    <div style="background: linear-gradient(135deg, #1e3a5f 0%, #2c5282 100%); padding: 30px; border-radius: 10px 10px 0 0;">
        <h1 style="color: white; margin: 0; font-size: 24px;">Zmanim Lab</h1>
    </div>
    <div style="background: #ffffff; padding: 30px; border: 1px solid #e2e8f0; border-top: none; border-radius: 0 0 10px 10px;">
        <h2 style="color: #1e3a5f; margin-top: 0;">You're Invited!</h2>
        <p>{{.inviter_name}} has invited you to join <strong>{{.publisher_name}}</strong> on Zmanim Lab.</p>
        <p>As a team member, you'll be able to help manage the publisher's algorithms and coverage areas.</p>
        <div style="text-align: center; margin: 30px 0;">
            <a href="{{.accept_url}}" style="background: #1e3a5f; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; display: inline-block; font-weight: 600;">Accept Invitation</a>
        </div>
        <p style="color: #718096; font-size: 14px;">This invitation will expire in 7 days.</p>
        <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 20px 0;">
        <p style="color: #718096; font-size: 12px;">If you didn't expect this invitation, you can safely ignore this email.</p>
    </div>
</body>
</html>`,

		TemplatePublisherApproved: `
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome to Zmanim Lab</title>
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
    <div style="background: linear-gradient(135deg, #1e3a5f 0%, #2c5282 100%); padding: 30px; border-radius: 10px 10px 0 0;">
        <h1 style="color: white; margin: 0; font-size: 24px;">Zmanim Lab</h1>
    </div>
    <div style="background: #ffffff; padding: 30px; border: 1px solid #e2e8f0; border-top: none; border-radius: 0 0 10px 10px;">
        <h2 style="color: #1e3a5f; margin-top: 0;">Welcome, {{.publisher_name}}!</h2>
        <p>Great news! Your publisher application has been <strong style="color: #38a169;">approved</strong>.</p>
        <p>You can now:</p>
        <ul style="color: #4a5568;">
            <li>Set up your calculation algorithms</li>
            <li>Define your coverage areas</li>
            <li>Invite team members to help manage your account</li>
            <li>Publish your zmanim for your community</li>
        </ul>
        <div style="text-align: center; margin: 30px 0;">
            <a href="{{.dashboard_url}}" style="background: #1e3a5f; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; display: inline-block; font-weight: 600;">Go to Dashboard</a>
        </div>
        <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 20px 0;">
        <p style="color: #718096; font-size: 12px;">Thank you for joining Zmanim Lab!</p>
    </div>
</body>
</html>`,

		TemplatePublisherRejected: `
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Zmanim Lab Application Update</title>
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
    <div style="background: linear-gradient(135deg, #1e3a5f 0%, #2c5282 100%); padding: 30px; border-radius: 10px 10px 0 0;">
        <h1 style="color: white; margin: 0; font-size: 24px;">Zmanim Lab</h1>
    </div>
    <div style="background: #ffffff; padding: 30px; border: 1px solid #e2e8f0; border-top: none; border-radius: 0 0 10px 10px;">
        <h2 style="color: #1e3a5f; margin-top: 0;">Application Update</h2>
        <p>Dear {{.publisher_name}},</p>
        <p>Thank you for your interest in becoming a publisher on Zmanim Lab.</p>
        <p>After reviewing your application, we regret to inform you that we are unable to approve it at this time.</p>
        {{if .reason}}
        <div style="background: #f7fafc; border-left: 4px solid #718096; padding: 15px; margin: 20px 0;">
            <p style="margin: 0; color: #4a5568;"><strong>Reason:</strong> {{.reason}}</p>
        </div>
        {{end}}
        <p>If you believe this decision was made in error or would like to provide additional information, please feel free to reach out to us.</p>
        <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 20px 0;">
        <p style="color: #718096; font-size: 12px;">Thank you for your understanding.</p>
    </div>
</body>
</html>`,

		TemplatePasswordReset: `
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reset Your Password</title>
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
    <div style="background: linear-gradient(135deg, #1e3a5f 0%, #2c5282 100%); padding: 30px; border-radius: 10px 10px 0 0;">
        <h1 style="color: white; margin: 0; font-size: 24px;">Zmanim Lab</h1>
    </div>
    <div style="background: #ffffff; padding: 30px; border: 1px solid #e2e8f0; border-top: none; border-radius: 0 0 10px 10px;">
        <h2 style="color: #1e3a5f; margin-top: 0;">Reset Your Password</h2>
        <p>We received a request to reset your password. Click the button below to create a new password.</p>
        <div style="text-align: center; margin: 30px 0;">
            <a href="{{.reset_url}}" style="background: #1e3a5f; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; display: inline-block; font-weight: 600;">Reset Password</a>
        </div>
        <p style="color: #e53e3e; font-size: 14px;">This link will expire in {{.expires_in}}.</p>
        <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 20px 0;">
        <p style="color: #718096; font-size: 12px;">If you didn't request a password reset, you can safely ignore this email. Your password will not be changed.</p>
    </div>
</body>
</html>`,

		TemplateWelcome: `
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome to Zmanim Lab</title>
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
    <div style="background: linear-gradient(135deg, #1e3a5f 0%, #2c5282 100%); padding: 30px; border-radius: 10px 10px 0 0;">
        <h1 style="color: white; margin: 0; font-size: 24px;">Zmanim Lab</h1>
    </div>
    <div style="background: #ffffff; padding: 30px; border: 1px solid #e2e8f0; border-top: none; border-radius: 0 0 10px 10px;">
        <h2 style="color: #1e3a5f; margin-top: 0;">Welcome, {{.user_name}}!</h2>
        <p>Thank you for joining Zmanim Lab! We're excited to have you.</p>
        <p>With Zmanim Lab, you can:</p>
        <ul style="color: #4a5568;">
            <li>Get accurate zmanim calculations for any location</li>
            <li>Choose from trusted publishers in your area</li>
            <li>See the formulas behind each calculation</li>
        </ul>
        <div style="text-align: center; margin: 30px 0;">
            <a href="{{.web_url}}" style="background: #1e3a5f; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; display: inline-block; font-weight: 600;">Get Started</a>
        </div>
        <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 20px 0;">
        <p style="color: #718096; font-size: 12px;">Thank you for being part of our community!</p>
    </div>
</body>
</html>`,
	}

	templateStr, ok := templates[templateType]
	if !ok {
		slog.Warn("unknown email template", "template", templateType)
		return fmt.Sprintf("<html><body><p>Template: %s</p></body></html>", templateType)
	}

	tmpl, err := template.New("email").Parse(templateStr)
	if err != nil {
		slog.Error("failed to parse email template", "error", err, "template", templateType)
		return templateStr
	}

	var buf bytes.Buffer
	if err := tmpl.Execute(&buf, data); err != nil {
		slog.Error("failed to execute email template", "error", err, "template", templateType)
		return templateStr
	}

	return buf.String()
}
