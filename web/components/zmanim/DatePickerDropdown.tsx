'use client';

import { useState, useRef, useEffect } from 'react';
import { DateTime } from 'luxon';
import { Calendar, ChevronLeft, ChevronRight, ChevronDown } from 'lucide-react';
import { cn } from '@/lib/utils';
import { toHebrewDate, type HebrewDateInfo } from '@/lib/hebrew-date';

interface DatePickerDropdownProps {
  selectedDate: DateTime;
  onDateChange: (date: DateTime) => void;
  showHebrew: boolean;
  className?: string;
}

const WEEKDAY_NAMES = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const WEEKDAY_NAMES_HEBREW = ['א׳', 'ב׳', 'ג׳', 'ד׳', 'ה׳', 'ו׳', 'ש׳'];

export function DatePickerDropdown({
  selectedDate,
  onDateChange,
  showHebrew,
  className,
}: DatePickerDropdownProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [viewDate, setViewDate] = useState(selectedDate);
  const dropdownRef = useRef<HTMLDivElement>(null);

  // Close dropdown when clicking outside
  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  // Update view date when selected date changes
  useEffect(() => {
    setViewDate(selectedDate);
  }, [selectedDate]);

  const hebrewDate = toHebrewDate(selectedDate.toJSDate());

  // Get calendar days for the current view month
  const getCalendarDays = () => {
    const firstDayOfMonth = viewDate.startOf('month');
    const lastDayOfMonth = viewDate.endOf('month');
    const startDay = firstDayOfMonth.weekday % 7; // 0 = Sunday
    const daysInMonth = lastDayOfMonth.day;

    const days: (DateTime | null)[] = [];

    // Add empty slots for days before the first of the month
    for (let i = 0; i < startDay; i++) {
      days.push(null);
    }

    // Add the days of the month
    for (let i = 1; i <= daysInMonth; i++) {
      days.push(viewDate.set({ day: i }));
    }

    return days;
  };

  const handlePrevMonth = () => {
    setViewDate(viewDate.minus({ months: 1 }));
  };

  const handleNextMonth = () => {
    setViewDate(viewDate.plus({ months: 1 }));
  };

  const handleSelectDate = (date: DateTime) => {
    onDateChange(date);
    setIsOpen(false);
  };

  const handleToday = () => {
    const today = DateTime.now();
    onDateChange(today);
    setViewDate(today);
    setIsOpen(false);
  };

  const calendarDays = getCalendarDays();
  const weekdays = showHebrew ? WEEKDAY_NAMES_HEBREW : WEEKDAY_NAMES;

  return (
    <div className={cn('relative', className)} ref={dropdownRef}>
      {/* Trigger Button */}
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="flex items-center gap-2 px-3 py-2 rounded-lg hover:bg-stone-200 dark:hover:bg-zinc-700 transition-colors group"
      >
        <Calendar className="w-4 h-4 text-stone-500 dark:text-zinc-500" />
        <div className="text-center">
          {showHebrew ? (
            <div className="flex items-center gap-2">
              <span className="text-base sm:text-lg font-semibold text-stone-800 dark:text-zinc-100 font-hebrew" dir="rtl">
                {hebrewDate.formatted}
              </span>
              <span className="text-stone-300 dark:text-zinc-600">•</span>
              <span className="text-sm text-stone-500 dark:text-zinc-400">
                {selectedDate.toFormat('MMM d')}
              </span>
            </div>
          ) : (
            <span className="text-base sm:text-lg font-semibold text-stone-800 dark:text-zinc-100">
              {selectedDate.toFormat('EEEE, MMMM d, yyyy')}
            </span>
          )}
        </div>
        <ChevronDown className={cn(
          'w-4 h-4 text-stone-400 transition-transform',
          isOpen && 'rotate-180'
        )} />
      </button>

      {/* Dropdown */}
      {isOpen && (
        <div className="absolute top-full left-1/2 -translate-x-1/2 mt-2 z-50 w-[320px] bg-white dark:bg-zinc-800 rounded-xl shadow-2xl border border-stone-200 dark:border-zinc-700 overflow-hidden animate-in fade-in slide-in-from-top-2 duration-200">
          {/* Month Navigation */}
          <div className="flex items-center justify-between p-3 border-b border-stone-200 dark:border-zinc-700 bg-stone-50 dark:bg-zinc-750">
            <button
              onClick={handlePrevMonth}
              className="p-2 hover:bg-stone-200 dark:hover:bg-zinc-700 rounded-full transition-colors"
              aria-label="Previous month"
            >
              <ChevronLeft className="w-4 h-4 text-stone-600 dark:text-zinc-400" />
            </button>

            <div className="text-center">
              <div className="font-semibold text-stone-800 dark:text-zinc-100">
                {viewDate.toFormat('MMMM yyyy')}
              </div>
              {showHebrew && (
                <div className="text-xs text-stone-500 dark:text-zinc-400 font-hebrew" dir="rtl">
                  {toHebrewDate(viewDate.toJSDate()).monthHebrew} {toHebrewDate(viewDate.toJSDate()).yearHebrew}
                </div>
              )}
            </div>

            <button
              onClick={handleNextMonth}
              className="p-2 hover:bg-stone-200 dark:hover:bg-zinc-700 rounded-full transition-colors"
              aria-label="Next month"
            >
              <ChevronRight className="w-4 h-4 text-stone-600 dark:text-zinc-400" />
            </button>
          </div>

          {/* Calendar Grid */}
          <div className="p-3">
            {/* Weekday Headers */}
            <div className={cn(
              'grid grid-cols-7 mb-2',
              showHebrew && 'direction-rtl'
            )} dir={showHebrew ? 'rtl' : 'ltr'}>
              {weekdays.map((day, i) => (
                <div
                  key={i}
                  className="text-center text-xs font-medium text-stone-500 dark:text-zinc-400 py-1"
                >
                  {day}
                </div>
              ))}
            </div>

            {/* Days Grid */}
            <div className={cn(
              'grid grid-cols-7 gap-1',
              showHebrew && 'direction-rtl'
            )} dir={showHebrew ? 'rtl' : 'ltr'}>
              {calendarDays.map((day, i) => {
                if (!day) {
                  return <div key={`empty-${i}`} className="h-9" />;
                }

                const isSelected = day.hasSame(selectedDate, 'day');
                const isToday = day.hasSame(DateTime.now(), 'day');
                const dayHebrewInfo = showHebrew ? toHebrewDate(day.toJSDate()) : null;

                return (
                  <button
                    key={day.toISODate()}
                    onClick={() => handleSelectDate(day)}
                    className={cn(
                      'h-9 flex flex-col items-center justify-center rounded-lg text-sm transition-all',
                      'hover:bg-indigo-100 dark:hover:bg-indigo-900/50',
                      isSelected && 'bg-indigo-600 text-white hover:bg-indigo-700 dark:hover:bg-indigo-700',
                      isToday && !isSelected && 'ring-2 ring-indigo-400 ring-inset',
                      !isSelected && 'text-stone-700 dark:text-zinc-200'
                    )}
                  >
                    {showHebrew ? (
                      <>
                        <span className="text-[10px] leading-none opacity-60">{day.day}</span>
                        <span className="text-xs font-hebrew leading-none">{dayHebrewInfo?.dayHebrew}</span>
                      </>
                    ) : (
                      <span>{day.day}</span>
                    )}
                  </button>
                );
              })}
            </div>
          </div>

          {/* Footer with Today button */}
          <div className="p-2 border-t border-stone-200 dark:border-zinc-700 bg-stone-50 dark:bg-zinc-750 flex justify-center">
            <button
              onClick={handleToday}
              className="px-4 py-1.5 text-sm font-medium text-indigo-600 dark:text-indigo-400 hover:bg-indigo-100 dark:hover:bg-indigo-900/30 rounded-lg transition-colors"
            >
              Today
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

export default DatePickerDropdown;
