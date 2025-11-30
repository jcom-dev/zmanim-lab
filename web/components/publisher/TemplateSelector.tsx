'use client';

import { useState, useEffect, useCallback } from 'react';
import { useApi } from '@/lib/api-client';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';

interface ZmanConfig {
  method: string;
  params: Record<string, unknown>;
}

interface AlgorithmConfig {
  name: string;
  description?: string;
  zmanim: Record<string, ZmanConfig>;
}

interface Template {
  id: string;
  name: string;
  description: string;
  configuration: AlgorithmConfig;
}

interface TemplateSelectorProps {
  onSelect: (template: AlgorithmConfig) => void;
}

export function TemplateSelector({ onSelect }: TemplateSelectorProps) {
  const api = useApi();
  const [templates, setTemplates] = useState<Template[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedId, setSelectedId] = useState<string | null>(null);

  const loadTemplates = useCallback(async () => {
    try {
      const data = await api.get<{ templates: Template[] }>('/publisher/algorithm/templates');
      setTemplates(data.templates || []);
    } catch (err) {
      console.error('Failed to load templates:', err);
    } finally {
      setLoading(false);
    }
  }, [api]);

  useEffect(() => {
    loadTemplates();
  }, [loadTemplates]);

  const handleSelect = (template: Template) => {
    setSelectedId(template.id);
    onSelect(template.configuration);
  };

  if (loading) {
    return <div className="text-muted-foreground">Loading templates...</div>;
  }

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-4" data-testid="template-selector">
      {templates.map((template) => (
        <Card
          key={template.id}
          className={`cursor-pointer transition-all hover:border-primary flex flex-col ${
            selectedId === template.id ? 'border-primary ring-2 ring-primary/50' : ''
          }`}
          onClick={() => handleSelect(template)}
          data-testid={`template-${template.id}`}
        >
          <CardHeader className="pb-2">
            <CardTitle className="text-lg">{template.name}</CardTitle>
          </CardHeader>
          <CardContent className="flex flex-col flex-1">
            <CardDescription className="text-sm flex-1">
              {template.description}
            </CardDescription>
            <Button
              variant="outline"
              size="sm"
              className="mt-4 self-start"
              onClick={(e) => {
                e.stopPropagation();
                handleSelect(template);
              }}
            >
              Use Template
            </Button>
          </CardContent>
        </Card>
      ))}
    </div>
  );
}
