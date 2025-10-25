import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '../services/api';

export interface Export {
  id: number;
  user_id: number;
  start_date: string;
  end_date: string;
  format: 'excel' | 'csv';
  recipient_email: string;
  status: 'pending' | 'processing' | 'completed' | 'failed';
  airflow_dag_run_id?: string;
  file_path?: string;
  error_message?: string;
  created_at: string;
  updated_at: string;
  completed_at?: string;
}

export interface ExportCreate {
  start_date: string;
  end_date: string;
  format: 'excel' | 'csv';
  recipient_email: string;
}

export function useExports() {
  return useQuery({
    queryKey: ['exports'],
    queryFn: async () => {
      const response = await apiClient.get('/exports/');
      return response.data as Export[];
    },
  });
}

export function useExport(id: number) {
  return useQuery({
    queryKey: ['exports', id],
    queryFn: async () => {
      const response = await apiClient.get(`/exports/${id}`);
      return response.data as Export;
    },
    enabled: !!id,
  });
}

export function useCreateExport() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (data: ExportCreate) => {
      const response = await apiClient.post('/exports/', data);
      return response.data as Export;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['exports'] });
    },
  });
}
