import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { processApi } from '../services/api';
import type { Process } from '../types';

export function useProcesses() {
  return useQuery({
    queryKey: ['processes'],
    queryFn: async () => {
      const response = await processApi.list();
      return response.data as Process[];
    },
  });
}

export function useProcess(id: number) {
  return useQuery({
    queryKey: ['processes', id],
    queryFn: async () => {
      const response = await processApi.get(id);
      return response.data as Process;
    },
    enabled: !!id,
  });
}

export function useCreateProcess() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (data: Omit<Process, 'id' | 'created_at' | 'updated_at'>) => {
      const response = await processApi.create(data);
      return response.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['processes'] });
    },
  });
}

export function useUpdateProcess() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ id, data }: { id: number; data: Partial<Process> }) => {
      const response = await processApi.update(id, data);
      return response.data;
    },
    onSuccess: (_, variables) => {
      queryClient.invalidateQueries({ queryKey: ['processes'] });
      queryClient.invalidateQueries({ queryKey: ['processes', variables.id] });
    },
  });
}

export function useDeleteProcess() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (id: number) => {
      await processApi.delete(id);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['processes'] });
    },
  });
}
