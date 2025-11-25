'use client';

import { useState } from 'react';
import { DateTime } from 'luxon';

interface DatePickerProps {
  onDateChange: (date: DateTime) => void;
}

export default function DatePicker({ onDateChange }: DatePickerProps) {
  const [selectedDate, setSelectedDate] = useState(
    DateTime.now().toISODate() || ''
  );

  const handleDateChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const dateString = e.target.value;
    setSelectedDate(dateString);

    const date = DateTime.fromISO(dateString);
    if (date.isValid) {
      onDateChange(date);
    }
  };

  const handleToday = () => {
    const today = DateTime.now();
    setSelectedDate(today.toISODate() || '');
    onDateChange(today);
  };

  const formatDisplayDate = (): string => {
    const date = DateTime.fromISO(selectedDate);
    if (!date.isValid) return '';

    return date.toLocaleString({
      weekday: 'long',
      month: 'long',
      day: 'numeric',
      year: 'numeric',
    });
  };

  return (
    <div className="bg-white rounded-2xl shadow-apple p-6 md:p-8 border border-apple-gray-200">
      <h2 className="text-xl font-semibold text-apple-gray-900 mb-6 flex items-center">
        <svg
          className="w-5 h-5 mr-2 text-apple-blue"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
          />
        </svg>
        Date
      </h2>

      <div className="space-y-4">
        {/* Date Input */}
        <div>
          <label
            htmlFor="date"
            className="block text-sm font-medium text-apple-gray-700 mb-2"
          >
            Select Date
          </label>
          <input
            id="date"
            type="date"
            value={selectedDate}
            onChange={handleDateChange}
            className="
              w-full px-4 py-2.5 rounded-xl
              border border-apple-gray-300
              focus:border-apple-blue focus:ring-2 focus:ring-apple-blue/20
              transition-all duration-200 outline-none
              text-apple-gray-900 font-normal text-[15px]
            "
          />
        </div>

        {/* Display formatted date */}
        <div className="bg-apple-gray-50 rounded-xl p-4 border border-apple-gray-200">
          <p className="text-xs text-apple-gray-500 mb-1 font-medium">Selected Date</p>
          <p className="text-base font-medium text-apple-gray-900">
            {formatDisplayDate()}
          </p>
        </div>

        {/* Quick action button */}
        <button
          type="button"
          onClick={handleToday}
          className="
            w-full bg-apple-blue hover:bg-[#0051D5]
            text-white font-medium py-2.5 px-5 rounded-xl
            transition-all duration-200
            shadow-sm hover:shadow-md
            flex items-center justify-center
          "
        >
          <svg
            className="w-4 h-4 mr-2"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
            />
          </svg>
          Today
        </button>
      </div>
    </div>
  );
}
