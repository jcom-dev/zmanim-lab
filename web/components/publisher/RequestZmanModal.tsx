'use client';

import { useState } from 'react';
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
import { Loader2, Plus, FileText } from 'lucide-react';
import { Checkbox } from '@/components/ui/checkbox';
import { ScrollArea } from '@/components/ui/scroll-area';

interface ZmanRequest {
  id: string;
  requested_key: string;
  requested_hebrew_name: string;
  requested_english_name: string;
  transliteration?: string;
  time_category: string;
  status: string;
  reviewed_at?: string;
  reviewer_notes?: string;
  created_at: string;
}

interface ZmanRequestListResponse {
  requests: ZmanRequest[];
  total: number;
}

interface RequestZmanModalProps {
  trigger?: React.ReactNode;
  onSuccess?: () => void;
}

/**
 * RequestZmanModal - Modal for requesting a new zman to be added to the master registry
 *
 * Features:
 * - Form for submitting new zman request
 * - Validation for required fields
 * - Halachic source fields
 * - Request history with status badges
 * - Uses useApi() hook for all API calls
 *
 * Story 5.7: Request New Zman UI
 */
export function RequestZmanModal({ trigger, onSuccess }: RequestZmanModalProps) {
  const [open, setOpen] = useState(false);
  const [showHistory, setShowHistory] = useState(false);

  // Form state
  const [requestedKey, setRequestedKey] = useState('');
  const [hebrewName, setHebrewName] = useState('');
  const [englishName, setEnglishName] = useState('');
  const [transliteration, setTransliteration] = useState('');
  const [timeCategory, setTimeCategory] = useState('');
  const [justification, setJustification] = useState('');
  const [description, setDescription] = useState('');
  const [halachicNotes, setHalachicNotes] = useState('');
  const [halachicSource, setHalachicSource] = useState('');
  const [publisherEmail, setPublisherEmail] = useState('');
  const [publisherName, setPublisherName] = useState('');
  const [autoAddOnApproval, setAutoAddOnApproval] = useState(true);

  // Fetch request history
  const { data: historyData, isLoading: historyLoading } = usePublisherQuery<ZmanRequestListResponse>(
    'zman-requests',
    '/publisher/registry/zmanim/requests',
    {
      enabled: showHistory,
    }
  );

  // Mutation to submit request
  const submitRequest = usePublisherMutation<unknown, {
    requested_key: string;
    requested_hebrew_name: string;
    requested_english_name: string;
    transliteration?: string;
    time_category: string;
    justification: string;
    description?: string;
    halachic_notes?: string;
    halachic_source?: string;
    publisher_email: string;
    publisher_name: string;
    auto_add_on_approval?: boolean;
  }>(
    '/publisher/registry/zmanim/request',
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
    setJustification('');
    setDescription('');
    setHalachicNotes('');
    setHalachicSource('');
    setPublisherEmail('');
    setPublisherName('');
    setAutoAddOnApproval(true);
  };

  const handleSubmit = async () => {
    if (!requestedKey.trim() || !hebrewName.trim() || !englishName.trim() ||
        !timeCategory || !justification.trim() || !publisherEmail.trim() || !publisherName.trim()) {
      return;
    }

    await submitRequest.mutateAsync({
      requested_key: requestedKey.trim(),
      requested_hebrew_name: hebrewName.trim(),
      requested_english_name: englishName.trim(),
      transliteration: transliteration.trim() || undefined,
      time_category: timeCategory,
      justification: justification.trim(),
      description: description.trim() || undefined,
      halachic_notes: halachicNotes.trim() || undefined,
      halachic_source: halachicSource.trim() || undefined,
      publisher_email: publisherEmail.trim(),
      publisher_name: publisherName.trim(),
      auto_add_on_approval: autoAddOnApproval,
    });
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

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        {trigger || (
          <Button variant="outline">
            <Plus className="h-4 w-4 mr-2" />
            Request New Zman
          </Button>
        )}
      </DialogTrigger>
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

              {/* Justification & Description */}
              <div className="space-y-3">
                <h3 className="font-semibold text-sm">Justification</h3>

                <div>
                  <Label htmlFor="justification">
                    Why is this zman needed? <span className="text-destructive">*</span>
                  </Label>
                  <Textarea
                    id="justification"
                    value={justification}
                    onChange={(e) => setJustification(e.target.value)}
                    placeholder="Explain why this zman should be added to the registry..."
                    rows={3}
                  />
                </div>

                <div>
                  <Label htmlFor="description">Description</Label>
                  <Textarea
                    id="description"
                    value={description}
                    onChange={(e) => setDescription(e.target.value)}
                    placeholder="Optional description of how this zman is calculated..."
                    rows={2}
                  />
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

              {/* Contact Information */}
              <div className="space-y-3">
                <h3 className="font-semibold text-sm">Contact Information</h3>

                <div>
                  <Label htmlFor="publisher-name">
                    Your Name <span className="text-destructive">*</span>
                  </Label>
                  <Input
                    id="publisher-name"
                    value={publisherName}
                    onChange={(e) => setPublisherName(e.target.value)}
                    placeholder="Your name or organization"
                  />
                </div>

                <div>
                  <Label htmlFor="publisher-email">
                    Email <span className="text-destructive">*</span>
                  </Label>
                  <Input
                    id="publisher-email"
                    type="email"
                    value={publisherEmail}
                    onChange={(e) => setPublisherEmail(e.target.value)}
                    placeholder="your@email.com"
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
                  Automatically add this zman to my algorithm when approved
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
                !justification.trim() ||
                !publisherEmail.trim() ||
                !publisherName.trim() ||
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
