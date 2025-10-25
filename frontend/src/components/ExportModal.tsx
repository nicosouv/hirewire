import { useState } from 'react';
import { X, Download, Mail, FileSpreadsheet, FileText } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';
import { useCreateExport } from '../hooks/useExports';

interface ExportModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export default function ExportModal({ isOpen, onClose }: ExportModalProps) {
  const { user } = useAuth();
  const createExport = useCreateExport();

  // Default to last 3 months
  const today = new Date();
  const threeMonthsAgo = new Date(today);
  threeMonthsAgo.setMonth(today.getMonth() - 3);

  const [form, setForm] = useState({
    start_date: threeMonthsAgo.toISOString().split('T')[0],
    end_date: today.toISOString().split('T')[0],
    format: 'excel' as 'excel' | 'csv',
    recipient_email: user?.email || '',
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    try {
      await createExport.mutateAsync(form);
      onClose();
      // Show success notification
      alert('Export request submitted! You will receive an email shortly.');
    } catch (error) {
      console.error('Failed to create export:', error);
      alert('Failed to submit export request. Please try again.');
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-2xl shadow-2xl max-w-lg w-full max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="sticky top-0 bg-white border-b border-sand/50 p-6 flex justify-between items-center rounded-t-2xl">
          <div>
            <h2 className="text-2xl font-display font-bold text-navy-900 flex items-center gap-2">
              <Download className="w-6 h-6 text-honey-500" />
              Export Report
            </h2>
            <p className="text-sm text-anthracite/60 mt-1">
              Generate a comprehensive report of your job search activity
            </p>
          </div>
          <button
            onClick={onClose}
            className="p-2 hover:bg-sand/30 rounded-lg transition-colors"
          >
            <X className="w-5 h-5 text-anthracite/60" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-6">
          {/* Date Range */}
          <div className="space-y-4">
            <h3 className="text-sm font-bold text-navy-900 uppercase tracking-wide">
              Date Range
            </h3>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-medium text-anthracite/70 mb-2">
                  Start Date
                </label>
                <input
                  type="date"
                  required
                  value={form.start_date}
                  onChange={(e) => setForm({ ...form, start_date: e.target.value })}
                  max={form.end_date}
                  className="w-full px-3 py-2 border-2 border-sand bg-white rounded-lg text-sm focus:outline-none focus:border-honey-500 transition-all"
                />
              </div>
              <div>
                <label className="block text-xs font-medium text-anthracite/70 mb-2">
                  End Date
                </label>
                <input
                  type="date"
                  required
                  value={form.end_date}
                  onChange={(e) => setForm({ ...form, end_date: e.target.value })}
                  min={form.start_date}
                  max={today.toISOString().split('T')[0]}
                  className="w-full px-3 py-2 border-2 border-sand bg-white rounded-lg text-sm focus:outline-none focus:border-honey-500 transition-all"
                />
              </div>
            </div>
            <div className="flex gap-2 text-xs">
              <button
                type="button"
                onClick={() => {
                  const date = new Date();
                  date.setMonth(date.getMonth() - 1);
                  setForm({ ...form, start_date: date.toISOString().split('T')[0] });
                }}
                className="px-3 py-1 bg-sand/30 hover:bg-sand/50 rounded-md transition-colors"
              >
                Last Month
              </button>
              <button
                type="button"
                onClick={() => {
                  const date = new Date();
                  date.setMonth(date.getMonth() - 3);
                  setForm({ ...form, start_date: date.toISOString().split('T')[0] });
                }}
                className="px-3 py-1 bg-sand/30 hover:bg-sand/50 rounded-md transition-colors"
              >
                Last 3 Months
              </button>
              <button
                type="button"
                onClick={() => {
                  const date = new Date();
                  date.setMonth(date.getMonth() - 6);
                  setForm({ ...form, start_date: date.toISOString().split('T')[0] });
                }}
                className="px-3 py-1 bg-sand/30 hover:bg-sand/50 rounded-md transition-colors"
              >
                Last 6 Months
              </button>
            </div>
          </div>

          {/* Format Selection */}
          <div className="space-y-4">
            <h3 className="text-sm font-bold text-navy-900 uppercase tracking-wide">
              Format
            </h3>
            <div className="grid grid-cols-2 gap-3">
              <button
                type="button"
                onClick={() => setForm({ ...form, format: 'excel' })}
                className={`
                  p-4 border-2 rounded-xl transition-all
                  ${form.format === 'excel'
                    ? 'border-honey-500 bg-honey-50'
                    : 'border-sand hover:border-honey-300'
                  }
                `}
              >
                <FileSpreadsheet className={`w-8 h-8 mx-auto mb-2 ${form.format === 'excel' ? 'text-honey-600' : 'text-anthracite/60'}`} />
                <p className={`text-sm font-semibold ${form.format === 'excel' ? 'text-honey-700' : 'text-anthracite'}`}>
                  Excel
                </p>
                <p className="text-xs text-anthracite/60 mt-1">
                  Multiple sheets, formatted
                </p>
              </button>

              <button
                type="button"
                onClick={() => setForm({ ...form, format: 'csv' })}
                className={`
                  p-4 border-2 rounded-xl transition-all
                  ${form.format === 'csv'
                    ? 'border-honey-500 bg-honey-50'
                    : 'border-sand hover:border-honey-300'
                  }
                `}
              >
                <FileText className={`w-8 h-8 mx-auto mb-2 ${form.format === 'csv' ? 'text-honey-600' : 'text-anthracite/60'}`} />
                <p className={`text-sm font-semibold ${form.format === 'csv' ? 'text-honey-700' : 'text-anthracite'}`}>
                  CSV
                </p>
                <p className="text-xs text-anthracite/60 mt-1">
                  Simple text format
                </p>
              </button>
            </div>
          </div>

          {/* Email */}
          <div className="space-y-4">
            <h3 className="text-sm font-bold text-navy-900 uppercase tracking-wide">
              Delivery
            </h3>
            <div>
              <label className="block text-xs font-medium text-anthracite/70 mb-2">
                Email Address
              </label>
              <div className="relative">
                <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-anthracite/40" />
                <input
                  type="email"
                  required
                  value={form.recipient_email}
                  onChange={(e) => setForm({ ...form, recipient_email: e.target.value })}
                  placeholder="your-email@example.com"
                  className="w-full pl-10 pr-4 py-3 border-2 border-sand bg-white rounded-lg text-sm focus:outline-none focus:border-honey-500 transition-all"
                />
              </div>
              <p className="text-xs text-anthracite/60 mt-2">
                The export file will be sent to this email address
              </p>
            </div>
          </div>

          {/* Info Box */}
          <div className="bg-blue-50 border-2 border-blue-200 rounded-xl p-4">
            <p className="text-sm text-blue-900 font-semibold mb-2">
              📊 What's included:
            </p>
            <ul className="text-xs text-blue-800 space-y-1">
              <li>• Summary statistics (applications, interviews, offers)</li>
              <li>• Detailed applications list with status</li>
              <li>• Complete interview timeline</li>
              <li>• Company statistics and insights</li>
            </ul>
            <p className="text-xs text-blue-700 mt-3">
              ⏱️ Processing time: 1-3 minutes
            </p>
          </div>

          {/* Actions */}
          <div className="flex gap-3 pt-2">
            <button
              type="submit"
              disabled={createExport.isPending}
              className="flex-1 flex items-center justify-center gap-2 px-6 py-3 bg-gradient-to-r from-honey-500 to-honey-600 hover:from-honey-600 hover:to-honey-700 font-semibold rounded-xl shadow-md hover:shadow-lg disabled:opacity-50 disabled:cursor-not-allowed transition-all"
            >
              {createExport.isPending ? (
                <>
                  <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                  Processing...
                </>
              ) : (
                <>
                  <Download className="w-5 h-5" />
                  Request Export
                </>
              )}
            </button>
            <button
              type="button"
              onClick={onClose}
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
