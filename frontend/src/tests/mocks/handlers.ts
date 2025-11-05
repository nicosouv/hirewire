/**
 * MSW (Mock Service Worker) handlers for API mocking in tests
 */
import { http, HttpResponse } from 'msw';

const API_URL = 'http://localhost:8000/api/v1';

export const handlers = [
  // Handle OPTIONS requests (CORS preflight)
  http.options(`${API_URL}/*`, () => {
    return new HttpResponse(null, {
      status: 204,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      },
    });
  }),

  // GET /companies - List all companies (without trailing slash)
  http.get(`${API_URL}/companies`, () => {
    return HttpResponse.json([
      {
        id: 1,
        name: 'Test Company 1',
        industry: 'Technology',
        size: '50-200',
        location: 'Paris, France',
        website: 'https://testcompany1.com',
        created_at: '2024-01-01T00:00:00Z',
        updated_at: '2024-01-01T00:00:00Z',
      },
      {
        id: 2,
        name: 'Test Company 2',
        industry: 'Finance',
        size: '200-1000',
        location: 'London, UK',
        website: 'https://testcompany2.com',
        created_at: '2024-01-02T00:00:00Z',
        updated_at: '2024-01-02T00:00:00Z',
      },
    ]);
  }),

  // POST /companies - Create a new company (without trailing slash)
  http.post(`${API_URL}/companies`, async ({ request }) => {
    const body = (await request.json()) as Record<string, unknown>;
    return HttpResponse.json(
      {
        id: 3,
        ...body,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      },
      { status: 201 }
    );
  }),

  // GET /companies/:id - Get single company
  http.get(`${API_URL}/companies/:id`, ({ params }) => {
    const { id} = params;
    return HttpResponse.json({
      id: Number(id),
      name: `Test Company ${id}`,
      industry: 'Technology',
      size: '50-200',
      location: 'Paris, France',
      website: `https://testcompany${id}.com`,
      created_at: '2024-01-01T00:00:00Z',
      updated_at: '2024-01-01T00:00:00Z',
    });
  }),
];
