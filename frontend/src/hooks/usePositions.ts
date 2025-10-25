import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { positionApi } from '../services/api';
import type { Position } from '../types';

export function usePositions() {
  return useQuery({
    queryKey: ['positions'],
    queryFn: async () => {
      const response = await positionApi.list();
      return response.data as Position[];
    },
  });
}

export function usePosition(id: number) {
  return useQuery({
    queryKey: ['positions', id],
    queryFn: async () => {
      const response = await positionApi.get(id);
      return response.data as Position;
    },
    enabled: !!id,
  });
}

export function useCreatePosition() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (data: Omit<Position, 'id' | 'created_at' | 'updated_at'>) => {
      const response = await positionApi.create(data);
      return response.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['positions'] });
      queryClient.invalidateQueries({ queryKey: ['dashboard'] });
    },
  });
}

export function useUpdatePosition() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ id, data }: { id: number; data: Partial<Position> }) => {
      const response = await positionApi.update(id, data);
      return response.data;
    },
    onSuccess: (_, variables) => {
      queryClient.invalidateQueries({ queryKey: ['positions'] });
      queryClient.invalidateQueries({ queryKey: ['positions', variables.id] });
      queryClient.invalidateQueries({ queryKey: ['dashboard'] });
    },
  });
}

export function useDeletePosition() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (id: number) => {
      await positionApi.delete(id);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['positions'] });
      queryClient.invalidateQueries({ queryKey: ['dashboard'] });
    },
  });
}
