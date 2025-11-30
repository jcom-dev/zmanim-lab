'use client';

import { useState, useEffect, useCallback } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Switch } from '@/components/ui/switch';
import { Checkbox } from '@/components/ui/checkbox';
import { Badge } from '@/components/ui/badge';
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
import { useAdminApi } from '@/lib/api-client';
import {
  Clock,
  Plus,
  Pencil,
  Trash2,
  Eye,
  EyeOff,
  Search,
  Loader2,
  AlertTriangle,
} from 'lucide-react';

interface ZmanTag {
  id: string;
  name: string;
  display_name_hebrew: string;
  display_name_english: string;
  tag_type: string;
  color?: string;
}

interface DayType {
  id: string;
  name: string;
  display_name_hebrew: string;
  display_name_english: string;
  description?: string;
  parent_type?: string;
  sort_order: number;
}

interface MasterZman {
  id: string;
  zman_key: string;
  canonical_hebrew_name: string;
  canonical_english_name: string;
  transliteration?: string;
  description?: string;
  halachic_notes?: string;
  halachic_source?: string;
  time_category: string;
  event_category?: string;
  display_offset?: string; // day_before, day_of, day_after
  default_formula_dsl: string;
  is_core: boolean;
  is_hidden: boolean;
  sort_order: number;
  created_at: string;
  updated_at: string;
  tags?: ZmanTag[];
  tag_ids?: string[]; // IDs of associated tags
  day_types?: string[]; // Day type names this zman applies to
}

interface TimeCategory {
  key: string;
  display_name: string;
}

const TIME_CATEGORIES: TimeCategory[] = [
  { key: 'dawn', display_name: 'Dawn' },
  { key: 'sunrise', display_name: 'Sunrise' },
  { key: 'morning', display_name: 'Morning' },
  { key: 'midday', display_name: 'Midday' },
  { key: 'afternoon', display_name: 'Afternoon' },
  { key: 'sunset', display_name: 'Sunset' },
  { key: 'nightfall', display_name: 'Nightfall' },
  { key: 'midnight', display_name: 'Midnight' },
];

// Event categories for what occasion/event a zman applies to
const EVENT_CATEGORIES = [
  { key: 'none', display_name: 'None (Daily)' },
  { key: 'erev_shabbos', display_name: 'Erev Shabbos' },
  { key: 'motzei_shabbos', display_name: 'Motzei Shabbos' },
  { key: 'erev_yom_tov', display_name: 'Erev Yom Tov' },
  { key: 'motzei_yom_tov', display_name: 'Motzei Yom Tov' },
  { key: 'taanis', display_name: 'Fast Day' },
  { key: 'erev_pesach', display_name: 'Erev Pesach' },
];

// Display offset - when to show this zman relative to the event
const DISPLAY_OFFSETS = [
  { key: 'day_of', display_name: 'Day Of (Default)' },
  { key: 'day_before', display_name: 'Day Before' },
  { key: 'day_after', display_name: 'Day After' },
];

const categoryColors: Record<string, string> = {
  dawn: 'bg-purple-100 text-purple-800 dark:bg-purple-900/30 dark:text-purple-200',
  sunrise: 'bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-200',
  morning: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-200',
  midday: 'bg-orange-100 text-orange-800 dark:bg-orange-900/30 dark:text-orange-200',
  afternoon: 'bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-200',
  sunset: 'bg-rose-100 text-rose-800 dark:bg-rose-900/30 dark:text-rose-200',
  nightfall: 'bg-indigo-100 text-indigo-800 dark:bg-indigo-900/30 dark:text-indigo-200',
  midnight: 'bg-slate-100 text-slate-800 dark:bg-slate-900/30 dark:text-slate-200',
};

// Infer tags from the formula DSL
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
  if (formula.includes('shaos(')) {
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

// Infer event type from zman key
function inferEventFromKey(key: string): string | null {
  if (key.includes('candle_lighting')) return 'Erev Shabbos/YT';
  if (key.includes('shabbos_ends') || key.includes('motzei')) return 'Motzei Shabbos';
  if (key.includes('fast_ends') || key.includes('taanis')) return 'Fast Day';
  if (key.includes('chametz') || key.includes('pesach')) return 'Erev Pesach';
  return null;
}

export default function AdminRegistryPage() {
  const api = useAdminApi();
  const [zmanim, setZmanim] = useState<MasterZman[]>([]);
  const [allTags, setAllTags] = useState<ZmanTag[]>([]);
  const [allDayTypes, setAllDayTypes] = useState<DayType[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [categoryFilter, setCategoryFilter] = useState<string>('all');
  const [shitaFilter, setShitaFilter] = useState<string>('all');
  const [eventFilter, setEventFilter] = useState<string>('all');
  const [showHidden, setShowHidden] = useState(true);
  const [showCoreOnly, setShowCoreOnly] = useState(false);

  // Dialog state
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [isDeleteDialogOpen, setIsDeleteDialogOpen] = useState(false);
  const [editingZman, setEditingZman] = useState<MasterZman | null>(null);
  const [deletingZman, setDeletingZman] = useState<MasterZman | null>(null);
  const [isSaving, setIsSaving] = useState(false);

  // Form state
  const [formData, setFormData] = useState({
    zman_key: '',
    canonical_hebrew_name: '',
    canonical_english_name: '',
    transliteration: '',
    description: '',
    halachic_notes: '',
    halachic_source: '',
    time_category: 'sunrise',
    event_category: '',
    display_offset: 'day_of',
    default_formula_dsl: '',
    is_core: false,
    is_hidden: false,
    sort_order: 0,
    tag_ids: [] as string[],
  });

  const fetchZmanim = useCallback(async () => {
    try {
      setLoading(true);
      const params = new URLSearchParams();
      params.set('include_hidden', showHidden ? 'true' : 'false');
      if (categoryFilter !== 'all') {
        params.set('category', categoryFilter);
      }
      const data = await api.get<MasterZman[]>(`/admin/registry/zmanim?${params}`);
      setZmanim(data || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch zmanim');
    } finally {
      setLoading(false);
    }
  }, [api, showHidden, categoryFilter]);

  const fetchTags = useCallback(async () => {
    try {
      const data = await api.get<ZmanTag[]>('/admin/registry/tags');
      setAllTags(data || []);
    } catch (err) {
      console.error('Failed to fetch tags:', err);
    }
  }, [api]);

  const fetchDayTypes = useCallback(async () => {
    try {
      const data = await api.get<DayType[]>('/admin/registry/day-types');
      setAllDayTypes(data || []);
    } catch (err) {
      console.error('Failed to fetch day types:', err);
    }
  }, [api]);

  useEffect(() => {
    fetchZmanim();
    fetchTags();
    fetchDayTypes();
  }, [fetchZmanim, fetchTags, fetchDayTypes]);

  const filteredZmanim = zmanim.filter((z) => {
    // Search filter
    if (searchTerm) {
      const search = searchTerm.toLowerCase();
      const matchesSearch = (
        z.zman_key.toLowerCase().includes(search) ||
        z.canonical_hebrew_name.toLowerCase().includes(search) ||
        z.canonical_english_name.toLowerCase().includes(search) ||
        z.transliteration?.toLowerCase().includes(search) ||
        z.default_formula_dsl.toLowerCase().includes(search)
      );
      if (!matchesSearch) return false;
    }

    // Category filter (already applied server-side, but double-check)
    if (categoryFilter !== 'all' && z.time_category !== categoryFilter) {
      return false;
    }

    // Shita filter (inferred from formula)
    if (shitaFilter !== 'all') {
      const inferredTags = inferTagsFromFormula(z.default_formula_dsl);
      if (shitaFilter === 'gra' && inferredTags.shita !== 'GRA') return false;
      if (shitaFilter === 'mga' && inferredTags.shita !== 'MGA') return false;
      if (shitaFilter === 'no_shita' && inferredTags.shita) return false;
    }

    // Event filter (inferred from key or event_category)
    if (eventFilter !== 'all') {
      const inferredEvent = inferEventFromKey(z.zman_key);
      const hasEvent = z.event_category || inferredEvent;
      if (eventFilter === 'shabbos' && !z.zman_key.includes('shabbos') && !z.zman_key.includes('candle')) return false;
      if (eventFilter === 'fast' && !z.zman_key.includes('fast') && !z.zman_key.includes('taanis')) return false;
      if (eventFilter === 'pesach' && !z.zman_key.includes('chametz') && !z.zman_key.includes('pesach')) return false;
      if (eventFilter === 'daily' && hasEvent) return false;
    }

    // Core filter
    if (showCoreOnly && !z.is_core) {
      return false;
    }

    return true;
  });

  const resetForm = () => {
    setFormData({
      zman_key: '',
      canonical_hebrew_name: '',
      canonical_english_name: '',
      transliteration: '',
      description: '',
      halachic_notes: '',
      halachic_source: '',
      time_category: 'sunrise',
      event_category: '',
      display_offset: 'day_of',
      default_formula_dsl: '',
      is_core: false,
      is_hidden: false,
      sort_order: 0,
      tag_ids: [],
    });
  };

  const openCreateDialog = () => {
    resetForm();
    setEditingZman(null);
    setIsDialogOpen(true);
  };

  const openEditDialog = (zman: MasterZman) => {
    setEditingZman(zman);
    setFormData({
      zman_key: zman.zman_key,
      canonical_hebrew_name: zman.canonical_hebrew_name,
      canonical_english_name: zman.canonical_english_name,
      transliteration: zman.transliteration || '',
      description: zman.description || '',
      halachic_notes: zman.halachic_notes || '',
      halachic_source: zman.halachic_source || '',
      time_category: zman.time_category,
      event_category: zman.event_category || '',
      display_offset: zman.display_offset || 'day_of',
      default_formula_dsl: zman.default_formula_dsl,
      is_core: zman.is_core,
      is_hidden: zman.is_hidden,
      sort_order: zman.sort_order,
      tag_ids: zman.tag_ids || (zman.tags?.map(t => t.id) || []),
    });
    setIsDialogOpen(true);
  };

  const handleSave = async () => {
    try {
      setIsSaving(true);
      const payload = {
        canonical_hebrew_name: formData.canonical_hebrew_name,
        canonical_english_name: formData.canonical_english_name,
        transliteration: formData.transliteration || null,
        description: formData.description || null,
        halachic_notes: formData.halachic_notes || null,
        halachic_source: formData.halachic_source || null,
        time_category: formData.time_category,
        event_category: formData.event_category || null,
        display_offset: formData.display_offset || 'day_of',
        default_formula_dsl: formData.default_formula_dsl,
        is_core: formData.is_core,
        is_hidden: formData.is_hidden,
        sort_order: formData.sort_order,
        tag_ids: formData.tag_ids,
      };

      if (editingZman) {
        // Update
        await api.put(`/admin/registry/zmanim/${editingZman.id}`, {
          body: JSON.stringify(payload),
        });
      } else {
        // Create - include zman_key
        await api.post('/admin/registry/zmanim', {
          body: JSON.stringify({ ...payload, zman_key: formData.zman_key }),
        });
      }
      setIsDialogOpen(false);
      fetchZmanim();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to save zman');
    } finally {
      setIsSaving(false);
    }
  };

  const handleDelete = async () => {
    if (!deletingZman) return;
    try {
      setIsSaving(true);
      await api.delete(`/admin/registry/zmanim/${deletingZman.id}`);
      setIsDeleteDialogOpen(false);
      setDeletingZman(null);
      fetchZmanim();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to delete zman');
    } finally {
      setIsSaving(false);
    }
  };

  const toggleVisibility = async (zman: MasterZman) => {
    try {
      await api.post(`/admin/registry/zmanim/${zman.id}/toggle-visibility`, {});
      fetchZmanim();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to toggle visibility');
    }
  };

  if (loading) {
    return (
      <div className="space-y-6">
        <div>
          <h1 className="text-3xl font-bold text-foreground">Zmanim Registry</h1>
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
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-foreground">Zmanim Registry</h1>
          <p className="text-muted-foreground mt-1">
            Manage the master zmanim registry. Publishers select zmanim from this canonical list.
          </p>
        </div>
        <Button onClick={openCreateDialog}>
          <Plus className="w-4 h-4 mr-2" />
          Add Zman
        </Button>
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
          <div className="flex flex-wrap items-center gap-4">
            <div className="flex items-center gap-2 flex-1 min-w-[200px]">
              <Search className="w-4 h-4 text-muted-foreground" />
              <Input
                placeholder="Search zmanim, formulas..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="flex-1"
              />
            </div>
            <div className="flex items-center gap-2">
              <Label className="text-sm text-muted-foreground whitespace-nowrap">Time:</Label>
              <Select value={categoryFilter} onValueChange={setCategoryFilter}>
                <SelectTrigger className="w-[130px]">
                  <SelectValue placeholder="All" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All Times</SelectItem>
                  {TIME_CATEGORIES.map((cat) => (
                    <SelectItem key={cat.key} value={cat.key}>
                      {cat.display_name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="flex items-center gap-2">
              <Label className="text-sm text-muted-foreground whitespace-nowrap">Shita:</Label>
              <Select value={shitaFilter} onValueChange={setShitaFilter}>
                <SelectTrigger className="w-[110px]">
                  <SelectValue placeholder="All" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All</SelectItem>
                  <SelectItem value="gra">GRA</SelectItem>
                  <SelectItem value="mga">MGA</SelectItem>
                  <SelectItem value="no_shita">None</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="flex items-center gap-2">
              <Label className="text-sm text-muted-foreground whitespace-nowrap">Event:</Label>
              <Select value={eventFilter} onValueChange={setEventFilter}>
                <SelectTrigger className="w-[130px]">
                  <SelectValue placeholder="All" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All Events</SelectItem>
                  <SelectItem value="daily">Daily Only</SelectItem>
                  <SelectItem value="shabbos">Shabbos</SelectItem>
                  <SelectItem value="fast">Fast Days</SelectItem>
                  <SelectItem value="pesach">Pesach</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="flex items-center gap-2">
              <Switch
                id="show-core"
                checked={showCoreOnly}
                onCheckedChange={setShowCoreOnly}
              />
              <Label htmlFor="show-core" className="text-sm text-muted-foreground whitespace-nowrap">
                Core
              </Label>
            </div>
            <div className="flex items-center gap-2">
              <Switch
                id="show-hidden"
                checked={showHidden}
                onCheckedChange={setShowHidden}
              />
              <Label htmlFor="show-hidden" className="text-sm text-muted-foreground whitespace-nowrap">
                Show hidden
              </Label>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Card>
          <CardContent className="pt-6">
            <div className="text-2xl font-bold text-foreground">{zmanim.length}</div>
            <p className="text-sm text-muted-foreground">Total Zmanim</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-6">
            <div className="text-2xl font-bold text-foreground">
              {zmanim.filter((z) => z.is_core).length}
            </div>
            <p className="text-sm text-muted-foreground">Core</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-6">
            <div className="text-2xl font-bold text-foreground">
              {zmanim.filter((z) => z.is_hidden).length}
            </div>
            <p className="text-sm text-muted-foreground">Hidden</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-6">
            <div className="text-2xl font-bold text-foreground">{filteredZmanim.length}</div>
            <p className="text-sm text-muted-foreground">Filtered Results</p>
          </CardContent>
        </Card>
      </div>

      {/* Zmanim Table */}
      <Card>
        <CardHeader>
          <div className="flex items-center gap-3">
            <Clock className="w-5 h-5" />
            <div>
              <CardTitle>Master Zmanim</CardTitle>
              <CardDescription>
                {filteredZmanim.length} zmanim matching filters. Use <code className="text-xs bg-muted px-1 rounded">@zman_key</code> in DSL formulas.
              </CardDescription>
            </div>
          </div>
        </CardHeader>
        <CardContent>
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="border-b border-border">
                <tr className="text-left text-sm">
                  <th className="pb-3 font-semibold text-foreground">DSL Variable</th>
                  <th className="pb-3 font-semibold text-foreground">Name</th>
                  <th className="pb-3 font-semibold text-foreground">Formula &amp; Tags</th>
                  <th className="pb-3 font-semibold text-foreground text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {filteredZmanim.map((zman) => {
                  const inferredTags = inferTagsFromFormula(zman.default_formula_dsl);
                  const inferredEvent = inferEventFromKey(zman.zman_key);
                  return (
                  <tr
                    key={zman.id}
                    className={`border-b border-border hover:bg-accent/50 ${
                      zman.is_hidden ? 'opacity-60' : ''
                    }`}
                  >
                    <td className="py-3 pr-4">
                      <code className="px-2 py-1 bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-200 rounded text-sm font-mono font-semibold">
                        @{zman.zman_key}
                      </code>
                    </td>
                    <td className="py-3 pr-4">
                      <div className="flex flex-col gap-0.5">
                        <span className="text-foreground font-medium">{zman.canonical_english_name}</span>
                        <span className="text-foreground" dir="rtl">
                          {zman.canonical_hebrew_name}
                        </span>
                      </div>
                    </td>
                    <td className="py-3 pr-4">
                      <div className="flex flex-col gap-2">
                        <code className="px-2 py-1 bg-muted text-foreground rounded text-xs font-mono inline-block w-fit">
                          {zman.default_formula_dsl}
                        </code>
                        <div className="flex flex-wrap items-center gap-1">
                          {/* Time category */}
                          <span
                            className={`px-2 py-0.5 rounded text-xs font-medium ${
                              categoryColors[zman.time_category] || 'bg-muted text-foreground'
                            }`}
                          >
                            {zman.time_category}
                          </span>
                          {/* Inferred shita tag */}
                          {inferredTags.shita && (
                            <span className="px-2 py-0.5 bg-cyan-100 text-cyan-800 dark:bg-cyan-900/30 dark:text-cyan-200 rounded text-xs font-medium">
                              {inferredTags.shita}
                            </span>
                          )}
                          {/* Inferred method tag */}
                          {inferredTags.method && (
                            <span className="px-2 py-0.5 bg-violet-100 text-violet-800 dark:bg-violet-900/30 dark:text-violet-200 rounded text-xs">
                              {inferredTags.method}
                            </span>
                          )}
                          {/* Relative time (before/after) */}
                          {inferredTags.relative && (
                            <span className="px-2 py-0.5 bg-pink-100 text-pink-800 dark:bg-pink-900/30 dark:text-pink-200 rounded text-xs">
                              {inferredTags.relative}
                            </span>
                          )}
                          {/* Event/Day type (inferred or explicit) */}
                          {(inferredEvent || zman.event_category) && (
                            <span className="px-2 py-0.5 bg-teal-100 text-teal-800 dark:bg-teal-900/30 dark:text-teal-200 rounded text-xs font-medium">
                              {zman.event_category || inferredEvent}
                            </span>
                          )}
                          {/* Status tags */}
                          {zman.is_core && (
                            <span className="px-2 py-0.5 bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-200 rounded text-xs">
                              Core
                            </span>
                          )}
                          {zman.is_hidden && (
                            <span className="px-2 py-0.5 bg-muted text-muted-foreground rounded text-xs">
                              Hidden
                            </span>
                          )}
                        </div>
                      </div>
                    </td>
                    <td className="py-3 text-right">
                      <div className="flex items-center justify-end gap-1">
                        <Button
                          variant="ghost"
                          size="icon"
                          onClick={() => toggleVisibility(zman)}
                          title={zman.is_hidden ? 'Show' : 'Hide'}
                        >
                          {zman.is_hidden ? (
                            <Eye className="w-4 h-4" />
                          ) : (
                            <EyeOff className="w-4 h-4" />
                          )}
                        </Button>
                        <Button
                          variant="ghost"
                          size="icon"
                          onClick={() => openEditDialog(zman)}
                          title="Edit"
                        >
                          <Pencil className="w-4 h-4" />
                        </Button>
                        <Button
                          variant="ghost"
                          size="icon"
                          onClick={() => {
                            setDeletingZman(zman);
                            setIsDeleteDialogOpen(true);
                          }}
                          title="Delete"
                          className="text-destructive hover:text-destructive"
                        >
                          <Trash2 className="w-4 h-4" />
                        </Button>
                      </div>
                    </td>
                  </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>

      {/* Create/Edit Dialog */}
      <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
        <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>
              {editingZman ? 'Edit Zman' : 'Create New Zman'}
            </DialogTitle>
            <DialogDescription>
              {editingZman
                ? 'Update the zman details below.'
                : 'Fill in the details to add a new zman to the registry.'}
            </DialogDescription>
          </DialogHeader>

          <div className="grid gap-4 py-4">
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="zman_key">Zman Key *</Label>
                <Input
                  id="zman_key"
                  value={formData.zman_key}
                  onChange={(e) =>
                    setFormData({ ...formData, zman_key: e.target.value })
                  }
                  placeholder="e.g., candle_lighting_18"
                  disabled={!!editingZman}
                  className="font-mono"
                />
                {formData.zman_key && (
                  <p className="text-xs text-muted-foreground">
                    DSL Reference: <code className="px-1 bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-200 rounded">@{formData.zman_key}</code>
                  </p>
                )}
              </div>
              <div className="space-y-2">
                <Label htmlFor="time_category">Time Category *</Label>
                <Select
                  value={formData.time_category}
                  onValueChange={(v) =>
                    setFormData({ ...formData, time_category: v })
                  }
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

            <div className="space-y-2">
              <Label htmlFor="event_category">Event Category</Label>
              <Select
                value={formData.event_category || 'none'}
                onValueChange={(v) =>
                  setFormData({ ...formData, event_category: v === 'none' ? '' : v })
                }
              >
                <SelectTrigger>
                  <SelectValue placeholder="Select event..." />
                </SelectTrigger>
                <SelectContent>
                  {EVENT_CATEGORIES.map((cat) => (
                    <SelectItem key={cat.key} value={cat.key}>
                      {cat.display_name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <p className="text-xs text-muted-foreground">
                When this zman applies (e.g., only on Erev Shabbos for candle lighting)
              </p>
            </div>

            {formData.event_category && formData.event_category !== 'none' && (
              <div className="space-y-2">
                <Label htmlFor="display_offset">Display Offset</Label>
                <Select
                  value={formData.display_offset || 'day_of'}
                  onValueChange={(v) =>
                    setFormData({ ...formData, display_offset: v })
                  }
                >
                  <SelectTrigger>
                    <SelectValue placeholder="Select offset..." />
                  </SelectTrigger>
                  <SelectContent>
                    {DISPLAY_OFFSETS.map((offset) => (
                      <SelectItem key={offset.key} value={offset.key}>
                        {offset.display_name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                <p className="text-xs text-muted-foreground">
                  When to show this zman relative to the event (e.g., candle lighting shows day before)
                </p>
              </div>
            )}

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="canonical_hebrew_name">Hebrew Name *</Label>
                <Input
                  id="canonical_hebrew_name"
                  value={formData.canonical_hebrew_name}
                  onChange={(e) =>
                    setFormData({
                      ...formData,
                      canonical_hebrew_name: e.target.value,
                    })
                  }
                  placeholder="עלות השחר"
                  dir="rtl"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="canonical_english_name">English Name *</Label>
                <Input
                  id="canonical_english_name"
                  value={formData.canonical_english_name}
                  onChange={(e) =>
                    setFormData({
                      ...formData,
                      canonical_english_name: e.target.value,
                    })
                  }
                  placeholder="Dawn"
                />
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="transliteration">Transliteration</Label>
              <Input
                id="transliteration"
                value={formData.transliteration}
                onChange={(e) =>
                  setFormData({ ...formData, transliteration: e.target.value })
                }
                placeholder="Alos HaShachar"
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="default_formula_dsl">Default Formula (DSL) *</Label>
              <Input
                id="default_formula_dsl"
                value={formData.default_formula_dsl}
                onChange={(e) =>
                  setFormData({
                    ...formData,
                    default_formula_dsl: e.target.value,
                  })
                }
                placeholder="sunrise - 72m"
                className="font-mono"
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="description">Description</Label>
              <Textarea
                id="description"
                value={formData.description}
                onChange={(e) =>
                  setFormData({ ...formData, description: e.target.value })
                }
                placeholder="Brief description of this zman..."
                rows={2}
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="halachic_notes">Halachic Notes</Label>
              <Textarea
                id="halachic_notes"
                value={formData.halachic_notes}
                onChange={(e) =>
                  setFormData({ ...formData, halachic_notes: e.target.value })
                }
                placeholder="Relevant halachic information..."
                rows={2}
              />
            </div>

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
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="sort_order">Sort Order</Label>
                <Input
                  id="sort_order"
                  type="number"
                  value={formData.sort_order}
                  onChange={(e) =>
                    setFormData({
                      ...formData,
                      sort_order: parseInt(e.target.value) || 0,
                    })
                  }
                />
              </div>
            </div>

            {/* Tags Section */}
            {allTags.length > 0 && (
              <div className="space-y-2">
                <Label>Tags</Label>
                <div className="border rounded-md p-3 max-h-[150px] overflow-y-auto">
                  <div className="flex flex-wrap gap-2">
                    {allTags.map((tag) => (
                      <label
                        key={tag.id}
                        className="flex items-center gap-2 cursor-pointer"
                      >
                        <Checkbox
                          checked={formData.tag_ids.includes(tag.id)}
                          onCheckedChange={(checked) => {
                            if (checked) {
                              setFormData({
                                ...formData,
                                tag_ids: [...formData.tag_ids, tag.id],
                              });
                            } else {
                              setFormData({
                                ...formData,
                                tag_ids: formData.tag_ids.filter((id) => id !== tag.id),
                              });
                            }
                          }}
                        />
                        <Badge
                          variant="outline"
                          style={{ borderColor: tag.color, color: tag.color }}
                        >
                          {tag.display_name_english}
                        </Badge>
                      </label>
                    ))}
                  </div>
                </div>
                <p className="text-xs text-muted-foreground">
                  Select tags to categorize this zman (shita, method, etc.)
                </p>
              </div>
            )}

            <div className="flex items-center gap-6">
              <div className="flex items-center gap-2">
                <Switch
                  id="is_core"
                  checked={formData.is_core}
                  onCheckedChange={(v) =>
                    setFormData({ ...formData, is_core: v })
                  }
                />
                <Label htmlFor="is_core">Core Zman</Label>
              </div>
              <div className="flex items-center gap-2">
                <Switch
                  id="is_hidden"
                  checked={formData.is_hidden}
                  onCheckedChange={(v) =>
                    setFormData({ ...formData, is_hidden: v })
                  }
                />
                <Label htmlFor="is_hidden">Hidden</Label>
              </div>
            </div>
          </div>

          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => setIsDialogOpen(false)}
              disabled={isSaving}
            >
              Cancel
            </Button>
            <Button onClick={handleSave} disabled={isSaving}>
              {isSaving && <Loader2 className="w-4 h-4 mr-2 animate-spin" />}
              {editingZman ? 'Update' : 'Create'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete Confirmation Dialog */}
      <Dialog open={isDeleteDialogOpen} onOpenChange={setIsDeleteDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <AlertTriangle className="w-5 h-5 text-destructive" />
              Delete Zman
            </DialogTitle>
            <DialogDescription>
              Are you sure you want to delete &quot;{deletingZman?.canonical_english_name}&quot;? This
              action cannot be undone.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => setIsDeleteDialogOpen(false)}
              disabled={isSaving}
            >
              Cancel
            </Button>
            <Button
              variant="destructive"
              onClick={handleDelete}
              disabled={isSaving}
            >
              {isSaving && <Loader2 className="w-4 h-4 mr-2 animate-spin" />}
              Delete
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
