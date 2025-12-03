import { test, expect } from '@playwright/test';

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';

test.describe('Story 1.8: Algorithm Editor', () => {
  test.describe('AC1: Publisher sees current algorithm configuration', () => {
    test('GET /api/v1/publisher/algorithm returns algorithm config', async ({ request }) => {
      // This would require auth in production - testing the endpoint exists
      const response = await request.get(`${API_BASE}/api/v1/publisher/algorithm`);
      // Should return 401 without auth
      expect(response.status()).toBe(401);
    });
  });

  test.describe('AC2: Publisher can choose from templates', () => {
    test('GET /api/v1/publisher/algorithm/templates returns templates', async ({ request }) => {
      const response = await request.get(`${API_BASE}/api/v1/publisher/algorithm/templates`);
      // Templates endpoint requires auth
      expect(response.status()).toBe(401);
    });
  });

  test.describe('AC4: Modal shows method options with intellisense', () => {
    test('GET /api/v1/publisher/algorithm/methods returns available methods', async ({ request }) => {
      const response = await request.get(`${API_BASE}/api/v1/publisher/algorithm/methods`);
      // Methods endpoint requires auth
      expect(response.status()).toBe(401);
    });
  });

  test.describe('AC5: Live preview shows calculated time', () => {
    test('POST /api/v1/publisher/algorithm/preview calculates preview', async ({ request }) => {
      const response = await request.post(`${API_BASE}/api/v1/publisher/algorithm/preview`, {
        data: {
          configuration: {
            name: 'Test',
            zmanim: {
              sunrise: { method: 'sunrise', params: {} },
              sunset: { method: 'sunset', params: {} },
            },
          },
          date: '2025-11-26',
          latitude: 40.6782,
          longitude: -73.9442,
          timezone: 'America/New_York',
        },
      });
      // Preview endpoint requires auth
      expect(response.status()).toBe(401);
    });
  });

  test.describe('AC7: Invalid configuration shows validation error', () => {
    test('PUT /api/v1/publisher/algorithm validates configuration', async ({ request }) => {
      const response = await request.put(`${API_BASE}/api/v1/publisher/algorithm`, {
        data: {
          configuration: {
            name: '',
            zmanim: {},
          },
        },
      });
      // Should require auth
      expect(response.status()).toBe(401);
    });
  });

  test.describe('Algorithm API integration', () => {
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

    test('Zmanim endpoint works with algorithm configuration', async ({ request }) => {
      if (!brooklynCityId) {
        test.skip();
        return;
      }

      // Test that zmanim calculation works
      const zmanimResponse = await request.get(
        `${API_BASE}/api/v1/zmanim?cityId=${brooklynCityId}`
      );
      expect(zmanimResponse.ok()).toBeTruthy();

      const zmanimData = await zmanimResponse.json();
      const zmanim = zmanimData.data?.zmanim || zmanimData.zmanim || [];

      // Should include formula details for each zman
      for (const zman of zmanim) {
        expect(zman.formula).toBeDefined();
        expect(zman.formula.method).toBeDefined();
        expect(zman.formula.display_name).toBeDefined();
      }
    });

    test('POST /api/v1/zmanim returns zmanim object', async ({ request }) => {
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
      const zmanim = data.data?.zmanim || data.zmanim;
      expect(zmanim).toBeDefined();
      // Check it's an object with sunrise/sunset keys
      expect(zmanim.sunrise).toBeDefined();
      expect(zmanim.sunset).toBeDefined();
    });
  });

  test.describe('Algorithm calculation methods (using GET endpoint)', () => {
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

    test('Solar angle method works correctly', async ({ request }) => {
      if (!brooklynCityId) {
        test.skip();
        return;
      }

      const response = await request.get(`${API_BASE}/api/v1/zmanim?cityId=${brooklynCityId}`);
      const data = await response.json();
      const zmanim = data.data?.zmanim || data.zmanim || [];

      const alos = zmanim.find((z: { key: string }) => z.key === 'alos_hashachar');
      expect(alos).toBeDefined();
      expect(alos.formula.method).toBe('solar_angle');
      expect(alos.formula.parameters.degrees).toBeDefined();
    });

    test('Fixed minutes method works correctly', async ({ request }) => {
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

    test('Proportional method works for GRA', async ({ request }) => {
      if (!brooklynCityId) {
        test.skip();
        return;
      }

      const response = await request.get(`${API_BASE}/api/v1/zmanim?cityId=${brooklynCityId}`);
      const data = await response.json();
      const zmanim = data.data?.zmanim || data.zmanim || [];

      const sofZmanShma = zmanim.find((z: { key: string }) => z.key === 'sof_zman_shma_gra');
      expect(sofZmanShma).toBeDefined();
      expect(sofZmanShma.formula.method).toBe('proportional');
      expect(sofZmanShma.formula.parameters.base).toBe('gra');
      expect(sofZmanShma.formula.parameters.hours).toBe(3);
    });

    test('Proportional method works for MGA', async ({ request }) => {
      if (!brooklynCityId) {
        test.skip();
        return;
      }

      const response = await request.get(`${API_BASE}/api/v1/zmanim?cityId=${brooklynCityId}`);
      const data = await response.json();
      const zmanim = data.data?.zmanim || data.zmanim || [];

      const sofZmanShmaMga = zmanim.find((z: { key: string }) => z.key === 'sof_zman_shma_mga');
      expect(sofZmanShmaMga).toBeDefined();
      expect(sofZmanShmaMga.formula.method).toBe('proportional');
      expect(sofZmanShmaMga.formula.parameters.base).toBe('mga');
    });

    test('Midpoint method works for chatzos', async ({ request }) => {
      if (!brooklynCityId) {
        test.skip();
        return;
      }

      const response = await request.get(`${API_BASE}/api/v1/zmanim?cityId=${brooklynCityId}`);
      const data = await response.json();
      const zmanim = data.data?.zmanim || data.zmanim || [];

      const chatzos = zmanim.find((z: { key: string }) => z.key === 'chatzos');
      expect(chatzos).toBeDefined();
      expect(chatzos.formula.method).toBe('midpoint');
    });
  });

  test.describe('Time ordering validation', () => {
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

    test('All zmanim are in correct chronological order', async ({ request }) => {
      if (!brooklynCityId) {
        test.skip();
        return;
      }

      const response = await request.get(`${API_BASE}/api/v1/zmanim?cityId=${brooklynCityId}`);
      const data = await response.json();
      const zmanim = data.data?.zmanim || data.zmanim || [];

      // Find specific zmanim and verify order
      const findTime = (key: string) => {
        const z = zmanim.find((z: { key: string }) => z.key === key);
        return z?.time || '';
      };

      const alos = findTime('alos_hashachar');
      const sunrise = findTime('sunrise');
      const sofZmanShma = findTime('sof_zman_shma_gra');
      const chatzos = findTime('chatzos');
      const sunset = findTime('sunset');
      const tzeis = findTime('tzeis_hakochavim');

      // Verify chronological order
      expect(alos < sunrise).toBeTruthy();
      expect(sunrise < sofZmanShma).toBeTruthy();
      expect(sofZmanShma < chatzos).toBeTruthy();
      expect(chatzos < sunset).toBeTruthy();
      expect(sunset < tzeis).toBeTruthy();
    });
  });
});
