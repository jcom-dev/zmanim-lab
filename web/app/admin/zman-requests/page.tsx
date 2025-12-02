'use client';

import { useState, useEffect, useCallback } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { ScrollArea } from '@/components/ui/scroll-area';
import { useAdminApi } from '@/lib/api-client';
import { useUser } from '@clerk/nextjs';
import {
  Clock,
  Search,
  Loader2,
  CheckCircle2,
  XCircle,
  FileText,
  User,
  Calendar,
} from 'lucide-react';

interface ZmanRequest {
  id: string;
  publisher_id: string;
  requested_key: string;
  requested_hebrew_name: string;
  requested_english_name: string;
  transliteration?: string;
  time_category: string;
  justification?: string;
  description?: string;
  halachic_notes?: string;
  halachic_source?: string;
  status: 'pending' | 'approved' | 'rejected';
  reviewed_at?: string;
  reviewer_notes?: string;
  publisher_name?: string;
  publisher_organization?: string;
  created_at: string;
}

interface ZmanRequestListResponse {
  requests: ZmanRequest[];
  total: number;
}

const categoryColors: Record<string, string> = {
  morning: 'bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-200',
  afternoon: 'bg-orange-100 text-orange-800 dark:bg-orange-900/30 dark:text-orange-200',
  evening: 'bg-rose-100 text-rose-800 dark:bg-rose-900/30 dark:text-rose-200',
  night: 'bg-indigo-100 text-indigo-800 dark:bg-indigo-900/30 dark:text-indigo-200',
  event: 'bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-200',
  seasonal: 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-200',
  other: 'bg-slate-100 text-slate-800 dark:bg-slate-900/30 dark:text-slate-200',
};

export default function AdminZmanRequestsPage() {
  const api = useAdminApi();
  const { user, isLoaded } = useUser();
  const [requests, setRequests] = useState<ZmanRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState<string>('pending');

  // Review dialog state
  const [selectedRequest, setSelectedRequest] = useState<ZmanRequest | null>(null);
  const [reviewDialogOpen, setReviewDialogOpen] = useState(false);
  const [reviewerNotes, setReviewerNotes] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const fetchRequests = useCallback(async () => {
    try {
      setLoading(true);
      const params = new URLSearchParams();
      if (statusFilter !== 'all') {
        params.set('status', statusFilter);
      }
      const data = await api.get<ZmanRequestListResponse>(`/admin/zman-requests?${params}`);
      setRequests(data?.requests || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch requests');
    } finally {
      setLoading(false);
    }
  }, [api, statusFilter]);

  useEffect(() => {
    if (isLoaded) {
      fetchRequests();
    }
  }, [fetchRequests, isLoaded]);

  const filteredRequests = requests.filter((req) => {
    if (searchTerm) {
      const search = searchTerm.toLowerCase();
      return (
        req.requested_key.toLowerCase().includes(search) ||
        req.requested_hebrew_name.toLowerCase().includes(search) ||
        req.requested_english_name.toLowerCase().includes(search) ||
        req.publisher_name?.toLowerCase().includes(search) ||
        req.publisher_organization?.toLowerCase().includes(search)
      );
    }
    return true;
  });

  const openReviewDialog = (request: ZmanRequest) => {
    setSelectedRequest(request);
    setReviewerNotes('');
    setReviewDialogOpen(true);
  };

  const handleApprove = async () => {
    if (!selectedRequest || !user?.id) return;

    try {
      setIsSubmitting(true);
      await api.put(`/admin/zman-requests/${selectedRequest.id}`, {
        body: JSON.stringify({
          status: 'approved',
          reviewer_notes: reviewerNotes.trim() || undefined,
        }),
      });
      setReviewDialogOpen(false);
      fetchRequests();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to approve request');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleReject = async () => {
    if (!selectedRequest || !user?.id) return;

    try {
      setIsSubmitting(true);
      await api.put(`/admin/zman-requests/${selectedRequest.id}`, {
        body: JSON.stringify({
          status: 'rejected',
          reviewer_notes: reviewerNotes.trim() || undefined,
        }),
      });
      setReviewDialogOpen(false);
      fetchRequests();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to reject request');
    } finally {
      setIsSubmitting(false);
    }
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
      hour: 'numeric',
      minute: '2-digit',
    });
  };

  if (!isLoaded || loading) {
    return (
      <div className="space-y-6">
        <div>
          <h1 className="text-3xl font-bold text-foreground">Zman Requests</h1>
          <p className="text-muted-foreground mt-1">Loading...</p>
        </div>
        <div className="flex justify-center p-8">
          <Loader2 className="w-8 h-8 animate-spin text-primary" />
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div>
          <h1 className="text-2xl md:text-3xl font-bold text-foreground">Zman Requests</h1>
          <p className="text-sm md:text-base text-muted-foreground mt-1">
            Review and approve requests from publishers to add new zmanim to the registry
          </p>
        </div>
      </div>

      {error && (
        <div className="bg-destructive/10 border border-destructive/30 rounded-lg p-4">
          <p className="text-destructive">{error}</p>
          <Button
            variant="ghost"
            size="sm"
            onClick={() => setError(null)}
            className="mt-2"
          >
            Dismiss
          </Button>
        </div>
      )}

      {/* Filters */}
      <Card>
        <CardContent className="pt-6">
          <div className="flex flex-col sm:flex-row gap-4">
            <div className="flex items-center gap-2 flex-1">
              <Search className="w-4 h-4 text-muted-foreground flex-shrink-0" />
              <Input
                placeholder="Search requests, publishers..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="flex-1"
              />
            </div>
            <div className="flex items-center gap-2">
              <Label className="text-sm text-muted-foreground whitespace-nowrap">Status:</Label>
              <Select value={statusFilter} onValueChange={setStatusFilter}>
                <SelectTrigger className="w-[130px]">
                  <SelectValue placeholder="All" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All</SelectItem>
                  <SelectItem value="pending">Pending</SelectItem>
                  <SelectItem value="approved">Approved</SelectItem>
                  <SelectItem value="rejected">Rejected</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Card>
          <CardContent className="pt-6">
            <div className="text-2xl font-bold text-foreground">{requests.length}</div>
            <p className="text-sm text-muted-foreground">Total Requests</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-6">
            <div className="text-2xl font-bold text-amber-600">
              {requests.filter((r) => r.status === 'pending').length}
            </div>
            <p className="text-sm text-muted-foreground">Pending</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-6">
            <div className="text-2xl font-bold text-green-600">
              {requests.filter((r) => r.status === 'approved').length}
            </div>
            <p className="text-sm text-muted-foreground">Approved</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-6">
            <div className="text-2xl font-bold text-destructive">
              {requests.filter((r) => r.status === 'rejected').length}
            </div>
            <p className="text-sm text-muted-foreground">Rejected</p>
          </CardContent>
        </Card>
      </div>

      {/* Requests List */}
      <Card>
        <CardHeader>
          <div className="flex items-center gap-3">
            <FileText className="w-5 h-5" />
            <div>
              <CardTitle>Zman Requests</CardTitle>
              <CardDescription>
                {filteredRequests.length} requests matching filters
              </CardDescription>
            </div>
          </div>
        </CardHeader>
        <CardContent>
          {filteredRequests.length === 0 ? (
            <div className="text-center py-12 text-muted-foreground">
              <FileText className="h-12 w-12 mx-auto mb-3 opacity-50" />
              <p>No requests found</p>
              <p className="text-xs mt-1">
                {statusFilter === 'pending'
                  ? 'No pending requests to review'
                  : 'Try adjusting your filters'}
              </p>
            </div>
          ) : (
            <div className="space-y-4">
              {filteredRequests.map((request) => (
                <div
                  key={request.id}
                  className="p-4 rounded-lg border hover:border-muted-foreground/50 transition-colors"
                >
                  <div className="flex flex-col md:flex-row md:items-start justify-between gap-4">
                    <div className="flex-1">
                      <div className="flex items-start gap-3">
                        <div className="flex-1">
                          <h3 className="font-semibold text-foreground">
                            <span className="font-hebrew">{request.requested_hebrew_name}</span>
                            <span className="mx-2 text-muted-foreground">•</span>
                            <span>{request.requested_english_name}</span>
                          </h3>
                          <p className="text-sm text-muted-foreground mt-1">
                            Key: <code className="font-mono bg-muted px-1 rounded">{request.requested_key}</code>
                          </p>
                        </div>
                        {getStatusBadge(request.status)}
                      </div>

                      <div className="flex flex-wrap items-center gap-3 mt-3 text-xs text-muted-foreground">
                        <span className={`px-2 py-0.5 rounded ${categoryColors[request.time_category] || categoryColors.other}`}>
                          {request.time_category}
                        </span>
                        {request.publisher_name && (
                          <span className="flex items-center gap-1">
                            <User className="h-3 w-3" />
                            {request.publisher_name}
                            {request.publisher_organization && ` (${request.publisher_organization})`}
                          </span>
                        )}
                        <span className="flex items-center gap-1">
                          <Calendar className="h-3 w-3" />
                          {formatDate(request.created_at)}
                        </span>
                      </div>

                      {request.justification && (
                        <p className="mt-3 text-sm text-muted-foreground line-clamp-2">
                          {request.justification}
                        </p>
                      )}

                      {request.reviewer_notes && request.status !== 'pending' && (
                        <div className="mt-3 p-2 bg-muted rounded text-xs">
                          <span className="font-medium">Review Notes:</span> {request.reviewer_notes}
                        </div>
                      )}
                    </div>

                    {request.status === 'pending' && (
                      <div className="flex gap-2">
                        <Button
                          size="sm"
                          variant="outline"
                          onClick={() => openReviewDialog(request)}
                        >
                          Review
                        </Button>
                      </div>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Review Dialog */}
      <Dialog open={reviewDialogOpen} onOpenChange={setReviewDialogOpen}>
        <DialogContent className="max-w-2xl max-h-[90vh]">
          <DialogHeader>
            <DialogTitle>Review Zman Request</DialogTitle>
            <DialogDescription>
              Review the request details and approve or reject
            </DialogDescription>
          </DialogHeader>

          {selectedRequest && (
            <ScrollArea className="max-h-[60vh]">
              <div className="space-y-4 pr-4">
                {/* Request Details */}
                <div className="p-4 bg-muted rounded-lg space-y-3">
                  <div>
                    <Label className="text-xs text-muted-foreground">Requested Name</Label>
                    <p className="font-medium">
                      <span className="font-hebrew">{selectedRequest.requested_hebrew_name}</span>
                      <span className="mx-2 text-muted-foreground">•</span>
                      <span>{selectedRequest.requested_english_name}</span>
                    </p>
                  </div>

                  <div>
                    <Label className="text-xs text-muted-foreground">Zman Key</Label>
                    <p className="font-mono text-sm">{selectedRequest.requested_key}</p>
                  </div>

                  {selectedRequest.transliteration && (
                    <div>
                      <Label className="text-xs text-muted-foreground">Transliteration</Label>
                      <p className="text-sm">{selectedRequest.transliteration}</p>
                    </div>
                  )}

                  <div>
                    <Label className="text-xs text-muted-foreground">Time Category</Label>
                    <p className="text-sm">{selectedRequest.time_category}</p>
                  </div>

                  {selectedRequest.description && (
                    <div>
                      <Label className="text-xs text-muted-foreground">Description</Label>
                      <p className="text-sm">{selectedRequest.description}</p>
                    </div>
                  )}

                  {selectedRequest.justification && (
                    <div>
                      <Label className="text-xs text-muted-foreground">Justification</Label>
                      <p className="text-sm">{selectedRequest.justification}</p>
                    </div>
                  )}

                  {selectedRequest.halachic_source && (
                    <div>
                      <Label className="text-xs text-muted-foreground">Halachic Source</Label>
                      <p className="text-sm">{selectedRequest.halachic_source}</p>
                    </div>
                  )}

                  {selectedRequest.halachic_notes && (
                    <div>
                      <Label className="text-xs text-muted-foreground">Halachic Notes</Label>
                      <p className="text-sm">{selectedRequest.halachic_notes}</p>
                    </div>
                  )}

                  <div className="pt-2 border-t">
                    <Label className="text-xs text-muted-foreground">Submitted By</Label>
                    <p className="text-sm">
                      {selectedRequest.publisher_name}
                      {selectedRequest.publisher_organization && ` (${selectedRequest.publisher_organization})`}
                    </p>
                    <p className="text-xs text-muted-foreground mt-1">
                      {formatDate(selectedRequest.created_at)}
                    </p>
                  </div>
                </div>

                {/* Reviewer Notes */}
                <div className="space-y-2">
                  <Label htmlFor="reviewer-notes">Reviewer Notes (optional)</Label>
                  <Textarea
                    id="reviewer-notes"
                    value={reviewerNotes}
                    onChange={(e) => setReviewerNotes(e.target.value)}
                    placeholder="Add notes about your decision..."
                    rows={3}
                  />
                </div>
              </div>
            </ScrollArea>
          )}

          <DialogFooter className="flex-col sm:flex-row gap-2">
            <Button
              variant="outline"
              onClick={() => setReviewDialogOpen(false)}
              disabled={isSubmitting}
            >
              Cancel
            </Button>
            <Button
              variant="destructive"
              onClick={handleReject}
              disabled={isSubmitting}
            >
              {isSubmitting ? (
                <Loader2 className="h-4 w-4 mr-2 animate-spin" />
              ) : (
                <XCircle className="h-4 w-4 mr-2" />
              )}
              Reject
            </Button>
            <Button
              onClick={handleApprove}
              disabled={isSubmitting}
              className="bg-green-600 hover:bg-green-700"
            >
              {isSubmitting ? (
                <Loader2 className="h-4 w-4 mr-2 animate-spin" />
              ) : (
                <CheckCircle2 className="h-4 w-4 mr-2" />
              )}
              Approve
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
