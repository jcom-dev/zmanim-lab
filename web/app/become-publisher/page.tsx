'use client';

import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import Link from 'next/link';
import { API_BASE } from '@/lib/api';

interface FormData {
  name: string;
  organization: string;
  email: string;
  website: string;
  description: string;
}

interface FormErrors {
  name?: string;
  organization?: string;
  email?: string;
  description?: string;
}

export default function BecomePublisherPage() {
  const [formData, setFormData] = useState<FormData>({
    name: '',
    organization: '',
    email: '',
    website: '',
    description: '',
  });
  const [errors, setErrors] = useState<FormErrors>({});
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitted, setSubmitted] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

  const validateForm = (): boolean => {
    const newErrors: FormErrors = {};

    if (!formData.name.trim()) {
      newErrors.name = 'Name is required';
    }
    if (!formData.organization.trim()) {
      newErrors.organization = 'Organization is required';
    }
    if (!formData.email.trim()) {
      newErrors.email = 'Email is required';
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email)) {
      newErrors.email = 'Please enter a valid email address';
    }
    // Description is optional, but if provided must be at least 10 characters
    if (formData.description.trim() && formData.description.trim().length < 10) {
      newErrors.description = 'Please provide at least 10 characters if adding a description';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitError(null);

    if (!validateForm()) {
      return;
    }

    setIsSubmitting(true);

    try {
      const response = await fetch(`${API_BASE}/api/v1/publisher-requests`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          name: formData.name.trim(),
          organization: formData.organization.trim(),
          email: formData.email.trim().toLowerCase(),
          website: formData.website.trim() || null,
          description: formData.description.trim(),
        }),
      });

      const data = await response.json();

      if (!response.ok) {
        if (response.status === 409) {
          setSubmitError(data.message || 'A request for this email is already pending or has been processed.');
        } else if (data.details) {
          // Server validation errors
          const serverErrors: FormErrors = {};
          Object.entries(data.details).forEach(([key, value]) => {
            serverErrors[key as keyof FormErrors] = value as string;
          });
          setErrors(serverErrors);
        } else {
          setSubmitError(data.message || 'Failed to submit request. Please try again.');
        }
        return;
      }

      setSubmitted(true);
    } catch {
      setSubmitError('Network error. Please check your connection and try again.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
    // Clear error when user starts typing
    if (errors[name as keyof FormErrors]) {
      setErrors((prev) => ({ ...prev, [name]: undefined }));
    }
  };

  if (submitted) {
    return (
      <div className="min-h-screen bg-gradient-to-b from-background to-background py-12 px-4">
        <div className="container mx-auto max-w-lg">
          <Card className="border-green-200 bg-green-50 dark:border-green-700 dark:bg-green-950">
            <CardHeader className="text-center">
              <div className="w-16 h-16 bg-green-100 dark:bg-green-900 rounded-full flex items-center justify-center mx-auto mb-4">
                <svg
                  className="w-8 h-8 text-green-600 dark:text-green-400"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M5 13l4 4L19 7"
                  />
                </svg>
              </div>
              <CardTitle className="text-green-800 dark:text-green-200">Request Submitted!</CardTitle>
              <CardDescription className="text-green-700 dark:text-green-300">
                Thank you for your interest in becoming a publisher on Zmanim Lab.
              </CardDescription>
            </CardHeader>
            <CardContent className="text-center">
              <p className="text-green-700 dark:text-green-300 mb-6">
                We&apos;ll review your application and get back to you soon. You&apos;ll receive an email
                notification once your request has been processed.
              </p>
              <Link href="/">
                <Button variant="outline" className="border-green-600 text-green-700 dark:border-green-400 dark:text-green-300 hover:bg-green-100 dark:hover:bg-green-900">
                  Return to Home
                </Button>
              </Link>
            </CardContent>
          </Card>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-b from-background to-background py-12 px-4">
      <div className="container mx-auto max-w-2xl">
        {/* Header */}
        <div className="text-center mb-8">
          <Link href="/" className="text-2xl font-bold text-primary mb-4 inline-block">
            Zmanim Lab
          </Link>
          <h1 className="text-3xl font-bold text-foreground mt-4">Become a Publisher</h1>
          <p className="text-muted-foreground mt-2">
            Join our network of trusted religious authorities providing accurate zmanim calculations
          </p>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>Publisher Application</CardTitle>
            <CardDescription>
              Fill in your details below. We review all applications carefully to ensure the highest
              quality for our users.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-6">
              {submitError && (
                <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-md">
                  {submitError}
                </div>
              )}

              {/* Name */}
              <div>
                <label htmlFor="name" className="block text-sm font-medium mb-1">
                  Your Name <span className="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  id="name"
                  name="name"
                  value={formData.name}
                  onChange={handleChange}
                  className={`w-full px-4 py-2 border rounded-md bg-background text-foreground focus:outline-none focus:ring-2 focus:ring-primary ${
                    errors.name ? 'border-red-500' : 'border-border'
                  }`}
                  placeholder="Rabbi Abraham Cohen"
                />
                {errors.name && <p className="mt-1 text-sm text-red-500">{errors.name}</p>}
              </div>

              {/* Organization */}
              <div>
                <label htmlFor="organization" className="block text-sm font-medium mb-1">
                  Organization <span className="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  id="organization"
                  name="organization"
                  value={formData.organization}
                  onChange={handleChange}
                  className={`w-full px-4 py-2 border rounded-md bg-background text-foreground focus:outline-none focus:ring-2 focus:ring-primary ${
                    errors.organization ? 'border-red-500' : 'border-border'
                  }`}
                  placeholder="Congregation Beth Israel"
                />
                {errors.organization && <p className="mt-1 text-sm text-red-500">{errors.organization}</p>}
              </div>

              {/* Email */}
              <div>
                <label htmlFor="email" className="block text-sm font-medium mb-1">
                  Email Address <span className="text-red-500">*</span>
                </label>
                <input
                  type="email"
                  id="email"
                  name="email"
                  value={formData.email}
                  onChange={handleChange}
                  className={`w-full px-4 py-2 border rounded-md bg-background text-foreground focus:outline-none focus:ring-2 focus:ring-primary ${
                    errors.email ? 'border-red-500' : 'border-border'
                  }`}
                  placeholder="rabbi@congregation.org"
                />
                {errors.email && <p className="mt-1 text-sm text-red-500">{errors.email}</p>}
              </div>

              {/* Website */}
              <div>
                <label htmlFor="website" className="block text-sm font-medium mb-1">
                  Website <span className="text-muted-foreground">(optional)</span>
                </label>
                <input
                  type="url"
                  id="website"
                  name="website"
                  value={formData.website}
                  onChange={handleChange}
                  className="w-full px-4 py-2 border border-border rounded-md bg-background text-foreground focus:outline-none focus:ring-2 focus:ring-primary"
                  placeholder="https://congregation.org"
                />
              </div>

              {/* Description */}
              <div>
                <label htmlFor="description" className="block text-sm font-medium mb-1">
                  About Your Organization <span className="text-red-500">*</span>
                </label>
                <textarea
                  id="description"
                  name="description"
                  value={formData.description}
                  onChange={handleChange}
                  rows={5}
                  className={`w-full px-4 py-2 border rounded-md bg-background text-foreground focus:outline-none focus:ring-2 focus:ring-primary ${
                    errors.description ? 'border-red-500' : 'border-border'
                  }`}
                  placeholder="Tell us about your community, the areas you serve, and your approach to zmanim calculations..."
                />
                {errors.description && <p className="mt-1 text-sm text-red-500">{errors.description}</p>}
                <p className="mt-1 text-sm text-muted-foreground">
                  {formData.description.length}/10 characters minimum
                </p>
              </div>

              {/* Submit */}
              <div className="flex justify-end gap-4 pt-4">
                <Link href="/">
                  <Button type="button" variant="outline">
                    Cancel
                  </Button>
                </Link>
                <Button type="submit" disabled={isSubmitting}>
                  {isSubmitting ? 'Submitting...' : 'Submit Application'}
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>

        {/* Info */}
        <div className="mt-8 text-center text-sm text-muted-foreground">
          <p>
            Already have an account?{' '}
            <Link href="/sign-in" className="text-blue-600 dark:text-blue-400 hover:underline">
              Sign in
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
}
