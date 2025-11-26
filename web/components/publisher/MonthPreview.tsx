'use client';

import { useState, useEffect } from 'react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';

interface ZmanConfig {
  method: string;
  params: Record<string, unknown>;
}

interface AlgorithmConfig {
  name: string;
  description?: string;
  zmanim: Record<string, ZmanConfig>;
}

interface DayZmanim {
  date: string;
  zmanim: Array<{
    key: string;
    name: string;
    time: string;
  }>;
}

interface MonthPreviewProps {
  configuration: AlgorithmConfig;
}

// Sample location for preview
const PREVIEW_LOCATION = {
  latitude: 40.6782,
  longitude: -73.9442,
  timezone: 'America/New_York',
};

export function MonthPreview({ configuration }: MonthPreviewProps) {
  const [currentMonth, setCurrentMonth] = useState(() => {
    const now = new Date();
    return { year: now.getFullYear(), month: now.getMonth() };
  });
  const [monthData, setMonthData] = useState<DayZmanim[]>([]);
  const [loading, setLoading] = useState(false);
  const [selectedDay, setSelectedDay] = useState<DayZmanim | null>(null);

  useEffect(() => {
    loadMonth();
  }, [currentMonth, configuration]);

  const loadMonth = async () => {
    if (Object.keys(configuration.zmanim).length === 0) {
      setMonthData([]);
      return;
    }

    try {
      setLoading(true);
      const days: DayZmanim[] = [];

      // Get all days in the month
      const year = currentMonth.year;
      const month = currentMonth.month;
      const daysInMonth = new Date(year, month + 1, 0).getDate();

      const apiBaseUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';

      // Fetch zmanim for each day (we'll batch this in a real implementation)
      // For now, fetch a few key days to demonstrate
      const daysToFetch = [1, 7, 14, 21, daysInMonth];

      for (const day of daysToFetch) {
        const date = `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;

        try {
          const response = await fetch(`${apiBaseUrl}/api/v1/publisher/algorithm/preview`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'include',
            body: JSON.stringify({
              configuration,
              date,
              latitude: PREVIEW_LOCATION.latitude,
              longitude: PREVIEW_LOCATION.longitude,
              timezone: PREVIEW_LOCATION.timezone,
            }),
          });

          if (response.ok) {
            const data = await response.json();
            days.push({
              date,
              zmanim: data.zmanim || [],
            });
          }
        } catch {
          // Skip failed days
        }
      }

      setMonthData(days);
    } catch (err) {
      console.error('Failed to load month data:', err);
    } finally {
      setLoading(false);
    }
  };

  const prevMonth = () => {
    setCurrentMonth(prev => {
      if (prev.month === 0) {
        return { year: prev.year - 1, month: 11 };
      }
      return { year: prev.year, month: prev.month - 1 };
    });
  };

  const nextMonth = () => {
    setCurrentMonth(prev => {
      if (prev.month === 11) {
        return { year: prev.year + 1, month: 0 };
      }
      return { year: prev.year, month: prev.month + 1 };
    });
  };

  const monthName = new Date(currentMonth.year, currentMonth.month).toLocaleString('default', { month: 'long', year: 'numeric' });

  // Generate calendar grid
  const firstDayOfMonth = new Date(currentMonth.year, currentMonth.month, 1).getDay();
  const daysInMonth = new Date(currentMonth.year, currentMonth.month + 1, 0).getDate();
  const calendarDays: (number | null)[] = [];

  // Add empty cells for days before the first day of the month
  for (let i = 0; i < firstDayOfMonth; i++) {
    calendarDays.push(null);
  }

  // Add days of the month
  for (let i = 1; i <= daysInMonth; i++) {
    calendarDays.push(i);
  }

  return (
    <Card data-testid="month-preview">
      <CardHeader>
        <div className="flex justify-between items-center">
          <CardTitle>Month View</CardTitle>
          <div className="flex items-center gap-4">
            <Button variant="outline" size="sm" onClick={prevMonth}>
              Previous
            </Button>
            <span className="text-white font-medium">{monthName}</span>
            <Button variant="outline" size="sm" onClick={nextMonth}>
              Next
            </Button>
          </div>
        </div>
      </CardHeader>
      <CardContent>
        {loading && (
          <div className="text-center py-8 text-slate-400">
            Loading month data...
          </div>
        )}

        {!loading && (
          <div className="grid grid-cols-7 gap-1">
            {/* Day headers */}
            {['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map(day => (
              <div key={day} className="text-center text-xs text-slate-400 py-2">
                {day}
              </div>
            ))}

            {/* Calendar days */}
            {calendarDays.map((day, index) => {
              if (day === null) {
                return <div key={`empty-${index}`} className="p-2" />;
              }

              const dateStr = `${currentMonth.year}-${String(currentMonth.month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
              const dayData = monthData.find(d => d.date === dateStr);
              const hasData = !!dayData;

              return (
                <div
                  key={day}
                  className={`p-2 text-center rounded cursor-pointer transition-colors ${
                    hasData
                      ? 'bg-blue-900/50 hover:bg-blue-800/50 text-white'
                      : 'bg-slate-800 hover:bg-slate-700 text-slate-400'
                  } ${selectedDay?.date === dateStr ? 'ring-2 ring-blue-500' : ''}`}
                  onClick={() => dayData && setSelectedDay(dayData)}
                >
                  <span className="text-sm">{day}</span>
                  {hasData && (
                    <div className="text-xs text-blue-300 mt-1">
                      {dayData.zmanim.length} zmanim
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}

        {/* Selected day details */}
        {selectedDay && (
          <div className="mt-6 p-4 bg-slate-700 rounded-lg">
            <h4 className="font-medium text-white mb-3">
              {new Date(selectedDay.date).toLocaleDateString('en-US', {
                weekday: 'long',
                year: 'numeric',
                month: 'long',
                day: 'numeric',
              })}
            </h4>
            <div className="space-y-2">
              {selectedDay.zmanim.map(zman => (
                <div key={zman.key} className="flex justify-between text-sm">
                  <span className="text-slate-300">{zman.name}</span>
                  <span className="font-mono text-blue-400">{zman.time}</span>
                </div>
              ))}
            </div>
          </div>
        )}

        <p className="text-xs text-slate-500 mt-4">
          Note: Preview shows sample days. Full month data available after save.
        </p>
      </CardContent>
    </Card>
  );
}
