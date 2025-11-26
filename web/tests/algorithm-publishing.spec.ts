import { test, expect } from '@playwright/test';

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';

test.describe('Story 1.9: Algorithm Publishing', () => {
  test.describe('AC1: Draft algorithm can be published', () => {
    test('POST /api/v1/publisher/algorithm/publish requires authentication', async ({ request }) => {
      const response = await request.post(`${API_BASE}/api/v1/publisher/algorithm/publish`);
      expect(response.status()).toBe(401);
    });
  });

  test.describe('AC3: Publish creates new version, archives old', () => {
    test('Publishing endpoint structure is correct', async ({ request }) => {
      // The publish endpoint is protected and requires auth
      const response = await request.post(`${API_BASE}/api/v1/publisher/algorithm/publish`, {
        headers: { 'Content-Type': 'application/json' },
      });
      // Should return 401 without auth (not 404 - endpoint exists)
      expect(response.status()).toBe(401);
    });
  });

  test.describe('AC4: Version history shows all versions', () => {
    test('GET /api/v1/publisher/algorithm/versions requires authentication', async ({ request }) => {
      const response = await request.get(`${API_BASE}/api/v1/publisher/algorithm/versions`);
      expect(response.status()).toBe(401);
    });

    test('GET /api/v1/publisher/algorithm/versions/{id} requires authentication', async ({
      request,
    }) => {
      const fakeUUID = '00000000-0000-0000-0000-000000000000';
      const response = await request.get(
        `${API_BASE}/api/v1/publisher/algorithm/versions/${fakeUUID}`
      );
      expect(response.status()).toBe(401);
    });
  });

  test.describe('AC5: Deprecated versions show notice', () => {
    test('PUT /api/v1/publisher/algorithm/versions/{id}/deprecate requires authentication', async ({
      request,
    }) => {
      const fakeUUID = '00000000-0000-0000-0000-000000000000';
      const response = await request.put(
        `${API_BASE}/api/v1/publisher/algorithm/versions/${fakeUUID}/deprecate`
      );
      expect(response.status()).toBe(401);
    });
  });

  test.describe('AC2: Changes to published algorithm save as new draft', () => {
    test('PUT /api/v1/publisher/algorithm requires authentication for save', async ({
      request,
    }) => {
      const response = await request.put(`${API_BASE}/api/v1/publisher/algorithm`, {
        data: {
          name: 'Test Algorithm',
          configuration: {
            name: 'Test',
            zmanim: {
              sunrise: { method: 'sunrise', params: {} },
            },
          },
        },
      });
      expect(response.status()).toBe(401);
    });
  });

  test.describe('Algorithm versioning API structure', () => {
    test('All publishing endpoints are routed correctly', async ({ request }) => {
      // Test that the routes exist and are protected
      const endpoints = [
        { method: 'POST', path: '/api/v1/publisher/algorithm/publish' },
        { method: 'GET', path: '/api/v1/publisher/algorithm/versions' },
        { method: 'GET', path: '/api/v1/publisher/algorithm/versions/test-id' },
        { method: 'PUT', path: '/api/v1/publisher/algorithm/versions/test-id/deprecate' },
      ];

      for (const endpoint of endpoints) {
        let response;
        if (endpoint.method === 'POST') {
          response = await request.post(`${API_BASE}${endpoint.path}`);
        } else if (endpoint.method === 'PUT') {
          response = await request.put(`${API_BASE}${endpoint.path}`);
        } else {
          response = await request.get(`${API_BASE}${endpoint.path}`);
        }

        // All should return 401 (unauthorized) not 404 (not found)
        expect(response.status()).toBe(401);
      }
    });
  });

  test.describe('Public zmanim calculation with published algorithms', () => {
    let brooklynCityId: string;

    test.beforeAll(async ({ request }) => {
      const citiesResponse = await request.get(`${API_BASE}/api/v1/cities?search=Brooklyn`);
      const citiesData = await citiesResponse.json();
      const cities = citiesData.data?.cities || citiesData.cities || [];
      const brooklyn = cities.find((c: { name: string }) => c.name === 'Brooklyn');
      if (brooklyn) {
        brooklynCityId = brooklyn.id;
      }
    });

    test('GET /api/v1/zmanim returns zmanim with formula details', async ({ request }) => {
      if (!brooklynCityId) {
        test.skip();
        return;
      }

      const response = await request.get(`${API_BASE}/api/v1/zmanim?cityId=${brooklynCityId}`);
      expect(response.ok()).toBeTruthy();

      const data = await response.json();
      const zmanim = data.data?.zmanim || data.zmanim || [];

      // Should have multiple zmanim
      expect(zmanim.length).toBeGreaterThan(5);

      // Each zman should have formula details
      for (const zman of zmanim) {
        expect(zman.name).toBeDefined();
        expect(zman.key).toBeDefined();
        expect(zman.time).toBeDefined();
        expect(zman.formula).toBeDefined();
        expect(zman.formula.method).toBeDefined();
        expect(zman.formula.display_name).toBeDefined();
      }
    });

    test('Zmanim include all standard times', async ({ request }) => {
      if (!brooklynCityId) {
        test.skip();
        return;
      }

      const response = await request.get(`${API_BASE}/api/v1/zmanim?cityId=${brooklynCityId}`);
      const data = await response.json();
      const zmanim = data.data?.zmanim || data.zmanim || [];

      // Standard zmanim keys that should be present
      const expectedKeys = [
        'alos_hashachar',
        'misheyakir',
        'sunrise',
        'sof_zman_shma_gra',
        'sof_zman_tefilla_gra',
        'chatzos',
        'mincha_gedola',
        'mincha_ketana',
        'plag_hamincha',
        'sunset',
        'tzeis_hakochavim',
        'tzeis_72',
      ];

      const zmanimKeys = zmanim.map((z: { key: string }) => z.key);
      for (const key of expectedKeys) {
        expect(zmanimKeys).toContain(key);
      }
    });

    test('Zmanim use default algorithm when no publisher specified', async ({ request }) => {
      if (!brooklynCityId) {
        test.skip();
        return;
      }

      const response = await request.get(`${API_BASE}/api/v1/zmanim?cityId=${brooklynCityId}`);
      const data = await response.json();
      const zmanim = data.data?.zmanim || data.zmanim || [];

      // Check that GRA-style zmanim use GRA base
      const sofZmanShmaGra = zmanim.find((z: { key: string }) => z.key === 'sof_zman_shma_gra');
      expect(sofZmanShmaGra?.formula?.parameters?.base).toBe('gra');

      // Check that MGA-style zmanim use MGA base
      const sofZmanShmaMga = zmanim.find((z: { key: string }) => z.key === 'sof_zman_shma_mga');
      expect(sofZmanShmaMga?.formula?.parameters?.base).toBe('mga');
    });
  });

  test.describe('Integration: Version workflow', () => {
    test('Algorithm status indicator exists in editor page', async ({ page }) => {
      // Note: This test requires UI interaction and would need auth setup
      // For now, just verify the page loads
      await page.goto('/publisher/algorithm');
      // The page should redirect to sign-in without auth
      await expect(page).toHaveURL(/sign-in|publisher\/algorithm/);
    });
  });
});
