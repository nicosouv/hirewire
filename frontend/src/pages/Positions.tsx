import { useState } from 'react';
import { Link } from 'react-router-dom';
import { usePositions, useCreatePosition, useDeletePosition } from '../hooks/usePositions';
import { useCompanies } from '../hooks/useCompanies';
import { useProcesses } from '../hooks/useProcesses';
import Loading from '../components/Loading';
import { Briefcase, Plus, Trash2, DollarSign, MapPin, Clock, Building2, GitBranch, ArrowRight } from 'lucide-react';
import type { Position } from '../types';

export default function Positions() {
  const { data: positions, isLoading, error } = usePositions();
  const { data: companies } = useCompanies();
  const { data: processes } = useProcesses();
  const createPosition = useCreatePosition();
  const deletePosition = useDeletePosition();
  const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState({
    company_id: '',
    title: '',
    level: '',
    contract_type: 'full_time',
    remote_policy: '',
    salary_min: '',
    salary_max: '',
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await createPosition.mutateAsync({
        ...formData,
        company_id: parseInt(formData.company_id),
        salary_min: formData.salary_min ? parseFloat(formData.salary_min) : undefined,
        salary_max: formData.salary_max ? parseFloat(formData.salary_max) : undefined,
      } as any);
      setFormData({
        company_id: '',
        title: '',
        level: '',
        contract_type: 'full_time',
        remote_policy: '',
        salary_min: '',
        salary_max: '',
      });
      setShowForm(false);
    } catch (error) {
      console.error('Failed to create position:', error);
    }
  };

  const handleDelete = async (id: number) => {
    if (window.confirm('Are you sure you want to delete this position?')) {
      try {
        await deletePosition.mutateAsync(id);
      } catch (error) {
        console.error('Failed to delete position:', error);
      }
    }
  };

  if (isLoading) return <Loading />;
  if (error) return (
    <div className="bg-red-50 border-l-4 border-red-500 text-red-800 px-6 py-4 rounded-xl">
      <p className="font-semibold">Failed to load positions</p>
      <p className="text-sm mt-1">Please try again later.</p>
    </div>
  );

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex justify-between items-start">
        <div>
          <h1 className="text-3xl font-display font-bold text-navy-900">Job Positions</h1>
          <p className="mt-2 text-anthracite/70">Track positions you're applying to</p>
        </div>
        <button
          onClick={() => setShowForm(!showForm)}
          className="flex items-center gap-2 px-5 py-3 bg-gradient-to-r from-honey-500 to-honey-600 hover:from-honey-600 hover:to-honey-700 text-white font-semibold rounded-xl shadow-md hover:shadow-lg transition-all transform hover:scale-[1.02]"
        >
          <Plus className="w-5 h-5" />
          {showForm ? 'Cancel' : 'Add Position'}
        </button>
      </div>

      {/* Add Form */}
      {showForm && (
        <div className="bg-white rounded-2xl shadow-card border border-sand/50 p-6">
          <div className="flex items-center gap-3 mb-6">
            <div className="w-10 h-10 bg-honey-100 rounded-xl flex items-center justify-center">
              <Briefcase className="w-5 h-5 text-honey-600" />
            </div>
            <h2 className="text-xl font-display font-semibold text-navy-900">Add New Position</h2>
          </div>

          <form onSubmit={handleSubmit} className="space-y-5">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
              <div>
                <label className="block text-sm font-semibold text-navy-900 mb-2">
                  Company *
                </label>
                <select
                  required
                  value={formData.company_id}
                  onChange={(e) => setFormData({ ...formData, company_id: e.target.value })}
                  className="w-full px-4 py-3 border border-sand bg-ivory/50 rounded-xl text-anthracite focus:outline-none focus:ring-2 focus:ring-honey-500 focus:border-transparent transition-all"
                >
                  <option value="">Select a company</option>
                  {companies?.map((company) => (
                    <option key={company.id} value={company.id}>
                      {company.name}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-semibold text-navy-900 mb-2">
                  Job Title *
                </label>
                <input
                  type="text"
                  required
                  value={formData.title}
                  onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                  className="w-full px-4 py-3 border border-sand bg-ivory/50 rounded-xl text-anthracite placeholder-anthracite/40 focus:outline-none focus:ring-2 focus:ring-honey-500 focus:border-transparent transition-all"
                  placeholder="e.g., Senior Software Engineer"
                />
              </div>

              <div>
                <label className="block text-sm font-semibold text-navy-900 mb-2">
                  Level
                </label>
                <select
                  value={formData.level}
                  onChange={(e) => setFormData({ ...formData, level: e.target.value })}
                  className="w-full px-4 py-3 border border-sand bg-ivory/50 rounded-xl text-anthracite focus:outline-none focus:ring-2 focus:ring-honey-500 focus:border-transparent transition-all"
                >
                  <option value="">Select level</option>
                  <option value="junior">Junior</option>
                  <option value="mid">Mid-Level</option>
                  <option value="senior">Senior</option>
                  <option value="lead">Lead</option>
                  <option value="staff">Staff</option>
                  <option value="principal">Principal</option>
                </select>
              </div>

              <div>
                <label className="block text-sm font-semibold text-navy-900 mb-2">
                  Contract Type
                </label>
                <select
                  value={formData.contract_type}
                  onChange={(e) => setFormData({ ...formData, contract_type: e.target.value })}
                  className="w-full px-4 py-3 border border-sand bg-ivory/50 rounded-xl text-anthracite focus:outline-none focus:ring-2 focus:ring-honey-500 focus:border-transparent transition-all"
                >
                  <option value="full_time">Full-time</option>
                  <option value="part_time">Part-time</option>
                  <option value="contract">Contract</option>
                  <option value="freelance">Freelance</option>
                </select>
              </div>

              <div>
                <label className="block text-sm font-semibold text-navy-900 mb-2">
                  Remote Policy
                </label>
                <select
                  value={formData.remote_policy}
                  onChange={(e) => setFormData({ ...formData, remote_policy: e.target.value })}
                  className="w-full px-4 py-3 border border-sand bg-ivory/50 rounded-xl text-anthracite focus:outline-none focus:ring-2 focus:ring-honey-500 focus:border-transparent transition-all"
                >
                  <option value="">Select policy</option>
                  <option value="remote">Full Remote</option>
                  <option value="hybrid">Hybrid</option>
                  <option value="onsite">On-site</option>
                </select>
              </div>

              <div>
                <label className="block text-sm font-semibold text-navy-900 mb-2">
                  Salary Min (€)
                </label>
                <input
                  type="number"
                  value={formData.salary_min}
                  onChange={(e) => setFormData({ ...formData, salary_min: e.target.value })}
                  className="w-full px-4 py-3 border border-sand bg-ivory/50 rounded-xl text-anthracite placeholder-anthracite/40 focus:outline-none focus:ring-2 focus:ring-honey-500 focus:border-transparent transition-all"
                  placeholder="50000"
                />
              </div>

              <div>
                <label className="block text-sm font-semibold text-navy-900 mb-2">
                  Salary Max (€)
                </label>
                <input
                  type="number"
                  value={formData.salary_max}
                  onChange={(e) => setFormData({ ...formData, salary_max: e.target.value })}
                  className="w-full px-4 py-3 border border-sand bg-ivory/50 rounded-xl text-anthracite placeholder-anthracite/40 focus:outline-none focus:ring-2 focus:ring-honey-500 focus:border-transparent transition-all"
                  placeholder="70000"
                />
              </div>
            </div>

            <div className="flex gap-3 pt-2">
              <button
                type="submit"
                disabled={createPosition.isPending}
                className="flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-honey-500 to-honey-600 hover:from-honey-600 hover:to-honey-700 text-white font-semibold rounded-xl shadow-md hover:shadow-lg disabled:opacity-50 disabled:cursor-not-allowed transition-all transform hover:scale-[1.02]"
              >
                {createPosition.isPending ? (
                  <>
                    <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                    Creating...
                  </>
                ) : (
                  <>
                    <Plus className="w-5 h-5" />
                    Create Position
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

      {/* Positions Grid */}
      {positions && positions.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {positions.map((position) => (
            <PositionCard
              key={position.id}
              position={position}
              companies={companies || []}
              processes={processes || []}
              onDelete={handleDelete}
            />
          ))}
        </div>
      ) : (
        <div className="text-center py-16">
          <div className="inline-flex items-center justify-center w-16 h-16 bg-sand rounded-2xl mb-4">
            <Briefcase className="w-8 h-8 text-anthracite/40" />
          </div>
          <h3 className="text-lg font-semibold text-navy-900 mb-2">No positions yet</h3>
          <p className="text-anthracite/60 mb-6">Start tracking job positions you're interested in</p>
          <button
            onClick={() => setShowForm(true)}
            className="inline-flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-honey-500 to-honey-600 hover:from-honey-600 hover:to-honey-700 text-white font-semibold rounded-xl shadow-md hover:shadow-lg transition-all transform hover:scale-[1.02]"
          >
            <Plus className="w-5 h-5" />
            Add Your First Position
          </button>
        </div>
      )}
    </div>
  );
}

interface PositionCardProps {
  position: Position;
  companies: any[];
  processes: any[];
  onDelete: (id: number) => void;
}

function PositionCard({ position, companies, processes, onDelete }: PositionCardProps) {
  const company = companies.find((c) => c.id === position.company_id);
  const positionProcesses = processes.filter((p) => p.job_position_id === position.id);
  const activeProcesses = positionProcesses.filter((p) =>
    !['rejected', 'accepted', 'withdrew', 'ghosted'].includes(p.status)
  );

  return (
    <div className="bg-white rounded-2xl shadow-card border border-sand/50 p-6 hover:shadow-soft transition-all">
      {/* Header */}
      <div className="flex justify-between items-start mb-4">
        <div className="flex-1">
          <h3 className="text-lg font-display font-semibold text-navy-900 mb-1">
            {position.title}
          </h3>
          {company && (
            <div className="flex items-center gap-2 text-anthracite/60">
              <Building2 className="w-4 h-4 text-honey-600" />
              <span className="text-sm font-medium">{company.name}</span>
            </div>
          )}
        </div>
        <button
          onClick={() => onDelete(position.id)}
          className="text-anthracite/40 hover:text-red-600 transition-colors p-1.5 hover:bg-red-50 rounded-lg"
          title="Delete position"
        >
          <Trash2 className="w-4 h-4" />
        </button>
      </div>

      {/* Details */}
      <div className="space-y-3">
        <div className="flex flex-wrap gap-2">
          {position.level && (
            <span className="px-3 py-1 bg-honey-50 text-honey-700 text-xs font-semibold rounded-lg">
              {position.level}
            </span>
          )}
          {position.contract_type && (
            <span className="px-3 py-1 bg-sky-50 text-sky-700 text-xs font-semibold rounded-lg">
              <Clock className="w-3 h-3 inline mr-1" />
              {position.contract_type.replace('_', '-')}
            </span>
          )}
          {position.remote_policy && (
            <span className="px-3 py-1 bg-navy-50 text-navy-700 text-xs font-semibold rounded-lg">
              <MapPin className="w-3 h-3 inline mr-1" />
              {position.remote_policy}
            </span>
          )}
        </div>

        {(position.salary_min || position.salary_max) && (
          <div className="flex items-center gap-2 text-sm font-semibold text-honey-700">
            <DollarSign className="w-4 h-4" />
            {position.salary_min && position.salary_max
              ? `${position.salary_min.toLocaleString()} - ${position.salary_max.toLocaleString()} €`
              : position.salary_min
              ? `From ${position.salary_min.toLocaleString()} €`
              : `Up to ${position.salary_max?.toLocaleString()} €`}
          </div>
        )}
      </div>

      {/* Processes for this position */}
      {positionProcesses.length > 0 && (
        <div className="mt-4 pt-4 border-t border-sand">
          <div className="flex items-center justify-between mb-3">
            <div className="flex items-center gap-2 text-sm font-semibold text-navy-900">
              <GitBranch className="w-4 h-4 text-honey-600" />
              <span>{positionProcesses.length} Application{positionProcesses.length > 1 ? 's' : ''}</span>
              {activeProcesses.length > 0 && (
                <span className="px-2 py-0.5 bg-green-50 text-green-700 text-xs rounded">
                  {activeProcesses.length} active
                </span>
              )}
            </div>
          </div>
          <div className="space-y-2">
            {positionProcesses.slice(0, 3).map((process) => (
              <Link
                key={process.id}
                to={`/processes/${process.id}`}
                className="block p-3 bg-sand/20 hover:bg-sand/40 rounded-lg transition-all group"
              >
                <div className="flex justify-between items-center">
                  <div className="flex items-center gap-2">
                    <span className="text-xs text-anthracite/60">
                      {new Date(process.application_date).toLocaleDateString('en-US', {
                        month: 'short',
                        day: 'numeric',
                        year: 'numeric'
                      })}
                    </span>
                    <ArrowRight className="w-3 h-3 text-honey-600 opacity-0 group-hover:opacity-100 transition-opacity" />
                  </div>
                  <span className="px-2 py-0.5 bg-honey-50 text-honey-700 text-xs font-semibold rounded capitalize">
                    {process.status.replace('_', ' ')}
                  </span>
                </div>
              </Link>
            ))}
            {positionProcesses.length > 3 && (
              <Link
                to="/processes"
                className="block text-center text-xs text-honey-600 hover:text-honey-700 font-semibold py-2"
              >
                View all {positionProcesses.length} applications →
              </Link>
            )}
          </div>
        </div>
      )}

      {/* Footer */}
      <div className="mt-5 pt-4 border-t border-sand">
        <p className="text-xs text-anthracite/50">
          Added {new Date(position.created_at).toLocaleDateString('en-US', {
            month: 'short',
            day: 'numeric',
            year: 'numeric'
          })}
        </p>
      </div>
    </div>
  );
}
