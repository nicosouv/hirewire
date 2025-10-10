/**
 * API client configuration and base utilities.
 * Uses axios for HTTP requests with TypeScript types.
 */
import axios from 'axios';

// Base URL from environment or default
const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000';
const API_VERSION = '/api/v1';

// Create axios instance with defaults
export const apiClient = axios.create({
  baseURL: `${API_BASE_URL}${API_VERSION}`,
  headers: {
    'Content-Type': 'application/json',
  },
  timeout: 10000,
});

// Request interceptor (for auth tokens, logging, etc.)
apiClient.interceptors.request.use(
  (config) => {
    // Add auth token if available
    const token = localStorage.getItem('auth_token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Response interceptor (for error handling)
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      // Handle unauthorized - redirect to login
      localStorage.removeItem('auth_token');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

// API endpoints
export const companyApi = {
  list: () => apiClient.get('/companies'),
  get: (id: number) => apiClient.get(`/companies/${id}`),
  create: (data: any) => apiClient.post('/companies', data),
  update: (id: number, data: any) => apiClient.put(`/companies/${id}`, data),
  delete: (id: number) => apiClient.delete(`/companies/${id}`),
};

export const positionApi = {
  list: () => apiClient.get('/job-positions/'),
  get: (id: number) => apiClient.get(`/job-positions/${id}/`),
  create: (data: any) => apiClient.post('/job-positions/', data),
  update: (id: number, data: any) => apiClient.put(`/job-positions/${id}/`, data),
  delete: (id: number) => apiClient.delete(`/job-positions/${id}/`),
};

export const processApi = {
  list: () => apiClient.get('/processes'),
  get: (id: number) => apiClient.get(`/processes/${id}`),
  create: (data: any) => apiClient.post('/processes', data),
  update: (id: number, data: any) => apiClient.put(`/processes/${id}`, data),
  delete: (id: number) => apiClient.delete(`/processes/${id}`),
};

export const interviewApi = {
  list: () => apiClient.get('/interviews/'),
  get: (id: number) => apiClient.get(`/interviews/${id}/`),
  create: (data: any) => apiClient.post('/interviews/', data),
  update: (id: number, data: any) => apiClient.put(`/interviews/${id}/`, data),
  delete: (id: number) => apiClient.delete(`/interviews/${id}/`),
};

export const dashboardApi = {
  stats: () => apiClient.get('/dashboard/stats'),
};
