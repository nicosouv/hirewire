import { useState } from 'react';
import { X, Calendar, MapPin, DollarSign, Building2, Briefcase, ExternalLink, Clock, User, MessageSquare, Edit2, Plus, Check } from 'lucide-react';
import { useInterviews, useCreateInterview } from '../hooks/useInterviews';
import { useUpdateProcess } from '../hooks/useProcesses';
import type { Process, Position, Company } from '../types';

interface ApplicationDetailPanelProps {
  process: Process;
  position: Position;
  company: Company;
  onClose: () => void;
}

const STATUS_CONFIG: Record<string, { label: string; color: string }> = {
  applied: { label: 'Applied', color: 'bg-blue-500' },
  screening: { label: 'Screening', color: 'bg-purple-500' },
  interviewing: { label: 'Interviewing', color: 'bg-honey-500' },
  tech_test: { label: 'Tech Test', color: 'bg-indigo-500' },
  final_round: { label: 'Final Round', color: 'bg-orange-500' },
  offer: { label: 'Offer Received', color: 'bg-green-500' },
  rejected: { label: 'Rejected', color: 'bg-red-500' },
  accepted: { label: 'Accepted', color: 'bg-emerald-500' },
  ghosted: { label: 'Ghosted', color: 'bg-gray-500' },
  withdrew: { label: 'Withdrew', color: 'bg-slate-500' },
};

const INTERVIEW_STATUS_CONFIG: Record<string, { label: string; color: string }> = {
  scheduled: { label: 'Scheduled', color: 'bg-blue-50 text-blue-700' },
  completed: { label: 'Completed', color: 'bg-green-50 text-green-700' },
  cancelled: { label: 'Cancelled', color: 'bg-red-50 text-red-700' },
  rescheduled: { label: 'Rescheduled', color: 'bg-yellow-50 text-yellow-700' },
  no_show: { label: 'No Show', color: 'bg-gray-50 text-gray-700' },
};

export default function ApplicationDetailPanel({
  process,
  position,
  company,
  onClose,
}: ApplicationDetailPanelProps) {
  const { data: allInterviews } = useInterviews();
  const updateProcess = useUpdateProcess();
  const createInterview = useCreateInterview();

  const [isEditingStatus, setIsEditingStatus] = useState(false);
  const [selectedStatus, setSelectedStatus] = useState(process.status);
  const [showAddInterview, setShowAddInterview] = useState(false);
  const [interviewForm, setInterviewForm] = useState({
    scheduled_date: new Date().toISOString().split('T')[0],
    interview_type: 'technical',
    interviewer_name: '',
    notes: '',
    status: 'scheduled' as const,
  });

  const interviews = allInterviews?.filter((i) => i.process_id === process.id) || [];
  const sortedInterviews = [...interviews].sort((a, b) => a.interview_round - b.interview_round);

  const statusConfig = STATUS_CONFIG[process.status] || STATUS_CONFIG.applied;

  const daysAgo = Math.floor(
    (Date.now() - new Date(process.application_date).getTime()) / (1000 * 60 * 60 * 24)
  );

  const handleStatusUpdate = async () => {
    try {
      await updateProcess.mutateAsync({
        id: process.id,
        data: { status: selectedStatus },
      });
      setIsEditingStatus(false);
    } catch (error) {
      console.error('Failed to update status:', error);
    }
  };

  const handleAddInterview = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await createInterview.mutateAsync({
        ...interviewForm,
        process_id: process.id,
      });
      setShowAddInterview(false);
      setInterviewForm({
        scheduled_date: new Date().toISOString().split('T')[0],
        interview_type: 'technical',
        interviewer_name: '',
        notes: '',
        status: 'scheduled',
      });
    } catch (error) {
      console.error('Failed to add interview:', error);
    }
  };

  return (
    <>
      {/* Overlay */}
      <div
        className="fixed inset-0 bg-black/30 z-40 transition-opacity"
        onClick={onClose}
      />

      {/* Panel */}
      <div className="fixed right-0 top-0 h-full w-full max-w-2xl bg-white shadow-2xl z-50 overflow-y-auto">
        {/* Header */}
        <div className="sticky top-0 bg-white border-b border-sand/50 p-6 flex justify-between items-start">
          <div className="flex-1">
            <div className={`h-1 ${statusConfig.color} rounded-full mb-4 w-24`} />
            <h2 className="text-2xl font-display font-bold text-navy-900">{position.title}</h2>
            <p className="text-lg text-anthracite/70 font-medium mt-1">{company.name}</p>
            <div className="flex items-center gap-2 mt-3">
              {!isEditingStatus ? (
                <>
                  <span className={`inline-block px-3 py-1 ${statusConfig.color} text-xs font-semibold rounded-lg`}>
                    {statusConfig.label}
                  </span>
                  <button
                    onClick={() => setIsEditingStatus(true)}
                    className="p-1 hover:bg-sand/30 rounded transition-colors"
                  >
                    <Edit2 className="w-3.5 h-3.5 text-anthracite/50" />
                  </button>
                </>
              ) : (
                <div className="flex items-center gap-2">
                  <select
                    value={selectedStatus}
                    onChange={(e) => setSelectedStatus(e.target.value)}
                    className="px-3 py-1 border-2 border-honey-500 rounded-lg text-xs font-semibold focus:outline-none"
                  >
                    <option value="applied">Applied</option>
                    <option value="screening">Screening</option>
                    <option value="interviewing">Interviewing</option>
                    <option value="tech_test">Tech Test</option>
                    <option value="final_round">Final Round</option>
                    <option value="offer">Offer Received</option>
                    <option value="rejected">Rejected</option>
                    <option value="accepted">Accepted</option>
                    <option value="ghosted">Ghosted</option>
                    <option value="withdrew">Withdrew</option>
                  </select>
                  <button
                    onClick={handleStatusUpdate}
                    disabled={updateProcess.isPending}
                    className="p-1 bg-green-500 rounded hover:bg-green-600 transition-colors disabled:opacity-50"
                  >
                    <Check className="w-3.5 h-3.5" />
                  </button>
                  <button
                    onClick={() => {
                      setIsEditingStatus(false);
                      setSelectedStatus(process.status);
                    }}
                    className="p-1 hover:bg-sand/30 rounded transition-colors"
                  >
                    <X className="w-3.5 h-3.5" />
                  </button>
                </div>
              )}
              <span className="text-sm text-anthracite/50">
                Applied {daysAgo === 0 ? 'today' : `${daysAgo}d ago`}
              </span>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2 hover:bg-sand/30 rounded-lg transition-colors flex-shrink-0"
          >
            <X className="w-6 h-6 text-anthracite/60" />
          </button>
        </div>

        <div className="p-6 space-y-6">
          {/* Position Details */}
          <section>
            <h3 className="text-sm font-bold text-navy-900 uppercase tracking-wide mb-3 flex items-center gap-2">
              <Briefcase className="w-4 h-4" />
              Position Details
            </h3>
            <div className="bg-sand/20 rounded-xl p-4 space-y-3">
              {position.location && (
                <div className="flex items-center gap-2 text-sm">
                  <MapPin className="w-4 h-4 text-anthracite/60" />
                  <span className="text-anthracite/70">{position.location}</span>
                </div>
              )}
              {position.salary_range && (
                <div className="flex items-center gap-2 text-sm">
                  <DollarSign className="w-4 h-4 text-anthracite/60" />
                  <span className="text-anthracite/70">{position.salary_range}</span>
                </div>
              )}
              {position.employment_type && (
                <div className="flex items-center gap-2 text-sm">
                  <Clock className="w-4 h-4 text-anthracite/60" />
                  <span className="text-anthracite/70 capitalize">{position.employment_type.replace('_', ' ')}</span>
                </div>
              )}
              {position.description && (
                <div className="pt-2 border-t border-sand/50">
                  <p className="text-sm text-anthracite/70 leading-relaxed">{position.description}</p>
                </div>
              )}
            </div>
          </section>

          {/* Company Details */}
          <section>
            <h3 className="text-sm font-bold text-navy-900 uppercase tracking-wide mb-3 flex items-center gap-2">
              <Building2 className="w-4 h-4" />
              Company Info
            </h3>
            <div className="bg-sand/20 rounded-xl p-4 space-y-3">
              {company.industry && (
                <div className="text-sm">
                  <span className="text-anthracite/60">Industry: </span>
                  <span className="text-anthracite font-medium">{company.industry}</span>
                </div>
              )}
              {company.size && (
                <div className="text-sm">
                  <span className="text-anthracite/60">Size: </span>
                  <span className="text-anthracite font-medium">{company.size}</span>
                </div>
              )}
              {company.location && (
                <div className="text-sm">
                  <span className="text-anthracite/60">Location: </span>
                  <span className="text-anthracite font-medium">{company.location}</span>
                </div>
              )}
              {company.website && (
                <a
                  href={company.website}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1 text-sm text-honey-600 hover:text-honey-700 font-medium"
                >
                  Visit website
                  <ExternalLink className="w-3.5 h-3.5" />
                </a>
              )}
            </div>
          </section>

          {/* Application Details */}
          <section>
            <h3 className="text-sm font-bold text-navy-900 uppercase tracking-wide mb-3 flex items-center gap-2">
              <Calendar className="w-4 h-4" />
              Application Timeline
            </h3>
            <div className="bg-sand/20 rounded-xl p-4 space-y-3">
              <div className="text-sm">
                <span className="text-anthracite/60">Applied on: </span>
                <span className="text-anthracite font-medium">
                  {new Date(process.application_date).toLocaleDateString('en-US', {
                    weekday: 'long',
                    year: 'numeric',
                    month: 'long',
                    day: 'numeric',
                  })}
                </span>
              </div>
              {process.source && (
                <div className="text-sm">
                  <span className="text-anthracite/60">Source: </span>
                  <span className="text-anthracite font-medium">{process.source}</span>
                </div>
              )}
            </div>
          </section>

          {/* Interviews */}
          <section>
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-sm font-bold text-navy-900 uppercase tracking-wide flex items-center gap-2">
                <User className="w-4 h-4" />
                Interviews ({sortedInterviews.length})
              </h3>
              <button
                onClick={() => setShowAddInterview(!showAddInterview)}
                className="flex items-center gap-2 px-4 py-2.5 bg-gradient-to-r from-honey-500 to-honey-600 hover:from-honey-600 hover:to-honey-700 text-sm font-bold rounded-xl shadow-md hover:shadow-lg transition-all transform hover:scale-[1.02]"
              >
                <Plus className="w-4 h-4" />
                Add Interview
              </button>
            </div>

            {showAddInterview && (
              <form onSubmit={handleAddInterview} className="bg-honey-50/50 border-2 border-honey-200 rounded-xl p-4 mb-3 space-y-3">
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs font-medium text-anthracite/70 mb-1">Date</label>
                    <input
                      type="date"
                      required
                      value={interviewForm.scheduled_date}
                      onChange={(e) => setInterviewForm({ ...interviewForm, scheduled_date: e.target.value })}
                      className="w-full px-3 py-2 border border-sand bg-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-honey-500"
                    />
                  </div>
                </div>
                <div>
                  <label className="block text-xs font-medium text-anthracite/70 mb-1">Type</label>
                  <select
                    value={interviewForm.interview_type}
                    onChange={(e) => setInterviewForm({ ...interviewForm, interview_type: e.target.value })}
                    className="w-full px-3 py-2 border border-sand bg-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-honey-500"
                  >
                    <option value="technical">Technical</option>
                    <option value="behavioral">Behavioral</option>
                    <option value="system_design">System Design</option>
                    <option value="hr">HR</option>
                    <option value="manager">Manager</option>
                    <option value="cultural">Cultural</option>
                    <option value="case_study">Case Study</option>
                  </select>
                </div>
                <div>
                  <label className="block text-xs font-medium text-anthracite/70 mb-1">Interviewer Name</label>
                  <input
                    type="text"
                    value={interviewForm.interviewer_name}
                    onChange={(e) => setInterviewForm({ ...interviewForm, interviewer_name: e.target.value })}
                    className="w-full px-3 py-2 border border-sand bg-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-honey-500"
                    placeholder="Optional"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-anthracite/70 mb-1">Notes</label>
                  <textarea
                    rows={2}
                    value={interviewForm.notes}
                    onChange={(e) => setInterviewForm({ ...interviewForm, notes: e.target.value })}
                    className="w-full px-3 py-2 border border-sand bg-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-honey-500 resize-none"
                    placeholder="Optional"
                  />
                </div>
                <div className="flex gap-2 pt-2">
                  <button
                    type="submit"
                    disabled={createInterview.isPending}
                    className="flex-1 px-4 py-2 bg-honey-500  text-sm font-semibold rounded-lg hover:bg-honey-600 transition-all disabled:opacity-50"
                  >
                    {createInterview.isPending ? 'Adding...' : 'Add Interview'}
                  </button>
                  <button
                    type="button"
                    onClick={() => setShowAddInterview(false)}
                    className="px-4 py-2 border-2 border-sand text-anthracite text-sm font-semibold rounded-lg hover:bg-sand/30 transition-all"
                  >
                    Cancel
                  </button>
                </div>
              </form>
            )}

            {sortedInterviews.length > 0 ? (
              <div className="space-y-3">
                {sortedInterviews.map((interview) => {
                  const interviewStatus = INTERVIEW_STATUS_CONFIG[interview.status] || INTERVIEW_STATUS_CONFIG.scheduled;
                  return (
                    <div key={interview.id} className="bg-sand/20 rounded-xl p-4">
                      <div className="flex justify-between items-start mb-2">
                        <div>
                          <h4 className="font-semibold text-navy-900">
                            Round {interview.interview_round}: {interview.interview_type}
                          </h4>
                          {interview.interviewer_name && (
                            <p className="text-sm text-anthracite/60 mt-1">
                              with {interview.interviewer_name}
                            </p>
                          )}
                        </div>
                        <span className={`px-2 py-1 ${interviewStatus.color} text-xs font-semibold rounded-md`}>
                          {interviewStatus.label}
                        </span>
                      </div>
                      <div className="flex items-center gap-2 text-sm text-anthracite/60 mt-2">
                        <Calendar className="w-3.5 h-3.5" />
                        <span>
                          {new Date(interview.scheduled_date).toLocaleDateString('en-US', {
                            month: 'short',
                            day: 'numeric',
                            year: 'numeric',
                          })}
                        </span>
                      </div>
                      {interview.notes && (
                        <p className="text-sm text-anthracite/70 mt-3 bg-white/50 p-2 rounded-lg">
                          {interview.notes}
                        </p>
                      )}
                    </div>
                  );
                })}
              </div>
            ) : !showAddInterview && (
              <div className="bg-gradient-to-br from-blue-50 to-purple-50 border-2 border-dashed border-blue-200 rounded-xl p-6 text-center">
                <div className="inline-flex items-center justify-center w-12 h-12 bg-blue-100 rounded-full mb-3">
                  <Calendar className="w-6 h-6 text-blue-600" />
                </div>
                <p className="text-sm font-semibold text-navy-900 mb-1">No interviews scheduled yet</p>
                <p className="text-xs text-anthracite/60 mb-4">Track your interview rounds to stay organized</p>
                <button
                  onClick={() => setShowAddInterview(true)}
                  className="inline-flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-honey-500 to-honey-600 hover:from-honey-600 hover:to-honey-700  text-sm font-bold rounded-lg shadow-md hover:shadow-lg transition-all"
                >
                  <Plus className="w-4 h-4" />
                  Schedule First Interview
                </button>
              </div>
            )}
          </section>

          {/* Notes */}
          {process.notes && (
            <section>
              <h3 className="text-sm font-bold text-navy-900 uppercase tracking-wide mb-3 flex items-center gap-2">
                <MessageSquare className="w-4 h-4" />
                Notes
              </h3>
              <div className="bg-sand/20 rounded-xl p-4">
                <p className="text-sm text-anthracite/70 leading-relaxed whitespace-pre-wrap">
                  {process.notes}
                </p>
              </div>
            </section>
          )}
        </div>
      </div>
    </>
  );
}
