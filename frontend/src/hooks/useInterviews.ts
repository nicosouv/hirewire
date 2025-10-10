import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { interviewApi } from '../services/api';
import type { Interview } from '../types';

export function useInterviews() {
  return useQuery({
    queryKey: ['interviews'],
    queryFn: async () => {
      const response = await interviewApi.list();
      return response.data as Interview[];
    },
  });
}

export function useInterview(id: number) {
  return useQuery({
    queryKey: ['interviews', id],
    queryFn: async () => {
      const response = await interviewApi.get(id);
      return response.data as Interview;
    },
    enabled: !!id,
  });
}

export function useCreateInterview() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (data: Omit<Interview, 'id' | 'created_at' | 'updated_at'>) => {
      const response = await interviewApi.create(data);
      return response.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['interviews'] });
    },
  });
}

export function useUpdateInterview() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ id, data }: { id: number; data: Partial<Interview> }) => {
      const response = await interviewApi.update(id, data);
      return response.data;
    },
    onSuccess: (_, variables) => {
      queryClient.invalidateQueries({ queryKey: ['interviews'] });
      queryClient.invalidateQueries({ queryKey: ['interviews', variables.id] });
    },
  });
}

export function useDeleteInterview() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (id: number) => {
      await interviewApi.delete(id);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['interviews'] });
    },
  });
}
