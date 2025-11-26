import { test, expect } from '@playwright/test';

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';

test.describe('Story 1.7: Calculation Engine & Caching', () => {
  // First, get a valid city ID
  let brooklynCityId: string;

  test.beforeAll(async ({ request }) => {
    const response = await request.get(`${API_BASE}/api/v1/cities?search=Brooklyn`);
    const data = await response.json();
    const cities = data.data?.cities || data.cities || [];
    const brooklyn = cities.find((c: { name: string }) => c.name === 'Brooklyn');
    if (brooklyn) {
      brooklynCityId = brooklyn.id;
    }
  });

  test.describe('AC1: System calculates all standard zmanim', () => {
    test('GET /api/v1/zmanim returns standard zmanim for a city', async ({ request }) => {
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

      // Check for standard zmanim
      const zmanKeys = zmanim.map((z: { key: string }) => z.key);
      expect(zmanKeys).toContain('sunrise');
      expect(zmanKeys).toContain('sunset');
    });

    test('zmanim response includes location info', async ({ request }) => {
      if (!brooklynCityId) {
        test.skip();
        return;
      }

      const response = await request.get(`${API_BASE}/api/v1/zmanim?cityId=${brooklynCityId}`);
      const data = await response.json();

      expect(data.location || data.data?.location).toBeDefined();
      const location = data.location || data.data?.location;
      expect(location.latitude).toBeDefined();
      expect(location.longitude).toBeDefined();
      expect(location.timezone).toBeDefined();
    });
  });

  test.describe('AC2: Solar angle method', () => {
    test('alos_hashachar calculated using solar angle', async ({ request }) => {
      if (!brooklynCityId) {
        test.skip();
        return;
      }

      const response = await request.get(`${API_BASE}/api/v1/zmanim?cityId=${brooklynCityId}`);
      const data = await response.json();
      const zmanim = data.data?.zmanim || data.zmanim || [];

      const alos = zmanim.find((z: { key: string }) => z.key === 'alos_hashachar');
      expect(alos).toBeDefined();
      expect(alos.time).toMatch(/^\d{2}:\d{2}:\d{2}$/);
      expect(alos.formula.method).toBe('solar_angle');
    });

    test('tzeis_hakochavim calculated using solar angle', async ({ request }) => {
      if (!brooklynCityId) {
        test.skip();
        return;
      }

      const response = await request.get(`${API_BASE}/api/v1/zmanim?cityId=${brooklynCityId}`);
      const data = await response.json();
      const zmanim = data.data?.zmanim || data.zmanim || [];

      const tzeis = zmanim.find((z: { key: string }) => z.key === 'tzeis_hakochavim');
      expect(tzeis).toBeDefined();
      expect(tzeis.formula.method).toBe('solar_angle');
    });
  });

  test.describe('AC3: Fixed minutes method', () => {
    test('tzeis_72 calculated using fixed minutes', async ({ request }) => {
      if (!brooklynCityId) {
        test.skip();
        return;
      }

      const response = await request.get(`${API_BASE}/api/v1/zmanim?cityId=${brooklynCityId}`);
      const data = await response.json();
      const zmanim = data.data?.zmanim || data.zmanim || [];

      const tzeis72 = zmanim.find((z: { key: string }) => z.key === 'tzeis_72');
      expect(tzeis72).toBeDefined();
      expect(tzeis72.formula.method).toBe('fixed_minutes');
      expect(tzeis72.formula.parameters.minutes).toBe(72);
    });
  });

  test.describe('AC4: Proportional method (GRA/MGA)', () => {
    test('sof_zman_shma_gra uses proportional GRA method', async ({ request }) => {
      if (!brooklynCityId) {
        test.skip();
        return;
      }

      const response = await request.get(`${API_BASE}/api/v1/zmanim?cityId=${brooklynCityId}`);
      const data = await response.json();
      const zmanim = data.data?.zmanim || data.zmanim || [];

      const sofZmanShmaGRA = zmanim.find((z: { key: string }) => z.key === 'sof_zman_shma_gra');
      expect(sofZmanShmaGRA).toBeDefined();
      expect(sofZmanShmaGRA.formula.method).toBe('proportional');
      expect(sofZmanShmaGRA.formula.parameters.base).toBe('gra');
      expect(sofZmanShmaGRA.formula.parameters.hours).toBe(3);
    });

    test('sof_zman_shma_mga uses proportional MGA method', async ({ request }) => {
      if (!brooklynCityId) {
        test.skip();
        return;
      }

      const response = await request.get(`${API_BASE}/api/v1/zmanim?cityId=${brooklynCityId}`);
      const data = await response.json();
      const zmanim = data.data?.zmanim || data.zmanim || [];

      const sofZmanShmaMGA = zmanim.find((z: { key: string }) => z.key === 'sof_zman_shma_mga');
      expect(sofZmanShmaMGA).toBeDefined();
      expect(sofZmanShmaMGA.formula.method).toBe('proportional');
      expect(sofZmanShmaMGA.formula.parameters.base).toBe('mga');
    });
  });

  test.describe('AC5: Formula details in response', () => {
    test('each zman includes formula details', async ({ request }) => {
      if (!brooklynCityId) {
        test.skip();
        return;
      }

      const response = await request.get(`${API_BASE}/api/v1/zmanim?cityId=${brooklynCityId}`);
      const data = await response.json();
      const zmanim = data.data?.zmanim || data.zmanim || [];

      for (const zman of zmanim) {
        expect(zman.formula).toBeDefined();
        expect(zman.formula.method).toBeDefined();
        expect(zman.formula.display_name).toBeDefined();
        expect(zman.formula.explanation).toBeDefined();
      }
    });

    test('formula explanation is human-readable', async ({ request }) => {
      if (!brooklynCityId) {
        test.skip();
        return;
      }

      const response = await request.get(`${API_BASE}/api/v1/zmanim?cityId=${brooklynCityId}`);
      const data = await response.json();
      const zmanim = data.data?.zmanim || data.zmanim || [];

      const alos = zmanim.find((z: { key: string }) => z.key === 'alos_hashachar');
      if (alos) {
        expect(alos.formula.explanation).toContain('below the horizon');
      }
    });
  });

  test.describe('API Validation', () => {
    test('GET /api/v1/zmanim requires cityId parameter', async ({ request }) => {
      const response = await request.get(`${API_BASE}/api/v1/zmanim`);
      expect(response.status()).toBe(400);
    });

    test('GET /api/v1/zmanim returns 404 for invalid cityId', async ({ request }) => {
      const response = await request.get(
        `${API_BASE}/api/v1/zmanim?cityId=00000000-0000-0000-0000-000000000000`
      );
      expect(response.status()).toBe(404);
    });

    test('GET /api/v1/zmanim accepts date parameter', async ({ request }) => {
      if (!brooklynCityId) {
        test.skip();
        return;
      }

      const response = await request.get(
        `${API_BASE}/api/v1/zmanim?cityId=${brooklynCityId}&date=2025-06-21`
      );
      expect(response.ok()).toBeTruthy();

      const data = await response.json();
      expect(data.date || data.data?.date).toBe('2025-06-21');
    });

    test('GET /api/v1/zmanim defaults to today if no date', async ({ request }) => {
      if (!brooklynCityId) {
        test.skip();
        return;
      }

      const today = new Date().toISOString().split('T')[0];
      const response = await request.get(`${API_BASE}/api/v1/zmanim?cityId=${brooklynCityId}`);
      expect(response.ok()).toBeTruthy();

      const data = await response.json();
      expect(data.date || data.data?.date).toBe(today);
    });
  });

  test.describe('Legacy POST Endpoint', () => {
    test('POST /api/v1/zmanim still works for backward compatibility', async ({ request }) => {
      const response = await request.post(`${API_BASE}/api/v1/zmanim`, {
        data: {
          date: '2025-11-26',
          latitude: 40.6782,
          longitude: -73.9442,
          timezone: 'America/New_York',
        },
      });
      expect(response.ok()).toBeTruthy();

      const data = await response.json();
      expect(data.zmanim || data.data?.zmanim).toBeDefined();
    });
  });

  test.describe('Cache Invalidation', () => {
    test('DELETE /api/v1/publisher/cache requires authentication', async ({ request }) => {
      const response = await request.delete(`${API_BASE}/api/v1/publisher/cache`);
      expect(response.status()).toBe(401);
    });
  });

  test.describe('Calculation Accuracy', () => {
    test('sunrise is before sunset', async ({ request }) => {
      if (!brooklynCityId) {
        test.skip();
        return;
      }

      const response = await request.get(`${API_BASE}/api/v1/zmanim?cityId=${brooklynCityId}`);
      const data = await response.json();
      const zmanim = data.data?.zmanim || data.zmanim || [];

      const sunrise = zmanim.find((z: { key: string }) => z.key === 'sunrise');
      const sunset = zmanim.find((z: { key: string }) => z.key === 'sunset');

      expect(sunrise).toBeDefined();
      expect(sunset).toBeDefined();

      // Compare times (HH:MM:SS format)
      expect(sunrise.time < sunset.time).toBeTruthy();
    });

    test('alos is before sunrise', async ({ request }) => {
      if (!brooklynCityId) {
        test.skip();
        return;
      }

      const response = await request.get(`${API_BASE}/api/v1/zmanim?cityId=${brooklynCityId}`);
      const data = await response.json();
      const zmanim = data.data?.zmanim || data.zmanim || [];

      const alos = zmanim.find((z: { key: string }) => z.key === 'alos_hashachar');
      const sunrise = zmanim.find((z: { key: string }) => z.key === 'sunrise');

      if (alos && sunrise) {
        expect(alos.time < sunrise.time).toBeTruthy();
      }
    });

    test('chatzos is between sunrise and sunset', async ({ request }) => {
      if (!brooklynCityId) {
        test.skip();
        return;
      }

      const response = await request.get(`${API_BASE}/api/v1/zmanim?cityId=${brooklynCityId}`);
      const data = await response.json();
      const zmanim = data.data?.zmanim || data.zmanim || [];

      const sunrise = zmanim.find((z: { key: string }) => z.key === 'sunrise');
      const chatzos = zmanim.find((z: { key: string }) => z.key === 'chatzos');
      const sunset = zmanim.find((z: { key: string }) => z.key === 'sunset');

      if (chatzos && sunrise && sunset) {
        expect(chatzos.time > sunrise.time).toBeTruthy();
        expect(chatzos.time < sunset.time).toBeTruthy();
      }
    });

    test('tzeis is after sunset', async ({ request }) => {
      if (!brooklynCityId) {
        test.skip();
        return;
      }

      const response = await request.get(`${API_BASE}/api/v1/zmanim?cityId=${brooklynCityId}`);
      const data = await response.json();
      const zmanim = data.data?.zmanim || data.zmanim || [];

      const sunset = zmanim.find((z: { key: string }) => z.key === 'sunset');
      const tzeis = zmanim.find((z: { key: string }) => z.key === 'tzeis_hakochavim');

      if (tzeis && sunset) {
        expect(tzeis.time > sunset.time).toBeTruthy();
      }
    });
  });
});
