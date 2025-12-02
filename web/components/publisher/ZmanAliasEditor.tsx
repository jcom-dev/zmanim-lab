'use client';

import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { useApi } from '@/lib/api-client';
import { usePublisherMutation, usePublisherQuery } from '@/lib/hooks';
import { Pencil, Trash2, Loader2, Plus } from 'lucide-react';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog';

interface ZmanAlias {
  id: string;
  zman_key: string;
  custom_hebrew_name: string;
  custom_english_name: string;
  custom_transliteration?: string;
  canonical_hebrew_name: string;
  canonical_english_name: string;
  created_at: string;
  updated_at: string;
}

interface ZmanAliasEditorProps {
  zmanKey: string;
  canonicalHebrewName: string;
  canonicalEnglishName: string;
  onAliasChanged?: () => void;
}

/**
 * ZmanAliasEditor - Inline alias editing component
 *
 * Features:
 * - Display current alias as a badge next to zman name
 * - Click badge or "Add Alias" to open edit dialog
 * - Save/delete aliases via API
 * - Uses useApi() hook for all API calls
 *
 * Story 5.5: Publisher Zman Alias UI
 */
export function ZmanAliasEditor({
  zmanKey,
  canonicalHebrewName,
  canonicalEnglishName,
  onAliasChanged,
}: ZmanAliasEditorProps) {
  const [showEditDialog, setShowEditDialog] = useState(false);
  const [showDeleteDialog, setShowDeleteDialog] = useState(false);
  const [hebrewName, setHebrewName] = useState('');
  const [englishName, setEnglishName] = useState('');
  const [transliteration, setTransliteration] = useState('');

  // Fetch current alias
  const { data: alias, isLoading } = usePublisherQuery<ZmanAlias>(
    ['publisher-alias', zmanKey],
    `/publisher/zmanim/${zmanKey}/alias`
  );

  // Mutation to save alias
  const saveAlias = usePublisherMutation<ZmanAlias, {
    custom_hebrew_name: string;
    custom_english_name: string;
    custom_transliteration?: string;
  }>(
    `/publisher/zmanim/${zmanKey}/alias`,
    'PUT',
    {
      invalidateKeys: [`publisher-alias-${zmanKey}`, 'publisher-zmanim'],
      onSuccess: () => {
        setShowEditDialog(false);
        onAliasChanged?.();
      },
    }
  );

  // Mutation to delete alias
  const deleteAlias = usePublisherMutation(
    `/publisher/zmanim/${zmanKey}/alias`,
    'DELETE',
    {
      invalidateKeys: [`publisher-alias-${zmanKey}`, 'publisher-zmanim'],
      onSuccess: () => {
        setShowDeleteDialog(false);
        onAliasChanged?.();
      },
    }
  );

  const handleOpenEdit = () => {
    if (alias) {
      setHebrewName(alias.custom_hebrew_name);
      setEnglishName(alias.custom_english_name);
      setTransliteration(alias.custom_transliteration || '');
    } else {
      setHebrewName('');
      setEnglishName('');
      setTransliteration('');
    }
    setShowEditDialog(true);
  };

  const handleSave = async () => {
    if (!hebrewName.trim() || !englishName.trim()) {
      return;
    }

    await saveAlias.mutateAsync({
      custom_hebrew_name: hebrewName.trim(),
      custom_english_name: englishName.trim(),
      custom_transliteration: transliteration.trim() || undefined,
    });
  };

  const handleDelete = async () => {
    await deleteAlias.mutateAsync({});
  };

  if (isLoading) {
    return (
      <div className="inline-flex items-center gap-1">
        <Loader2 className="h-3 w-3 animate-spin text-muted-foreground" />
      </div>
    );
  }

  return (
    <>
      {/* Display alias badge or "Add Alias" button */}
      {alias ? (
        <div className="inline-flex items-center gap-1 group">
          <Badge
            variant="outline"
            className="cursor-pointer hover:bg-muted transition-colors"
            onClick={handleOpenEdit}
          >
            <span className="font-hebrew">{alias.custom_hebrew_name}</span>
            <span className="mx-1">•</span>
            <span>{alias.custom_english_name}</span>
            <Pencil className="h-3 w-3 ml-1 opacity-0 group-hover:opacity-100 transition-opacity" />
          </Badge>
        </div>
      ) : (
        <Button
          variant="ghost"
          size="sm"
          onClick={handleOpenEdit}
          className="h-6 px-2 text-xs text-muted-foreground hover:text-foreground"
        >
          <Plus className="h-3 w-3 mr-1" />
          Add Alias
        </Button>
      )}

      {/* Edit Alias Dialog */}
      <Dialog open={showEditDialog} onOpenChange={setShowEditDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{alias ? 'Edit Alias' : 'Add Alias'}</DialogTitle>
            <DialogDescription>
              Create a custom name for this zman. The canonical name is:
              <div className="mt-2 p-2 bg-muted rounded text-foreground">
                <span className="font-hebrew">{canonicalHebrewName}</span>
                <span className="mx-2">•</span>
                <span>{canonicalEnglishName}</span>
              </div>
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4">
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
              <Label htmlFor="transliteration">
                Transliteration <span className="text-muted-foreground">(optional)</span>
              </Label>
              <Input
                id="transliteration"
                value={transliteration}
                onChange={(e) => setTransliteration(e.target.value)}
                placeholder="e.g., Alos HaShachar"
              />
            </div>
          </div>

          <DialogFooter className="flex-col sm:flex-row gap-2">
            {alias && (
              <Button
                variant="destructive"
                onClick={() => {
                  setShowEditDialog(false);
                  setShowDeleteDialog(true);
                }}
                className="sm:mr-auto"
              >
                <Trash2 className="h-4 w-4 mr-2" />
                Delete Alias
              </Button>
            )}
            <Button
              variant="outline"
              onClick={() => setShowEditDialog(false)}
            >
              Cancel
            </Button>
            <Button
              onClick={handleSave}
              disabled={!hebrewName.trim() || !englishName.trim() || saveAlias.isPending}
            >
              {saveAlias.isPending ? (
                <>
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                  Saving...
                </>
              ) : (
                'Save Alias'
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete Confirmation Dialog */}
      <AlertDialog open={showDeleteDialog} onOpenChange={setShowDeleteDialog}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete Alias?</AlertDialogTitle>
            <AlertDialogDescription>
              Are you sure you want to delete this alias? The zman will revert to its canonical name:
              <div className="mt-2 p-2 bg-muted rounded text-foreground">
                <span className="font-hebrew">{canonicalHebrewName}</span>
                <span className="mx-2">•</span>
                <span>{canonicalEnglishName}</span>
              </div>
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction
              onClick={handleDelete}
              className="bg-destructive hover:bg-destructive/90"
              disabled={deleteAlias.isPending}
            >
              {deleteAlias.isPending ? (
                <>
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                  Deleting...
                </>
              ) : (
                'Delete'
              )}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
}

/**
 * ZmanAliasBadge - Display-only alias badge
 *
 * Shows the current alias for a zman without edit functionality.
 * Useful for read-only views.
 */
export function ZmanAliasBadge({ zmanKey }: { zmanKey: string }) {
  const { data: alias, isLoading } = usePublisherQuery<ZmanAlias>(
    ['publisher-alias', zmanKey],
    `/publisher/zmanim/${zmanKey}/alias`
  );

  if (isLoading || !alias) {
    return null;
  }

  return (
    <Badge variant="outline" className="font-normal">
      <span className="font-hebrew">{alias.custom_hebrew_name}</span>
      <span className="mx-1">•</span>
      <span>{alias.custom_english_name}</span>
    </Badge>
  );
}
