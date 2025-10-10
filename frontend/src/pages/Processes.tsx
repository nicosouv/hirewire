import { useState } from 'react';
import { Link } from 'react-router-dom';
import { useProcesses, useCreateProcess, useDeleteProcess } from '../hooks/useProcesses';
import { usePositions } from '../hooks/usePositions';
import { useCompanies } from '../hooks/useCompanies';
import Loading from '../components/Loading';
import { GitBranch, Plus, Trash2, Calendar, FileText, AlertCircle, CheckCircle, Clock, ArrowRight } from 'lucide-react';
import type { Process } from '../types';

const STATUS_CONFIG = {
  applied: { label: 'Applied', color: 'bg-blue-50 text-blue-700', icon: FileText },
  screening: { label: 'Screening', color: 'bg-purple-50 text-purple-700', icon: AlertCircle },
  interviewing: { label: 'Interviewing', color: 'bg-honey-50 text-honey-700', icon: Clock },
  tech_test: { label: 'Tech Test', color: 'bg-indigo-50 text-indigo-700', icon: FileText },
  final_round: { label: 'Final Round', color: 'bg-orange-50 text-orange-700', icon: AlertCircle },
  offer: { label: 'Offer', color: 'bg-green-50 text-green-700', icon: CheckCircle },
  rejected: { label: 'Rejected', color: 'bg-red-50 text-red-700', icon: AlertCircle },
  accepted: { label: 'Accepted', color: 'bg-emerald-50 text-emerald-700', icon: CheckCircle },
  ghosted: { label: 'Ghosted', color: 'bg-gray-50 text-gray-700', icon: AlertCircle },
  withdrew: { label: 'Withdrew', color: 'bg-slate-50 text-slate-700', icon: AlertCircle },
  reminder: { label: 'Reminder', color: 'bg-yellow-50 text-yellow-700', icon: Clock },
};

export default function Processes() {
  const { data: processes, isLoading, error } = useProcesses();
  const { data: positions } = usePositions();
  const { data: companies } = useCompanies();
  const createProcess = useCreateProcess();
  const deleteProcess = useDeleteProcess();
  const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState({
    job_position_id: '',
    application_date: new Date().toISOString().split('T')[0],
    status: 'applied' as const,
    source: '',
    notes: '',
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await createProcess.mutateAsync({
        ...formData,
        job_position_id: parseInt(formData.job_position_id),
      } as any);
      setFormData({
        job_position_id: '',
        application_date: new Date().toISOString().split('T')[0],
        status: 'applied',
        source: '',
        notes: '',
      });
      setShowForm(false);
    } catch (error) {
      console.error('Failed to create process:', error);
    }
  };

  const handleDelete = async (id: number) => {
    if (window.confirm('Are you sure you want to delete this process?')) {
      try {
        await deleteProcess.mutateAsync(id);
      } catch (error) {
        console.error('Failed to delete process:', error);
      }
    }
  };

  if (isLoading) return <Loading />;
  if (error) return (
    <div className="bg-red-50 border-l-4 border-red-500 text-red-800 px-6 py-4 rounded-xl">
      <p className="font-semibold">Failed to load processes</p>
      <p className="text-sm mt-1">Please try again later.</p>
    </div>
  );

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex justify-between items-start">
        <div>
          <h1 className="text-3xl font-display font-bold text-navy-900">Interview Processes</h1>
          <p className="mt-2 text-anthracite/70">Track your application journey</p>
        </div>
        <button
          onClick={() => setShowForm(!showForm)}
          className="flex items-center gap-2 px-5 py-3 bg-gradient-to-r from-honey-500 to-honey-600 hover:from-honey-600 hover:to-honey-700 text-white font-semibold rounded-xl shadow-md hover:shadow-lg transition-all transform hover:scale-[1.02]"
        >
          <Plus className="w-5 h-5" />
          {showForm ? 'Cancel' : 'Add Process'}
        </button>
      </div>

      {/* Add Form */}
      {showForm && (
        <div className="bg-white rounded-2xl shadow-card border border-sand/50 p-6">
          <div className="flex items-center gap-3 mb-6">
            <div className="w-10 h-10 bg-honey-100 rounded-xl flex items-center justify-center">
              <GitBranch className="w-5 h-5 text-honey-600" />
            </div>
            <h2 className="text-xl font-display font-semibold text-navy-900">Start New Application Process</h2>
          </div>

          <form onSubmit={handleSubmit} className="space-y-5">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
              <div>
                <label className="block text-sm font-semibold text-navy-900 mb-2">
                  Job Position *
                </label>
                <select
                  required
                  value={formData.job_position_id}
                  onChange={(e) => setFormData({ ...formData, job_position_id: e.target.value })}
                  className="w-full px-4 py-3 border border-sand bg-ivory/50 rounded-xl text-anthracite focus:outline-none focus:ring-2 focus:ring-honey-500 focus:border-transparent transition-all"
                >
                  <option value="">Select a position</option>
                  {positions?.map((position) => {
                    const company = companies?.find(c => c.id === position.company_id);
                    return (
                      <option key={position.id} value={position.id}>
                        {position.title} @ {company?.name || 'Unknown'}
                      </option>
                    );
                  })}
                </select>
              </div>

              <div>
                <label className="block text-sm font-semibold text-navy-900 mb-2">
                  Application Date *
                </label>
                <input
                  type="date"
                  required
                  value={formData.application_date}
                  onChange={(e) => setFormData({ ...formData, application_date: e.target.value })}
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
                  Source
                </label>
                <input
                  type="text"
                  value={formData.source}
                  onChange={(e) => setFormData({ ...formData, source: e.target.value })}
                  className="w-full px-4 py-3 border border-sand bg-ivory/50 rounded-xl text-anthracite placeholder-anthracite/40 focus:outline-none focus:ring-2 focus:ring-honey-500 focus:border-transparent transition-all"
                  placeholder="e.g., LinkedIn, Company website"
                />
              </div>

              <div className="md:col-span-2">
                <label className="block text-sm font-semibold text-navy-900 mb-2">
                  Notes
                </label>
                <textarea
                  value={formData.notes}
                  onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
                  rows={3}
                  className="w-full px-4 py-3 border border-sand bg-ivory/50 rounded-xl text-anthracite placeholder-anthracite/40 focus:outline-none focus:ring-2 focus:ring-honey-500 focus:border-transparent transition-all resize-none"
                  placeholder="Add any relevant notes..."
                />
              </div>
            </div>

            <div className="flex gap-3 pt-2">
              <button
                type="submit"
                disabled={createProcess.isPending}
                className="flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-honey-500 to-honey-600 hover:from-honey-600 hover:to-honey-700 text-white font-semibold rounded-xl shadow-md hover:shadow-lg disabled:opacity-50 disabled:cursor-not-allowed transition-all transform hover:scale-[1.02]"
              >
                {createProcess.isPending ? (
                  <>
                    <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                    Creating...
                  </>
                ) : (
                  <>
                    <Plus className="w-5 h-5" />
                    Start Process
                  </>
                )}
              </button>
              <button
                type="button"
                onClick={() => setShowForm(false)}
                className="px-6 py-3 border-2 border-navy-900 text-navy-900 font-semibold rounded-xl hover:bg-navy-900 hover:text-white transition-all"
              >
                Cancel
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Processes List */}
      {processes && processes.length > 0 ? (
        <div className="space-y-4">
          {processes.map((process) => (
            <ProcessCard
              key={process.id}
              process={process}
              positions={positions || []}
              companies={companies || []}
              onDelete={handleDelete}
            />
          ))}
        </div>
      ) : (
        <div className="text-center py-16">
          <div className="inline-flex items-center justify-center w-16 h-16 bg-sand rounded-2xl mb-4">
            <GitBranch className="w-8 h-8 text-anthracite/40" />
          </div>
          <h3 className="text-lg font-semibold text-navy-900 mb-2">No processes yet</h3>
          <p className="text-anthracite/60 mb-6">Start tracking your first application</p>
          <button
            onClick={() => setShowForm(true)}
            className="inline-flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-honey-500 to-honey-600 hover:from-honey-600 hover:to-honey-700 text-white font-semibold rounded-xl shadow-md hover:shadow-lg transition-all transform hover:scale-[1.02]"
          >
            <Plus className="w-5 h-5" />
            Start Your First Process
          </button>
        </div>
      )}
    </div>
  );
}

interface ProcessCardProps {
  process: Process;
  positions: any[];
  companies: any[];
  onDelete: (id: number) => void;
}

function ProcessCard({ process, positions, companies, onDelete }: ProcessCardProps) {
  const position = positions.find(p => p.id === process.job_position_id);
  const company = companies.find(c => c.id === position?.company_id);
  const statusConfig = STATUS_CONFIG[process.status] || STATUS_CONFIG.applied;
  const StatusIcon = statusConfig.icon;

  return (
    <div className="bg-white rounded-2xl shadow-card border border-sand/50 p-6 hover:shadow-soft transition-all group">
      <div className="flex justify-between items-start gap-4">
        <Link to={`/processes/${process.id}`} className="flex-1">
          {/* Header */}
          <div className="flex items-start gap-3 mb-4">
            <div className="w-12 h-12 bg-gradient-to-br from-honey-400 to-honey-500 rounded-xl flex items-center justify-center flex-shrink-0">
              <GitBranch className="w-6 h-6 text-white" />
            </div>
            <div className="flex-1">
              <h3 className="text-lg font-display font-semibold text-navy-900 group-hover:text-honey-600 transition-colors flex items-center gap-2">
                {position?.title || 'Unknown Position'}
                <ArrowRight className="w-4 h-4 opacity-0 group-hover:opacity-100 transition-opacity" />
              </h3>
              {company && (
                <p className="text-sm text-anthracite/60 font-medium mt-0.5">
                  {company.name}
                </p>
              )}
            </div>
          </div>

          {/* Status and Date */}
          <div className="flex flex-wrap items-center gap-3 mb-4">
            <span className={`inline-flex items-center gap-1.5 px-3 py-1.5 ${statusConfig.color} text-xs font-semibold rounded-lg`}>
              <StatusIcon className="w-3.5 h-3.5" />
              {statusConfig.label}
            </span>
            <span className="inline-flex items-center gap-1.5 text-xs text-anthracite/60">
              <Calendar className="w-3.5 h-3.5" />
              Applied {new Date(process.application_date).toLocaleDateString('en-US', {
                month: 'short',
                day: 'numeric',
                year: 'numeric'
              })}
            </span>
            {process.source && (
              <span className="text-xs text-anthracite/60">
                via {process.source}
              </span>
            )}
          </div>

          {/* Notes */}
          {process.notes && (
            <p className="text-sm text-anthracite/70 bg-sand/30 px-4 py-2 rounded-lg">
              {process.notes}
            </p>
          )}
        </Link>

        {/* Delete button */}
        <button
          onClick={(e) => {
            e.preventDefault();
            onDelete(process.id);
          }}
          className="text-anthracite/40 hover:text-red-600 transition-colors p-1.5 hover:bg-red-50 rounded-lg flex-shrink-0"
          title="Delete process"
        >
          <Trash2 className="w-4 h-4" />
        </button>
      </div>
    </div>
  );
}
