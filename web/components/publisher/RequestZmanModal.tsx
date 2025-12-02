'use client';

import { useState, useMemo } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Badge } from '@/components/ui/badge';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { usePublisherMutation, usePublisherQuery } from '@/lib/hooks';
import { Loader2, Plus, FileText, X, Tag } from 'lucide-react';
import { Checkbox } from '@/components/ui/checkbox';
import { ScrollArea } from '@/components/ui/scroll-area';

interface ZmanRequest {
  id: string;
  requested_key: string;
  requested_hebrew_name: string;
  requested_english_name: string;
  transliteration?: string;
  time_category: string;
  tags?: string[];
  status: string;
  reviewed_at?: string;
  reviewer_notes?: string;
  created_at: string;
}

interface ZmanRequestListResponse {
  requests: ZmanRequest[];
  total: number;
}

interface ZmanTag {
  id: string;
  tag_key: string;
  name: string;
  display_name_hebrew: string;
  display_name_english: string;
  tag_type: 'event' | 'timing' | 'behavior' | 'shita' | 'method';
  description?: string;
  color?: string;
}

interface TagsResponse {
  tags: ZmanTag[];
}

interface RequestZmanModalProps {
  trigger?: React.ReactNode;
  onSuccess?: () => void;
  onOpen?: () => void;
  /** Controlled mode: open state */
  open?: boolean;
  /** Controlled mode: callback when open state changes */
  onOpenChange?: (open: boolean) => void;
}

// Tag type labels for display
const TAG_TYPE_LABELS: Record<string, string> = {
  event: 'Event Type',
  timing: 'Time of Day',
  behavior: 'Behavior',
  shita: 'Shita (Halachic Opinion)',
  method: 'Calculation Method',
};

// Tag type order for display
const TAG_TYPE_ORDER = ['timing', 'event', 'shita', 'method', 'behavior'];

/**
 * RequestZmanModal - Modal for requesting a new zman to be added to the master registry
 *
 * Features:
 * - Form for submitting new zman request
 * - Validation for required fields
 * - Halachic source fields
 * - Tag selection with tags fetched from API, organized by type
 * - Request new tags with type selection
 * - Request history with status badges
 * - Uses useApi() hook for all API calls
 * - Supports both controlled (open/onOpenChange) and uncontrolled (trigger) modes
 *
 * Story 5.7: Request New Zman UI
 */
export function RequestZmanModal({ trigger, onSuccess, onOpen, open: controlledOpen, onOpenChange }: RequestZmanModalProps) {
  const [internalOpen, setInternalOpen] = useState(false);

  // Use controlled mode if open prop is provided, otherwise use internal state
  const isControlled = controlledOpen !== undefined;
  const open = isControlled ? controlledOpen : internalOpen;
  const setOpen = isControlled ? (onOpenChange ?? (() => {})) : setInternalOpen;

  const handleOpenChange = (newOpen: boolean) => {
    setOpen(newOpen);
    if (newOpen && onOpen) {
      onOpen();
    }
  };
  const [showHistory, setShowHistory] = useState(false);

  // Form state
  const [requestedKey, setRequestedKey] = useState('');
  const [hebrewName, setHebrewName] = useState('');
  const [englishName, setEnglishName] = useState('');
  const [transliteration, setTransliteration] = useState('');
  const [timeCategory, setTimeCategory] = useState('');
  const [description, setDescription] = useState('');
  const [formulaDsl, setFormulaDsl] = useState('');
  const [halachicNotes, setHalachicNotes] = useState('');
  const [halachicSource, setHalachicSource] = useState('');
  const [autoAddOnApproval, setAutoAddOnApproval] = useState(true);

  // Tags state
  const [selectedTagIds, setSelectedTagIds] = useState<string[]>([]);
  const [customTagInput, setCustomTagInput] = useState('');
  const [customTagType, setCustomTagType] = useState<string>('');
  const [requestedNewTags, setRequestedNewTags] = useState<{ name: string; type: string }[]>([]);

  // Fetch available tags from API
  const { data: tagsData, isLoading: tagsLoading } = usePublisherQuery<TagsResponse>(
    'zman-tags',
    '/registry/tags',
    {
      enabled: open,
    }
  );

  // Group tags by type
  const tagsByType = useMemo(() => {
    if (!tagsData?.tags) return {};

    const grouped: Record<string, ZmanTag[]> = {};
    for (const tag of tagsData.tags) {
      if (!grouped[tag.tag_type]) {
        grouped[tag.tag_type] = [];
      }
      grouped[tag.tag_type].push(tag);
    }
    return grouped;
  }, [tagsData?.tags]);

  // Fetch request history
  const { data: historyData, isLoading: historyLoading } = usePublisherQuery<ZmanRequestListResponse>(
    'zman-requests',
    '/publisher/zman-requests',
    {
      enabled: showHistory && open,
    }
  );

  // Mutation to submit request
  const submitRequest = usePublisherMutation<unknown, {
    requested_key: string;
    requested_hebrew_name: string;
    requested_english_name: string;
    transliteration?: string;
    time_category: string;
    tag_ids?: string[];
    requested_new_tags?: { name: string; type: string }[];
    description: string;
    requested_formula_dsl?: string;
    halachic_notes?: string;
    halachic_source?: string;
    auto_add_on_approval?: boolean;
  }>(
    '/publisher/zman-requests',
    'POST',
    {
      invalidateKeys: ['zman-requests'],
      onSuccess: () => {
        handleReset();
        setOpen(false);
        onSuccess?.();
      },
    }
  );

  const handleReset = () => {
    setRequestedKey('');
    setHebrewName('');
    setEnglishName('');
    setTransliteration('');
    setTimeCategory('');
    setDescription('');
    setFormulaDsl('');
    setHalachicNotes('');
    setHalachicSource('');
    setAutoAddOnApproval(true);
    setSelectedTagIds([]);
    setCustomTagInput('');
    setCustomTagType('');
    setRequestedNewTags([]);
  };

  const handleSubmit = async () => {
    if (!requestedKey.trim() || !hebrewName.trim() || !englishName.trim() ||
        !timeCategory || !description.trim()) {
      return;
    }

    await submitRequest.mutateAsync({
      requested_key: requestedKey.trim(),
      requested_hebrew_name: hebrewName.trim(),
      requested_english_name: englishName.trim(),
      transliteration: transliteration.trim() || undefined,
      time_category: timeCategory,
      tag_ids: selectedTagIds.length > 0 ? selectedTagIds : undefined,
      requested_new_tags: requestedNewTags.length > 0 ? requestedNewTags : undefined,
      description: description.trim(),
      requested_formula_dsl: formulaDsl.trim() || undefined,
      halachic_notes: halachicNotes.trim() || undefined,
      halachic_source: halachicSource.trim() || undefined,
      auto_add_on_approval: autoAddOnApproval,
    });
  };

  const toggleTag = (tagId: string) => {
    setSelectedTagIds(prev =>
      prev.includes(tagId)
        ? prev.filter(id => id !== tagId)
        : [...prev, tagId]
    );
  };

  const addCustomTag = () => {
    const tagName = customTagInput.trim().toLowerCase().replace(/\s+/g, '_');
    if (tagName && customTagType && !requestedNewTags.some(t => t.name === tagName)) {
      setRequestedNewTags(prev => [...prev, { name: tagName, type: customTagType }]);
      setCustomTagInput('');
      setCustomTagType('');
    }
  };

  const removeRequestedTag = (tagName: string) => {
    setRequestedNewTags(prev => prev.filter(t => t.name !== tagName));
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'pending':
        return <Badge variant="outline" className="text-amber-600 border-amber-600">Pending</Badge>;
      case 'approved':
        return <Badge className="bg-green-600 hover:bg-green-700">Approved</Badge>;
      case 'rejected':
        return <Badge variant="destructive">Rejected</Badge>;
      default:
        return <Badge variant="outline">{status}</Badge>;
    }
  };

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    });
  };

  const formatTagLabel = (tag: string) => {
    return tag
      .split('_')
      .map(word => word.charAt(0).toUpperCase() + word.slice(1))
      .join(' ');
  };

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      {/* Only render DialogTrigger if trigger prop is provided (uncontrolled mode) */}
      {trigger && (
        <DialogTrigger asChild>
          {trigger}
        </DialogTrigger>
      )}
      {/* In controlled mode without trigger, show default button */}
      {!trigger && !isControlled && (
        <DialogTrigger asChild>
          <Button variant="outline">
            <Plus className="h-4 w-4 mr-2" />
            Request New Zman
          </Button>
        </DialogTrigger>
      )}
      <DialogContent className="max-w-2xl max-h-[90vh]">
        <DialogHeader>
          <DialogTitle>Request New Zman</DialogTitle>
          <DialogDescription>
            Request a new zman to be added to the master registry. Admins will review your request.
          </DialogDescription>
        </DialogHeader>

        {/* Toggle between form and history */}
        <div className="flex gap-2 border-b">
          <Button
            variant={!showHistory ? 'default' : 'ghost'}
            size="sm"
            onClick={() => setShowHistory(false)}
            className="rounded-b-none"
          >
            <FileText className="h-4 w-4 mr-2" />
            New Request
          </Button>
          <Button
            variant={showHistory ? 'default' : 'ghost'}
            size="sm"
            onClick={() => setShowHistory(true)}
            className="rounded-b-none"
          >
            Request History
          </Button>
        </div>

        {showHistory ? (
          /* Request History View */
          <ScrollArea className="h-[400px]">
            {historyLoading ? (
              <div className="flex justify-center py-8">
                <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
              </div>
            ) : historyData?.requests && historyData.requests.length > 0 ? (
              <div className="space-y-3">
                {historyData.requests.map((request) => (
                  <div
                    key={request.id}
                    className="p-4 rounded-lg border hover:border-muted-foreground/50"
                  >
                    <div className="flex items-start justify-between mb-2">
                      <div className="flex-1">
                        <h4 className="font-semibold text-sm">
                          <span className="font-hebrew">{request.requested_hebrew_name}</span>
                          <span className="mx-2 text-muted-foreground">•</span>
                          <span>{request.requested_english_name}</span>
                        </h4>
                        <p className="text-xs text-muted-foreground mt-1">
                          Key: <code className="font-mono">{request.requested_key}</code>
                        </p>
                      </div>
                      {getStatusBadge(request.status)}
                    </div>

                    <div className="flex items-center gap-4 text-xs text-muted-foreground mt-2">
                      <span>Category: {request.time_category}</span>
                      <span>•</span>
                      <span>Submitted: {formatDate(request.created_at)}</span>
                    </div>

                    {request.tags && request.tags.length > 0 && (
                      <div className="flex flex-wrap gap-1 mt-2">
                        {request.tags.map(tag => (
                          <Badge key={tag} variant="secondary" className="text-xs">
                            {formatTagLabel(tag)}
                          </Badge>
                        ))}
                      </div>
                    )}

                    {request.reviewer_notes && (
                      <div className="mt-2 p-2 bg-muted rounded text-xs">
                        <span className="font-medium">Admin Notes:</span> {request.reviewer_notes}
                      </div>
                    )}
                  </div>
                ))}
              </div>
            ) : (
              <div className="text-center py-8 text-muted-foreground">
                <FileText className="h-12 w-12 mx-auto mb-3 opacity-50" />
                <p>No requests yet</p>
                <p className="text-xs mt-1">Your submitted requests will appear here</p>
              </div>
            )}
          </ScrollArea>
        ) : (
          /* New Request Form */
          <ScrollArea className="h-[400px] pr-4">
            <div className="space-y-4">
              {/* Basic Information */}
              <div className="space-y-3">
                <h3 className="font-semibold text-sm">Basic Information</h3>

                <div>
                  <Label htmlFor="requested-key">
                    Zman Key <span className="text-destructive">*</span>
                  </Label>
                  <Input
                    id="requested-key"
                    value={requestedKey}
                    onChange={(e) => setRequestedKey(e.target.value)}
                    placeholder="e.g., alos_my_minhag"
                    className="font-mono"
                  />
                  <p className="text-xs text-muted-foreground mt-1">
                    Unique identifier (lowercase, underscores only)
                  </p>
                </div>

                <div>
                  <Label htmlFor="hebrew-name">
                    Hebrew Name <span className="text-destructive">*</span>
                  </Label>
                  <Input
                    id="hebrew-name"
                    value={hebrewName}
                    onChange={(e) => setHebrewName(e.target.value)}
                    className="font-hebrew"
                    placeholder="שם בעברית"
                    dir="rtl"
                  />
                </div>

                <div>
                  <Label htmlFor="english-name">
                    English Name <span className="text-destructive">*</span>
                  </Label>
                  <Input
                    id="english-name"
                    value={englishName}
                    onChange={(e) => setEnglishName(e.target.value)}
                    placeholder="English name"
                  />
                </div>

                <div>
                  <Label htmlFor="transliteration">Transliteration</Label>
                  <Input
                    id="transliteration"
                    value={transliteration}
                    onChange={(e) => setTransliteration(e.target.value)}
                    placeholder="e.g., Alos HaShachar"
                  />
                </div>

                <div>
                  <Label htmlFor="time-category">
                    Time Category <span className="text-destructive">*</span>
                  </Label>
                  <Select value={timeCategory} onValueChange={setTimeCategory}>
                    <SelectTrigger id="time-category">
                      <SelectValue placeholder="Select category" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="morning">Morning</SelectItem>
                      <SelectItem value="afternoon">Afternoon</SelectItem>
                      <SelectItem value="evening">Evening</SelectItem>
                      <SelectItem value="night">Night</SelectItem>
                      <SelectItem value="event">Event-based</SelectItem>
                      <SelectItem value="seasonal">Seasonal</SelectItem>
                      <SelectItem value="other">Other</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>

              {/* Tags Section */}
              <div className="space-y-3">
                <h3 className="font-semibold text-sm flex items-center gap-2">
                  <Tag className="h-4 w-4" />
                  Tags
                </h3>
                <p className="text-xs text-muted-foreground">
                  Select tags that describe this zman. You can also request new tags.
                </p>

                {tagsLoading ? (
                  <div className="flex justify-center py-4">
                    <Loader2 className="h-5 w-5 animate-spin text-muted-foreground" />
                  </div>
                ) : (
                  <>
                    {/* Tags by Type */}
                    {TAG_TYPE_ORDER.map(tagType => {
                      const tags = tagsByType[tagType];
                      if (!tags || tags.length === 0) return null;

                      return (
                        <div key={tagType} className="space-y-1.5">
                          <Label className="text-xs text-muted-foreground">
                            {TAG_TYPE_LABELS[tagType] || tagType}
                          </Label>
                          <div className="flex flex-wrap gap-1.5">
                            {tags.map(tag => (
                              <Badge
                                key={tag.id}
                                variant={selectedTagIds.includes(tag.id) ? 'default' : 'outline'}
                                className="cursor-pointer hover:bg-primary/80 transition-colors"
                                onClick={() => toggleTag(tag.id)}
                                title={tag.description || tag.display_name_english}
                              >
                                {tag.display_name_english}
                              </Badge>
                            ))}
                          </div>
                        </div>
                      );
                    })}
                  </>
                )}

                {/* Custom/New Tag Input */}
                <div className="space-y-2 pt-2 border-t">
                  <Label className="text-xs">Request New Tag</Label>
                  <div className="flex gap-2">
                    <Input
                      value={customTagInput}
                      onChange={(e) => setCustomTagInput(e.target.value)}
                      placeholder="Tag name"
                      className="flex-1 text-sm"
                    />
                    <Select value={customTagType} onValueChange={setCustomTagType}>
                      <SelectTrigger className="w-[140px]">
                        <SelectValue placeholder="Type" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="event">Event</SelectItem>
                        <SelectItem value="timing">Timing</SelectItem>
                        <SelectItem value="behavior">Behavior</SelectItem>
                        <SelectItem value="shita">Shita</SelectItem>
                        <SelectItem value="method">Method</SelectItem>
                      </SelectContent>
                    </Select>
                    <Button
                      type="button"
                      variant="outline"
                      size="sm"
                      onClick={addCustomTag}
                      disabled={!customTagInput.trim() || !customTagType}
                    >
                      <Plus className="h-4 w-4" />
                    </Button>
                  </div>
                  <p className="text-xs text-muted-foreground">
                    New tags will be reviewed by admins before being added to the system.
                  </p>

                  {/* Requested New Tags */}
                  {requestedNewTags.length > 0 && (
                    <div className="flex flex-wrap gap-1.5 mt-2">
                      {requestedNewTags.map(tag => (
                        <Badge
                          key={tag.name}
                          variant="secondary"
                          className="bg-amber-100 dark:bg-amber-900/30 text-amber-700 dark:text-amber-300 border-amber-300 dark:border-amber-700"
                        >
                          {formatTagLabel(tag.name)}
                          <span className="ml-1 text-xs opacity-70">({TAG_TYPE_LABELS[tag.type] || tag.type})</span>
                          <button
                            type="button"
                            onClick={() => removeRequestedTag(tag.name)}
                            className="ml-1 hover:text-destructive"
                          >
                            <X className="h-3 w-3" />
                          </button>
                        </Badge>
                      ))}
                    </div>
                  )}
                </div>
              </div>

              {/* Description & Formula */}
              <div className="space-y-3">
                <h3 className="font-semibold text-sm">Details</h3>

                <div>
                  <Label htmlFor="description">
                    Description <span className="text-destructive">*</span>
                  </Label>
                  <Textarea
                    id="description"
                    value={description}
                    onChange={(e) => setDescription(e.target.value)}
                    placeholder="Describe this zman and how it is calculated..."
                    rows={3}
                  />
                </div>

                <div>
                  <Label htmlFor="formula-dsl">Suggested Formula (optional)</Label>
                  <Textarea
                    id="formula-dsl"
                    value={formulaDsl}
                    onChange={(e) => setFormulaDsl(e.target.value)}
                    placeholder='e.g., {"type": "solar", "event": "sunrise", "offset_minutes": -72}'
                    className="font-mono text-sm"
                    rows={2}
                  />
                  <p className="text-xs text-muted-foreground mt-1">
                    Optional DSL formula suggestion for this zman
                  </p>
                </div>
              </div>

              {/* Halachic Sources */}
              <div className="space-y-3">
                <h3 className="font-semibold text-sm">Halachic Sources</h3>

                <div>
                  <Label htmlFor="halachic-source">Source Reference</Label>
                  <Input
                    id="halachic-source"
                    value={halachicSource}
                    onChange={(e) => setHalachicSource(e.target.value)}
                    placeholder="e.g., Shulchan Aruch O.C. 89:1"
                  />
                </div>

                <div>
                  <Label htmlFor="halachic-notes">Halachic Notes</Label>
                  <Textarea
                    id="halachic-notes"
                    value={halachicNotes}
                    onChange={(e) => setHalachicNotes(e.target.value)}
                    placeholder="Optional notes about the halachic basis..."
                    rows={2}
                  />
                </div>
              </div>

              {/* Auto-add option */}
              <div className="flex items-center space-x-2">
                <Checkbox
                  id="auto-add"
                  checked={autoAddOnApproval}
                  onCheckedChange={(checked) => setAutoAddOnApproval(checked === true)}
                />
                <Label
                  htmlFor="auto-add"
                  className="text-sm font-normal cursor-pointer"
                >
                  Automatically add this zman to my zmanim when approved
                </Label>
              </div>
            </div>
          </ScrollArea>
        )}

        {!showHistory && (
          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => {
                handleReset();
                setOpen(false);
              }}
            >
              Cancel
            </Button>
            <Button
              onClick={handleSubmit}
              disabled={
                !requestedKey.trim() ||
                !hebrewName.trim() ||
                !englishName.trim() ||
                !timeCategory ||
                !description.trim() ||
                submitRequest.isPending
              }
            >
              {submitRequest.isPending ? (
                <>
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                  Submitting...
                </>
              ) : (
                'Submit Request'
              )}
            </Button>
          </DialogFooter>
        )}
      </DialogContent>
    </Dialog>
  );
}
