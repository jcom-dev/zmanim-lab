'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Card, CardContent, CardHeader } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { HighlightedFormula } from '@/components/shared/HighlightedFormula';
import {
  PublisherZman,
  useUpdateZman,
  useDeleteZman,
  useZmanVersionHistory,
  useRollbackZmanVersion,
  ZmanVersion,
} from '@/lib/hooks/useZmanimList';
import {
  Pencil,
  Trash2,
  Globe,
  CircleDashed,
  History,
  RotateCcw,
  Loader2,
  Eye,
  EyeOff,
  Link2,
  Copy,
  Library,
  AlertTriangle,
} from 'lucide-react';
import { Switch } from '@/components/ui/switch';
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
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { ScrollArea } from '@/components/ui/scroll-area';

// Infer tags from the formula DSL (same logic as Registry page)
interface InferredTags {
  shita?: string;
  method?: string;
  relative?: string; // e.g., "before sunset", "after sunrise"
  baseTime?: string; // the base astronomical event
}

function inferTagsFromFormula(formula: string): InferredTags {
  const result: InferredTags = {};

  // Check for shita
  if (formula.includes('gra') || formula.includes(', gra)')) {
    result.shita = 'GRA';
  } else if (formula.includes('mga') || formula.includes(', mga)')) {
    result.shita = 'MGA';
  } else if (formula.includes('alos_16_1')) {
    result.shita = '16.1°';
  }

  // Check for calculation method
  if (formula.includes('proportional_hours(')) {
    result.method = 'Proportional Hours';
  } else if (formula.includes('solar(')) {
    result.method = 'Solar Angle';
  } else if (/\d+\s*min/.test(formula)) {
    result.method = 'Fixed Minutes';
  }

  // Detect base time and before/after
  const baseTimePatterns = [
    { pattern: /sunset/i, name: 'sunset' },
    { pattern: /sunrise/i, name: 'sunrise' },
    { pattern: /chatzos/i, name: 'chatzos' },
    { pattern: /tzais/i, name: 'tzais' },
    { pattern: /alos/i, name: 'alos' },
  ];

  for (const { pattern, name } of baseTimePatterns) {
    if (pattern.test(formula)) {
      result.baseTime = name;
      // Check if before (-) or after (+)
      if (formula.includes('-') && /\d+\s*min/.test(formula)) {
        result.relative = `before ${name}`;
      } else if (formula.includes('+') && /\d+\s*min/.test(formula)) {
        result.relative = `after ${name}`;
      }
      break;
    }
  }

  return result;
}

// Event tags for event zmanim - maps zman_key to applicable events
// Using design tokens: primary for Shabbos/YT, destructive for fasts, muted for others
const EVENT_ZMAN_TAGS: Record<string, string[]> = {
  // Candle lighting - Shabbos & Yom Tov
  candle_lighting: ['Shabbos', 'Yom Tov'],
  candle_lighting_18: ['Shabbos', 'Yom Tov'],
  candle_lighting_20: ['Shabbos', 'Yom Tov'],
  candle_lighting_22: ['Shabbos', 'Yom Tov'],
  candle_lighting_40: ['Shabbos', 'Yom Tov'],
  // Havdalah / Shabbos ends - Shabbos & Yom Tov
  shabbos_ends: ['Shabbos', 'Yom Tov'],
  havdalah: ['Shabbos', 'Yom Tov'],
  havdalah_42: ['Shabbos', 'Yom Tov'],
  havdalah_50: ['Shabbos', 'Yom Tov'],
  havdalah_72: ['Shabbos', 'Yom Tov'],
  // Yom Kippur
  yom_kippur_starts: ['Yom Kippur'],
  yom_kippur_ends: ['Yom Kippur'],
  // Fast days
  fast_begins: ['Fast Day'],
  fast_ends: ['Fast Day'],
  fast_ends_42: ['Fast Day'],
  fast_ends_50: ['Fast Day'],
  // Tisha B'Av
  tisha_bav_starts: ["Tisha B'Av"],
  tisha_bav_ends: ["Tisha B'Av"],
  // Pesach
  sof_zman_achilas_chametz_gra: ['Erev Pesach'],
  sof_zman_achilas_chametz_mga: ['Erev Pesach'],
  sof_zman_biur_chametz_gra: ['Erev Pesach'],
  sof_zman_biur_chametz_mga: ['Erev Pesach'],
};

// Get badge variant based on event type - uses design tokens
function getEventBadgeVariant(event: string): 'default' | 'secondary' | 'outline' | 'destructive' {
  switch (event) {
    case 'Shabbos':
    case 'Yom Tov':
      return 'default'; // primary color
    case 'Yom Kippur':
    case "Tisha B'Av":
    case 'Fast Day':
      return 'secondary'; // muted for solemn occasions
    case 'Erev Pesach':
      return 'outline'; // neutral
    default:
      return 'outline';
  }
}

interface ZmanCardProps {
  zman: PublisherZman;
  category: 'essential' | 'optional';
  onEdit?: (zmanKey: string) => void;
  displayLanguage?: 'hebrew' | 'english' | 'both';
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
export function ZmanCard({ zman, category, onEdit, displayLanguage = 'both' }: ZmanCardProps) {
  const router = useRouter();
  const [showDeleteDialog, setShowDeleteDialog] = useState(false);
  const [showHistoryDialog, setShowHistoryDialog] = useState(false);
  const [selectedVersion, setSelectedVersion] = useState<ZmanVersion | null>(null);

  const updateZman = useUpdateZman(zman.zman_key);
  const deleteZman = useDeleteZman();
  const { data: versionHistory, isLoading: historyLoading } = useZmanVersionHistory(
    showHistoryDialog ? zman.zman_key : null
  );
  const rollbackVersion = useRollbackZmanVersion(zman.zman_key);

  const handleEdit = () => {
    if (onEdit) {
      onEdit(zman.zman_key);
    } else {
      router.push(`/publisher/algorithm/edit/${zman.zman_key}`);
    }
  };

  const handleTogglePublished = async () => {
    await updateZman.mutateAsync({
      is_published: !zman.is_published,
    });
  };

  const handleToggleCategory = async () => {
    const newCategory = zman.category === 'essential' ? 'optional' : 'essential';
    console.log('[ZmanCard] Toggling category from', zman.category, 'to', newCategory, 'for', zman.zman_key);
    try {
      const result = await updateZman.mutateAsync({
        category: newCategory,
      });
      console.log('[ZmanCard] Update result:', result);
    } catch (error: unknown) {
      console.error('[ZmanCard] Update error:', error);
      // Log more details about the error
      if (error && typeof error === 'object') {
        const e = error as { status?: number; message?: string; data?: unknown };
        console.error('[ZmanCard] Error details - status:', e.status, 'message:', e.message, 'data:', e.data);
      }
    }
  };

  const handleToggleEnabled = async () => {
    await updateZman.mutateAsync({
      is_enabled: !zman.is_enabled,
    });
  };

  const handleToggleVisible = async () => {
    await updateZman.mutateAsync({
      is_visible: !zman.is_visible,
    });
  };

  const handleDelete = async () => {
    await deleteZman.mutateAsync(zman.zman_key);
    setShowDeleteDialog(false);
  };

  const handleRollback = async (version: ZmanVersion) => {
    await rollbackVersion.mutateAsync({ version_number: version.version_number });
    setShowHistoryDialog(false);
    setSelectedVersion(null);
  };

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  // Use zman.category for actual state (not the prop which is for grid styling)
  const isEssential = zman.category === 'essential';
  const isOptional = zman.category === 'optional';

  return (
    <>
      <Card
        className={`
          hover:border-primary/50 transition-colors group
          ${!zman.is_enabled ? 'opacity-60' : ''}
          ${!zman.is_visible ? 'border-dashed border-muted-foreground/30' : ''}
        `}
      >
        <CardHeader className="pb-3">
          {/* Mobile: Actions on top, then title | Desktop: Title left, actions right */}
          <div className="flex flex-col-reverse sm:flex-row sm:items-start sm:justify-between gap-2 sm:gap-4">
            {/* Left: Name and Dependencies */}
            <div className="flex-1 min-w-0">
              {/* Name - respects displayLanguage setting */}
              <h3 className={`text-base sm:text-lg font-semibold leading-tight mb-2 ${displayLanguage === 'hebrew' ? 'font-hebrew' : ''}`}>
                {displayLanguage === 'hebrew' ? (
                  <span className="text-foreground">{zman.hebrew_name}</span>
                ) : displayLanguage === 'english' ? (
                  <span className="text-foreground">{zman.english_name}</span>
                ) : (
                  <>
                    <span className="text-foreground block sm:inline font-hebrew">{zman.hebrew_name}</span>
                    <span className="text-muted-foreground mx-0 sm:mx-2 hidden sm:inline">•</span>
                    <span className="text-foreground block sm:inline">{zman.english_name}</span>
                  </>
                )}
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

              {/* Status Toggles */}
              <div className="flex flex-wrap items-center gap-2 sm:gap-4 mt-3">
                {/* Enabled/Disabled Toggle */}
                <div className="flex items-center gap-2">
                  <span className={`text-xs ${!zman.is_enabled ? 'text-muted-foreground' : 'font-medium text-foreground'}`}>
                    Enabled
                  </span>
                  <Switch
                    checked={zman.is_enabled}
                    onCheckedChange={handleToggleEnabled}
                    disabled={updateZman.isPending}
                  />
                </div>

                {/* Core/Optional Flag - clickable badge */}
                <Badge
                  variant={isEssential ? 'default' : 'outline'}
                  className={`cursor-pointer transition-colors select-none ${
                    isEssential
                      ? 'bg-primary hover:bg-primary/80'
                      : 'hover:bg-muted'
                  } ${updateZman.isPending ? 'opacity-50 pointer-events-none' : ''}`}
                  onClick={handleToggleCategory}
                  title={isEssential ? 'Click to mark as optional' : 'Click to mark as core'}
                >
                  {isEssential ? 'Core' : 'Optional'}
                </Badge>

                {/* Published Status Badge */}
                {zman.is_published ? (
                  <Badge className="text-xs bg-green-600 hover:bg-green-700">
                    Published
                  </Badge>
                ) : (
                  <Badge variant="outline" className="text-xs text-amber-600 border-amber-600">
                    Draft
                  </Badge>
                )}

                {/* Hidden Badge - when not visible to public */}
                {!zman.is_visible && (
                  <Badge variant="outline" className="text-xs text-muted-foreground border-muted-foreground/50">
                    <EyeOff className="h-3 w-3 mr-1" />
                    Hidden
                  </Badge>
                )}

                {/* Linked Status Badge - shows if zman is linked to another publisher */}
                {zman.is_linked && zman.linked_source_publisher_name && (
                  <Badge
                    variant="outline"
                    className={`text-xs ${
                      zman.linked_source_is_deleted
                        ? 'bg-amber-100 text-amber-800 border-amber-300 dark:bg-amber-900/30 dark:text-amber-200 dark:border-amber-700'
                        : 'bg-green-100 text-green-800 border-green-300 dark:bg-green-900/30 dark:text-green-200 dark:border-green-700'
                    }`}
                    title={
                      zman.linked_source_is_deleted
                        ? `Linked to ${zman.linked_source_publisher_name} (deleted)`
                        : `Linked to ${zman.linked_source_publisher_name}`
                    }
                  >
                    {zman.linked_source_is_deleted ? (
                      <AlertTriangle className="h-3 w-3 mr-1" />
                    ) : (
                      <Link2 className="h-3 w-3 mr-1" />
                    )}
                    {zman.linked_source_publisher_name}
                  </Badge>
                )}

                {/* Source Type Badge - shows how the zman was added */}
                {zman.source_type && zman.source_type !== 'custom' && !zman.is_linked && (
                  <Badge
                    variant="outline"
                    className={`text-xs ${
                      zman.source_type === 'registry'
                        ? 'bg-blue-100 text-blue-800 border-blue-300 dark:bg-blue-900/30 dark:text-blue-200 dark:border-blue-700'
                        : 'bg-amber-100 text-amber-800 border-amber-300 dark:bg-amber-900/30 dark:text-amber-200 dark:border-amber-700'
                    }`}
                  >
                    {zman.source_type === 'registry' ? (
                      <>
                        <Library className="h-3 w-3 mr-1" />
                        Registry
                      </>
                    ) : zman.source_type === 'copied' ? (
                      <>
                        <Copy className="h-3 w-3 mr-1" />
                        Copied
                      </>
                    ) : null}
                  </Badge>
                )}
              </div>

              {/* Event Tags - Show which events this zman applies to */}
              {EVENT_ZMAN_TAGS[zman.zman_key] && (
                <div className="flex flex-wrap gap-1.5 mt-2">
                  {EVENT_ZMAN_TAGS[zman.zman_key].map((event) => (
                    <Badge
                      key={event}
                      variant={getEventBadgeVariant(event)}
                      className="text-xs"
                    >
                      {event}
                    </Badge>
                  ))}
                </div>
              )}
            </div>

            {/* Right: Quick Actions - top row centered on mobile, right side on desktop */}
            <div className="flex justify-center sm:justify-end gap-0.5 sm:gap-1 flex-shrink-0 w-full sm:w-auto">
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

              {/* Toggle Published - shows globe icon */}
              <Button
                variant="ghost"
                size="icon"
                onClick={handleTogglePublished}
                title={zman.is_published ? 'Unpublish zman' : 'Publish zman'}
                className={`h-8 w-8 ${zman.is_published ? 'text-green-600 hover:text-green-700' : 'text-amber-600 hover:text-amber-700'}`}
                disabled={updateZman.isPending}
              >
                {zman.is_published ? (
                  <Globe className="h-4 w-4" />
                ) : (
                  <CircleDashed className="h-4 w-4" />
                )}
              </Button>

              {/* Toggle Visibility - hide from public display */}
              <Button
                variant="ghost"
                size="icon"
                onClick={handleToggleVisible}
                title={zman.is_visible ? 'Hide from public display' : 'Show in public display'}
                className={`h-8 w-8 ${zman.is_visible ? 'text-foreground' : 'text-muted-foreground'}`}
                disabled={updateZman.isPending}
              >
                {zman.is_visible ? (
                  <Eye className="h-4 w-4" />
                ) : (
                  <EyeOff className="h-4 w-4" />
                )}
              </Button>

              {/* Version History */}
              <Button
                variant="ghost"
                size="icon"
                onClick={() => setShowHistoryDialog(true)}
                title="View version history"
                className="h-8 w-8"
              >
                <History className="h-4 w-4" />
              </Button>

              {/* Delete (only for disabled zmanim) */}
              {!zman.is_enabled && (
                <Button
                  variant="ghost"
                  size="icon"
                  onClick={() => setShowDeleteDialog(true)}
                  title="Delete zman"
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

          {/* Database Tags from Master Zman */}
          {zman.tags && zman.tags.length > 0 && (
            <div className="flex flex-wrap items-center gap-1.5 mt-2">
              {zman.tags.map((tag) => {
                const colorClass = tag.tag_type === 'event'
                  ? 'bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-200 border-blue-300 dark:border-blue-700'
                  : tag.tag_type === 'timing'
                  ? 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-200 border-green-300 dark:border-green-700'
                  : 'bg-purple-100 text-purple-800 dark:bg-purple-900/30 dark:text-purple-200 border-purple-300 dark:border-purple-700';

                return (
                  <Badge key={tag.id} variant="outline" className={`text-xs ${colorClass}`}>
                    {tag.display_name_english}
                  </Badge>
                );
              })}
            </div>
          )}

          {/* Inferred Tags from Formula */}
          {(() => {
            const inferredTags = inferTagsFromFormula(zman.formula_dsl);
            const hasTags = inferredTags.shita || inferredTags.method || inferredTags.relative;
            if (!hasTags) return null;
            return (
              <div className="flex flex-wrap items-center gap-1.5 mt-2">
                {inferredTags.shita && (
                  <Badge variant="outline" className="text-xs bg-cyan-100 text-cyan-800 dark:bg-cyan-900/30 dark:text-cyan-200 border-cyan-300 dark:border-cyan-700">
                    {inferredTags.shita}
                  </Badge>
                )}
                {inferredTags.method && (
                  <Badge variant="outline" className="text-xs bg-violet-100 text-violet-800 dark:bg-violet-900/30 dark:text-violet-200 border-violet-300 dark:border-violet-700">
                    {inferredTags.method}
                  </Badge>
                )}
                {inferredTags.relative && (
                  <Badge variant="outline" className="text-xs bg-pink-100 text-pink-800 dark:bg-pink-900/30 dark:text-pink-200 border-pink-300 dark:border-pink-700">
                    {inferredTags.relative}
                  </Badge>
                )}
              </div>
            );
          })()}

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
            <AlertDialogTitle>Delete Zman?</AlertDialogTitle>
            <AlertDialogDescription>
              Are you sure you want to delete <strong>{zman.english_name}</strong>?
              You can restore it later from the Deleted tab.
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

      {/* Version History Dialog */}
      <Dialog open={showHistoryDialog} onOpenChange={setShowHistoryDialog}>
        <DialogContent className="max-w-2xl">
          <DialogHeader>
            <DialogTitle>Version History</DialogTitle>
            <DialogDescription>
              {zman.hebrew_name} • {zman.english_name}
            </DialogDescription>
          </DialogHeader>

          {historyLoading ? (
            <div className="flex justify-center py-8">
              <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
            </div>
          ) : versionHistory?.versions && versionHistory.versions.length > 0 ? (
            <ScrollArea className="max-h-[400px]">
              <div className="space-y-3">
                {versionHistory.versions.map((version) => (
                  <div
                    key={version.id}
                    className={`
                      p-4 rounded-lg border
                      ${version.version_number === versionHistory.current_version
                        ? 'border-primary bg-primary/5'
                        : 'border-border hover:border-muted-foreground/50'}
                    `}
                  >
                    <div className="flex items-center justify-between mb-2">
                      <div className="flex items-center gap-2">
                        <Badge
                          variant={version.version_number === versionHistory.current_version ? 'default' : 'outline'}
                        >
                          v{version.version_number}
                        </Badge>
                        {version.version_number === versionHistory.current_version && (
                          <span className="text-xs text-primary font-medium">Current</span>
                        )}
                      </div>
                      <span className="text-xs text-muted-foreground">
                        {formatDate(version.created_at)}
                      </span>
                    </div>

                    <div className="text-sm font-mono bg-muted p-2 rounded mb-2 overflow-x-auto">
                      <code className="text-xs">{version.formula_dsl}</code>
                    </div>

                    {version.version_number !== versionHistory.current_version && (
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => handleRollback(version)}
                        disabled={rollbackVersion.isPending}
                        className="mt-2"
                      >
                        {rollbackVersion.isPending ? (
                          <Loader2 className="h-3 w-3 animate-spin mr-1" />
                        ) : (
                          <RotateCcw className="h-3 w-3 mr-1" />
                        )}
                        Restore this version
                      </Button>
                    )}
                  </div>
                ))}
              </div>
            </ScrollArea>
          ) : (
            <div className="text-center py-8 text-muted-foreground">
              <History className="h-12 w-12 mx-auto mb-3 opacity-50" />
              <p>No version history available</p>
              <p className="text-xs mt-1">Changes to the formula will be tracked here</p>
            </div>
          )}
        </DialogContent>
      </Dialog>
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
  displayLanguage = 'both',
}: {
  zmanim: PublisherZman[];
  category: 'essential' | 'optional';
  onEdit?: (zmanKey: string) => void;
  displayLanguage?: 'hebrew' | 'english' | 'both';
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
        <ZmanCard key={zman.id} zman={zman} category={category} onEdit={onEdit} displayLanguage={displayLanguage} />
      ))}
    </div>
  );
}
