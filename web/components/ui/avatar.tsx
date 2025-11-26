'use client';

import * as React from 'react';

interface AvatarProps {
  className?: string;
  children: React.ReactNode;
}

interface AvatarImageProps {
  src?: string | null;
  alt?: string;
  className?: string;
}

interface AvatarFallbackProps {
  children: React.ReactNode;
  className?: string;
}

export function Avatar({ className = '', children }: AvatarProps) {
  return (
    <div className={`relative inline-flex items-center justify-center overflow-hidden rounded-full bg-gray-100 ${className}`}>
      {children}
    </div>
  );
}

export function AvatarImage({ src, alt, className = '' }: AvatarImageProps) {
  const [error, setError] = React.useState(false);

  if (!src || error) {
    return null;
  }

  return (
    <img
      src={src}
      alt={alt}
      className={`w-full h-full object-cover ${className}`}
      onError={() => setError(true)}
    />
  );
}

export function AvatarFallback({ children, className = '' }: AvatarFallbackProps) {
  return (
    <span className={`flex items-center justify-center w-full h-full text-sm font-medium text-gray-600 ${className}`}>
      {children}
    </span>
  );
}
