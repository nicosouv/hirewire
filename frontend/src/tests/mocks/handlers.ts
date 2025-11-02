/**
 * MSW (Mock Service Worker) request handlers
 * Mocks API responses for testing
 */
import { http, HttpResponse } from 'msw';

const API_URL = 'http://localhost:8000/api/v1';

// Mock data
export const mockCompanies = [
  {
    id: 1,
    name: 'Test Company',
    industry: 'Technology',
    size: '50-200',
    location: 'Paris, France',
    website: 'https://testcompany.com',
    created_at: '2024-01-01T00:00:00Z',
    updated_at: '2024-01-01T00:00:00Z',
  },
  {
    id: 2,
    name: 'Another Company',
    industry: 'Finance',
    size: '200-1000',
    location: 'London, UK',
    website: 'https://anothercompany.com',
    created_at: '2024-01-02T00:00:00Z',
    updated_at: '2024-01-02T00:00:00Z',
  },
];

export const mockPositions = [
  {
    id: 1,
    company_id: 1,
    title: 'Senior Software Engineer',
    department: 'Engineering',
    location: 'Paris',
    job_type: 'full_time',
    salary_min: 60000,
    salary_max: 80000,
    description: 'Great opportunity',
    created_at: '2024-01-01T00:00:00Z',
    updated_at: '2024-01-01T00:00:00Z',
  },
];

export const mockProcesses = [
  {
    id: 1,
    job_position_id: 1,
    application_date: '2024-01-15',
    status: 'interviewing',
    source: 'LinkedIn',
    notes: null,
    created_at: '2024-01-15T00:00:00Z',
    updated_at: '2024-01-15T00:00:00Z',
  },
];

export const mockUser = {
  id: 1,
  email: 'test@example.com',
  is_active: true,
  is_airflow_admin: false,
  created_at: '2024-01-01T00:00:00Z',
};

// Request handlers
export const handlers = [
  // Auth endpoints
  http.post(`${API_URL}/auth/login/json`, () => {
    return HttpResponse.json({
      access_token: 'mock_token',
      token_type: 'bearer',
    });
  }),

  http.get(`${API_URL}/auth/me`, () => {
    return HttpResponse.json(mockUser);
  }),

  // Company endpoints
  http.get(`${API_URL}/companies/`, () => {
    return HttpResponse.json(mockCompanies);
  }),

  http.get(`${API_URL}/companies/:id`, ({ params }) => {
    const company = mockCompanies.find((c) => c.id === Number(params.id));
    if (!company) {
      return new HttpResponse(null, { status: 404 });
    }
    return HttpResponse.json(company);
  }),

  http.post(`${API_URL}/companies/`, async ({ request }) => {
    const body = (await request.json()) as any;
    const newCompany = {
      id: mockCompanies.length + 1,
      ...body,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    return HttpResponse.json(newCompany, { status: 201 });
  }),

  // Position endpoints
  http.get(`${API_URL}/job-positions/`, () => {
    return HttpResponse.json(mockPositions);
  }),

  // Process endpoints
  http.get(`${API_URL}/processes`, () => {
    return HttpResponse.json(mockProcesses);
  }),

  http.post(`${API_URL}/processes`, async ({ request }) => {
    const body = (await request.json()) as any;
    const newProcess = {
      id: mockProcesses.length + 1,
      ...body,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    return HttpResponse.json(newProcess, { status: 201 });
  }),

  // Dashboard endpoints
  http.get(`${API_URL}/dashboard/stats`, () => {
    return HttpResponse.json({
      total_applications: 10,
      active_processes: 5,
      total_interviews: 15,
      offers_received: 2,
    });
  }),
];
