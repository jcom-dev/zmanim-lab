'use client';

import { Sun, Clock, Scale, Star } from 'lucide-react';
import { cn } from '@/lib/utils';
import type { MethodType } from './types';

interface MethodCardProps {
  method: MethodType;
  title: string;
  description: string;
  selected: boolean;
  onSelect: () => void;
  children?: React.ReactNode;
}

const methodIcons: Record<string, React.ReactNode> = {
  solar: <Sun className="h-6 w-6" />,
  fixed: <Clock className="h-6 w-6" />,
  proportional: <Scale className="h-6 w-6" />,
  fixed_zman: <Star className="h-6 w-6" />,
};

export function MethodCard({
  method,
  title,
  description,
  selected,
  onSelect,
  children,
}: MethodCardProps) {
  return (
    <div
      className={cn(
        'relative rounded-lg border-2 transition-all cursor-pointer',
        selected
          ? 'border-primary bg-primary/5 shadow-md'
          : 'border-border bg-card hover:border-primary/50'
      )}
      onClick={onSelect}
    >
      <div className="p-4">
        <div className="flex items-center gap-3">
          <div
            className={cn(
              'p-2 rounded-lg transition-colors',
              selected ? 'bg-primary text-primary-foreground' : 'bg-muted text-muted-foreground'
            )}
          >
            {method && methodIcons[method]}
          </div>
          <div>
            <h3 className="font-semibold">{title}</h3>
            <p className="text-sm text-muted-foreground">{description}</p>
          </div>
        </div>

        {/* Expandable parameters section */}
        {selected && children && (
          <div className="mt-4 pt-4 border-t border-border animate-in slide-in-from-top-2 duration-200">
            {children}
          </div>
        )}
      </div>
    </div>
  );
}

export default MethodCard;
