import { useState } from 'react';
import { Link } from 'react-router-dom';
import { useInterviews, useCreateInterview, useDeleteInterview } from '../hooks/useInterviews';
import { useProcesses } from '../hooks/useProcesses';
import { usePositions } from '../hooks/usePositions';
import { useCompanies } from '../hooks/useCompanies';
import Loading from '../components/Loading';
import { Calendar, Plus, Trash2, Clock, User, Star, CheckCircle, XCircle, AlertCircle, ArrowRight } from 'lucide-react';
import type { Interview } from '../types';

const STATUS_CONFIG = {
  scheduled: { label: 'Scheduled', color: 'bg-blue-50 text-blue-700', icon: Clock },
  completed: { label: 'Completed', color: 'bg-green-50 text-green-700', icon: CheckCircle },
  cancelled: { label: 'Cancelled', color: 'bg-red-50 text-red-700', icon: XCircle },
  rescheduled: { label: 'Rescheduled', color: 'bg-yellow-50 text-yellow-700', icon: AlertCircle },
  no_show: { label: 'No Show', color: 'bg-gray-50 text-gray-700', icon: XCircle },
};

export default function Interviews() {
  const { data: interviews, isLoading, error } = useInterviews();
  const { data: processes } = useProcesses();
  const { data: positions } = usePositions();
  const { data: companies } = useCompanies();
  const createInterview = useCreateInterview();
  const deleteInterview = useDeleteInterview();
  const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState({
    process_id: '',
    interview_type: '',
    interview_round: '1',
    scheduled_date: '',
    duration_minutes: '60',
    interviewer_name: '',
    interviewer_role: '',
    status: 'scheduled' as const,
    feedback: '',
    rating: '',
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await createInterview.mutateAsync({
        ...formData,
        process_id: parseInt(formData.process_id),
        interview_round: parseInt(formData.interview_round),
        duration_minutes: formData.duration_minutes ? parseInt(formData.duration_minutes) : undefined,
        rating: formData.rating ? parseInt(formData.rating) : undefined,
      } as any);
      setFormData({
        process_id: '',
        interview_type: '',
        interview_round: '1',
        scheduled_date: '',
        duration_minutes: '60',
        interviewer_name: '',
        interviewer_role: '',
        status: 'scheduled',
        feedback: '',
        rating: '',
      });
      setShowForm(false);
    } catch (error) {
      console.error('Failed to create interview:', error);
    }
  };

  const handleDelete = async (id: number) => {
    if (window.confirm('Are you sure you want to delete this interview?')) {
      try {
        await deleteInterview.mutateAsync(id);
      } catch (error) {
        console.error('Failed to delete interview:', error);
      }
    }
  };

  if (isLoading) return <Loading />;
  if (error) return (
    <div className="bg-red-50 border-l-4 border-red-500 text-red-800 px-6 py-4 rounded-xl">
      <p className="font-semibold">Failed to load interviews</p>
      <p className="text-sm mt-1">Please try again later.</p>
    </div>
  );

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex justify-between items-start">
        <div>
          <h1 className="text-3xl font-display font-bold text-navy-900">Interviews</h1>
          <p className="mt-2 text-anthracite/70">Manage your interview schedule</p>
        </div>
        <button
          onClick={() => setShowForm(!showForm)}
          className="flex items-center gap-2 px-5 py-3 bg-gradient-to-r from-honey-500 to-honey-600 hover:from-honey-600 hover:to-honey-700 font-semibold rounded-xl shadow-md hover:shadow-lg transition-all transform hover:scale-[1.02]"
        >
          <Plus className="w-5 h-5" />
          {showForm ? 'Cancel' : 'Add Interview'}
        </button>
      </div>

      {/* Add Form */}
      {showForm && (
        <div className="bg-white rounded-2xl shadow-card border border-sand/50 p-6">
          <div className="flex items-center gap-3 mb-6">
            <div className="w-10 h-10 bg-honey-100 rounded-xl flex items-center justify-center">
              <Calendar className="w-5 h-5 text-honey-600" />
            </div>
            <h2 className="text-xl font-display font-semibold text-navy-900">Schedule New Interview</h2>
          </div>

          <form onSubmit={handleSubmit} className="space-y-5">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
              <div>
                <label className="block text-sm font-semibold text-navy-900 mb-2">
                  Process *
                </label>
                <select
                  required
                  value={formData.process_id}
                  onChange={(e) => setFormData({ ...formData, process_id: e.target.value })}
                  className="w-full px-4 py-3 border border-sand bg-ivory/50 rounded-xl text-anthracite focus:outline-none focus:ring-2 focus:ring-honey-500 focus:border-transparent transition-all"
                >
                  <option value="">Select a process</option>
                  {processes?.map((process) => {
                    const position = positions?.find(p => p.id === process.job_position_id);
                    const company = companies?.find(c => c.id === position?.company_id);
                    return (
                      <option key={process.id} value={process.id}>
                        {position?.title || 'Unknown'} @ {company?.name || 'Unknown'}
                      </option>
                    );
                  })}
                </select>
              </div>

              <div>
                <label className="block text-sm font-semibold text-navy-900 mb-2">
                  Interview Type
                </label>
                <select
                  value={formData.interview_type}
                  onChange={(e) => setFormData({ ...formData, interview_type: e.target.value })}
                  className="w-full px-4 py-3 border border-sand bg-ivory/50 rounded-xl text-anthracite focus:outline-none focus:ring-2 focus:ring-honey-500 focus:border-transparent transition-all"
                >
                  <option value="">Select type</option>
                  <option value="phone_screen">Phone Screen</option>
                  <option value="video">Video Call</option>
                  <option value="onsite">On-site</option>
                  <option value="technical">Technical</option>
                  <option value="behavioral">Behavioral</option>
                  <option value="case_study">Case Study</option>
                  <option value="final">Final Round</option>
                </select>
              </div>

              <div>
                <label className="block text-sm font-semibold text-navy-900 mb-2">
                  Round Number *
                </label>
                <input
                  type="number"
                  required
                  min="1"
                  value={formData.interview_round}
                  onChange={(e) => setFormData({ ...formData, interview_round: e.target.value })}
                  className="w-full px-4 py-3 border border-sand bg-ivory/50 rounded-xl text-anthracite focus:outline-none focus:ring-2 focus:ring-honey-500 focus:border-transparent transition-all"
                />
              </div>

              <div>
                <label className="block text-sm font-semibold text-navy-900 mb-2">
                  Scheduled Date
                </label>
                <input
                  type="datetime-local"
                  value={formData.scheduled_date}
                  onChange={(e) => setFormData({ ...formData, scheduled_date: e.target.value })}
                  className="w-full px-4 py-3 border border-sand bg-ivory/50 rounded-xl text-anthracite focus:outline-none focus:ring-2 focus:ring-honey-500 focus:border-transparent transition-all"
                />
              </div>

              <div>
                <label className="block text-sm font-semibold text-navy-900 mb-2">
                  Duration (minutes)
                </label>
                <input
                  type="number"
                  min="15"
                  step="15"
                  value={formData.duration_minutes}
                  onChange={(e) => setFormData({ ...formData, duration_minutes: e.target.value })}
                  className="w-full px-4 py-3 border border-sand bg-ivory/50 rounded-xl text-anthracite focus:outline-none focus:ring-2 focus:ring-honey-500 focus:border-transparent transition-all"
                />
              </div>

              <div>
                <label className="block text-sm font-semibold text-navy-900 mb-2">
                  Status
                </label>
                <select
                  value={formData.status}
                  onChange={(e) => setFormData({ ...formData, status: e.target.value as any })}
                  className="w-full px-4 py-3 border border-sand bg-ivory/50 rounded-xl text-anthracite focus:outline-none focus:ring-2 focus:ring-honey-500 focus:border-transparent transition-all"
                >
                  {Object.entries(STATUS_CONFIG).map(([key, config]) => (
                    <option key={key} value={key}>{config.label}</option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-semibold text-navy-900 mb-2">
                  Interviewer Name
                </label>
                <input
                  type="text"
                  value={formData.interviewer_name}
                  onChange={(e) => setFormData({ ...formData, interviewer_name: e.target.value })}
                  className="w-full px-4 py-3 border border-sand bg-ivory/50 rounded-xl text-anthracite placeholder-anthracite/40 focus:outline-none focus:ring-2 focus:ring-honey-500 focus:border-transparent transition-all"
                  placeholder="e.g., John Doe"
                />
              </div>

              <div>
                <label className="block text-sm font-semibold text-navy-900 mb-2">
                  Interviewer Role
                </label>
                <input
                  type="text"
                  value={formData.interviewer_role}
                  onChange={(e) => setFormData({ ...formData, interviewer_role: e.target.value })}
                  className="w-full px-4 py-3 border border-sand bg-ivory/50 rounded-xl text-anthracite placeholder-anthracite/40 focus:outline-none focus:ring-2 focus:ring-honey-500 focus:border-transparent transition-all"
                  placeholder="e.g., Engineering Manager"
                />
              </div>

              <div>
                <label className="block text-sm font-semibold text-navy-900 mb-2">
                  Rating (1-5)
                </label>
                <input
                  type="number"
                  min="1"
                  max="5"
                  value={formData.rating}
                  onChange={(e) => setFormData({ ...formData, rating: e.target.value })}
                  className="w-full px-4 py-3 border border-sand bg-ivory/50 rounded-xl text-anthracite focus:outline-none focus:ring-2 focus:ring-honey-500 focus:border-transparent transition-all"
                />
              </div>

              <div className="md:col-span-2">
                <label className="block text-sm font-semibold text-navy-900 mb-2">
                  Feedback / Notes
                </label>
                <textarea
                  value={formData.feedback}
                  onChange={(e) => setFormData({ ...formData, feedback: e.target.value })}
                  rows={3}
                  className="w-full px-4 py-3 border border-sand bg-ivory/50 rounded-xl text-anthracite placeholder-anthracite/40 focus:outline-none focus:ring-2 focus:ring-honey-500 focus:border-transparent transition-all resize-none"
                  placeholder="Add interview notes and feedback..."
                />
              </div>
            </div>

            <div className="flex gap-3 pt-2">
              <button
                type="submit"
                disabled={createInterview.isPending}
                className="flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-honey-500 to-honey-600 hover:from-honey-600 hover:to-honey-700 font-semibold rounded-xl shadow-md hover:shadow-lg disabled:opacity-50 disabled:cursor-not-allowed transition-all transform hover:scale-[1.02]"
              >
                {createInterview.isPending ? (
                  <>
                    <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                    Creating...
                  </>
                ) : (
                  <>
                    <Plus className="w-5 h-5" />
                    Schedule Interview
                  </>
                )}
              </button>
              <button
                type="button"
                onClick={() => setShowForm(false)}
                className="px-6 py-3 border-2 border-navy-900 text-navy-900 font-semibold rounded-xl hover:bg-navy-900 transition-all"
              >
                Cancel
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Interviews List */}
      {interviews && interviews.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {interviews.map((interview) => (
            <InterviewCard
              key={interview.id}
              interview={interview}
              processes={processes || []}
              positions={positions || []}
              companies={companies || []}
              onDelete={handleDelete}
            />
          ))}
        </div>
      ) : (
        <div className="text-center py-16">
          <div className="inline-flex items-center justify-center w-16 h-16 bg-sand rounded-2xl mb-4">
            <Calendar className="w-8 h-8 text-anthracite/40" />
          </div>
          <h3 className="text-lg font-semibold text-navy-900 mb-2">No interviews yet</h3>
          <p className="text-anthracite/60 mb-6">Schedule your first interview</p>
          <button
            onClick={() => setShowForm(true)}
            className="inline-flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-honey-500 to-honey-600 hover:from-honey-600 hover:to-honey-700 font-semibold rounded-xl shadow-md hover:shadow-lg transition-all transform hover:scale-[1.02]"
          >
            <Plus className="w-5 h-5" />
            Schedule First Interview
          </button>
        </div>
      )}
    </div>
  );
}

interface InterviewCardProps {
  interview: Interview;
  processes: any[];
  positions: any[];
  companies: any[];
  onDelete: (id: number) => void;
}

function InterviewCard({ interview, processes, positions, companies, onDelete }: InterviewCardProps) {
  const process = processes.find(p => p.id === interview.process_id);
  const position = positions.find(p => p.id === process?.job_position_id);
  const company = companies.find(c => c.id === position?.company_id);
  const statusConfig = STATUS_CONFIG[interview.status] || STATUS_CONFIG.scheduled;
  const StatusIcon = statusConfig.icon;

  return (
    <div className="bg-white rounded-2xl shadow-card border border-sand/50 p-6 hover:shadow-soft transition-all group">
      {/* Header */}
      <div className="flex justify-between items-start mb-4">
        <Link to={`/processes/${process?.id}`} className="flex-1">
          <div className="flex items-center gap-2 mb-2">
            <span className="px-2 py-1 bg-honey-50 text-honey-700 text-xs font-bold rounded">
              Round {interview.interview_round}
            </span>
            {interview.interview_type && (
              <span className="text-xs text-anthracite/60 capitalize">
                {interview.interview_type.replace('_', ' ')}
              </span>
            )}
          </div>
          <h3 className="text-lg font-display font-semibold text-navy-900 group-hover:text-honey-600 transition-colors flex items-center gap-2">
            {position?.title || 'Unknown Position'}
            <ArrowRight className="w-4 h-4 opacity-0 group-hover:opacity-100 transition-opacity" />
          </h3>
          {company && (
            <p className="text-sm text-anthracite/60 font-medium">
              {company.name}
            </p>
          )}
        </Link>
        <button
          onClick={(e) => {
            e.preventDefault();
            onDelete(interview.id);
          }}
          className="text-anthracite/40 hover:text-red-600 transition-colors p-1.5 hover:bg-red-50 rounded-lg"
          title="Delete interview"
        >
          <Trash2 className="w-4 h-4" />
        </button>
      </div>

      {/* Status and Details */}
      <div className="space-y-3">
        <span className={`inline-flex items-center gap-1.5 px-3 py-1.5 ${statusConfig.color} text-xs font-semibold rounded-lg`}>
          <StatusIcon className="w-3.5 h-3.5" />
          {statusConfig.label}
        </span>

        {interview.scheduled_date && (
          <div className="flex items-center gap-2 text-sm text-anthracite/70">
            <Calendar className="w-4 h-4 text-honey-600" />
            {new Date(interview.scheduled_date).toLocaleDateString('en-US', {
              month: 'short',
              day: 'numeric',
              year: 'numeric',
              hour: '2-digit',
              minute: '2-digit'
            })}
            {interview.duration_minutes && (
              <span className="text-xs">({interview.duration_minutes}min)</span>
            )}
          </div>
        )}

        {interview.interviewer_name && (
          <div className="flex items-center gap-2 text-sm text-anthracite/70">
            <User className="w-4 h-4 text-honey-600" />
            <span>{interview.interviewer_name}</span>
            {interview.interviewer_role && (
              <span className="text-xs text-anthracite/50">({interview.interviewer_role})</span>
            )}
          </div>
        )}

        {interview.rating && (
          <div className="flex items-center gap-1">
            {[...Array(5)].map((_, i) => (
              <Star
                key={i}
                className={`w-4 h-4 ${
                  i < interview.rating!
                    ? 'fill-honey-500 text-honey-500'
                    : 'text-gray-300'
                }`}
              />
            ))}
          </div>
        )}

        {interview.feedback && (
          <p className="text-sm text-anthracite/70 bg-sand/30 px-4 py-2 rounded-lg mt-3">
            {interview.feedback}
          </p>
        )}
      </div>
    </div>
  );
}
