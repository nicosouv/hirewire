import { useState } from 'react';
import { X, Plus, Building2, Briefcase } from 'lucide-react';
import { useCreateCompany } from '../hooks/useCompanies';
import { useCreatePosition } from '../hooks/usePositions';
import { useCreateProcess } from '../hooks/useProcesses';

interface QuickAddModalProps {
  isOpen: boolean;
  onClose: () => void;
  companies: any[];
  positions: any[];
}

export default function QuickAddModal({ isOpen, onClose, companies, positions }: QuickAddModalProps) {
  const [step, setStep] = useState<'company' | 'position' | 'process'>('process');
  const [selectedCompanyId, setSelectedCompanyId] = useState<string>('');
  const [selectedPositionId, setSelectedPositionId] = useState<string>('');
  const [showNewCompany, setShowNewCompany] = useState(false);
  const [showNewPosition, setShowNewPosition] = useState(false);

  const createCompany = useCreateCompany();
  const createPosition = useCreatePosition();
  const createProcess = useCreateProcess();

  const [companyForm, setCompanyForm] = useState({
    name: '',
    industry: '',
    size: '',
    location: '',
  });

  const [positionForm, setPositionForm] = useState({
    title: '',
    department: '',
    level: '',
    employment_type: 'full-time' as const,
    remote_policy: '',
    salary_min: '',
    salary_max: '',
    currency: 'EUR',
  });

  const [processForm, setProcessForm] = useState({
    application_date: new Date().toISOString().split('T')[0],
    status: 'applied' as const,
    source: '',
    notes: '',
  });

  const resetForm = () => {
    setStep('process');
    setSelectedCompanyId('');
    setSelectedPositionId('');
    setShowNewCompany(false);
    setShowNewPosition(false);
    setCompanyForm({ name: '', industry: '', size: '', location: '' });
    setPositionForm({
      title: '',
      department: '',
      level: '',
      employment_type: 'full-time',
      remote_policy: '',
      salary_min: '',
      salary_max: '',
      currency: 'EUR'
    });
    setProcessForm({
      application_date: new Date().toISOString().split('T')[0],
      status: 'applied',
      source: '',
      notes: '',
    });
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    try {
      let companyId: number;
      let positionId: number;

      // Create company if needed
      if (showNewCompany) {
        const company = await createCompany.mutateAsync(companyForm);
        companyId = company.id;
      } else {
        companyId = parseInt(selectedCompanyId);
      }

      // Create position if needed
      if (showNewPosition) {
        const position = await createPosition.mutateAsync({
          ...positionForm,
          company_id: companyId,
          salary_min: positionForm.salary_min ? parseInt(positionForm.salary_min) : undefined,
          salary_max: positionForm.salary_max ? parseInt(positionForm.salary_max) : undefined,
        });
        positionId = position.id;
      } else {
        positionId = parseInt(selectedPositionId);
      }

      // Create process
      await createProcess.mutateAsync({
        ...processForm,
        job_position_id: positionId,
      } as any);

      resetForm();
      onClose();
    } catch (error) {
      console.error('Failed to create application:', error);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-2xl shadow-2xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="sticky top-0 bg-white border-b border-sand/50 p-6 flex justify-between items-center">
          <div>
            <h2 className="text-2xl font-display font-bold text-navy-900">Quick Add Application</h2>
            <p className="text-sm text-anthracite/60 mt-1">Add a new job application in seconds</p>
          </div>
          <button
            onClick={() => {
              resetForm();
              onClose();
            }}
            className="p-2 hover:bg-sand/30 rounded-lg transition-colors"
          >
            <X className="w-5 h-5 text-anthracite/60" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-6">
          {/* Company Selection */}
          <div>
            <label className="block text-sm font-semibold text-navy-900 mb-2">
              Company *
            </label>
            {!showNewCompany ? (
              <div className="flex gap-2">
                <select
                  required={!showNewCompany}
                  value={selectedCompanyId}
                  onChange={(e) => setSelectedCompanyId(e.target.value)}
                  className="flex-1 px-4 py-3 border-2 border-sand bg-white rounded-xl text-anthracite focus:outline-none focus:border-honey-500 transition-all"
                >
                  <option value="">Select a company</option>
                  {companies?.map((company) => (
                    <option key={company.id} value={company.id}>
                      {company.name}
                    </option>
                  ))}
                </select>
                <button
                  type="button"
                  onClick={() => setShowNewCompany(true)}
                  className="px-4 py-3 border-2 border-honey-500 text-honey-600 font-semibold rounded-xl hover:bg-honey-50 transition-all flex items-center gap-2"
                >
                  <Building2 className="w-4 h-4" />
                  New
                </button>
              </div>
            ) : (
              <div className="space-y-3 p-4 bg-honey-50/50 rounded-xl border-2 border-honey-200">
                <div className="flex justify-between items-center mb-2">
                  <span className="text-sm font-semibold text-honey-700">New Company</span>
                  <button
                    type="button"
                    onClick={() => setShowNewCompany(false)}
                    className="text-xs text-anthracite/60 hover:text-anthracite"
                  >
                    Use existing
                  </button>
                </div>
                <input
                  type="text"
                  required
                  placeholder="Company name *"
                  value={companyForm.name}
                  onChange={(e) => setCompanyForm({ ...companyForm, name: e.target.value })}
                  className="w-full px-3 py-2 border border-sand bg-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-honey-500"
                />
                <div className="grid grid-cols-2 gap-2">
                  <input
                    type="text"
                    placeholder="Industry"
                    value={companyForm.industry}
                    onChange={(e) => setCompanyForm({ ...companyForm, industry: e.target.value })}
                    className="px-3 py-2 border border-sand bg-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-honey-500"
                  />
                  <input
                    type="text"
                    placeholder="Location"
                    value={companyForm.location}
                    onChange={(e) => setCompanyForm({ ...companyForm, location: e.target.value })}
                    className="px-3 py-2 border border-sand bg-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-honey-500"
                  />
                </div>
              </div>
            )}
          </div>

          {/* Position Selection */}
          <div>
            <label className="block text-sm font-semibold text-navy-900 mb-2">
              Position *
            </label>
            {!showNewPosition ? (
              <div className="flex gap-2">
                <select
                  required={!showNewPosition}
                  value={selectedPositionId}
                  onChange={(e) => setSelectedPositionId(e.target.value)}
                  className="flex-1 px-4 py-3 border-2 border-sand bg-white rounded-xl text-anthracite focus:outline-none focus:border-honey-500 transition-all"
                  disabled={!selectedCompanyId && !showNewCompany}
                >
                  <option value="">Select a position</option>
                  {positions
                    ?.filter((p) => p.company_id === parseInt(selectedCompanyId))
                    .map((position) => (
                      <option key={position.id} value={position.id}>
                        {position.title}
                      </option>
                    ))}
                </select>
                <button
                  type="button"
                  onClick={() => setShowNewPosition(true)}
                  disabled={!selectedCompanyId && !showNewCompany}
                  className="px-4 py-3 border-2 border-honey-500 text-honey-600 font-semibold rounded-xl hover:bg-honey-50 transition-all flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <Briefcase className="w-4 h-4" />
                  New
                </button>
              </div>
            ) : (
              <div className="space-y-3 p-4 bg-honey-50/50 rounded-xl border-2 border-honey-200">
                <div className="flex justify-between items-center mb-2">
                  <span className="text-sm font-semibold text-honey-700">New Position</span>
                  <button
                    type="button"
                    onClick={() => setShowNewPosition(false)}
                    className="text-xs text-anthracite/60 hover:text-anthracite"
                  >
                    Use existing
                  </button>
                </div>
                <input
                  type="text"
                  required
                  placeholder="Position title *"
                  value={positionForm.title}
                  onChange={(e) => setPositionForm({ ...positionForm, title: e.target.value })}
                  className="w-full px-3 py-2 border border-sand bg-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-honey-500"
                />
                <div className="grid grid-cols-2 gap-2">
                  <input
                    type="text"
                    placeholder="Department"
                    value={positionForm.department}
                    onChange={(e) => setPositionForm({ ...positionForm, department: e.target.value })}
                    className="px-3 py-2 border border-sand bg-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-honey-500"
                  />
                  <input
                    type="text"
                    placeholder="Level (e.g., Senior)"
                    value={positionForm.level}
                    onChange={(e) => setPositionForm({ ...positionForm, level: e.target.value })}
                    className="px-3 py-2 border border-sand bg-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-honey-500"
                  />
                </div>
                <div className="grid grid-cols-2 gap-2">
                  <select
                    value={positionForm.employment_type}
                    onChange={(e) => setPositionForm({ ...positionForm, employment_type: e.target.value as any })}
                    className="px-3 py-2 border border-sand bg-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-honey-500"
                  >
                    <option value="full-time">Full-time</option>
                    <option value="part-time">Part-time</option>
                    <option value="contract">Contract</option>
                    <option value="freelance">Freelance</option>
                  </select>
                  <select
                    value={positionForm.remote_policy}
                    onChange={(e) => setPositionForm({ ...positionForm, remote_policy: e.target.value })}
                    className="px-3 py-2 border border-sand bg-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-honey-500"
                  >
                    <option value="">Remote policy</option>
                    <option value="full-remote">Full remote</option>
                    <option value="hybrid">Hybrid</option>
                    <option value="on-site">On-site</option>
                  </select>
                </div>
                <div className="grid grid-cols-3 gap-2">
                  <input
                    type="number"
                    placeholder="Min salary"
                    value={positionForm.salary_min}
                    onChange={(e) => setPositionForm({ ...positionForm, salary_min: e.target.value })}
                    className="px-3 py-2 border border-sand bg-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-honey-500"
                  />
                  <input
                    type="number"
                    placeholder="Max salary"
                    value={positionForm.salary_max}
                    onChange={(e) => setPositionForm({ ...positionForm, salary_max: e.target.value })}
                    className="px-3 py-2 border border-sand bg-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-honey-500"
                  />
                  <select
                    value={positionForm.currency}
                    onChange={(e) => setPositionForm({ ...positionForm, currency: e.target.value })}
                    className="px-3 py-2 border border-sand bg-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-honey-500"
                  >
                    <option value="EUR">EUR</option>
                    <option value="USD">USD</option>
                    <option value="GBP">GBP</option>
                  </select>
                </div>
              </div>
            )}
          </div>

          {/* Application Details */}
          <div className="space-y-4 p-4 bg-sand/20 rounded-xl">
            <h3 className="text-sm font-semibold text-navy-900">Application Details</h3>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-medium text-anthracite/70 mb-1">
                  Application Date
                </label>
                <input
                  type="date"
                  required
                  value={processForm.application_date}
                  onChange={(e) => setProcessForm({ ...processForm, application_date: e.target.value })}
                  className="w-full px-3 py-2 border border-sand bg-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-honey-500"
                />
              </div>

              <div>
                <label className="block text-xs font-medium text-anthracite/70 mb-1">
                  Source
                </label>
                <input
                  type="text"
                  placeholder="e.g., LinkedIn"
                  value={processForm.source}
                  onChange={(e) => setProcessForm({ ...processForm, source: e.target.value })}
                  className="w-full px-3 py-2 border border-sand bg-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-honey-500"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-medium text-anthracite/70 mb-1">
                Notes (optional)
              </label>
              <textarea
                rows={3}
                placeholder="Add any notes about this application..."
                value={processForm.notes}
                onChange={(e) => setProcessForm({ ...processForm, notes: e.target.value })}
                className="w-full px-3 py-2 border border-sand bg-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-honey-500 resize-none"
              />
            </div>
          </div>

          {/* Actions */}
          <div className="flex gap-3 pt-2">
            <button
              type="submit"
              disabled={createCompany.isPending || createPosition.isPending || createProcess.isPending}
              className="flex-1 flex items-center justify-center gap-2 px-6 py-3 bg-gradient-to-r from-honey-500 to-honey-600 hover:from-honey-600 hover:to-honey-700 font-semibold rounded-xl shadow-md hover:shadow-lg disabled:opacity-50 disabled:cursor-not-allowed transition-all"
            >
              {createProcess.isPending ? (
                <>
                  <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                  Creating...
                </>
              ) : (
                <>
                  <Plus className="w-5 h-5" />
                  Add Application
                </>
              )}
            </button>
            <button
              type="button"
              onClick={() => {
                resetForm();
                onClose();
              }}
              className="px-6 py-3 border-2 border-sand text-anthracite font-semibold rounded-xl hover:bg-sand/30 transition-all"
            >
              Cancel
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
