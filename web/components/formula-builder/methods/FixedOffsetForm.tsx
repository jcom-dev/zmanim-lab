'use client';

import { Input } from '@/components/ui/input';
import { Select } from '@/components/ui/select';
import { Button } from '@/components/ui/button';
import type { OffsetDirection } from '../types';
import { baseTimeOptions } from '../types';

interface FixedOffsetFormProps {
  minutes: number;
  direction: OffsetDirection;
  base: string;
  onMinutesChange: (value: number) => void;
  onDirectionChange: (direction: OffsetDirection) => void;
  onBaseChange: (base: string) => void;
}

export function FixedOffsetForm({
  minutes,
  direction,
  base,
  onMinutesChange,
  onDirectionChange,
  onBaseChange,
}: FixedOffsetFormProps) {
  const hours = Math.floor(minutes / 60);
  const mins = minutes % 60;

  const handleHoursChange = (h: number) => {
    onMinutesChange(h * 60 + mins);
  };

  const handleMinutesChange = (m: number) => {
    onMinutesChange(hours * 60 + m);
  };

  return (
    <div className="space-y-4">
      {/* Duration input */}
      <div className="space-y-2">
        <label className="text-sm font-medium">Duration</label>
        <div className="flex gap-2 items-center">
          <div className="flex-1">
            <Input
              type="number"
              min={0}
              max={23}
              value={hours}
              onChange={(e) => handleHoursChange(parseInt(e.target.value) || 0)}
              onClick={(e) => e.stopPropagation()}
            />
            <span className="text-xs text-muted-foreground">hours</span>
          </div>
          <span className="text-lg">:</span>
          <div className="flex-1">
            <Input
              type="number"
              min={0}
              max={59}
              value={mins}
              onChange={(e) => handleMinutesChange(parseInt(e.target.value) || 0)}
              onClick={(e) => e.stopPropagation()}
            />
            <span className="text-xs text-muted-foreground">minutes</span>
          </div>
        </div>
        <p className="text-xs text-muted-foreground">
          Total: {minutes} minutes
        </p>
      </div>

      {/* Quick presets */}
      <div className="flex flex-wrap gap-2">
        {[18, 30, 45, 60, 72, 90].map((m) => (
          <Button
            key={m}
            variant={minutes === m ? 'default' : 'outline'}
            size="sm"
            onClick={(e) => {
              e.stopPropagation();
              onMinutesChange(m);
            }}
          >
            {m}min
          </Button>
        ))}
      </div>

      {/* Direction toggle */}
      <div className="space-y-2">
        <label className="text-sm font-medium">Direction</label>
        <div className="flex gap-2">
          <Button
            variant={direction === 'before' ? 'default' : 'outline'}
            size="sm"
            className="flex-1"
            onClick={(e) => {
              e.stopPropagation();
              onDirectionChange('before');
            }}
          >
            Before
          </Button>
          <Button
            variant={direction === 'after' ? 'default' : 'outline'}
            size="sm"
            className="flex-1"
            onClick={(e) => {
              e.stopPropagation();
              onDirectionChange('after');
            }}
          >
            After
          </Button>
        </div>
      </div>

      {/* Base time selection */}
      <div className="space-y-2" onClick={(e) => e.stopPropagation()}>
        <label className="text-sm font-medium">Base Time</label>
        <Select
          value={base}
          onChange={onBaseChange}
          groups={baseTimeOptions}
          placeholder="Select base time..."
        />
      </div>
    </div>
  );
}

export default FixedOffsetForm;
