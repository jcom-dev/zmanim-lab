'use client';
import { API_BASE } from '@/lib/api';
import { useApi } from '@/lib/api-client';

import { useState, useEffect, useCallback, useRef, useMemo } from 'react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { ChevronLeft, ChevronRight, ChevronUp, ChevronDown, Eye, EyeOff, Moon, Sun, Calendar, Star } from 'lucide-react';
import { PublisherZman } from '@/lib/hooks/useZmanimList';

// Hebrew months with their numeric values (matching hdate library)
const hebrewMonthsWithNum = [
  { num: 7, eng: 'Tishrei', heb: 'תשרי' },
  { num: 8, eng: 'Cheshvan', heb: 'חשון' },
  { num: 9, eng: 'Kislev', heb: 'כסלו' },
  { num: 10, eng: 'Tevet', heb: 'טבת' },
  { num: 11, eng: 'Shvat', heb: 'שבט' },
  { num: 12, eng: 'Adar', heb: 'אדר' },
  { num: 1, eng: 'Nisan', heb: 'ניסן' },
  { num: 2, eng: 'Iyyar', heb: 'אייר' },
  { num: 3, eng: 'Sivan', heb: 'סיון' },
  { num: 4, eng: 'Tamuz', heb: 'תמוז' },
  { num: 5, eng: 'Av', heb: 'אב' },
  { num: 6, eng: 'Elul', heb: 'אלול' },
];

// Hebrew years range
const currentGregorianYear = new Date().getFullYear();
const currentHebrewYear = currentGregorianYear + 3760;
const hebrewYears = Array.from({ length: 10 }, (_, i) => currentHebrewYear - 3 + i);

export interface PreviewLocation {
  latitude: number;
  longitude: number;
  timezone: string;
  displayName: string;
}

interface HebrewDate {
  day: number;
  month: string;
  year: number;
  hebrew: string;
  formatted: string;
}

interface Holiday {
  name: string;
  name_hebrew: string;
  category: string; // "major", "minor", "shabbat", "roshchodesh", "fast"
  candles: boolean;
  yomtov: boolean;
}

interface CalendarDayInfo {
  date: string;
  hebrew_date: HebrewDate;
  day_of_week: number;
  day_name_hebrew: string;
  day_name_eng: string;
  holidays: Holiday[];
  is_shabbat: boolean;
  is_yomtov: boolean;
}

interface DayResult {
  date: string;
  dayName: string;
  dayNumber: number;
  month: string;
  year: number;
  times: Record<string, string | null>;
  hebrewDate?: HebrewDate;
  holidays: Holiday[];
  isYomTov: boolean;
}

interface WeekPreviewProps {
  zmanim: PublisherZman[];
  getToken: () => Promise<string | null>;
  location: PreviewLocation;
}

const delay = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

// Event zman keys - these should only show on specific days
const EVENT_ZMAN_KEYS = new Set([
  // Candle lighting
  'candle_lighting', 'candle_lighting_18', 'candle_lighting_20', 'candle_lighting_22', 'candle_lighting_40',
  // Havdalah / Shabbos ends
  'shabbos_ends', 'havdalah', 'havdalah_42', 'havdalah_50', 'havdalah_72',
  // Yom Kippur
  'yom_kippur_starts', 'yom_kippur_ends',
  // Fast days
  'fast_begins', 'fast_ends', 'fast_ends_42', 'fast_ends_50',
  // Tisha B'Av
  'tisha_bav_starts', 'tisha_bav_ends',
  // Pesach
  'sof_zman_achilas_chametz_gra', 'sof_zman_achilas_chametz_mga', 'sof_zman_biur_chametz_gra', 'sof_zman_biur_chametz_mga',
]);

/**
 * Determines if an event zman should be shown for a specific day
 * based on the day's holidays and day of week
 */
function shouldShowEventZman(zmanKey: string, day: DayResult): boolean {
  // If not an event zman, always show
  if (!EVENT_ZMAN_KEYS.has(zmanKey)) {
    return true;
  }

  const dayOfWeek = new Date(day.date).getDay();
  const isFriday = dayOfWeek === 5;
  const isSaturday = dayOfWeek === 6;
  const holidays = day.holidays || [];

  // Check holiday categories
  const hasFast = holidays.some(h => h.category === 'fast');
  const hasYomTov = holidays.some(h => h.yomtov);
  const hasCandles = holidays.some(h => h.candles);

  // Check specific holidays
  const isYomKippur = holidays.some(h => h.name.toLowerCase().includes('yom kippur'));
  const isTishaBav = holidays.some(h => h.name.toLowerCase().includes("tisha b'av") || h.name.toLowerCase().includes('tisha bav'));
  const isErevPesach = holidays.some(h => h.name.toLowerCase().includes('erev pesach'));

  // Candle lighting: Friday (Erev Shabbat) or Erev Yom Tov (when candles = true)
  if (zmanKey.startsWith('candle_lighting')) {
    return isFriday || hasCandles;
  }

  // Havdalah/Shabbos ends: Saturday (Motzei Shabbat) or Motzei Yom Tov
  // Note: Motzei Yom Tov is tricky - we show on Yom Tov day itself since the time is for that evening
  if (zmanKey === 'shabbos_ends' || zmanKey.startsWith('havdalah')) {
    return isSaturday || hasYomTov;
  }

  // Yom Kippur zmanim
  if (zmanKey.startsWith('yom_kippur')) {
    return isYomKippur;
  }

  // General fast day zmanim (not Tisha B'Av specific)
  if (zmanKey === 'fast_begins' || zmanKey === 'fast_ends' || zmanKey === 'fast_ends_42' || zmanKey === 'fast_ends_50') {
    return hasFast && !isTishaBav;
  }

  // Tisha B'Av specific zmanim
  if (zmanKey.startsWith('tisha_bav')) {
    return isTishaBav;
  }

  // Pesach chametz zmanim - only on Erev Pesach
  if (zmanKey.includes('chametz')) {
    return isErevPesach;
  }

  // Default: don't show unknown event zmanim
  return false;
}

export function WeekPreview({ zmanim, getToken, location }: WeekPreviewProps) {
  const api = useApi();
  const [selectedDate, setSelectedDate] = useState(() => new Date());
  const [weekData, setWeekData] = useState<DayResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [progress, setProgress] = useState({ current: 0, total: 0 });
  const [currentDayIndex, setCurrentDayIndex] = useState(0);
  const abortControllerRef = useRef<AbortController | null>(null);
  const dayRefs = useRef<(HTMLDivElement | null)[]>([]);

  const enabledZmanim = useMemo(() => zmanim.filter(z => z.is_enabled), [zmanim]);

  // Convert Hebrew date to Gregorian and update selectedDate
  const handleHebrewDateChange = useCallback(async (year: number, monthNum: number, day: number) => {
    try {
      const data = await api.public.get<{ date: string }>(`/calendar/gregorian-date?year=${year}&month=${monthNum}&day=${day}`);
      if (data.date) {
        setSelectedDate(new Date(data.date + 'T12:00:00'));
      }
    } catch (err) {
      console.error('Failed to convert Hebrew date:', err);
    }
  }, [api]);

  // Get Hebrew month number from English name
  const getHebrewMonthNum = (englishMonth: string): number => {
    const month = hebrewMonthsWithNum.find(m => m.eng === englishMonth);
    return month?.num || 7; // Default to Tishrei
  };

  const weekStartStr = useMemo(() => {
    const d = new Date(selectedDate);
    const day = d.getDay();
    d.setDate(d.getDate() - day);
    return d.toISOString().split('T')[0];
  }, [selectedDate]);

  const loadWeek = useCallback(async () => {
    if (abortControllerRef.current) {
      abortControllerRef.current.abort();
    }
    abortControllerRef.current = new AbortController();

    try {
      setLoading(true);
      setError(null);
      setProgress({ current: 0, total: enabledZmanim.length + 1 }); // +1 for calendar fetch

      const token = await getToken();
      if (!token) {
        setError('Not authenticated');
        setLoading(false);
        return;
      }

      const dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
      const monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
      const startDate = new Date(weekStartStr + 'T00:00:00');

      // Initialize days structure
      const days: DayResult[] = [];
      for (let i = 0; i < 7; i++) {
        const date = new Date(startDate);
        date.setDate(startDate.getDate() + i);
        days.push({
          date: date.toISOString().split('T')[0],
          dayName: dayNames[date.getDay()],
          dayNumber: date.getDate(),
          month: monthNames[date.getMonth()],
          year: date.getFullYear(),
          times: {},
          holidays: [],
          isYomTov: false,
        });
      }

      // Fetch Hebrew calendar data
      try {
        const calendarResponse = await fetch(
          `${API_BASE}/api/v1/calendar/week?date=${weekStartStr}`,
          {
            headers: {
              Authorization: `Bearer ${token}`,
            },
            signal: abortControllerRef.current?.signal,
          }
        );

        if (calendarResponse.ok) {
          const calendarData = await calendarResponse.json();
          const result = calendarData.data || calendarData;

          if (result.days && Array.isArray(result.days)) {
            result.days.forEach((dayInfo: CalendarDayInfo) => {
              const dayIndex = days.findIndex(d => d.date === dayInfo.date);
              if (dayIndex !== -1) {
                days[dayIndex].hebrewDate = dayInfo.hebrew_date;
                days[dayIndex].holidays = dayInfo.holidays || [];
                days[dayIndex].isYomTov = dayInfo.is_yomtov;
              }
            });
          }
        }
      } catch (err) {
        if ((err as Error).name === 'AbortError') return;
        console.error('Failed to fetch calendar data:', err);
      }

      setProgress({ current: 1, total: enabledZmanim.length + 1 });

      // Fetch zmanim times if we have any enabled
      if (enabledZmanim.length > 0) {
        for (let i = 0; i < enabledZmanim.length; i++) {
          const zman = enabledZmanim[i];

          if (abortControllerRef.current?.signal.aborted) {
            return;
          }

          try {
            const response = await fetch(`${API_BASE}/api/v1/dsl/preview-week`, {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                Authorization: `Bearer ${token}`,
              },
              body: JSON.stringify({
                formula: zman.formula_dsl,
                start_date: weekStartStr,
                latitude: location.latitude,
                longitude: location.longitude,
                timezone: location.timezone,
              }),
              signal: abortControllerRef.current?.signal,
            });

            if (response.ok) {
              const data = await response.json();
              const result = data.data || data;

              if (result.days && Array.isArray(result.days)) {
                result.days.forEach((dayResult: { date: string; result: string }) => {
                  const dayIndex = days.findIndex(d => d.date === dayResult.date);
                  if (dayIndex !== -1) {
                    days[dayIndex].times[zman.zman_key] = dayResult.result || null;
                  }
                });
              }
            } else {
              days.forEach(day => {
                day.times[zman.zman_key] = null;
              });
            }
          } catch (err) {
            if ((err as Error).name === 'AbortError') {
              return;
            }
            days.forEach(day => {
              day.times[zman.zman_key] = null;
            });
          }

          setProgress({ current: i + 2, total: enabledZmanim.length + 1 });

          if (i < enabledZmanim.length - 1) {
            await delay(100);
          }
        }
      }

      setWeekData(days);
    } catch (err) {
      if ((err as Error).name !== 'AbortError') {
        console.error('Failed to load week data:', err);
        setError('Failed to load week data');
      }
    } finally {
      setLoading(false);
    }
  }, [weekStartStr, enabledZmanim, getToken, location]);

  useEffect(() => {
    loadWeek();
    return () => {
      if (abortControllerRef.current) {
        abortControllerRef.current.abort();
      }
    };
  }, [loadWeek]);

  const prevWeek = () => {
    const newDate = new Date(selectedDate);
    newDate.setDate(selectedDate.getDate() - 7);
    setSelectedDate(newDate);
  };

  const nextWeek = () => {
    const newDate = new Date(selectedDate);
    newDate.setDate(selectedDate.getDate() + 7);
    setSelectedDate(newDate);
  };

  const goToToday = () => {
    setSelectedDate(new Date());
  };

  const formatTime = (timeStr: string | null): string => {
    if (!timeStr) return '--:--';
    try {
      const [hours, minutes] = timeStr.split(':').map(Number);
      const period = hours >= 12 ? 'PM' : 'AM';
      const displayHours = hours % 12 || 12;
      return `${displayHours}:${minutes.toString().padStart(2, '0')} ${period}`;
    } catch {
      return timeStr;
    }
  };

  const isToday = (dateStr: string): boolean => {
    const today = new Date().toISOString().split('T')[0];
    return dateStr === today;
  };

  const isShabbat = (dateStr: string): boolean => {
    const date = new Date(dateStr);
    return date.getDay() === 6;
  };

  const isFriday = (dateStr: string): boolean => {
    const date = new Date(dateStr);
    return date.getDay() === 5;
  };

  // Get holiday badge color based on category - prominent colors
  const getHolidayBadgeClass = (category: string): string => {
    switch (category) {
      case 'major':
        // Major holidays (Yom Tov) - vibrant purple
        return 'bg-purple-600 text-white border-purple-700';
      case 'fast':
        // Fast days - prominent red
        return 'bg-red-600 text-white border-red-700';
      case 'roshchodesh':
        // Rosh Chodesh - bright blue
        return 'bg-blue-600 text-white border-blue-700';
      case 'shabbat':
        // Special Shabbatot - golden amber
        return 'bg-amber-500 text-black border-amber-600';
      case 'minor':
        // Minor holidays (Chanukah, Purim, etc.) - teal/cyan
        return 'bg-teal-600 text-white border-teal-700';
      default:
        // Other events - slate
        return 'bg-slate-600 text-white border-slate-700';
    }
  };

  // Date picker helpers
  const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  const years = Array.from({ length: 10 }, (_, i) => new Date().getFullYear() - 2 + i);

  const handleMonthChange = (month: number) => {
    const newDate = new Date(selectedDate);
    newDate.setMonth(month);
    setSelectedDate(newDate);
  };

  const handleYearChange = (year: number) => {
    const newDate = new Date(selectedDate);
    newDate.setFullYear(year);
    setSelectedDate(newDate);
  };

  // Scroll navigation functions
  const scrollToDay = (index: number) => {
    if (index >= 0 && index < weekData.length && dayRefs.current[index]) {
      dayRefs.current[index]?.scrollIntoView({ behavior: 'smooth', block: 'start' });
      setCurrentDayIndex(index);
    }
  };

  const scrollToPrevDay = () => {
    const newIndex = Math.max(0, currentDayIndex - 1);
    scrollToDay(newIndex);
  };

  const scrollToNextDay = () => {
    const newIndex = Math.min(weekData.length - 1, currentDayIndex + 1);
    scrollToDay(newIndex);
  };

  const scrollToTop = () => {
    scrollToDay(0);
  };

  const scrollToBottom = () => {
    scrollToDay(weekData.length - 1);
  };

  // Helper to get Hebrew month name
  const getHebrewMonthName = (englishMonth: string): string => {
    const monthMap: Record<string, string> = {
      'Nisan': 'ניסן',
      'Iyyar': 'אייר',
      'Sivan': 'סיון',
      'Tamuz': 'תמוז',
      'Av': 'אב',
      'Elul': 'אלול',
      'Tishrei': 'תשרי',
      'Cheshvan': 'חשון',
      'Kislev': 'כסלו',
      'Tevet': 'טבת',
      'Shvat': 'שבט',
      'Adar': 'אדר',
      'Adar I': 'אדר א׳',
      'Adar II': 'אדר ב׳',
    };
    return monthMap[englishMonth] || englishMonth;
  };

  // Helper to get Hebrew day name
  const getHebrewDayName = (englishDay: string): string => {
    const dayMap: Record<string, string> = {
      'Sunday': 'יום ראשון',
      'Monday': 'יום שני',
      'Tuesday': 'יום שלישי',
      'Wednesday': 'יום רביעי',
      'Thursday': 'יום חמישי',
      'Friday': 'יום שישי',
      'Saturday': 'שבת קודש',
    };
    return dayMap[englishDay] || englishDay;
  };

  // Convert day number to Hebrew numerals (gematria)
  const toHebrewNumerals = (num: number): string => {
    if (num === undefined || num === null) return '';

    const ones = ['', 'א', 'ב', 'ג', 'ד', 'ה', 'ו', 'ז', 'ח', 'ט'];
    const tens = ['', 'י', 'כ', 'ל'];

    if (num === 15) return 'ט״ו';
    if (num === 16) return 'ט״ז';
    if (num === 30) return 'ל׳';

    if (num < 10) return ones[num] + '׳';
    if (num < 30) {
      const t = Math.floor(num / 10);
      const o = num % 10;
      if (o === 0) return tens[t] + '׳';
      return tens[t] + '״' + ones[o];
    }
    return num.toString();
  };

  // Convert year to Hebrew numerals (simplified - show as תשפ״ח style)
  const toHebrewYear = (year: number): string => {
    if (year === undefined || year === null) return '';

    // Hebrew years like 5788 -> תשפ״ח
    const hundreds = ['', 'ק', 'ר', 'ש', 'ת', 'תק', 'תר', 'תש'];
    const tens = ['', 'י', 'כ', 'ל', 'מ', 'נ', 'ס', 'ע', 'פ', 'צ'];
    const ones = ['', 'א', 'ב', 'ג', 'ד', 'ה', 'ו', 'ז', 'ח', 'ט'];

    const lastThree = year % 1000;
    const h = Math.floor(lastThree / 100);
    const t = Math.floor((lastThree % 100) / 10);
    const o = lastThree % 10;

    let result = hundreds[h] || '';
    if (t === 1 && o === 5) {
      result += 'ט״ו';
    } else if (t === 1 && o === 6) {
      result += 'ט״ז';
    } else {
      result += tens[t] || '';
      if (o > 0) {
        result += '״' + ones[o];
      } else if (result.length > 0) {
        result += '׳';
      }
    }

    return result;
  };

  // Get Hebrew date range for the week header (Hebrew only)
  const getHebrewWeekRange = () => {
    if (weekData.length === 0) return null;
    const firstDay = weekData[0];
    const lastDay = weekData[weekData.length - 1];
    if (!firstDay.hebrewDate || !lastDay.hebrewDate) return null;

    const startHeb = firstDay.hebrewDate;
    const endHeb = lastDay.hebrewDate;

    const startDayHeb = toHebrewNumerals(startHeb.day);
    const endDayHeb = toHebrewNumerals(endHeb.day);

    // If same month, show "י׳-ט״ז כסלו תשפ״ח"
    if (startHeb.month === endHeb.month && startHeb.year === endHeb.year) {
      return {
        hebrew: `${startDayHeb}-${endDayHeb} ${getHebrewMonthName(startHeb.month)} ${toHebrewYear(startHeb.year)}`
      };
    }
    // Different months: "כ״ח כסלו - ד׳ טבת תשפ״ח"
    return {
      hebrew: `${startDayHeb} ${getHebrewMonthName(startHeb.month)} - ${endDayHeb} ${getHebrewMonthName(endHeb.month)} ${toHebrewYear(endHeb.year)}`
    };
  };

  const hebrewWeekRange = getHebrewWeekRange();

  return (
    <div data-testid="week-preview" className="space-y-4">
      {/* Date Navigation Header */}
      <div className="flex flex-col gap-3">
        {/* Top row: Location display */}
        <div className="flex justify-end items-center">
          <span className="text-sm text-muted-foreground">{location.displayName}</span>
        </div>

        {/* Date Pickers Row: English (Year/Month) | Arrows | Hebrew (Year/Month) */}
        <div className="grid grid-cols-3 items-center">
          {/* Left: English Year / Month pickers */}
          <div className="flex items-center gap-2 justify-start">
            <select
              value={selectedDate.getFullYear()}
              onChange={(e) => handleYearChange(parseInt(e.target.value))}
              className="bg-background border border-input rounded-md px-3 py-2 text-base font-medium focus:outline-none focus:ring-2 focus:ring-ring cursor-pointer hover:bg-muted/50"
              disabled={loading}
            >
              {years.map((year) => (
                <option key={year} value={year}>{year}</option>
              ))}
            </select>
            <select
              value={selectedDate.getMonth()}
              onChange={(e) => handleMonthChange(parseInt(e.target.value))}
              className="bg-background border border-input rounded-md px-3 py-2 text-base font-medium focus:outline-none focus:ring-2 focus:ring-ring cursor-pointer hover:bg-muted/50"
              disabled={loading}
            >
              {months.map((month, index) => (
                <option key={month} value={index}>{month}</option>
              ))}
            </select>
          </div>

          {/* Center: Navigation arrows */}
          <div className="flex items-center justify-center gap-2">
            <button
              onClick={prevWeek}
              disabled={loading}
              className="p-2 rounded-md border border-input bg-background hover:bg-muted disabled:opacity-50 transition-colors"
            >
              <ChevronLeft className="h-6 w-6" />
            </button>
            <button
              onClick={nextWeek}
              disabled={loading}
              className="p-2 rounded-md border border-input bg-background hover:bg-muted disabled:opacity-50 transition-colors"
            >
              <ChevronRight className="h-6 w-6" />
            </button>
          </div>

          {/* Right: Hebrew Year / Month pickers (no day) */}
          <div className="flex items-center gap-2 justify-end">
            {weekData.length > 0 && weekData[0].hebrewDate && (
              <>
                <select
                  value={getHebrewMonthNum(weekData[0].hebrewDate.month)}
                  onChange={(e) => handleHebrewDateChange(
                    weekData[0].hebrewDate!.year,
                    parseInt(e.target.value),
                    1
                  )}
                  className="bg-background border border-input rounded-md px-3 py-2 text-base font-medium font-hebrew focus:outline-none focus:ring-2 focus:ring-ring cursor-pointer hover:bg-muted/50"
                  disabled={loading}
                >
                  {hebrewMonthsWithNum.map((m) => (
                    <option key={m.num} value={m.num}>{m.heb}</option>
                  ))}
                </select>
                <select
                  value={weekData[0].hebrewDate.year}
                  onChange={(e) => handleHebrewDateChange(
                    parseInt(e.target.value),
                    getHebrewMonthNum(weekData[0].hebrewDate!.month),
                    1
                  )}
                  className="bg-background border border-input rounded-md px-3 py-2 text-base font-medium font-hebrew focus:outline-none focus:ring-2 focus:ring-ring cursor-pointer hover:bg-muted/50"
                  disabled={loading}
                >
                  {hebrewYears.map((year) => (
                    <option key={year} value={year}>{toHebrewYear(year)}</option>
                  ))}
                </select>
              </>
            )}
          </div>
        </div>

        {/* Date Range Display with Today button */}
        <div className="grid grid-cols-3 items-center px-1">
          {/* Gregorian Range */}
          <div className="text-sm font-medium text-foreground justify-start">
            {weekData.length > 0 ? (
              <>
                {weekData[0].month} {weekData[0].dayNumber} - {weekData[weekData.length - 1].month} {weekData[weekData.length - 1].dayNumber}, {weekData[0].year}
              </>
            ) : (
              <>{months[selectedDate.getMonth()]} {selectedDate.getFullYear()}</>
            )}
          </div>

          {/* Today button in center */}
          <div className="flex justify-center">
            <Button variant="outline" size="sm" onClick={goToToday} disabled={loading}>
              Today
            </Button>
          </div>

          {/* Hebrew Range */}
          <div className="text-right font-hebrew" dir="rtl">
            {hebrewWeekRange && (
              <div className="text-sm font-medium text-foreground">
                {hebrewWeekRange.hebrew}
              </div>
            )}
          </div>
        </div>

        {/* Legend - Always visible */}
        <div className="flex flex-wrap items-center justify-center gap-4 text-xs text-muted-foreground py-2 px-3 bg-muted/20 rounded-md border border-border/50">
          <div className="flex items-center gap-1">
            <Eye className="h-3 w-3 text-green-400" />
            <span>Published</span>
          </div>
          <div className="flex items-center gap-1">
            <EyeOff className="h-3 w-3" />
            <span>Draft</span>
          </div>
          <div className="flex items-center gap-1">
            <div className="w-3 h-3 rounded border border-primary bg-primary/20" />
            <span>Today</span>
          </div>
          <div className="flex items-center gap-1">
            <div className="w-3 h-3 rounded border border-purple-500 bg-purple-500/20" />
            <span>Yom Tov</span>
          </div>
          <div className="flex items-center gap-1">
            <div className="w-3 h-3 rounded border border-amber-500 bg-amber-500/20" />
            <span>Shabbat</span>
          </div>
        </div>
      </div>

      {/* Loading State */}
      {loading && (
        <div className="text-center py-8 text-muted-foreground">
          <div>Calculating zmanim for the week...</div>
          {progress.total > 0 && (
            <div className="text-xs mt-2">
              {progress.current} / {progress.total}
            </div>
          )}
        </div>
      )}

      {/* Error State */}
      {error && (
        <div className="text-center py-8 text-destructive">{error}</div>
      )}

      {/* Empty state - data is loading or failed silently */}
      {!loading && !error && weekData.length === 0 && (
        <div className="text-center py-8 text-muted-foreground">
          Loading week data...
        </div>
      )}

      {/* Vertical Day List */}
      {!loading && !error && weekData.length > 0 && (
        <div className="space-y-4 relative">
          {weekData.map((day, index) => (
            <div
              key={day.date}
              ref={(el) => { dayRefs.current[index] = el; }}
              className={`rounded-lg border overflow-hidden ${
                isToday(day.date)
                  ? 'border-primary'
                  : day.isYomTov
                    ? 'border-purple-500/50'
                    : isShabbat(day.date)
                      ? 'border-amber-500/50'
                      : isFriday(day.date)
                        ? 'border-orange-500/30'
                        : 'border-border'
              }`}
            >
              {/* Day Header */}
              <div className={`px-4 py-3 ${
                isToday(day.date)
                  ? 'bg-primary/10'
                  : day.isYomTov
                    ? 'bg-purple-500/10'
                    : isShabbat(day.date)
                      ? 'bg-amber-500/10'
                      : isFriday(day.date)
                        ? 'bg-orange-500/10'
                        : 'bg-muted/50'
              }`}>
                <div className="flex items-center justify-between">
                  {/* English Date - Left Side */}
                  <div className="flex items-center gap-3">
                    <div className={`text-3xl font-bold ${
                      isToday(day.date)
                        ? 'text-primary'
                        : day.isYomTov
                          ? 'text-purple-400'
                          : isShabbat(day.date)
                            ? 'text-amber-400'
                            : 'text-foreground'
                    }`}>
                      {day.dayNumber}
                    </div>
                    <div>
                      <div className={`font-semibold ${
                        isToday(day.date)
                          ? 'text-primary'
                          : day.isYomTov
                            ? 'text-purple-400'
                            : isShabbat(day.date)
                              ? 'text-amber-400'
                              : 'text-foreground'
                      }`}>
                        {day.dayName}
                      </div>
                      <div className="text-sm text-muted-foreground">
                        {day.month} {day.year}
                      </div>
                    </div>
                  </div>

                  {/* Hebrew Date - Right Side (Symmetrical) */}
                  {day.hebrewDate && (
                    <div className="flex items-center gap-3" dir="rtl">
                      <div className={`text-3xl font-bold font-hebrew ${
                        isToday(day.date)
                          ? 'text-primary'
                          : day.isYomTov
                            ? 'text-purple-400'
                            : isShabbat(day.date)
                              ? 'text-amber-400'
                              : 'text-foreground'
                      }`}>
                        {toHebrewNumerals(day.hebrewDate.day)}
                      </div>
                      <div className="text-right">
                        <div className={`font-semibold font-hebrew ${
                          isToday(day.date)
                            ? 'text-primary'
                            : day.isYomTov
                              ? 'text-purple-400'
                              : isShabbat(day.date)
                                ? 'text-amber-400'
                                : 'text-foreground'
                        }`}>
                          {getHebrewDayName(day.dayName)}
                        </div>
                        <div className="text-sm text-muted-foreground font-hebrew">
                          {getHebrewMonthName(day.hebrewDate.month)} {toHebrewYear(day.hebrewDate.year)}
                        </div>
                      </div>
                    </div>
                  )}
                </div>

                {/* Badges Row - English left, Hebrew right */}
                <div className="flex items-center justify-between mt-2">
                  {/* English badges */}
                  <div className="flex flex-wrap items-center gap-2">
                    {isToday(day.date) && (
                      <Badge variant="default" className="text-xs">Today</Badge>
                    )}
                    {isShabbat(day.date) && (
                      <Badge className="text-xs bg-orange-500 text-white border-orange-600">
                        <Moon className="h-3 w-3 mr-1" />
                        Shabbat
                      </Badge>
                    )}
                    {isFriday(day.date) && !day.isYomTov && (
                      <Badge className="text-xs bg-orange-400 text-black border-orange-500">
                        <Sun className="h-3 w-3 mr-1" />
                        Erev Shabbat
                      </Badge>
                    )}
                    {/* Holidays - English */}
                    {day.holidays.map((holiday, idx) => (
                      <Badge
                        key={idx}
                        variant="outline"
                        className={`text-xs ${getHolidayBadgeClass(holiday.category)}`}
                      >
                        {holiday.yomtov && <Star className="h-3 w-3 mr-1" />}
                        {holiday.name}
                      </Badge>
                    ))}
                  </div>

                  {/* Hebrew badges - flex-row-reverse so order matches English (Shabbat first = on right in RTL) */}
                  <div className="flex flex-row-reverse flex-wrap items-center gap-2 justify-start">
                    {isToday(day.date) && (
                      <Badge variant="default" className="text-xs font-hebrew">היום</Badge>
                    )}
                    {isShabbat(day.date) && (
                      <Badge className="text-xs font-hebrew bg-orange-500 text-white border-orange-600">
                        שבת
                      </Badge>
                    )}
                    {isFriday(day.date) && !day.isYomTov && (
                      <Badge className="text-xs font-hebrew bg-orange-400 text-black border-orange-500">
                        ערב שבת
                      </Badge>
                    )}
                    {/* Holidays - Hebrew */}
                    {day.holidays.map((holiday, idx) => (
                      <Badge
                        key={idx}
                        variant="outline"
                        className={`text-xs font-hebrew ${getHolidayBadgeClass(holiday.category)}`}
                      >
                        {holiday.yomtov && <Star className="h-3 w-3 ml-1" />}
                        {holiday.name_hebrew || holiday.name}
                      </Badge>
                    ))}
                  </div>
                </div>
              </div>

              {/* Zmanim List - Vertical (filtered by day's events) */}
              {enabledZmanim.length > 0 && (
                <div className="divide-y divide-border">
                  {enabledZmanim
                    .filter((zman) => shouldShowEventZman(zman.zman_key, day))
                    .map((zman) => (
                    <div
                      key={zman.zman_key}
                      className="flex items-center justify-between px-4 py-2 hover:bg-muted/30 transition-colors"
                    >
                      <div className="flex items-center gap-2">
                        {zman.is_published ? (
                          <Eye className="h-3.5 w-3.5 text-green-400 shrink-0" />
                        ) : (
                          <EyeOff className="h-3.5 w-3.5 text-muted-foreground shrink-0" />
                        )}
                        <span className="text-sm text-foreground">
                          {zman.english_name}
                        </span>
                        {!zman.is_published && (
                          <span className="text-[10px] text-muted-foreground">(draft)</span>
                        )}
                      </div>
                      <div className={`font-mono text-sm font-medium ${
                        day.times[zman.zman_key] ? 'text-foreground' : 'text-muted-foreground'
                      }`}>
                        {formatTime(day.times[zman.zman_key])}
                      </div>
                    </div>
                  ))}
                </div>
              )}

              {/* No zmanim message */}
              {enabledZmanim.length === 0 && (
                <div className="px-4 py-3 text-sm text-muted-foreground">
                  No enabled zmanim to display
                </div>
              )}
            </div>
          ))}

          {/* Floating Scroll Navigation */}
          <div className="sticky bottom-0 left-0 right-0 flex justify-center gap-2 py-3 bg-gradient-to-t from-background via-background to-transparent">
            <Button
              variant="outline"
              size="sm"
              onClick={scrollToTop}
              disabled={currentDayIndex === 0}
              className="shadow-md"
            >
              <ChevronUp className="h-4 w-4 mr-1" />
              Top
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={scrollToPrevDay}
              disabled={currentDayIndex === 0}
              className="shadow-md"
            >
              <ChevronUp className="h-4 w-4" />
              Prev
            </Button>
            <div className="flex items-center px-3 text-sm text-muted-foreground">
              {weekData[currentDayIndex]?.dayName.slice(0, 3)} ({currentDayIndex + 1}/7)
            </div>
            <Button
              variant="outline"
              size="sm"
              onClick={scrollToNextDay}
              disabled={currentDayIndex === weekData.length - 1}
              className="shadow-md"
            >
              Next
              <ChevronDown className="h-4 w-4" />
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={scrollToBottom}
              disabled={currentDayIndex === weekData.length - 1}
              className="shadow-md"
            >
              Bottom
              <ChevronDown className="h-4 w-4 ml-1" />
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}
