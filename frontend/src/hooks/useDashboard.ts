import { useQuery } from '@tanstack/react-query';
import { apiClient } from '../services/api';

export interface DashboardStats {
  total_applications: number;
  active_processes: number;
  total_interviews: number;
  offers_received: number;
  acceptance_rate: number;
  avg_process_duration_days: number;
}

export interface ProcessByStatus {
  status: string;
  count: number;
}

export interface InterviewByType {
  interview_type: string;
  count: number;
}

export interface CompanyStats {
  company_name: string;
  application_count: number;
  interview_count: number;
  offer_count: number;
}

export interface MonthlyActivity {
  month: string;
  applications: number;
  interviews: number;
}

export interface DashboardData {
  stats: DashboardStats;
  processes_by_status: ProcessByStatus[];
  interviews_by_type: InterviewByType[];
  top_companies: CompanyStats[];
  monthly_activity: MonthlyActivity[];
  recent_activities: any[];
}

export function useDashboard() {
  return useQuery({
    queryKey: ['dashboard'],
    queryFn: async () => {
      const response = await apiClient.get<DashboardData>('/dashboard/');
      return response.data;
    },
  });
}

export function useDashboardStats() {
  return useQuery({
    queryKey: ['dashboard', 'stats'],
    queryFn: async () => {
      const response = await apiClient.get<DashboardStats>('/dashboard/stats');
      return response.data;
    },
  });
}
