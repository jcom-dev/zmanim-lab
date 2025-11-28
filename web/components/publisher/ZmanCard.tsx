'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Card, CardContent, CardHeader } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { HighlightedFormula } from '@/components/shared/HighlightedFormula';
import { PublisherZman, useUpdateZman, useDeleteZman } from '@/lib/hooks/useZmanimList';
import { Pencil, Eye, EyeOff, Trash2, GripVertical } from 'lucide-react';
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

interface ZmanCardProps {
  zman: PublisherZman;
  category: 'essential' | 'optional' | 'custom';
  onEdit?: (zmanKey: string) => void;
}

/**
 * ZmanCard - Displays a single zman with quick actions
 *
 * Features:
 * - Bilingual name display (Hebrew • English)
 * - Syntax-highlighted formula
 * - Dependency badges
 * - Quick action buttons (Edit, Toggle Visibility, Delete)
 * - Drag handle for reordering
 */
export function ZmanCard({ zman, category, onEdit }: ZmanCardProps) {
  const router = useRouter();
  const [showDeleteDialog, setShowDeleteDialog] = useState(false);

  const updateZman = useUpdateZman(zman.zman_key);
  const deleteZman = useDeleteZman();

  const handleEdit = () => {
    if (onEdit) {
      onEdit(zman.zman_key);
    } else {
      router.push(`/publisher/algorithm/edit/${zman.zman_key}`);
    }
  };

  const handleToggleVisibility = async () => {
    if (category === 'essential') return; // Can't toggle essential zmanim

    await updateZman.mutateAsync({
      is_visible: !zman.is_visible,
    });
  };

  const handleDelete = async () => {
    if (category !== 'custom') return; // Can only delete custom zmanim

    await deleteZman.mutateAsync(zman.zman_key);
    setShowDeleteDialog(false);
  };

  const isEssential = category === 'essential';
  const isCustom = category === 'custom';

  return (
    <>
      <Card
        className={`
          hover:border-primary/50 transition-colors group
          ${!zman.is_enabled || !zman.is_visible ? 'opacity-60' : ''}
        `}
      >
        <CardHeader className="pb-3">
          <div className="flex items-start justify-between gap-4">
            {/* Left: Name and Dependencies */}
            <div className="flex-1 min-w-0">
              {/* Drag Handle (for custom zmanim) */}
              {isCustom && (
                <div className="float-left mr-2 mt-1 opacity-0 group-hover:opacity-100 transition-opacity cursor-grab active:cursor-grabbing">
                  <GripVertical className="h-5 w-5 text-muted-foreground" />
                </div>
              )}

              {/* Name */}
              <h3 className="text-lg font-semibold leading-tight mb-2">
                <span className="text-foreground">{zman.hebrew_name}</span>
                <span className="text-muted-foreground mx-2">•</span>
                <span className="text-foreground">{zman.english_name}</span>
              </h3>

              {/* Dependencies */}
              {zman.dependencies && zman.dependencies.length > 0 && (
                <div className="flex flex-wrap gap-1.5 mt-2">
                  {zman.dependencies.map((dep) => (
                    <Badge key={dep} variant="outline" className="text-xs font-mono">
                      @{dep}
                    </Badge>
                  ))}
                </div>
              )}

              {/* Status Indicators */}
              <div className="flex gap-2 mt-2">
                {isEssential && (
                  <Badge variant="secondary" className="text-xs">
                    Essential
                  </Badge>
                )}
                {isCustom && (
                  <Badge variant="default" className="text-xs">
                    Custom
                  </Badge>
                )}
                {!zman.is_enabled && (
                  <Badge variant="destructive" className="text-xs">
                    Disabled
                  </Badge>
                )}
                {!zman.is_visible && (
                  <Badge variant="outline" className="text-xs">
                    Hidden
                  </Badge>
                )}
              </div>
            </div>

            {/* Right: Quick Actions */}
            <div className="flex gap-1 flex-shrink-0">
              {/* Edit Button */}
              <Button
                variant="ghost"
                size="icon"
                onClick={handleEdit}
                title="Edit formula"
                className="h-8 w-8"
              >
                <Pencil className="h-4 w-4" />
              </Button>

              {/* Toggle Visibility (not for essential) */}
              {!isEssential && (
                <Button
                  variant="ghost"
                  size="icon"
                  onClick={handleToggleVisibility}
                  title={zman.is_visible ? 'Hide zman' : 'Show zman'}
                  className="h-8 w-8"
                  disabled={updateZman.isPending}
                >
                  {zman.is_visible ? (
                    <Eye className="h-4 w-4" />
                  ) : (
                    <EyeOff className="h-4 w-4 opacity-50" />
                  )}
                </Button>
              )}

              {/* Delete (custom only) */}
              {isCustom && (
                <Button
                  variant="ghost"
                  size="icon"
                  onClick={() => setShowDeleteDialog(true)}
                  title="Delete custom zman"
                  className="h-8 w-8 text-destructive hover:text-destructive"
                >
                  <Trash2 className="h-4 w-4" />
                </Button>
              )}
            </div>
          </div>
        </CardHeader>

        <CardContent className="pt-0">
          {/* Formula Display */}
          <HighlightedFormula formula={zman.formula_dsl} />

          {/* AI Explanation (if exists) */}
          {zman.ai_explanation && (
            <div className="mt-3 p-3 bg-primary/5 rounded-md border border-primary/10">
              <p className="text-sm text-muted-foreground leading-relaxed">
                <span className="font-medium text-primary">AI:</span> {zman.ai_explanation}
              </p>
            </div>
          )}

          {/* Publisher Comment (if exists) */}
          {zman.publisher_comment && (
            <div className="mt-2 p-3 bg-muted/50 rounded-md">
              <p className="text-sm text-foreground leading-relaxed">
                {zman.publisher_comment}
              </p>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Delete Confirmation Dialog */}
      <AlertDialog open={showDeleteDialog} onOpenChange={setShowDeleteDialog}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete Custom Zman?</AlertDialogTitle>
            <AlertDialogDescription>
              Are you sure you want to delete <strong>{zman.english_name}</strong>?
              This action cannot be undone.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction
              onClick={handleDelete}
              className="bg-destructive hover:bg-destructive/90"
            >
              Delete
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
}

/**
 * ZmanGrid - Grid layout for displaying multiple zman cards
 */
export function ZmanGrid({
  zmanim,
  category,
  onEdit,
}: {
  zmanim: PublisherZman[];
  category: 'essential' | 'optional' | 'custom';
  onEdit?: (zmanKey: string) => void;
}) {
  if (zmanim.length === 0) {
    return (
      <div className="text-center py-8 text-muted-foreground">
        <p>No zmanim in this category</p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {zmanim.map((zman) => (
        <ZmanCard key={zman.id} zman={zman} category={category} onEdit={onEdit} />
      ))}
    </div>
  );
}
