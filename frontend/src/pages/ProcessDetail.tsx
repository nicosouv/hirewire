import { useParams, Link, useNavigate } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { processApi, positionApi, companyApi, interviewApi } from '../services/api';
import { useInterviews } from '../hooks/useInterviews';
import Loading from '../components/Loading';
import {
  ArrowLeft,
  Building2,
  Briefcase,
  Calendar,
  Clock,
  MapPin,
  DollarSign,
  ExternalLink,
  Star,
  User,
  CheckCircle,
  XCircle,
  AlertCircle,
  FileText
} from 'lucide-react';
import type { Process, Position, Company, Interview } from '../types';

const STATUS_CONFIG = {
  applied: { label: 'Applied', color: 'bg-blue-50 text-blue-700 border-blue-200', icon: FileText },
  screening: { label: 'Screening', color: 'bg-purple-50 text-purple-700 border-purple-200', icon: AlertCircle },
  interviewing: { label: 'Interviewing', color: 'bg-honey-50 text-honey-700 border-honey-200', icon: Clock },
  tech_test: { label: 'Tech Test', color: 'bg-indigo-50 text-indigo-700 border-indigo-200', icon: FileText },
  final_round: { label: 'Final Round', color: 'bg-orange-50 text-orange-700 border-orange-200', icon: AlertCircle },
  offer: { label: 'Offer Received', color: 'bg-green-50 text-green-700 border-green-200', icon: CheckCircle },
  rejected: { label: 'Rejected', color: 'bg-red-50 text-red-700 border-red-200', icon: XCircle },
  accepted: { label: 'Accepted', color: 'bg-emerald-50 text-emerald-700 border-emerald-200', icon: CheckCircle },
  ghosted: { label: 'Ghosted', color: 'bg-gray-50 text-gray-700 border-gray-200', icon: AlertCircle },
  withdrew: { label: 'Withdrew', color: 'bg-slate-50 text-slate-700 border-slate-200', icon: XCircle },
  reminder: { label: 'Reminder', color: 'bg-yellow-50 text-yellow-700 border-yellow-200', icon: Clock },
};

const INTERVIEW_STATUS_CONFIG = {
  scheduled: { label: 'Scheduled', color: 'bg-blue-50 text-blue-700', icon: Clock },
  completed: { label: 'Completed', color: 'bg-green-50 text-green-700', icon: CheckCircle },
  cancelled: { label: 'Cancelled', color: 'bg-red-50 text-red-700', icon: XCircle },
  rescheduled: { label: 'Rescheduled', color: 'bg-yellow-50 text-yellow-700', icon: AlertCircle },
  no_show: { label: 'No Show', color: 'bg-gray-50 text-gray-700', icon: XCircle },
};

export default function ProcessDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const processId = parseInt(id || '0');

  // Fetch process data
  const { data: process, isLoading: processLoading } = useQuery<Process>({
    queryKey: ['processes', processId],
    queryFn: async () => {
      const response = await processApi.get(processId);
      return response.data;
    },
    enabled: !!processId,
  });

  // Fetch position data
  const { data: position, isLoading: positionLoading } = useQuery<Position>({
    queryKey: ['positions', process?.job_position_id],
    queryFn: async () => {
      const response = await positionApi.get(process!.job_position_id);
      return response.data;
    },
    enabled: !!process?.job_position_id,
  });

  // Fetch company data
  const { data: company, isLoading: companyLoading } = useQuery<Company>({
    queryKey: ['companies', position?.company_id],
    queryFn: async () => {
      const response = await companyApi.get(position!.company_id);
      return response.data;
    },
    enabled: !!position?.company_id,
  });

  // Fetch interviews for this process
  const { data: allInterviews } = useInterviews();
  const interviews = allInterviews?.filter(i => i.process_id === processId) || [];
  const sortedInterviews = [...interviews].sort((a, b) => a.interview_round - b.interview_round);

  if (processLoading || positionLoading || companyLoading) {
    return <Loading />;
  }

  if (!process || !position || !company) {
    return (
      <div className="text-center py-16">
        <h2 className="text-xl font-semibold text-navy-900 mb-2">Process not found</h2>
        <Link to="/processes" className="text-honey-600 hover:text-honey-700">
          ← Back to processes
        </Link>
      </div>
    );
  }

  const statusConfig = STATUS_CONFIG[process.status] || STATUS_CONFIG.applied;
  const StatusIcon = statusConfig.icon;

  return (
    <div className="space-y-6">
      {/* Header with back button */}
      <div className="flex items-center gap-4">
        <button
          onClick={() => navigate('/processes')}
          className="flex items-center gap-2 px-4 py-2 text-anthracite/70 hover:text-navy-900 hover:bg-sand/50 rounded-xl transition-all"
        >
          <ArrowLeft className="w-5 h-5" />
          <span className="font-semibold">Back to Processes</span>
        </button>
      </div>

      {/* Main header card */}
      <div className="bg-gradient-to-br from-white to-sand/30 rounded-2xl shadow-card border border-sand/50 p-8">
        <div className="flex flex-col md:flex-row justify-between items-start gap-6">
          <div className="flex-1">
            {/* Company logo/icon */}
            <div className="flex items-center gap-4 mb-4">
              <div className="w-16 h-16 bg-gradient-to-br from-honey-400 to-honey-500 rounded-2xl flex items-center justify-center shadow-md">
                <Building2 className="w-8 h-8 text-white" />
              </div>
              <div>
                <Link
                  to={`/companies`}
                  className="text-3xl font-display font-bold text-navy-900 hover:text-honey-600 transition-colors"
                >
                  {company.name}
                </Link>
                {company.industry && (
                  <p className="text-anthracite/60 font-medium">{company.industry}</p>
                )}
              </div>
            </div>

            {/* Position title */}
            <Link
              to={`/positions`}
              className="text-2xl font-display font-semibold text-navy-900 hover:text-honey-600 transition-colors flex items-center gap-2 mb-3"
            >
              <Briefcase className="w-6 h-6" />
              {position.title}
            </Link>

            {/* Position details */}
            <div className="flex flex-wrap gap-3 mb-4">
              {position.level && (
                <span className="px-3 py-1 bg-honey-50 text-honey-700 text-sm font-semibold rounded-lg">
                  {position.level}
                </span>
              )}
              {position.contract_type && (
                <span className="px-3 py-1 bg-sky-50 text-sky-700 text-sm font-semibold rounded-lg">
                  {position.contract_type.replace('_', ' ')}
                </span>
              )}
              {position.remote_policy && (
                <span className="px-3 py-1 bg-purple-50 text-purple-700 text-sm font-semibold rounded-lg">
                  {position.remote_policy}
                </span>
              )}
            </div>

            {/* Location and salary */}
            <div className="space-y-2 text-anthracite/70">
              {position.location && (
                <div className="flex items-center gap-2">
                  <MapPin className="w-4 h-4" />
                  <span>{position.location}</span>
                </div>
              )}
              {position.salary_min && position.salary_max && (
                <div className="flex items-center gap-2">
                  <DollarSign className="w-4 h-4" />
                  <span>
                    {position.salary_min.toLocaleString()} - {position.salary_max.toLocaleString()} €
                  </span>
                </div>
              )}
            </div>

            {/* Company links */}
            {company.website && (
              <a
                href={company.website}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-2 mt-4 text-honey-600 hover:text-honey-700 font-medium"
              >
                <ExternalLink className="w-4 h-4" />
                Company Website
              </a>
            )}
          </div>

          {/* Status badge */}
          <div className="flex flex-col items-end gap-3">
            <span className={`inline-flex items-center gap-2 px-6 py-3 ${statusConfig.color} text-lg font-bold rounded-xl border-2 shadow-sm`}>
              <StatusIcon className="w-6 h-6" />
              {statusConfig.label}
            </span>
            <div className="text-right text-sm text-anthracite/60">
              <div>Applied: {new Date(process.application_date).toLocaleDateString()}</div>
              {process.source && <div>Source: {process.source}</div>}
            </div>
          </div>
        </div>

        {/* Notes */}
        {process.notes && (
          <div className="mt-6 p-4 bg-sand/30 rounded-xl border border-sand">
            <p className="text-sm font-semibold text-navy-900 mb-2">📝 Notes</p>
            <p className="text-anthracite/70">{process.notes}</p>
          </div>
        )}
      </div>

      {/* Interview Timeline */}
      <div className="bg-white rounded-2xl shadow-card border border-sand/50 p-8">
        <h2 className="text-2xl font-display font-bold text-navy-900 mb-6 flex items-center gap-3">
          <Calendar className="w-7 h-7 text-honey-600" />
          Interview Timeline
        </h2>

        {sortedInterviews.length > 0 ? (
          <div className="space-y-6">
            {sortedInterviews.map((interview, index) => {
              const interviewStatus = INTERVIEW_STATUS_CONFIG[interview.status] || INTERVIEW_STATUS_CONFIG.scheduled;
              const InterviewStatusIcon = interviewStatus.icon;

              return (
                <div key={interview.id} className="relative pl-8 pb-8 border-l-2 border-sand last:border-0 last:pb-0">
                  {/* Timeline dot */}
                  <div className="absolute left-0 top-0 transform -translate-x-1/2">
                    <div className="w-4 h-4 bg-honey-500 rounded-full border-4 border-white shadow-md"></div>
                  </div>

                  {/* Interview card */}
                  <div className="bg-sand/20 rounded-xl p-6 hover:bg-sand/30 transition-all">
                    <div className="flex justify-between items-start mb-4">
                      <div>
                        <div className="flex items-center gap-3 mb-2">
                          <span className="px-3 py-1 bg-honey-500 text-white text-sm font-bold rounded-lg">
                            Round {interview.interview_round}
                          </span>
                          {interview.interview_type && (
                            <span className="text-sm text-anthracite/60 capitalize">
                              {interview.interview_type.replace('_', ' ')}
                            </span>
                          )}
                        </div>
                        {interview.scheduled_date && (
                          <div className="flex items-center gap-2 text-anthracite/70">
                            <Calendar className="w-4 h-4 text-honey-600" />
                            <span>
                              {new Date(interview.scheduled_date).toLocaleDateString('en-US', {
                                month: 'short',
                                day: 'numeric',
                                year: 'numeric',
                                hour: '2-digit',
                                minute: '2-digit'
                              })}
                            </span>
                            {interview.duration_minutes && (
                              <span className="text-sm">({interview.duration_minutes} min)</span>
                            )}
                          </div>
                        )}
                      </div>

                      <span className={`inline-flex items-center gap-1.5 px-3 py-1.5 ${interviewStatus.color} text-sm font-semibold rounded-lg`}>
                        <InterviewStatusIcon className="w-4 h-4" />
                        {interviewStatus.label}
                      </span>
                    </div>

                    {/* Interviewer info */}
                    {interview.interviewer_name && (
                      <div className="flex items-center gap-2 text-sm text-anthracite/70 mb-3">
                        <User className="w-4 h-4 text-honey-600" />
                        <span className="font-medium">{interview.interviewer_name}</span>
                        {interview.interviewer_role && (
                          <span className="text-anthracite/50">({interview.interviewer_role})</span>
                        )}
                      </div>
                    )}

                    {/* Rating */}
                    {interview.rating && (
                      <div className="flex items-center gap-2 mb-3">
                        <span className="text-sm text-anthracite/60 font-medium">Rating:</span>
                        <div className="flex gap-1">
                          {[...Array(5)].map((_, i) => (
                            <Star
                              key={i}
                              className={`w-5 h-5 ${
                                i < interview.rating!
                                  ? 'fill-honey-500 text-honey-500'
                                  : 'text-gray-300'
                              }`}
                            />
                          ))}
                        </div>
                      </div>
                    )}

                    {/* Feedback */}
                    {interview.feedback && (
                      <div className="mt-3 p-3 bg-white rounded-lg border border-sand/50">
                        <p className="text-sm font-semibold text-navy-900 mb-1">💬 Feedback</p>
                        <p className="text-sm text-anthracite/70">{interview.feedback}</p>
                      </div>
                    )}

                    {/* Technical topics */}
                    {interview.technical_topics && (
                      <div className="mt-3 p-3 bg-white rounded-lg border border-sand/50">
                        <p className="text-sm font-semibold text-navy-900 mb-1">🔧 Technical Topics</p>
                        <p className="text-sm text-anthracite/70">{interview.technical_topics}</p>
                      </div>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        ) : (
          <div className="text-center py-12">
            <div className="inline-flex items-center justify-center w-16 h-16 bg-sand rounded-2xl mb-4">
              <Calendar className="w-8 h-8 text-anthracite/40" />
            </div>
            <h3 className="text-lg font-semibold text-navy-900 mb-2">No interviews yet</h3>
            <p className="text-anthracite/60 mb-6">This process doesn't have any interview rounds scheduled.</p>
            <Link
              to="/interviews"
              className="inline-flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-honey-500 to-honey-600 hover:from-honey-600 hover:to-honey-700 text-white font-semibold rounded-xl shadow-md hover:shadow-lg transition-all"
            >
              <Calendar className="w-5 h-5" />
              Schedule Interview
            </Link>
          </div>
        )}
      </div>

      {/* Quick Actions */}
      <div className="bg-white rounded-2xl shadow-card border border-sand/50 p-6">
        <h3 className="text-lg font-display font-semibold text-navy-900 mb-4">Quick Actions</h3>
        <div className="flex flex-wrap gap-3">
          <Link
            to="/interviews"
            className="inline-flex items-center gap-2 px-5 py-2.5 bg-honey-500 hover:bg-honey-600 text-white font-semibold rounded-xl transition-all"
          >
            <Calendar className="w-4 h-4" />
            Add Interview
          </Link>
          <Link
            to="/processes"
            className="inline-flex items-center gap-2 px-5 py-2.5 border-2 border-navy-900 text-navy-900 hover:bg-navy-900 hover:text-white font-semibold rounded-xl transition-all"
          >
            <ArrowLeft className="w-4 h-4" />
            All Processes
          </Link>
        </div>
      </div>
    </div>
  );
}
