import { test, expect } from '@playwright/test';

/**
 * Global Location System E2E Tests
 * Story 1.5: Global Location System
 *
 * Tests the city search API, nearby city lookup, and LocationPicker component.
 */

const API_BASE = 'http://localhost:8080';

test.describe('City Search API (AC: 1, 2, 3)', () => {
  test('GET /api/v1/cities should return autocomplete suggestions', async ({ page }) => {
    const response = await page.request.get(`${API_BASE}/api/v1/cities?search=new&limit=10`);

    expect(response.status()).toBe(200);

    const body = await response.json();
    const data = body.data || body;
    expect(data.cities).toBeDefined();
    expect(Array.isArray(data.cities)).toBe(true);
  });

  test('Search for "Brooklyn" should return Brooklyn, New York (AC: 2)', async ({ page }) => {
    const response = await page.request.get(`${API_BASE}/api/v1/cities?search=Brooklyn`);

    expect(response.status()).toBe(200);

    const body = await response.json();
    const data = body.data || body;
    const cities = data.cities || [];

    // Find Brooklyn in results
    const brooklyn = cities.find((c: { name: string; region: string; country: string }) =>
      c.name === 'Brooklyn' && c.region === 'New York' && c.country === 'United States'
    );

    expect(brooklyn).toBeDefined();
    expect(brooklyn.display_name).toContain('Brooklyn');
    expect(brooklyn.display_name).toContain('New York');
  });

  test('Search for "London" should return London, Greater London, UK (AC: 3)', async ({ page }) => {
    const response = await page.request.get(`${API_BASE}/api/v1/cities?search=London`);

    expect(response.status()).toBe(200);

    const body = await response.json();
    const data = body.data || body;
    const cities = data.cities || [];

    // Find London in results
    const london = cities.find((c: { name: string; country: string }) =>
      c.name === 'London' && c.country === 'United Kingdom'
    );

    expect(london).toBeDefined();
    expect(london.display_name).toContain('London');
    expect(london.display_name).toContain('United Kingdom');
  });

  test('Search with less than 2 characters should return empty results', async ({ page }) => {
    const response = await page.request.get(`${API_BASE}/api/v1/cities?search=a`);

    expect(response.status()).toBe(200);

    const body = await response.json();
    const data = body.data || body;
    expect(data.cities).toBeDefined();
    expect(data.cities.length).toBe(0);
  });

  test('Search should respect limit parameter', async ({ page }) => {
    const response = await page.request.get(`${API_BASE}/api/v1/cities?search=san&limit=3`);

    expect(response.status()).toBe(200);

    const body = await response.json();
    const data = body.data || body;
    expect(data.cities.length).toBeLessThanOrEqual(3);
  });

  test('Search should return cities with required fields', async ({ page }) => {
    const response = await page.request.get(`${API_BASE}/api/v1/cities?search=Jerusalem`);

    expect(response.status()).toBe(200);

    const body = await response.json();
    const data = body.data || body;
    const cities = data.cities || [];

    if (cities.length > 0) {
      const city = cities[0];
      expect(city.id).toBeDefined();
      expect(city.name).toBeDefined();
      expect(city.country).toBeDefined();
      expect(city.country_code).toBeDefined();
      expect(city.latitude).toBeDefined();
      expect(city.longitude).toBeDefined();
      expect(city.timezone).toBeDefined();
      expect(city.display_name).toBeDefined();
    }
  });
});

test.describe('Reverse Geocoding API (AC: 4)', () => {
  test('GET /api/v1/cities/nearby should return nearest city', async ({ page }) => {
    // Coordinates for Jerusalem
    const lat = 31.7683;
    const lng = 35.2137;

    const response = await page.request.get(`${API_BASE}/api/v1/cities/nearby?lat=${lat}&lng=${lng}`);

    expect(response.status()).toBe(200);

    const body = await response.json();
    const data = body.data || body;
    expect(data.city).toBeDefined();
    expect(data.city.name).toBe('Jerusalem');
    expect(data.distance_km).toBeDefined();
  });

  test('GET /api/v1/cities/nearby for New York coordinates', async ({ page }) => {
    // Coordinates for New York
    const lat = 40.7128;
    const lng = -74.0060;

    const response = await page.request.get(`${API_BASE}/api/v1/cities/nearby?lat=${lat}&lng=${lng}`);

    expect(response.status()).toBe(200);

    const body = await response.json();
    const data = body.data || body;
    expect(data.city).toBeDefined();
    expect(data.city.country_code).toBe('US');
  });

  test('GET /api/v1/cities/nearby should fail with missing lat', async ({ page }) => {
    const response = await page.request.get(`${API_BASE}/api/v1/cities/nearby?lng=35`);

    expect(response.status()).toBe(400);
  });

  test('GET /api/v1/cities/nearby should fail with missing lng', async ({ page }) => {
    const response = await page.request.get(`${API_BASE}/api/v1/cities/nearby?lat=31`);

    expect(response.status()).toBe(400);
  });

  test('GET /api/v1/cities/nearby should fail with invalid lat', async ({ page }) => {
    const response = await page.request.get(`${API_BASE}/api/v1/cities/nearby?lat=100&lng=35`);

    expect(response.status()).toBe(400);
  });
});

test.describe('Global Cities Coverage (AC: 5)', () => {
  test('Should have cities from multiple countries', async ({ page }) => {
    // Test US
    let response = await page.request.get(`${API_BASE}/api/v1/cities?search=Chicago`);
    let body = await response.json();
    let data = body.data || body;
    expect(data.cities.some((c: { country_code: string }) => c.country_code === 'US')).toBe(true);

    // Test UK
    response = await page.request.get(`${API_BASE}/api/v1/cities?search=Manchester`);
    body = await response.json();
    data = body.data || body;
    expect(data.cities.some((c: { country_code: string }) => c.country_code === 'GB')).toBe(true);

    // Test Israel
    response = await page.request.get(`${API_BASE}/api/v1/cities?search=Tel Aviv`);
    body = await response.json();
    data = body.data || body;
    expect(data.cities.some((c: { country_code: string }) => c.country_code === 'IL')).toBe(true);

    // Test Canada
    response = await page.request.get(`${API_BASE}/api/v1/cities?search=Toronto`);
    body = await response.json();
    data = body.data || body;
    expect(data.cities.some((c: { country_code: string }) => c.country_code === 'CA')).toBe(true);

    // Test Australia
    response = await page.request.get(`${API_BASE}/api/v1/cities?search=Sydney`);
    body = await response.json();
    data = body.data || body;
    expect(data.cities.some((c: { country_code: string }) => c.country_code === 'AU')).toBe(true);
  });

  test('Cities should have locale-appropriate region types (AC: 5)', async ({ page }) => {
    // US should have "state"
    let response = await page.request.get(`${API_BASE}/api/v1/cities?search=Los Angeles`);
    let body = await response.json();
    let data = body.data || body;
    const laCity = data.cities.find((c: { name: string }) => c.name === 'Los Angeles');
    expect(laCity?.region_type).toBe('state');

    // UK should have "county" or "region"
    response = await page.request.get(`${API_BASE}/api/v1/cities?search=London`);
    body = await response.json();
    data = body.data || body;
    const london = data.cities.find((c: { name: string; country_code: string }) => c.name === 'London' && c.country_code === 'GB');
    expect(['county', 'region']).toContain(london?.region_type);

    // Israel should have "district"
    response = await page.request.get(`${API_BASE}/api/v1/cities?search=Jerusalem`);
    body = await response.json();
    data = body.data || body;
    const jerusalem = data.cities.find((c: { name: string; country_code: string }) => c.name === 'Jerusalem' && c.country_code === 'IL');
    expect(jerusalem?.region_type).toBe('district');

    // Canada should have "province"
    response = await page.request.get(`${API_BASE}/api/v1/cities?search=Toronto`);
    body = await response.json();
    data = body.data || body;
    const toronto = data.cities.find((c: { name: string }) => c.name === 'Toronto');
    expect(toronto?.region_type).toBe('province');
  });
});

test.describe('API Health Check', () => {
  test('GET /health should return 200', async ({ page }) => {
    const response = await page.request.get(`${API_BASE}/health`);

    expect(response.status()).toBe(200);

    const body = await response.json();
    expect(body.data.status).toBe('ok');
  });
});
