import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

/**
 * Format time string to 12-hour AM/PM format with seconds
 * @param time - Time string in HH:MM:SS or HH:MM format
 * @returns Formatted time like "2:30:36 PM"
 */
export function formatTime(time: string): string {
  const [hours, minutes, seconds] = time.split(':').map(Number);
  const period = hours >= 12 ? 'PM' : 'AM';
  const hour12 = hours % 12 || 12;

  if (seconds !== undefined && !isNaN(seconds)) {
    return `${hour12}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')} ${period}`;
  }
  return `${hour12}:${minutes.toString().padStart(2, '0')} ${period}`;
}

/**
 * Format time string to 12-hour AM/PM format without seconds
 * @param time - Time string in HH:MM:SS or HH:MM format
 * @returns Formatted time like "2:30 PM"
 */
export function formatTimeShort(time: string): string {
  const [hours, minutes] = time.split(':').map(Number);
  const period = hours >= 12 ? 'PM' : 'AM';
  const hour12 = hours % 12 || 12;
  return `${hour12}:${minutes.toString().padStart(2, '0')} ${period}`;
}
