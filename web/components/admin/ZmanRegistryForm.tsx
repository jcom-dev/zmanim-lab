'use client';

import { useState, useEffect, useCallback, useMemo } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Switch } from '@/components/ui/switch';
import { Badge } from '@/components/ui/badge';
import { ColorBadge, getTagTypeColor, type ColorBadgeColor } from '@/components/ui/color-badge';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { useAdminApi } from '@/lib/api-client';
import {
  Loader2,
  AlertTriangle,
  CheckCircle2,
  XCircle,
  User,
  Calendar,
  Info,
} from 'lucide-react';

// Types
export interface ZmanTag {
  id: string;
  tag_key: string;
  name: string;
  display_name_hebrew: string;
  display_name_english: string;
  tag_type: 'event' | 'timing' | 'behavior';
  color?: string;
}

export interface PendingTagRequest {
  id: string;
  zman_request_id: string;
  tag_id?: string;
  requested_tag_name?: string;
  requested_tag_type?: string;
  is_new_tag_request: boolean;
}

export interface ZmanFormData {
  zman_key: string;
  canonical_hebrew_name: string;
  canonical_english_name: string;
  transliteration: string;
  description: string;
  halachic_notes: string;
  halachic_source: string;
  time_category: string;
  default_formula_dsl: string;
  is_core: boolean;
  is_hidden: boolean;
  tag_ids: string[];
}

export interface ReviewSourceInfo {
  publisher_name: string;
  publisher_id: string;
  submitted_at: string;
  request_id: string;
}

interface ZmanRegistryFormProps {
  mode: 'create' | 'edit' | 'review';
  initialData?: Partial<ZmanFormData>;
  sourceInfo?: ReviewSourceInfo;
  pendingTagRequests?: PendingTagRequest[];
  disabled?: boolean;
  onSave?: (data: ZmanFormData) => Promise<void>;
  onApprove?: (data: ZmanFormData, reviewerNotes: string) => Promise<void>;
  onReject?: (reviewerNotes: string) => Promise<void>;
  onCancel?: () => void;
  onTagApprove?: (tagRequest: PendingTagRequest) => Promise<ZmanTag | null>;
  onTagReject?: (tagRequest: PendingTagRequest) => Promise<void>;
}

const TIME_CATEGORIES = [
  { key: 'dawn', display_name: 'Dawn' },
  { key: 'sunrise', display_name: 'Sunrise' },
  { key: 'morning', display_name: 'Morning' },
  { key: 'midday', display_name: 'Midday' },
  { key: 'afternoon', display_name: 'Afternoon' },
  { key: 'sunset', display_name: 'Sunset' },
  { key: 'nightfall', display_name: 'Nightfall' },
  { key: 'midnight', display_name: 'Midnight' },
];

// Tag colors are now handled by ColorBadge component

const DEFAULT_FORM_DATA: ZmanFormData = {
  zman_key: '',
  canonical_hebrew_name: '',
  canonical_english_name: '',
  transliteration: '',
  description: '',
  halachic_notes: '',
  halachic_source: '',
  time_category: 'sunrise',
  default_formula_dsl: '',
  is_core: false,
  is_hidden: false,
  tag_ids: [],
};

/**
 * ZmanRegistryForm - Reusable form for creating, editing, and reviewing zmanim
 *
 * Modes:
 * - create: New zman entry with Save button
 * - edit: Edit existing zman with Save button
 * - review: Review request with Approve/Reject buttons and source info banner
 */
export function ZmanRegistryForm({
  mode,
  initialData,
  sourceInfo,
  pendingTagRequests = [],
  disabled = false,
  onSave,
  onApprove,
  onReject,
  onCancel,
  onTagApprove,
  onTagReject,
}: ZmanRegistryFormProps) {
  const api = useAdminApi();
  const [formData, setFormData] = useState<ZmanFormData>({
    ...DEFAULT_FORM_DATA,
    ...initialData,
  });
  const [originalData, setOriginalData] = useState<ZmanFormData | null>(null);
  const [allTags, setAllTags] = useState<ZmanTag[]>([]);
  const [reviewerNotes, setReviewerNotes] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [processingTagId, setProcessingTagId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  // Key validation state (for create mode)
  const [keyValidation, setKeyValidation] = useState<{
    available: boolean | null;
    reason: string | null;
    isValidating: boolean;
  }>({ available: null, reason: null, isValidating: false });

  // Track pending tag requests that haven't been resolved yet
  const [resolvedTagIds, setResolvedTagIds] = useState<Set<string>>(new Set());

  // Initialize form data and track original for change detection
  useEffect(() => {
    const data = { ...DEFAULT_FORM_DATA, ...initialData };
    setFormData(data);
    if (mode === 'review') {
      setOriginalData(data);
    }
  }, [initialData, mode]);

  // Fetch all available tags
  const fetchTags = useCallback(async () => {
    try {
      const data = await api.get<ZmanTag[]>('/admin/registry/tags');
      setAllTags(data || []);
    } catch (err) {
      console.error('Failed to fetch tags:', err);
    }
  }, [api]);

  useEffect(() => {
    fetchTags();
  }, [fetchTags]);

  // Validate zman key format
  const isValidKeyFormat = (key: string): boolean => {
    return /^[a-z][a-z0-9_]*$/.test(key);
  };

  // Debounced key validation (for create mode only)
  const validateKey = useCallback(async (key: string) => {
    const trimmedKey = key.trim().toLowerCase();
    if (!trimmedKey) {
      setKeyValidation({ available: null, reason: null, isValidating: false });
      return;
    }

    if (trimmedKey.length < 2) {
      setKeyValidation({ available: false, reason: 'Key must be at least 2 characters', isValidating: false });
      return;
    }

    if (!isValidKeyFormat(trimmedKey)) {
      setKeyValidation({
        available: false,
        reason: 'Key must start with a letter and contain only lowercase letters, numbers, and underscores',
        isValidating: false,
      });
      return;
    }

    setKeyValidation({ available: null, reason: null, isValidating: true });
    try {
      const result = await api.get<{ available: boolean; reason?: string }>(
        `/registry/zmanim/validate-key?key=${encodeURIComponent(trimmedKey)}`
      );
      setKeyValidation({
        available: result.available,
        reason: result.available ? null : (result.reason || 'Key is not available'),
        isValidating: false,
      });
    } catch {
      setKeyValidation({ available: null, reason: 'Could not validate key', isValidating: false });
    }
  }, [api]);

  // Debounce key validation on zman_key change (create mode only)
  useEffect(() => {
    if (mode !== 'create') return;

    const timer = setTimeout(() => {
      if (formData.zman_key.trim()) {
        validateKey(formData.zman_key);
      } else {
        setKeyValidation({ available: null, reason: null, isValidating: false });
      }
    }, 300);

    return () => clearTimeout(timer);
  }, [formData.zman_key, mode, validateKey]);

  // Check if form data has been modified from original (for review mode)
  const hasChanges = useMemo(() => {
    if (mode !== 'review' || !originalData) return false;
    return JSON.stringify(formData) !== JSON.stringify(originalData);
  }, [mode, formData, originalData]);

  // Count unresolved pending tag requests
  const unresolvedTagRequests = useMemo(() => {
    return pendingTagRequests.filter(
      (req) => req.is_new_tag_request && !resolvedTagIds.has(req.id)
    );
  }, [pendingTagRequests, resolvedTagIds]);

  const canApprove = mode === 'review' && unresolvedTagRequests.length === 0;

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
    });
  };

  const handleTagApprove = async (tagRequest: PendingTagRequest) => {
    if (!onTagApprove) return;
    setProcessingTagId(tagRequest.id);
    try {
      const newTag = await onTagApprove(tagRequest);
      if (newTag) {
        // Add the new tag to selected tags
        setFormData((prev) => ({
          ...prev,
          tag_ids: [...prev.tag_ids, newTag.id],
        }));
        // Add to all tags list
        setAllTags((prev) => [...prev, newTag]);
      }
      // Mark as resolved
      setResolvedTagIds((prev) => new Set([...prev, tagRequest.id]));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to approve tag');
    } finally {
      setProcessingTagId(null);
    }
  };

  const handleTagReject = async (tagRequest: PendingTagRequest) => {
    if (!onTagReject) return;
    setProcessingTagId(tagRequest.id);
    try {
      await onTagReject(tagRequest);
      // Mark as resolved
      setResolvedTagIds((prev) => new Set([...prev, tagRequest.id]));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to reject tag');
    } finally {
      setProcessingTagId(null);
    }
  };

  const handleSubmit = async () => {
    setError(null);

    // Basic validation
    const errors: string[] = [];

    if (!formData.zman_key.trim()) {
      errors.push('Zman Key is required');
    }
    if (!formData.canonical_hebrew_name.trim()) {
      errors.push('Hebrew Name is required');
    }
    if (!formData.canonical_english_name.trim()) {
      errors.push('English Name is required');
    }
    if (!formData.default_formula_dsl.trim()) {
      errors.push('Default Formula (DSL) is required');
    }

    // Key validation check (create mode only)
    if (mode === 'create') {
      if (keyValidation.isValidating) {
        errors.push('Please wait for key validation to complete');
      } else if (keyValidation.available === false) {
        errors.push(keyValidation.reason || 'Zman key is not available');
      }
    }

    if (errors.length > 0) {
      setError(errors.join('. '));
      return;
    }

    setIsSubmitting(true);
    try {
      // Validate DSL formula before proceeding
      const dslValidation = await api.post<{
        valid: boolean;
        errors?: Array<{ message: string; line?: number; column?: number }>;
      }>('/dsl/validate', {
        body: JSON.stringify({ formula: formData.default_formula_dsl }),
      });

      if (!dslValidation.valid) {
        const dslErrors = dslValidation.errors?.map(e => e.message).join('; ') || 'Invalid formula syntax';
        setError(`Formula validation failed: ${dslErrors}`);
        setIsSubmitting(false);
        return;
      }

      if (mode === 'review' && onApprove) {
        await onApprove(formData, reviewerNotes);
      } else if (onSave) {
        await onSave(formData);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to save');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleReject = async () => {
    if (!onReject) return;
    setError(null);

    // Require reviewer notes for rejection
    if (!reviewerNotes.trim()) {
      setError('Please provide a reason for rejecting this request');
      return;
    }

    setIsSubmitting(true);
    try {
      await onReject(reviewerNotes);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to reject');
    } finally {
      setIsSubmitting(false);
    }
  };

  const removeTag = (tagId: string) => {
    setFormData({
      ...formData,
      tag_ids: formData.tag_ids.filter((id) => id !== tagId),
    });
  };

  const addTag = (tagId: string) => {
    if (!formData.tag_ids.includes(tagId)) {
      setFormData({
        ...formData,
        tag_ids: [...formData.tag_ids, tagId],
      });
    }
  };

  return (
    <div className="space-y-6">
      {/* Source Info Banner (Review Mode) */}
      {mode === 'review' && sourceInfo && (
        <div className="p-4 bg-blue-50 dark:bg-blue-950/50 border border-blue-200 dark:border-blue-800 rounded-lg">
          <div className="flex items-start gap-3">
            <Info className="h-5 w-5 text-blue-600 dark:text-blue-400 mt-0.5" />
            <div className="flex-1">
              <h3 className="font-medium text-blue-900 dark:text-blue-100">
                Reviewing Zman Request
              </h3>
              <div className="mt-2 flex flex-wrap gap-4 text-sm text-blue-700 dark:text-blue-300">
                <span className="flex items-center gap-1">
                  <User className="h-3.5 w-3.5" />
                  {sourceInfo.publisher_name}
                </span>
                <span className="flex items-center gap-1">
                  <Calendar className="h-3.5 w-3.5" />
                  {formatDate(sourceInfo.submitted_at)}
                </span>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Pending Tag Requests (Review Mode) */}
      {mode === 'review' && unresolvedTagRequests.length > 0 && (
        <div className="p-4 bg-amber-50 dark:bg-amber-950/50 border border-amber-200 dark:border-amber-800 rounded-lg">
          <div className="flex items-start gap-3">
            <AlertTriangle className="h-5 w-5 text-amber-600 dark:text-amber-400 mt-0.5" />
            <div className="flex-1">
              <h3 className="font-medium text-amber-900 dark:text-amber-100">
                Pending Tag Requests ({unresolvedTagRequests.length})
              </h3>
              <p className="text-sm text-amber-700 dark:text-amber-300 mt-1">
                Resolve all tag requests before approving this zman
              </p>
              <div className="mt-3 space-y-2">
                {unresolvedTagRequests.map((tagReq) => (
                  <div
                    key={tagReq.id}
                    className="flex items-center justify-between p-2 bg-white dark:bg-gray-900 rounded border"
                  >
                    <div>
                      <span className="font-medium">{tagReq.requested_tag_name}</span>
                      {tagReq.requested_tag_type && (
                        <Badge variant="outline" className="ml-2 text-xs">
                          {tagReq.requested_tag_type}
                        </Badge>
                      )}
                    </div>
                    <div className="flex gap-2">
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => handleTagReject(tagReq)}
                        disabled={processingTagId === tagReq.id || disabled}
                        className="text-destructive hover:text-destructive"
                      >
                        {processingTagId === tagReq.id ? (
                          <Loader2 className="h-3 w-3 animate-spin" />
                        ) : (
                          <XCircle className="h-3 w-3 mr-1" />
                        )}
                        Reject
                      </Button>
                      <Button
                        size="sm"
                        onClick={() => handleTagApprove(tagReq)}
                        disabled={processingTagId === tagReq.id || disabled}
                        className="bg-green-600 hover:bg-green-700"
                      >
                        {processingTagId === tagReq.id ? (
                          <Loader2 className="h-3 w-3 animate-spin" />
                        ) : (
                          <CheckCircle2 className="h-3 w-3 mr-1" />
                        )}
                        Approve
                      </Button>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Changes Warning (Review Mode) */}
      {mode === 'review' && hasChanges && (
        <div className="flex items-center gap-2 p-3 bg-amber-50 dark:bg-amber-950/50 border border-amber-200 dark:border-amber-800 rounded-lg text-amber-700 dark:text-amber-300">
          <AlertTriangle className="h-4 w-4 flex-shrink-0" />
          <span className="text-sm">
            You modified the request. These changes will be saved when you approve.
          </span>
        </div>
      )}

      {/* Form Fields */}
      <div className="grid gap-4">
        {/* Zman Key and Time Category */}
        <div className="grid grid-cols-2 gap-4">
          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <Label htmlFor="zman_key">Zman Key *</Label>
              {/* Key Validation Status (create mode only) */}
              {mode === 'create' && formData.zman_key.trim() && (
                <div className="flex items-center gap-1.5">
                  {keyValidation.isValidating ? (
                    <>
                      <Loader2 className="h-3.5 w-3.5 animate-spin text-muted-foreground" />
                      <span className="text-xs text-muted-foreground">Checking...</span>
                    </>
                  ) : keyValidation.available === true ? (
                    <>
                      <CheckCircle2 className="h-3.5 w-3.5 text-green-600" />
                      <span className="text-xs text-green-600">Available</span>
                    </>
                  ) : keyValidation.available === false ? (
                    <>
                      <AlertTriangle className="h-3.5 w-3.5 text-destructive" />
                      <span className="text-xs text-destructive">Unavailable</span>
                    </>
                  ) : null}
                </div>
              )}
            </div>
            <Input
              id="zman_key"
              value={formData.zman_key}
              onChange={(e) => setFormData({ ...formData, zman_key: e.target.value.toLowerCase().replace(/[^a-z0-9_]/g, '_') })}
              placeholder="e.g., candle_lighting_18"
              disabled={mode === 'edit' || disabled}
              className={`font-mono ${
                mode === 'create' && formData.zman_key.trim() && keyValidation.available === false
                  ? 'border-destructive focus-visible:ring-destructive'
                  : mode === 'create' && formData.zman_key.trim() && keyValidation.available === true
                  ? 'border-green-500 focus-visible:ring-green-500'
                  : ''
              }`}
            />
            {/* Key Error Message */}
            {mode === 'create' && keyValidation.reason ? (
              <p className="text-xs text-destructive flex items-start gap-1">
                <AlertTriangle className="h-3 w-3 mt-0.5 flex-shrink-0" />
                {keyValidation.reason}
              </p>
            ) : formData.zman_key ? (
              <p className="text-xs text-muted-foreground">
                DSL Reference:{' '}
                <code className="px-1 bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-200 rounded">
                  @{formData.zman_key}
                </code>
              </p>
            ) : null}
          </div>
          <div className="space-y-2">
            <Label htmlFor="time_category">Time Category *</Label>
            <Select
              value={formData.time_category}
              onValueChange={(v) => setFormData({ ...formData, time_category: v })}
              disabled={disabled}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {TIME_CATEGORIES.map((cat) => (
                  <SelectItem key={cat.key} value={cat.key}>
                    {cat.display_name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </div>

        {/* Tags Section */}
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <Label>Tags</Label>
            <Select
              value=""
              onValueChange={(tagId) => addTag(tagId)}
              disabled={disabled}
            >
              <SelectTrigger className="w-[140px] h-8">
                <SelectValue placeholder="+ Add Tag" />
              </SelectTrigger>
              <SelectContent>
                {/* Event Tags */}
                {allTags.filter((t) => t.tag_type === 'event').length > 0 && (
                  <>
                    <div className="px-2 py-1.5 text-xs font-semibold text-muted-foreground">
                      Event
                    </div>
                    {allTags
                      .filter((t) => t.tag_type === 'event')
                      .map((tag) => {
                        const isSelected = formData.tag_ids.includes(tag.id);
                        return (
                          <SelectItem key={tag.id} value={tag.id} disabled={isSelected}>
                            <div className="flex items-center gap-2">
                              {tag.display_name_english}
                              {isSelected && (
                                <span className="text-xs text-muted-foreground">✓</span>
                              )}
                            </div>
                          </SelectItem>
                        );
                      })}
                  </>
                )}
                {/* Timing Tags */}
                {allTags.filter((t) => t.tag_type === 'timing').length > 0 && (
                  <>
                    <div className="px-2 py-1.5 text-xs font-semibold text-muted-foreground">
                      Timing
                    </div>
                    {allTags
                      .filter((t) => t.tag_type === 'timing')
                      .map((tag) => {
                        const isSelected = formData.tag_ids.includes(tag.id);
                        return (
                          <SelectItem key={tag.id} value={tag.id} disabled={isSelected}>
                            <div className="flex items-center gap-2">
                              {tag.display_name_english}
                              {isSelected && (
                                <span className="text-xs text-muted-foreground">✓</span>
                              )}
                            </div>
                          </SelectItem>
                        );
                      })}
                  </>
                )}
                {/* Behavior Tags */}
                {allTags.filter((t) => t.tag_type === 'behavior').length > 0 && (
                  <>
                    <div className="px-2 py-1.5 text-xs font-semibold text-muted-foreground">
                      Behavior
                    </div>
                    {allTags
                      .filter((t) => t.tag_type === 'behavior')
                      .map((tag) => {
                        const isSelected = formData.tag_ids.includes(tag.id);
                        return (
                          <SelectItem key={tag.id} value={tag.id} disabled={isSelected}>
                            <div className="flex items-center gap-2">
                              {tag.display_name_english}
                              {isSelected && (
                                <span className="text-xs text-muted-foreground">✓</span>
                              )}
                            </div>
                          </SelectItem>
                        );
                      })}
                  </>
                )}
              </SelectContent>
            </Select>
          </div>
          <p className="text-xs text-muted-foreground">
            Select tags to categorize when/how this zman applies
          </p>
          <div className="flex flex-wrap gap-2 min-h-[36px] p-2 border rounded-md">
            {formData.tag_ids.length === 0 ? (
              <span className="text-sm text-muted-foreground">No tags selected</span>
            ) : (
              formData.tag_ids.map((tagId) => {
                const tag = allTags.find((t) => t.id === tagId);
                if (!tag) return null;

                return (
                  <button
                    key={tag.id}
                    type="button"
                    onClick={() => !disabled && removeTag(tag.id)}
                    className={`inline-flex items-center gap-1.5 transition-opacity ${disabled ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer hover:opacity-80'}`}
                    title={disabled ? tag.display_name_english : 'Click to remove'}
                    disabled={disabled}
                  >
                    <ColorBadge color={getTagTypeColor(tag.tag_type)} size="sm">
                      {tag.display_name_english}
                      {!disabled && <span className="text-xs opacity-70 ml-1">×</span>}
                    </ColorBadge>
                  </button>
                );
              })
            )}
          </div>
        </div>

        {/* Hebrew and English Names */}
        <div className="grid grid-cols-2 gap-4">
          <div className="space-y-2">
            <Label htmlFor="canonical_hebrew_name">Hebrew Name *</Label>
            <Input
              id="canonical_hebrew_name"
              value={formData.canonical_hebrew_name}
              onChange={(e) =>
                setFormData({ ...formData, canonical_hebrew_name: e.target.value })
              }
              placeholder="עלות השחר"
              dir="rtl"
              disabled={disabled}
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="canonical_english_name">English Name *</Label>
            <Input
              id="canonical_english_name"
              value={formData.canonical_english_name}
              onChange={(e) =>
                setFormData({ ...formData, canonical_english_name: e.target.value })
              }
              placeholder="Dawn"
              disabled={disabled}
            />
          </div>
        </div>

        {/* Transliteration */}
        <div className="space-y-2">
          <Label htmlFor="transliteration">Transliteration</Label>
          <Input
            id="transliteration"
            value={formData.transliteration}
            onChange={(e) => setFormData({ ...formData, transliteration: e.target.value })}
            placeholder="Alos HaShachar"
            disabled={disabled}
          />
        </div>

        {/* Default Formula */}
        <div className="space-y-2">
          <Label htmlFor="default_formula_dsl">Default Formula (DSL) *</Label>
          <Input
            id="default_formula_dsl"
            value={formData.default_formula_dsl}
            onChange={(e) =>
              setFormData({ ...formData, default_formula_dsl: e.target.value })
            }
            placeholder="sunrise - 72m"
            className="font-mono"
            disabled={disabled}
          />
        </div>

        {/* Description */}
        <div className="space-y-2">
          <Label htmlFor="description">Description</Label>
          <Textarea
            id="description"
            value={formData.description}
            onChange={(e) => setFormData({ ...formData, description: e.target.value })}
            placeholder="Brief description of this zman..."
            rows={2}
            disabled={disabled}
          />
        </div>

        {/* Halachic Notes */}
        <div className="space-y-2">
          <Label htmlFor="halachic_notes">Halachic Notes</Label>
          <Textarea
            id="halachic_notes"
            value={formData.halachic_notes}
            onChange={(e) => setFormData({ ...formData, halachic_notes: e.target.value })}
            placeholder="Relevant halachic information..."
            rows={2}
            disabled={disabled}
          />
        </div>

        {/* Halachic Source and Sort Order */}
        <div className="grid grid-cols-2 gap-4">
          <div className="space-y-2">
            <Label htmlFor="halachic_source">Halachic Source</Label>
            <Input
              id="halachic_source"
              value={formData.halachic_source}
              onChange={(e) =>
                setFormData({ ...formData, halachic_source: e.target.value })
              }
              placeholder="e.g., Shulchan Aruch 89:1"
              disabled={disabled}
            />
          </div>
        </div>

        {/* Core and Hidden Toggles */}
        <div className="flex items-center gap-6">
          <div className="flex items-center gap-2">
            <Switch
              id="is_core"
              checked={formData.is_core}
              onCheckedChange={(v) => setFormData({ ...formData, is_core: v })}
              disabled={disabled}
            />
            <Label htmlFor="is_core">Core Zman</Label>
          </div>
          <div className="flex items-center gap-2">
            <Switch
              id="is_hidden"
              checked={formData.is_hidden}
              onCheckedChange={(v) => setFormData({ ...formData, is_hidden: v })}
              disabled={disabled}
            />
            <Label htmlFor="is_hidden">Hidden</Label>
          </div>
        </div>

        {/* Reviewer Notes (Review Mode) */}
        {mode === 'review' && (
          <div className="space-y-2">
            <Label htmlFor="reviewer_notes">Reviewer Notes</Label>
            <Textarea
              id="reviewer_notes"
              value={reviewerNotes}
              onChange={(e) => setReviewerNotes(e.target.value)}
              placeholder="Add notes about your decision (required for rejection)..."
              rows={3}
              disabled={disabled}
            />
          </div>
        )}
      </div>

      {/* Error Alert (shown near buttons for visibility) */}
      {error && (
        <div className="flex items-center gap-2 p-3 bg-destructive/10 border border-destructive/30 rounded-lg text-destructive">
          <AlertTriangle className="h-4 w-4 flex-shrink-0" />
          <span className="text-sm">{error}</span>
        </div>
      )}

      {/* Footer Buttons */}
      <div className="flex justify-end gap-2 pt-4 border-t">
        {onCancel && (
          <Button variant="outline" onClick={onCancel} disabled={isSubmitting}>
            Cancel
          </Button>
        )}

        {mode === 'review' ? (
          <>
            <Button
              variant="destructive"
              onClick={handleReject}
              disabled={isSubmitting || disabled}
            >
              {isSubmitting ? (
                <Loader2 className="h-4 w-4 mr-2 animate-spin" />
              ) : (
                <XCircle className="h-4 w-4 mr-2" />
              )}
              Reject
            </Button>
            <Button
              onClick={handleSubmit}
              disabled={isSubmitting || disabled || !canApprove}
              className="bg-green-600 hover:bg-green-700"
              title={
                !canApprove
                  ? `Resolve ${unresolvedTagRequests.length} pending tag request(s) before approving`
                  : undefined
              }
            >
              {isSubmitting ? (
                <Loader2 className="h-4 w-4 mr-2 animate-spin" />
              ) : (
                <CheckCircle2 className="h-4 w-4 mr-2" />
              )}
              Approve
            </Button>
          </>
        ) : (
          <Button
            onClick={handleSubmit}
            disabled={
              isSubmitting ||
              disabled ||
              (mode === 'create' && (keyValidation.isValidating || keyValidation.available === false))
            }
          >
            {isSubmitting ? (
              <Loader2 className="h-4 w-4 mr-2 animate-spin" />
            ) : keyValidation.isValidating ? (
              <>
                <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                Checking key...
              </>
            ) : null}
            {!isSubmitting && !keyValidation.isValidating && (mode === 'create' ? 'Create' : 'Update')}
          </Button>
        )}
      </div>
    </div>
  );
}

export default ZmanRegistryForm;
