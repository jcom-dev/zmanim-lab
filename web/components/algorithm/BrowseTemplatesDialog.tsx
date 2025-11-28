'use client';

import { useState, useMemo, useCallback } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from '@/components/ui/dialog';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { ScrollArea } from '@/components/ui/scroll-area';
import { HighlightedFormula } from '@/components/shared/HighlightedFormula';
import {
  Search,
  Copy,
  CheckCircle2,
  BookOpen,
  Users,
  Star,
  Loader2,
} from 'lucide-react';
import { toast } from 'sonner';
import { useZmanimTemplates, useBrowseZmanim, type ZmanimTemplate, type PublisherZman } from '@/lib/hooks/useZmanimList';

interface BrowseTemplatesDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSelectFormula: (formula: string, name?: string) => void;
  currentZmanKey?: string;
}

interface CommunityZman extends PublisherZman {
  publisher_name: string;
  usage_count: number;
}

export function BrowseTemplatesDialog({
  open,
  onOpenChange,
  onSelectFormula,
  currentZmanKey,
}: BrowseTemplatesDialogProps) {
  const [searchQuery, setSearchQuery] = useState('');
  const [activeTab, setActiveTab] = useState<'templates' | 'community'>('templates');
  const [copiedId, setCopiedId] = useState<string | null>(null);

  // Fetch templates (system defaults)
  const { data: templates = [], isLoading: loadingTemplates } = useZmanimTemplates();

  // Fetch community formulas
  const { data: communityZmanim = [], isLoading: loadingCommunity } = useBrowseZmanim(
    activeTab === 'community' ? searchQuery : undefined,
    undefined
  );

  // Filter templates by search
  const filteredTemplates = useMemo(() => {
    if (!searchQuery.trim()) return templates;
    const query = searchQuery.toLowerCase();
    return templates.filter(
      (t) =>
        t.english_name.toLowerCase().includes(query) ||
        t.hebrew_name.toLowerCase().includes(query) ||
        t.zman_key.toLowerCase().includes(query) ||
        t.formula_dsl.toLowerCase().includes(query)
    );
  }, [templates, searchQuery]);

  // Group templates by category
  const groupedTemplates = useMemo(() => {
    return {
      essential: filteredTemplates.filter((t) => t.category === 'essential'),
      optional: filteredTemplates.filter((t) => t.category === 'optional'),
    };
  }, [filteredTemplates]);

  const handleCopy = useCallback(
    (formula: string, id: string, name?: string) => {
      onSelectFormula(formula, name);
      setCopiedId(id);
      toast.success('Formula copied to editor');
      setTimeout(() => setCopiedId(null), 2000);
    },
    [onSelectFormula]
  );

  const renderTemplateCard = (template: ZmanimTemplate) => (
    <Card
      key={template.id}
      className={`hover:border-primary/50 transition-colors ${
        currentZmanKey === template.zman_key ? 'border-primary/50 bg-primary/5' : ''
      }`}
    >
      <CardHeader className="pb-2">
        <div className="flex items-start justify-between">
          <div>
            <CardTitle className="text-base">
              <span className="font-hebrew">{template.hebrew_name}</span>
              <span className="mx-2 text-muted-foreground">•</span>
              <span>{template.english_name}</span>
            </CardTitle>
            <p className="text-xs text-muted-foreground mt-1">
              {template.zman_key}
            </p>
          </div>
          <div className="flex items-center gap-2">
            {template.is_required && (
              <Badge variant="secondary" className="text-xs">
                Required
              </Badge>
            )}
            <Button
              variant="ghost"
              size="sm"
              onClick={() => handleCopy(template.formula_dsl, template.id, template.english_name)}
              className="h-8"
            >
              {copiedId === template.id ? (
                <CheckCircle2 className="h-4 w-4 text-green-500" />
              ) : (
                <Copy className="h-4 w-4" />
              )}
            </Button>
          </div>
        </div>
      </CardHeader>
      <CardContent className="pt-0">
        <HighlightedFormula formula={template.formula_dsl} className="text-xs" />
        {template.description && (
          <p className="text-xs text-muted-foreground mt-2">{template.description}</p>
        )}
      </CardContent>
    </Card>
  );

  const renderCommunityCard = (zman: CommunityZman) => (
    <Card
      key={zman.id}
      className="hover:border-primary/50 transition-colors"
    >
      <CardHeader className="pb-2">
        <div className="flex items-start justify-between">
          <div>
            <CardTitle className="text-base">
              <span className="font-hebrew">{zman.hebrew_name}</span>
              <span className="mx-2 text-muted-foreground">•</span>
              <span>{zman.english_name}</span>
            </CardTitle>
            <div className="flex items-center gap-2 mt-1">
              <Badge variant="outline" className="text-xs">
                <Users className="h-3 w-3 mr-1" />
                {zman.publisher_name}
              </Badge>
              {zman.usage_count > 0 && (
                <Badge variant="secondary" className="text-xs">
                  <Star className="h-3 w-3 mr-1" />
                  {zman.usage_count} uses
                </Badge>
              )}
            </div>
          </div>
          <Button
            variant="ghost"
            size="sm"
            onClick={() => handleCopy(zman.formula_dsl, zman.id, zman.english_name)}
            className="h-8"
          >
            {copiedId === zman.id ? (
              <CheckCircle2 className="h-4 w-4 text-green-500" />
            ) : (
              <Copy className="h-4 w-4" />
            )}
          </Button>
        </div>
      </CardHeader>
      <CardContent className="pt-0">
        <HighlightedFormula formula={zman.formula_dsl} className="text-xs" />
        {zman.publisher_comment && (
          <p className="text-xs text-muted-foreground mt-2 italic">
            "{zman.publisher_comment}"
          </p>
        )}
      </CardContent>
    </Card>
  );

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-3xl max-h-[85vh] flex flex-col">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <BookOpen className="h-5 w-5" />
            Browse Formulas
          </DialogTitle>
          <DialogDescription>
            Browse system templates or discover formulas from other publishers
          </DialogDescription>
        </DialogHeader>

        {/* Search */}
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <Input
            placeholder="Search formulas..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="pl-10"
          />
        </div>

        {/* Tabs */}
        <Tabs value={activeTab} onValueChange={(v) => setActiveTab(v as 'templates' | 'community')}>
          <TabsList className="grid w-full grid-cols-2">
            <TabsTrigger value="templates">
              <BookOpen className="h-4 w-4 mr-2" />
              System Templates
            </TabsTrigger>
            <TabsTrigger value="community">
              <Users className="h-4 w-4 mr-2" />
              Community
            </TabsTrigger>
          </TabsList>

          <TabsContent value="templates" className="flex-1 mt-4">
            <ScrollArea className="h-[400px] pr-4">
              {loadingTemplates ? (
                <div className="flex items-center justify-center h-32">
                  <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
                </div>
              ) : filteredTemplates.length === 0 ? (
                <div className="text-center py-8 text-muted-foreground">
                  No templates found matching your search
                </div>
              ) : (
                <div className="space-y-6">
                  {/* Essential */}
                  {groupedTemplates.essential.length > 0 && (
                    <div>
                      <h3 className="text-sm font-semibold mb-3 flex items-center gap-2">
                        Essential Zmanim
                        <Badge variant="secondary">{groupedTemplates.essential.length}</Badge>
                      </h3>
                      <div className="space-y-3">
                        {groupedTemplates.essential.map(renderTemplateCard)}
                      </div>
                    </div>
                  )}

                  {/* Optional */}
                  {groupedTemplates.optional.length > 0 && (
                    <div>
                      <h3 className="text-sm font-semibold mb-3 flex items-center gap-2">
                        Optional Zmanim
                        <Badge variant="secondary">{groupedTemplates.optional.length}</Badge>
                      </h3>
                      <div className="space-y-3">
                        {groupedTemplates.optional.map(renderTemplateCard)}
                      </div>
                    </div>
                  )}
                </div>
              )}
            </ScrollArea>
          </TabsContent>

          <TabsContent value="community" className="flex-1 mt-4">
            <ScrollArea className="h-[400px] pr-4">
              {loadingCommunity ? (
                <div className="flex items-center justify-center h-32">
                  <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
                </div>
              ) : communityZmanim.length === 0 ? (
                <div className="text-center py-8 text-muted-foreground">
                  {searchQuery
                    ? 'No community formulas found matching your search'
                    : 'Enter a search term to find community formulas'}
                </div>
              ) : (
                <div className="space-y-3">
                  {(communityZmanim as CommunityZman[]).map(renderCommunityCard)}
                </div>
              )}
            </ScrollArea>
          </TabsContent>
        </Tabs>
      </DialogContent>
    </Dialog>
  );
}

export default BrowseTemplatesDialog;
