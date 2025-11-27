'use client';

import { useState, useEffect } from 'react';
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
  const [templates, setTemplates] = useState<Template[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedId, setSelectedId] = useState<string | null>(null);

  useEffect(() => {
    loadTemplates();
  }, []);

  const loadTemplates = async () => {
    try {
      const apiBaseUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';
      const response = await fetch(`${apiBaseUrl}/api/v1/publisher/algorithm/templates`, {
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
      });

      if (response.ok) {
        const data = await response.json();
        setTemplates(data.data?.templates || data.templates || []);
      }
    } catch (err) {
      console.error('Failed to load templates:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleSelect = (template: Template) => {
    setSelectedId(template.id);
    onSelect(template.configuration);
  };

  if (loading) {
    return <div className="text-slate-400">Loading templates...</div>;
  }

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-4" data-testid="template-selector">
      {templates.map((template) => (
        <Card
          key={template.id}
          className={`cursor-pointer transition-all hover:border-blue-500 ${
            selectedId === template.id ? 'border-blue-500 ring-2 ring-blue-500/50' : ''
          }`}
          onClick={() => handleSelect(template)}
          data-testid={`template-${template.id}`}
        >
          <CardHeader className="pb-2">
            <CardTitle className="text-lg">{template.name}</CardTitle>
          </CardHeader>
          <CardContent>
            <CardDescription className="text-sm">
              {template.description}
            </CardDescription>
            <Button
              variant="outline"
              size="sm"
              className="mt-4"
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
