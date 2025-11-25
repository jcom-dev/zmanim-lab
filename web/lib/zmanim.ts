import { ComplexZmanimCalendar, GeoLocation } from 'kosher-zmanim';
import { DateTime } from 'luxon';

export interface AlosMethod {
  id: string;
  name: string;
  calculate: (calendar: ComplexZmanimCalendar) => DateTime | null;
  description: string;
  source: string;
  category: 'fixed' | 'zmaniyos' | 'angle';
  degrees?: number;
  minutes?: number;
}

/**
 * All Alos Hashachar calculation methods available in ComplexZmanimCalendar
 */
export const ALOS_METHODS: AlosMethod[] = [
  // Fixed Minutes Before Sunrise
  {
    id: 'alos-60',
    name: 'Alos 60 Minutes',
    calculate: (cal) => cal.getAlos60(),
    description: 'Dawn calculated as 60 minutes before sunrise',
    source: 'Various poskim',
    category: 'fixed',
    minutes: 60,
  },
  {
    id: 'alos-72',
    name: 'Alos 72 Minutes',
    calculate: (cal) => cal.getAlos72(),
    description: 'Dawn calculated as 72 minutes (4 mil) before sunrise',
    source: 'Magen Avraham',
    category: 'fixed',
    minutes: 72,
  },
  {
    id: 'alos-90',
    name: 'Alos 90 Minutes',
    calculate: (cal) => cal.getAlos90(),
    description: 'Dawn calculated as 90 minutes before sunrise',
    source: 'Some opinions',
    category: 'fixed',
    minutes: 90,
  },
  {
    id: 'alos-96',
    name: 'Alos 96 Minutes',
    calculate: (cal) => cal.getAlos96(),
    description: 'Dawn calculated as 96 minutes before sunrise',
    source: 'Some opinions',
    category: 'fixed',
    minutes: 96,
  },
  {
    id: 'alos-120',
    name: 'Alos 120 Minutes',
    calculate: (cal) => cal.getAlos120(),
    description: 'Dawn calculated as 120 minutes before sunrise',
    source: 'Some opinions',
    category: 'fixed',
    minutes: 120,
  },

  // Proportional Hours (Zmaniyos)
  {
    id: 'alos-72-zmanis',
    name: 'Alos 72 Zmaniyos',
    calculate: (cal) => cal.getAlos72Zmanis(),
    description: 'Dawn calculated as 72 seasonal minutes (1/10th of day) before sunrise',
    source: 'Based on seasonal hours',
    category: 'zmaniyos',
    minutes: 72,
  },
  {
    id: 'alos-90-zmanis',
    name: 'Alos 90 Zmaniyos',
    calculate: (cal) => cal.getAlos90Zmanis(),
    description: 'Dawn calculated as 90 seasonal minutes (1/8th of day) before sunrise',
    source: 'Based on seasonal hours',
    category: 'zmaniyos',
    minutes: 90,
  },
  {
    id: 'alos-96-zmanis',
    name: 'Alos 96 Zmaniyos',
    calculate: (cal) => cal.getAlos96Zmanis(),
    description: 'Dawn calculated as 96 seasonal minutes (1/7.5th of day) before sunrise',
    source: 'Based on seasonal hours',
    category: 'zmaniyos',
    minutes: 96,
  },

  // Solar Depression Angles
  {
    id: 'alos-16-1',
    name: 'Alos 16.1°',
    calculate: (cal) => cal.getAlos16Point1Degrees(),
    description: 'Dawn when sun is 16.1° below horizon',
    source: 'Based on calculations',
    category: 'angle',
    degrees: 16.1,
  },
  {
    id: 'alos-18',
    name: 'Alos 18°',
    calculate: (cal) => cal.getAlos18Degrees(),
    description: 'Dawn when sun is 18° below horizon',
    source: 'Astronomical dawn',
    category: 'angle',
    degrees: 18,
  },
  {
    id: 'alos-19-8',
    name: 'Alos 19.8°',
    calculate: (cal) => cal.getAlos19Point8Degrees(),
    description: 'Dawn when sun is 19.8° below horizon',
    source: 'Based on calculations',
    category: 'angle',
    degrees: 19.8,
  },
  {
    id: 'alos-26',
    name: 'Alos 26°',
    calculate: (cal) => cal.getAlos26Degrees(),
    description: 'Dawn when sun is 26° below horizon',
    source: 'Some opinions',
    category: 'angle',
    degrees: 26,
  },
  {
    id: 'alos-19',
    name: 'Alos 19°',
    calculate: (cal) => cal.getAlos19Degrees(),
    description: 'Dawn when sun is 19° below horizon',
    source: 'Based on calculations',
    category: 'angle',
    degrees: 19,
  },
];

/**
 * Calculate all Alos Hashachar times for a given location and date
 */
export const calculateAllAlosTimes = (
  geoLocation: GeoLocation,
  date: DateTime
): Map<string, DateTime | null> => {
  const calendar = new ComplexZmanimCalendar(geoLocation);

  // Set the date - convert Luxon DateTime to JS Date
  const jsDate = date.toJSDate();
  calendar.setDate(jsDate);

  const results = new Map<string, DateTime | null>();

  for (const method of ALOS_METHODS) {
    try {
      const result = method.calculate(calendar);
      results.set(method.id, result);
    } catch (error) {
      console.error(`Error calculating ${method.name}:`, error);
      results.set(method.id, null);
    }
  }

  return results;
};

/**
 * Get method by ID
 */
export const getMethodById = (id: string): AlosMethod | undefined => {
  return ALOS_METHODS.find((method) => method.id === id);
};

/**
 * Get methods by category
 */
export const getMethodsByCategory = (
  category: 'fixed' | 'zmaniyos' | 'angle'
): AlosMethod[] => {
  return ALOS_METHODS.filter((method) => method.category === category);
};
