import { useState } from 'react';
import { useCompanies, useCreateCompany, useDeleteCompany } from '../hooks/useCompanies';
import Loading from '../components/Loading';
import ErrorMessage from '../components/ErrorMessage';
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
  if (error) return <ErrorMessage message="Failed to load companies" />;

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Companies</h1>
          <p className="mt-2 text-gray-600">Manage companies you're interested in</p>
        </div>
        <button
          onClick={() => setShowForm(!showForm)}
          className="px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition"
        >
          {showForm ? 'Cancel' : '+ Add Company'}
        </button>
      </div>

      {showForm && (
        <div className="bg-white rounded-lg shadow p-6">
          <h2 className="text-xl font-semibold text-gray-900 mb-4">Add New Company</h2>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Company Name *
                </label>
                <input
                  type="text"
                  required
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                  placeholder="e.g., Acme Corporation"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Industry
                </label>
                <input
                  type="text"
                  value={formData.industry}
                  onChange={(e) => setFormData({ ...formData, industry: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                  placeholder="e.g., Technology"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Company Size
                </label>
                <input
                  type="text"
                  value={formData.size}
                  onChange={(e) => setFormData({ ...formData, size: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                  placeholder="e.g., 100"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Location
                </label>
                <input
                  type="text"
                  value={formData.location}
                  onChange={(e) => setFormData({ ...formData, location: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                  placeholder="e.g., Paris, France"
                />
              </div>
              <div className="md:col-span-2">
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Website
                </label>
                <input
                  type="url"
                  value={formData.website}
                  onChange={(e) => setFormData({ ...formData, website: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                  placeholder="https://example.com"
                />
              </div>
            </div>
            <div className="flex gap-3">
              <button
                type="submit"
                disabled={createCompany.isPending}
                className="px-6 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 disabled:opacity-50 transition"
              >
                {createCompany.isPending ? 'Creating...' : 'Create Company'}
              </button>
              <button
                type="button"
                onClick={() => setShowForm(false)}
                className="px-6 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition"
              >
                Cancel
              </button>
            </div>
          </form>
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {companies?.map((company) => (
          <CompanyCard
            key={company.id}
            company={company}
            onDelete={handleDelete}
          />
        ))}
      </div>

      {companies?.length === 0 && (
        <div className="text-center py-12">
          <p className="text-gray-500 text-lg">No companies yet. Add your first company!</p>
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
    <div className="bg-white rounded-lg shadow p-6 hover:shadow-lg transition">
      <div className="flex justify-between items-start mb-4">
        <h3 className="text-xl font-semibold text-gray-900">{company.name}</h3>
        <button
          onClick={() => onDelete(company.id)}
          className="text-red-600 hover:text-red-800 text-sm"
        >
          Delete
        </button>
      </div>
      <div className="space-y-2 text-sm">
        {company.industry && (
          <p className="text-gray-600">
            <span className="font-medium">Industry:</span> {company.industry}
          </p>
        )}
        {company.size && (
          <p className="text-gray-600">
            <span className="font-medium">Size:</span> {company.size} employees
          </p>
        )}
        {company.location && (
          <p className="text-gray-600">
            <span className="font-medium">Location:</span> {company.location}
          </p>
        )}
        {company.website && (
          <a
            href={company.website}
            target="_blank"
            rel="noopener noreferrer"
            className="text-primary-600 hover:text-primary-700 inline-flex items-center gap-1"
          >
            Visit Website →
          </a>
        )}
      </div>
      <div className="mt-4 pt-4 border-t border-gray-200">
        <p className="text-xs text-gray-500">
          Added {new Date(company.created_at).toLocaleDateString()}
        </p>
      </div>
    </div>
  );
}
