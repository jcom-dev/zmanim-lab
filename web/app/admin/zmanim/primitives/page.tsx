'use client';

import { useState, useEffect, useCallback } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { useAdminApi } from '@/lib/api-client';
import { Sun, Sunrise, Moon, Clock, Loader2 } from 'lucide-react';
import { ColorBadge, getCalculationTypeColor } from '@/components/ui/color-badge';

interface AstronomicalPrimitive {
  id: string;
  variable_name: string;
  display_name: string;
  description?: string;
  formula_dsl: string;
  category: string;
  calculation_type: string;
  solar_angle?: number;
  is_dawn?: boolean;
  edge_type: string;
  sort_order: number;
}

interface PrimitivesGrouped {
  category: string;
  display_name: string;
  primitives: AstronomicalPrimitive[];
}

const categoryIcons: Record<string, React.ReactNode> = {
  horizon: <Sunrise className="w-5 h-5" />,
  civil_twilight: <Sun className="w-5 h-5" />,
  nautical_twilight: <Sun className="w-5 h-5 opacity-70" />,
  astronomical_twilight: <Moon className="w-5 h-5" />,
  solar_position: <Clock className="w-5 h-5" />,
};

const categoryColors: Record<string, string> = {
  horizon: 'border-l-amber-500 bg-amber-500/10',
  civil_twilight: 'border-l-orange-500 bg-orange-500/10',
  nautical_twilight: 'border-l-blue-500 bg-blue-500/10',
  astronomical_twilight: 'border-l-indigo-500 bg-indigo-500/10',
  solar_position: 'border-l-yellow-500 bg-yellow-500/10',
};

export default function AdminPrimitivesPage() {
  const api = useAdminApi();
  const [groupedPrimitives, setGroupedPrimitives] = useState<PrimitivesGrouped[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchPrimitives = useCallback(async () => {
    try {
      setLoading(true);
      const data = await api.get<PrimitivesGrouped[]>('/admin/registry/primitives/grouped');
      setGroupedPrimitives(data || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  }, [api]);

  useEffect(() => {
    fetchPrimitives();
  }, [fetchPrimitives]);

  if (loading) {
    return (
      <div className="space-y-6">
        <div>
          <h1 className="text-3xl font-bold text-foreground">Astronomical Primitives</h1>
          <p className="text-muted-foreground mt-1">Loading...</p>
        </div>
        <div className="flex justify-center p-8">
          <Loader2 className="w-8 h-8 animate-spin text-primary" />
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="space-y-6">
        <div>
          <h1 className="text-3xl font-bold text-foreground">Astronomical Primitives</h1>
        </div>
        <div className="bg-destructive/10 border border-destructive/30 rounded-lg p-4">
          <p className="text-destructive">{error}</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-foreground">Astronomical Primitives</h1>
        <p className="text-muted-foreground mt-1">
          Core astronomical times used as building blocks for zmanim calculations.
          Use <code className="text-xs bg-muted px-1 rounded">@variable_name</code> in DSL formulas.
        </p>
      </div>

      {/* Summary Card */}
      <Card>
        <CardHeader>
          <CardTitle>Overview</CardTitle>
          <CardDescription>
            {groupedPrimitives.reduce((acc, g) => acc + g.primitives.length, 0)} astronomical primitives
            across {groupedPrimitives.length} categories
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
            {groupedPrimitives.map((group) => (
              <div key={group.category} className={`p-4 rounded-lg border-l-4 ${categoryColors[group.category] || 'border-l-muted bg-muted/50'}`}>
                <div className="flex items-center gap-2 mb-2">
                  {categoryIcons[group.category]}
                  <span className="font-medium text-sm text-foreground">{group.display_name}</span>
                </div>
                <div className="text-2xl font-bold text-foreground">{group.primitives.length}</div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Primitives by Category */}
      {groupedPrimitives.map((group) => (
        <Card key={group.category}>
          <CardHeader>
            <div className="flex items-center gap-3">
              {categoryIcons[group.category]}
              <div>
                <CardTitle>{group.display_name}</CardTitle>
                <CardDescription>
                  {group.primitives.length} primitive{group.primitives.length !== 1 ? 's' : ''}
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
                    <th className="pb-3 font-semibold text-foreground">Type & Info</th>
                  </tr>
                </thead>
                <tbody>
                  {group.primitives.map((primitive) => (
                    <tr key={primitive.id} className="border-b border-border hover:bg-accent/50">
                      <td className="py-3 pr-4">
                        <code className="px-2 py-1 bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-200 rounded text-sm font-mono font-semibold">
                          @{primitive.variable_name}
                        </code>
                      </td>
                      <td className="py-3 pr-4">
                        <div className="flex flex-col gap-0.5">
                          <span className="text-foreground font-medium">{primitive.display_name}</span>
                          {primitive.description && (
                            <span className="text-sm text-muted-foreground max-w-md">
                              {primitive.description}
                            </span>
                          )}
                        </div>
                      </td>
                      <td className="py-3 pr-4">
                        <div className="flex flex-wrap items-center gap-1">
                          {/* Calculation type */}
                          <ColorBadge color={getCalculationTypeColor(primitive.calculation_type)} size="sm">
                            {primitive.calculation_type.replace('_', ' ')}
                          </ColorBadge>
                          {/* Solar angle if present */}
                          {primitive.solar_angle !== null && primitive.solar_angle !== undefined && (
                            <ColorBadge color="violet" size="sm">
                              {primitive.solar_angle}°
                            </ColorBadge>
                          )}
                          {/* Dawn/Dusk indicator */}
                          {primitive.is_dawn === true && (
                            <ColorBadge color="orange" size="sm">
                              Dawn
                            </ColorBadge>
                          )}
                          {primitive.is_dawn === false && (
                            <ColorBadge color="indigo" size="sm">
                              Dusk
                            </ColorBadge>
                          )}
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>
      ))}
    </div>
  );
}
