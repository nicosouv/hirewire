/**
 * TypeScript types for HireWire application.
 * Matches backend Pydantic schemas.
 */

export interface Company {
  id: number;
  name: string;
  industry?: string;
  size?: string;
  location?: string;
  website?: string;
  created_at: string;
  updated_at: string;
}

export interface JobPosition {
  id: number;
  company_id: number;
  title: string;
  level?: string;
  contract_type?: string;
  salary_min?: number;
  salary_max?: number;
  location?: string;
  remote_policy?: string;
  job_description?: string;
  requirements?: string;
  benefits?: string;
  application_url?: string;
  notes?: string;
  created_at: string;
  updated_at: string;
}

export interface InterviewProcess {
  id: number;
  job_position_id: number;
  application_date: string;
  status: ProcessStatus;
  source?: string;
  notes?: string;
  created_at: string;
  updated_at: string;
}

export interface Interview {
  id: number;
  process_id: number;
  interview_type?: string;
  interview_round: number;
  scheduled_date?: string;
  actual_date?: string;
  duration_minutes?: number;
  interviewer_name?: string;
  interviewer_role?: string;
  status: InterviewStatus;
  feedback?: string;
  rating?: number;
  technical_topics?: string;
  created_at: string;
  updated_at: string;
}

export interface InterviewOutcome {
  id: number;
  process_id: number;
  outcome: OutcomeType;
  outcome_date: string;
  offer_salary?: number;
  offer_currency?: string;
  rejection_reason?: string;
  feedback_received?: boolean;
  would_reapply?: boolean;
  overall_experience_rating?: number;
  notes?: string;
  created_at: string;
  updated_at: string;
}

// Enums
export type ProcessStatus =
  | 'applied'
  | 'screening'
  | 'interviewing'
  | 'tech_test'
  | 'final_round'
  | 'offer'
  | 'rejected'
  | 'accepted'
  | 'ghosted'
  | 'withdrew'
  | 'reminder';

export type InterviewStatus =
  | 'scheduled'
  | 'completed'
  | 'cancelled'
  | 'rescheduled'
  | 'no_show';

export type OutcomeType =
  | 'rejection'
  | 'rejected'
  | 'offer'
  | 'accepted'
  | 'ghosted'
  | 'withdrew';

// Type aliases for convenience
export type Position = JobPosition;
export type Process = InterviewProcess;

// Dashboard types
export interface DashboardStats {
  active_processes: number;
  total_interviews: number;
  total_companies: number;
  success_rate: number;
}
