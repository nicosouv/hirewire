import { useState } from 'react';
import { useCompanies, useCreateCompany, useDeleteCompany } from '../hooks/useCompanies';
import Loading from '../components/Loading';
import { Building2, Plus, Trash2, ExternalLink, MapPin, Users, Briefcase, Globe } from 'lucide-react';
import type { Company } from '../types';

export default function Companies() {
  const { data: companies, isLoading, error } = useCompanies();
  const createCompany = useCreateCompany();
  const deleteCompany = useDeleteCompany();
  const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState({
    name: '',
    industry: '',
    size: '',
    location: '',
    website: '',
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await createCompany.mutateAsync(formData);
      setFormData({ name: '', industry: '', size: '', location: '', website: '' });
      setShowForm(false);
    } catch (error) {
      console.error('Failed to create company:', error);
    }
  };

  const handleDelete = async (id: number) => {
    if (window.confirm('Are you sure you want to delete this company?')) {
      try {
        await deleteCompany.mutateAsync(id);
      } catch (error) {
        console.error('Failed to delete company:', error);
      }
    }
  };

  if (isLoading) return <Loading />;
  if (error) return (
    <div className="bg-red-50 border-l-4 border-red-500 text-red-800 px-6 py-4 rounded-xl">
      <p className="font-semibold">Failed to load companies</p>
      <p className="text-sm mt-1">Please try again later.</p>
    </div>
  );

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex justify-between items-start">
        <div>
          <h1 className="text-3xl font-display font-bold text-navy-900">Companies</h1>
          <p className="mt-2 text-anthracite/70">Manage companies you're interested in</p>
        </div>
        <button
          onClick={() => setShowForm(!showForm)}
          className="flex items-center gap-2 px-5 py-3 bg-gradient-to-r from-honey-500 to-honey-600 hover:from-honey-600 hover:to-honey-700 text-white font-semibold rounded-xl shadow-md hover:shadow-lg focus:outline-none focus:ring-4 focus:ring-honey-300 transition-all transform hover:scale-[1.02]"
        >
          <Plus className="w-5 h-5" />
          {showForm ? 'Cancel' : 'Add Company'}
        </button>
      </div>

      {/* Add Form */}
      {showForm && (
        <div className="bg-white rounded-2xl shadow-card border border-sand/50 p-6">
          <div className="flex items-center gap-3 mb-6">
            <div className="w-10 h-10 bg-honey-100 rounded-xl flex items-center justify-center">
              <Building2 className="w-5 h-5 text-honey-600" />
            </div>
            <h2 className="text-xl font-display font-semibold text-navy-900">Add New Company</h2>
          </div>

          <form onSubmit={handleSubmit} className="space-y-5">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
              <div>
                <label className="block text-sm font-semibold text-navy-900 mb-2">
                  Company Name *
                </label>
                <input
                  type="text"
                  required
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  className="w-full px-4 py-3 border border-sand bg-ivory/50 rounded-xl text-anthracite placeholder-anthracite/40 focus:outline-none focus:ring-2 focus:ring-honey-500 focus:border-transparent transition-all"
                  placeholder="e.g., Acme Corporation"
                />
              </div>

              <div>
                <label className="block text-sm font-semibold text-navy-900 mb-2">
                  Industry
                </label>
                <input
                  type="text"
                  value={formData.industry}
                  onChange={(e) => setFormData({ ...formData, industry: e.target.value })}
                  className="w-full px-4 py-3 border border-sand bg-ivory/50 rounded-xl text-anthracite placeholder-anthracite/40 focus:outline-none focus:ring-2 focus:ring-honey-500 focus:border-transparent transition-all"
                  placeholder="e.g., Technology, Finance"
                />
              </div>

              <div>
                <label className="block text-sm font-semibold text-navy-900 mb-2">
                  Company Size
                </label>
                <input
                  type="text"
                  value={formData.size}
                  onChange={(e) => setFormData({ ...formData, size: e.target.value })}
                  className="w-full px-4 py-3 border border-sand bg-ivory/50 rounded-xl text-anthracite placeholder-anthracite/40 focus:outline-none focus:ring-2 focus:ring-honey-500 focus:border-transparent transition-all"
                  placeholder="e.g., 50-200 employees"
                />
              </div>

              <div>
                <label className="block text-sm font-semibold text-navy-900 mb-2">
                  Location
                </label>
                <input
                  type="text"
                  value={formData.location}
                  onChange={(e) => setFormData({ ...formData, location: e.target.value })}
                  className="w-full px-4 py-3 border border-sand bg-ivory/50 rounded-xl text-anthracite placeholder-anthracite/40 focus:outline-none focus:ring-2 focus:ring-honey-500 focus:border-transparent transition-all"
                  placeholder="e.g., Paris, France"
                />
              </div>

              <div className="md:col-span-2">
                <label className="block text-sm font-semibold text-navy-900 mb-2">
                  Website
                </label>
                <input
                  type="url"
                  value={formData.website}
                  onChange={(e) => setFormData({ ...formData, website: e.target.value })}
                  className="w-full px-4 py-3 border border-sand bg-ivory/50 rounded-xl text-anthracite placeholder-anthracite/40 focus:outline-none focus:ring-2 focus:ring-honey-500 focus:border-transparent transition-all"
                  placeholder="https://example.com"
                />
              </div>
            </div>

            <div className="flex gap-3 pt-2">
              <button
                type="submit"
                disabled={createCompany.isPending}
                className="flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-honey-500 to-honey-600 hover:from-honey-600 hover:to-honey-700 text-white font-semibold rounded-xl shadow-md hover:shadow-lg disabled:opacity-50 disabled:cursor-not-allowed transition-all transform hover:scale-[1.02]"
              >
                {createCompany.isPending ? (
                  <>
                    <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                    Creating...
                  </>
                ) : (
                  <>
                    <Plus className="w-5 h-5" />
                    Create Company
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

      {/* Companies Grid */}
      {companies && companies.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {companies.map((company) => (
            <CompanyCard
              key={company.id}
              company={company}
              onDelete={handleDelete}
            />
          ))}
        </div>
      ) : (
        <div className="text-center py-16">
          <div className="inline-flex items-center justify-center w-16 h-16 bg-sand rounded-2xl mb-4">
            <Building2 className="w-8 h-8 text-anthracite/40" />
          </div>
          <h3 className="text-lg font-semibold text-navy-900 mb-2">No companies yet</h3>
          <p className="text-anthracite/60 mb-6">Start by adding your first company</p>
          <button
            onClick={() => setShowForm(true)}
            className="inline-flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-honey-500 to-honey-600 hover:from-honey-600 hover:to-honey-700 text-white font-semibold rounded-xl shadow-md hover:shadow-lg transition-all transform hover:scale-[1.02]"
          >
            <Plus className="w-5 h-5" />
            Add Your First Company
          </button>
        </div>
      )}
    </div>
  );
}

interface CompanyCardProps {
  company: Company;
  onDelete: (id: number) => void;
}

function CompanyCard({ company, onDelete }: CompanyCardProps) {
  return (
    <div className="bg-white rounded-2xl shadow-card border border-sand/50 p-6 hover:shadow-soft transition-all group">
      {/* Header */}
      <div className="flex justify-between items-start mb-4">
        <div className="flex items-start gap-3 flex-1">
          <div className="w-12 h-12 bg-gradient-to-br from-honey-400 to-honey-500 rounded-xl flex items-center justify-center flex-shrink-0">
            <Building2 className="w-6 h-6 text-white" />
          </div>
          <div className="flex-1 min-w-0">
            <h3 className="text-lg font-display font-semibold text-navy-900 truncate">
              {company.name}
            </h3>
            {company.industry && (
              <p className="text-sm text-anthracite/60 flex items-center gap-1 mt-1">
                <Briefcase className="w-3.5 h-3.5" />
                {company.industry}
              </p>
            )}
          </div>
        </div>
        <button
          onClick={() => onDelete(company.id)}
          className="text-anthracite/40 hover:text-red-600 transition-colors p-1.5 hover:bg-red-50 rounded-lg"
          title="Delete company"
        >
          <Trash2 className="w-4 h-4" />
        </button>
      </div>

      {/* Details */}
      <div className="space-y-2.5 text-sm">
        {company.size && (
          <div className="flex items-center gap-2 text-anthracite/70">
            <Users className="w-4 h-4 text-honey-600" />
            <span>{company.size} employees</span>
          </div>
        )}
        {company.location && (
          <div className="flex items-center gap-2 text-anthracite/70">
            <MapPin className="w-4 h-4 text-honey-600" />
            <span>{company.location}</span>
          </div>
        )}
        {company.website && (
          <a
            href={company.website}
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-2 text-sky-400 hover:text-sky-500 font-medium group/link"
          >
            <Globe className="w-4 h-4" />
            <span className="group-hover/link:underline">Visit Website</span>
            <ExternalLink className="w-3.5 h-3.5" />
          </a>
        )}
      </div>

      {/* Footer */}
      <div className="mt-5 pt-4 border-t border-sand">
        <p className="text-xs text-anthracite/50">
          Added {new Date(company.created_at).toLocaleDateString('en-US', {
            month: 'short',
            day: 'numeric',
            year: 'numeric'
          })}
        </p>
      </div>
    </div>
  );
}
