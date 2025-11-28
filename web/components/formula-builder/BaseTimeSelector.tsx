'use client';

import { Select } from '@/components/ui/select';
import { baseTimeOptions } from './types';
import { cn } from '@/lib/utils';

interface BaseTimeSelectorProps {
  value: string;
  onChange: (value: string) => void;
  className?: string;
}

export function BaseTimeSelector({
  value,
  onChange,
  className,
}: BaseTimeSelectorProps) {
  return (
    <div className={cn('space-y-2', className)}>
      <label className="text-sm font-medium text-foreground">
        Base Time
      </label>
      <Select
        value={value}
        onChange={onChange}
        groups={baseTimeOptions}
        placeholder="Select base time..."
      />
      <p className="text-xs text-muted-foreground">
        Choose the reference point for your calculation
      </p>
    </div>
  );
}

export default BaseTimeSelector;
