'use client';

import * as React from 'react';
import { ChevronDown, Check } from 'lucide-react';
import { cn } from '@/lib/utils';

interface SelectOption {
  value: string;
  label: string;
  description?: string;
  disabled?: boolean;
}

interface SelectGroup {
  label: string;
  options: SelectOption[];
}

interface SelectProps {
  value: string;
  onChange: (value: string) => void;
  options?: SelectOption[];
  groups?: SelectGroup[];
  placeholder?: string;
  disabled?: boolean;
  className?: string;
}

export function Select({
  value,
  onChange,
  options,
  groups,
  placeholder = 'Select...',
  disabled = false,
  className,
}: SelectProps) {
  const [open, setOpen] = React.useState(false);
  const containerRef = React.useRef<HTMLDivElement>(null);

  // Close on click outside
  React.useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (containerRef.current && !containerRef.current.contains(event.target as Node)) {
        setOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  // Get selected option label
  const allOptions = groups
    ? groups.flatMap((g) => g.options)
    : options || [];
  const selectedOption = allOptions.find((o) => o.value === value);

  const handleSelect = (optionValue: string) => {
    onChange(optionValue);
    setOpen(false);
  };

  const renderOption = (option: SelectOption) => (
    <button
      key={option.value}
      type="button"
      onClick={() => !option.disabled && handleSelect(option.value)}
      className={cn(
        'w-full flex items-center justify-between px-3 py-2 text-left text-sm transition-colors',
        'hover:bg-accent hover:text-accent-foreground',
        option.value === value && 'bg-accent',
        option.disabled && 'opacity-50 cursor-not-allowed'
      )}
    >
      <div>
        <div>{option.label}</div>
        {option.description && (
          <div className="text-xs text-muted-foreground">{option.description}</div>
        )}
      </div>
      {option.value === value && <Check className="h-4 w-4" />}
    </button>
  );

  return (
    <div ref={containerRef} className={cn('relative', className)}>
      <button
        type="button"
        onClick={() => !disabled && setOpen(!open)}
        className={cn(
          'flex h-10 w-full items-center justify-between rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background',
          'focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2',
          disabled && 'cursor-not-allowed opacity-50'
        )}
      >
        <span className={cn(!selectedOption && 'text-muted-foreground')}>
          {selectedOption?.label || placeholder}
        </span>
        <ChevronDown className={cn('h-4 w-4 transition-transform', open && 'rotate-180')} />
      </button>

      {open && (
        <div className="absolute z-50 mt-1 w-full rounded-md border bg-popover text-popover-foreground shadow-md animate-in fade-in-0 zoom-in-95">
          <div className="max-h-60 overflow-auto py-1">
            {groups ? (
              groups.map((group) => (
                <div key={group.label}>
                  <div className="px-3 py-1.5 text-xs font-semibold text-muted-foreground">
                    {group.label}
                  </div>
                  {group.options.map(renderOption)}
                </div>
              ))
            ) : (
              options?.map(renderOption)
            )}
          </div>
        </div>
      )}
    </div>
  );
}

export default Select;
