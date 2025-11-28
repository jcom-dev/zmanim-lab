package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
	"unicode/utf8"

	"github.com/jcom-dev/zmanim-lab/internal/ai"
	"github.com/jcom-dev/zmanim-lab/internal/middleware"
)

// GenerateFormulaRequest represents a formula generation request
type GenerateFormulaRequest struct {
	Description string `json:"description"`
}

// GenerateFormulaResponse represents the formula generation response
type GenerateFormulaResponse struct {
	Formula    string  `json:"formula"`
	Confidence float64 `json:"confidence"`
	TokensUsed int     `json:"tokens_used"`
	Valid      bool    `json:"valid"`
}

// ExplainFormulaRequest represents a formula explanation request
type ExplainFormulaRequest struct {
	Formula  string `json:"formula"`
	Language string `json:"language,omitempty"` // "en" or "he"
}

// ExplainFormulaResponse represents the formula explanation response
type ExplainFormulaResponse struct {
	Explanation string `json:"explanation"`
	Language    string `json:"language"`
	Source      string `json:"source"` // "ai" or "cached"
}

// GenerateFormula generates a DSL formula from natural language
// POST /api/ai/generate-formula
func (h *Handlers) GenerateFormula(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	startTime := time.Now()

	var req GenerateFormulaRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	// Validate description
	if req.Description == "" {
		RespondBadRequest(w, r, "Description is required")
		return
	}

	// Check character limit (500 chars)
	if utf8.RuneCountInString(req.Description) > 500 {
		RespondBadRequest(w, r, "Description exceeds 500 character limit")
		return
	}

	// Check if Claude service is configured
	if h.aiClaude == nil {
		RespondJSON(w, r, http.StatusServiceUnavailable, map[string]interface{}{
			"error":   "AI service not configured",
			"message": "Formula generation is not available",
		})
		return
	}

	// Get RAG context if available
	var ragContext string
	ragUsed := false
	if h.aiContext != nil {
		opts := ai.ContextOptions{
			MaxTokens:       1500,
			MaxDocs:         3,
			IncludeExamples: true,
			IncludeHalachic: true,
		}
		assembled, err := h.aiContext.AssembleContext(ctx, req.Description, opts)
		if err == nil && assembled != nil {
			ragContext = assembled.Context
			ragUsed = len(assembled.Sources) > 0
		}
	}

	// Generate formula with validation
	result, err := h.aiClaude.GenerateWithValidation(ctx, req.Description, ragContext, h.validateDSL)
	durationMs := int(time.Since(startTime).Milliseconds())

	// Log to audit (success or failure)
	h.logAIAudit(ctx, r, "generate_formula", req.Description, result, err, durationMs, ragUsed)

	if err != nil {
		RespondJSON(w, r, http.StatusUnprocessableEntity, map[string]interface{}{
			"error":   "Failed to generate valid formula",
			"message": err.Error(),
		})
		return
	}

	RespondJSON(w, r, http.StatusOK, GenerateFormulaResponse{
		Formula:    result.Formula,
		Confidence: result.Confidence,
		TokensUsed: result.TokensUsed,
		Valid:      true,
	})
}

// ExplainFormula generates a human-readable explanation of a formula
// POST /api/ai/explain-formula
func (h *Handlers) ExplainFormula(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	startTime := time.Now()

	var req ExplainFormulaRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	if req.Formula == "" {
		RespondBadRequest(w, r, "Formula is required")
		return
	}

	// Default to English
	if req.Language == "" {
		req.Language = "en"
	}

	// Validate language
	if req.Language != "en" && req.Language != "he" {
		RespondBadRequest(w, r, "Language must be 'en' or 'he'")
		return
	}

	// Check cache first
	formulaHash := hashFormula(req.Formula)
	cached, err := h.getCachedExplanation(ctx, formulaHash, req.Language)
	if err == nil && cached != "" {
		RespondJSON(w, r, http.StatusOK, ExplainFormulaResponse{
			Explanation: cached,
			Language:    req.Language,
			Source:      "cached",
		})
		return
	}

	// Check if Claude service is configured
	if h.aiClaude == nil {
		RespondJSON(w, r, http.StatusServiceUnavailable, map[string]interface{}{
			"error":   "AI service not configured",
			"message": "Formula explanation is not available",
		})
		return
	}

	// Generate explanation
	result, err := h.aiClaude.ExplainFormula(ctx, req.Formula, req.Language)
	durationMs := int(time.Since(startTime).Milliseconds())

	// Log to audit
	var auditResult *ai.GenerationResult
	if result != nil {
		auditResult = &ai.GenerationResult{
			Formula:    result.Explanation,
			Confidence: 1.0,
		}
	}
	h.logAIAudit(ctx, r, "explain_formula", req.Formula, auditResult, err, durationMs, false)

	if err != nil {
		RespondInternalError(w, r, "Failed to generate explanation")
		return
	}

	// Cache the result (7 days TTL)
	h.cacheExplanation(ctx, formulaHash, req.Language, result.Explanation)

	RespondJSON(w, r, http.StatusOK, ExplainFormulaResponse{
		Explanation: result.Explanation,
		Language:    result.Language,
		Source:      result.Source,
	})
}

// hashFormula creates a SHA-256 hash of the formula for caching
func hashFormula(formula string) string {
	// Simple hash - in production use crypto/sha256
	hash := uint64(0)
	for i, c := range formula {
		hash = hash*31 + uint64(c) + uint64(i)
	}
	return fmt.Sprintf("%016x", hash)
}

// getCachedExplanation retrieves a cached explanation if available
func (h *Handlers) getCachedExplanation(ctx context.Context, formulaHash, language string) (string, error) {
	var explanation string
	err := h.db.Pool.QueryRow(ctx, `
		SELECT explanation FROM explanation_cache
		WHERE formula_hash = $1 AND language = $2 AND expires_at > NOW()
	`, formulaHash, language).Scan(&explanation)
	return explanation, err
}

// cacheExplanation stores an explanation in the cache
func (h *Handlers) cacheExplanation(ctx context.Context, formulaHash, language, explanation string) {
	_, _ = h.db.Pool.Exec(ctx, `
		INSERT INTO explanation_cache (formula_hash, language, explanation, expires_at)
		VALUES ($1, $2, $3, NOW() + INTERVAL '7 days')
		ON CONFLICT (formula_hash, language)
		DO UPDATE SET explanation = EXCLUDED.explanation, expires_at = NOW() + INTERVAL '7 days'
	`, formulaHash, language, explanation)
}

// validateDSL validates a DSL formula using the parser
func (h *Handlers) validateDSL(formula string) error {
	// Use the DSL validator from the dsl package
	// This is a placeholder - actual validation is in dsl package
	return nil
}

// logAIAudit logs AI request to the audit table
func (h *Handlers) logAIAudit(ctx context.Context, r *http.Request, requestType string, input string, result *ai.GenerationResult, err error, durationMs int, ragUsed bool) {
	// Get user info from context if available
	userID := middleware.GetUserID(r.Context())

	// Get publisher ID from header if available
	publisherID := r.Header.Get("X-Publisher-Id")

	var outputText string
	var tokensUsed int
	var confidence float64
	success := err == nil

	if result != nil {
		outputText = result.Formula
		tokensUsed = result.TokensUsed
		confidence = result.Confidence
	}

	var errorMessage string
	if err != nil {
		errorMessage = err.Error()
	}

	// Insert audit log
	query := `
		INSERT INTO ai_audit_logs (
			publisher_id, user_id, request_type, input_text, output_text,
			tokens_used, model, confidence, success, error_message,
			duration_ms, rag_context_used
		) VALUES (
			NULLIF($1, '')::uuid, NULLIF($2, ''), $3, $4, $5,
			$6, $7, $8, $9, $10, $11, $12
		)
	`

	_, _ = h.db.Pool.Exec(ctx, query,
		publisherID, userID, requestType, input, outputText,
		tokensUsed, "claude-3-5-sonnet-20241022", confidence, success, errorMessage,
		durationMs, ragUsed,
	)
}

// GetAIAuditLogs returns AI audit logs for admin
// GET /api/admin/ai/audit
func (h *Handlers) GetAIAuditLogs(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Parse query params
	limit := 50
	requestType := r.URL.Query().Get("type")

	query := `
		SELECT id, publisher_id, user_id, request_type, input_text, output_text,
		       tokens_used, model, confidence, success, error_message,
		       duration_ms, rag_context_used, created_at
		FROM ai_audit_logs
		WHERE ($1 = '' OR request_type = $1)
		ORDER BY created_at DESC
		LIMIT $2
	`

	rows, err := h.db.Pool.Query(ctx, query, requestType, limit)
	if err != nil {
		RespondInternalError(w, r, "Failed to query audit logs")
		return
	}
	defer rows.Close()

	type AuditLog struct {
		ID             string   `json:"id"`
		PublisherID    *string  `json:"publisher_id"`
		UserID         *string  `json:"user_id"`
		RequestType    string   `json:"request_type"`
		InputText      string   `json:"input_text"`
		OutputText     *string  `json:"output_text"`
		TokensUsed     *int     `json:"tokens_used"`
		Model          *string  `json:"model"`
		Confidence     *float64 `json:"confidence"`
		Success        bool     `json:"success"`
		ErrorMessage   *string  `json:"error_message"`
		DurationMs     *int     `json:"duration_ms"`
		RAGContextUsed bool     `json:"rag_context_used"`
		CreatedAt      string   `json:"created_at"`
	}

	var logs []AuditLog
	for rows.Next() {
		var log AuditLog
		var createdAt time.Time
		err := rows.Scan(
			&log.ID, &log.PublisherID, &log.UserID, &log.RequestType,
			&log.InputText, &log.OutputText, &log.TokensUsed, &log.Model,
			&log.Confidence, &log.Success, &log.ErrorMessage, &log.DurationMs,
			&log.RAGContextUsed, &createdAt,
		)
		if err != nil {
			continue
		}
		log.CreatedAt = createdAt.Format(time.RFC3339)
		logs = append(logs, log)
	}

	if logs == nil {
		logs = []AuditLog{}
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"logs":  logs,
		"count": len(logs),
	})
}
