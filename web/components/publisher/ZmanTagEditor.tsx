'use client';

import { useState, useEffect } from 'react';
import { Button } from '@/components/ui/button';
import { ColorBadge, getTagTypeColor } from '@/components/ui/color-badge';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
  DialogFooter,
} from '@/components/ui/dialog';
import { Checkbox } from '@/components/ui/checkbox';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Loader2, Tags, Check } from 'lucide-react';
import {
  ZmanTag,
  useZmanTags,
  useUpdatePublisherZmanTags,
} from '@/lib/hooks/useZmanimList';
import { useTagTypes } from '@/lib/hooks';
import { cn } from '@/lib/utils';

interface ZmanTagEditorProps {
  zmanKey: string;
  currentTags: ZmanTag[];
  onTagsUpdated?: () => void;
}

/**
 * ZmanTagEditor - Dialog for managing tags on a publisher zman
 *
 * Features:
 * - Shows all available tags grouped by type
 * - Checkboxes to toggle tags on/off
 * - Saves changes on confirm
 */
export function ZmanTagEditor({ zmanKey, currentTags, onTagsUpdated }: ZmanTagEditorProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [selectedTagIds, setSelectedTagIds] = useState<Set<string>>(
    new Set(currentTags.map((t) => t.id))
  );

  const { data: allTags, isLoading: tagsLoading } = useZmanTags();
  const { data: tagTypes, isLoading: tagTypesLoading } = useTagTypes();
  const updateTags = useUpdatePublisherZmanTags(zmanKey);

  // Build tag type labels map from database
  const tagTypeLabelsMap = tagTypes?.reduce((acc, tt) => {
    acc[tt.key] = tt.display_name_english;
    return acc;
  }, {} as Record<string, string>) ?? {};

  // Reset selection when dialog opens
  useEffect(() => {
    if (isOpen) {
      setSelectedTagIds(new Set(currentTags.map((t) => t.id)));
    }
  }, [isOpen, currentTags]);

  // Group tags by type (ensure allTags is an array)
  const tagsArray = Array.isArray(allTags) ? allTags : [];
  const tagsByType = tagsArray.reduce((acc, tag) => {
    const type = tag.tag_type || 'other';
    if (!acc[type]) acc[type] = [];
    acc[type].push(tag);
    return acc;
  }, {} as Record<string, ZmanTag[]>);

  const handleTagToggle = (tagId: string) => {
    setSelectedTagIds((prev) => {
      const next = new Set(prev);
      if (next.has(tagId)) {
        next.delete(tagId);
      } else {
        next.add(tagId);
      }
      return next;
    });
  };

  const hasChanges = () => {
    const currentIds = new Set(currentTags.map((t) => t.id));
    if (currentIds.size !== selectedTagIds.size) return true;
    for (const id of currentIds) {
      if (!selectedTagIds.has(id)) return true;
    }
    return false;
  };

  const handleSave = async () => {
    // Convert selected tag IDs to TagAssignment format (not negated by default)
    const tagAssignments = Array.from(selectedTagIds).map((tagId) => ({
      tag_id: tagId,
      is_negated: false,
    }));
    await updateTags.mutateAsync({ tags: tagAssignments });
    setIsOpen(false);
    onTagsUpdated?.();
  };

  return (
    <Dialog open={isOpen} onOpenChange={setIsOpen}>
      <DialogTrigger asChild>
        <Button
          variant="ghost"
          size="sm"
          className="h-7 px-2 gap-1.5 text-muted-foreground hover:text-foreground"
        >
          <Tags className="h-3.5 w-3.5" />
          <span className="text-xs">
            {currentTags.length > 0 ? `${currentTags.length} tags` : 'Add tags'}
          </span>
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Edit Tags</DialogTitle>
          <DialogDescription>
            Select tags to categorize this zman
          </DialogDescription>
        </DialogHeader>

        {tagsLoading || tagTypesLoading ? (
          <div className="flex justify-center py-8">
            <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
          </div>
        ) : Object.keys(tagsByType).length === 0 ? (
          <div className="text-center py-8 text-muted-foreground">
            No tags available
          </div>
        ) : (
          <ScrollArea className="max-h-[50vh] pr-4">
            <div className="space-y-6">
              {Object.entries(tagsByType).map(([type, tags]) => (
                <div key={type}>
                  <h5 className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-3">
                    {tagTypeLabelsMap[type] || type}
                  </h5>
                  <div className="space-y-2">
                    {tags.map((tag) => {
                      const isSelected = selectedTagIds.has(tag.id);
                      return (
                        <label
                          key={tag.id}
                          className={cn(
                            'flex items-center gap-3 px-3 py-2 rounded-lg cursor-pointer transition-colors border',
                            isSelected
                              ? 'bg-primary/10 border-primary/30'
                              : 'bg-card hover:bg-muted border-transparent'
                          )}
                        >
                          <Checkbox
                            checked={isSelected}
                            onCheckedChange={() => handleTagToggle(tag.id)}
                          />
                          <ColorBadge
                            color={getTagTypeColor(tag.tag_type)}
                            size="sm"
                            className="flex-shrink-0"
                          >
                            {tag.display_name_english}
                          </ColorBadge>
                          {tag.display_name_hebrew && (
                            <span className="text-sm text-muted-foreground font-hebrew ml-auto">
                              {tag.display_name_hebrew}
                            </span>
                          )}
                        </label>
                      );
                    })}
                  </div>
                </div>
              ))}
            </div>
          </ScrollArea>
        )}

        <DialogFooter className="gap-2">
          <Button
            variant="outline"
            onClick={() => setIsOpen(false)}
          >
            Cancel
          </Button>
          <Button
            onClick={handleSave}
            disabled={updateTags.isPending || !hasChanges()}
          >
            {updateTags.isPending ? (
              <>
                <Loader2 className="h-4 w-4 animate-spin mr-2" />
                Saving...
              </>
            ) : (
              <>
                <Check className="h-4 w-4 mr-2" />
                Save Changes
              </>
            )}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
