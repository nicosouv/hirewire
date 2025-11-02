/**
 * Tests for useCompanies hook
 */
import { describe, it, expect, beforeEach } from 'vitest';
import { renderHook, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useCompanies, useCreateCompany } from '../useCompanies';
import { createTestQueryClient } from '@/tests/utils/test-utils';

describe('useCompanies', () => {
  let queryClient: QueryClient;

  beforeEach(() => {
    queryClient = createTestQueryClient();
  });

  const wrapper = ({ children }: { children: React.ReactNode }) => (
    <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
  );

  it('should fetch companies successfully', async () => {
    const { result } = renderHook(() => useCompanies(), { wrapper });

    // Initially loading
    expect(result.current.isLoading).toBe(true);

    // Wait for data
    await waitFor(() => {
      expect(result.current.isSuccess).toBe(true);
    });

    // Check data structure
    expect(result.current.data).toBeDefined();
    expect(Array.isArray(result.current.data)).toBe(true);
  });

  it('should handle errors when fetching companies', async () => {
    // Mock API failure
    // TODO: Implement error simulation

    const { result } = renderHook(() => useCompanies(), { wrapper });

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });
  });
});

describe('useCreateCompany', () => {
  let queryClient: QueryClient;

  beforeEach(() => {
    queryClient = createTestQueryClient();
  });

  const wrapper = ({ children }: { children: React.ReactNode }) => (
    <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
  );

  it('should create a company successfully', async () => {
    const { result } = renderHook(() => useCreateCompany(), { wrapper });

    const newCompany = {
      name: 'New Company',
      industry: 'Tech',
      size: '10-50',
      location: 'Paris',
      website: 'https://newcompany.com',
    };

    // Trigger mutation
    result.current.mutate(newCompany);

    // Wait for mutation to complete
    await waitFor(() => {
      expect(result.current.isSuccess).toBe(true);
    });

    expect(result.current.data).toBeDefined();
  });

  it('should invalidate companies query after creating', async () => {
    const { result } = renderHook(() => useCreateCompany(), { wrapper });

    // TODO: Verify query invalidation
    expect(result.current.mutate).toBeDefined();
  });
});
