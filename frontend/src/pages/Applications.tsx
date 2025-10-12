import { useState, useEffect } from 'react';
import { useSearchParams } from 'react-router-dom';
import { useProcesses } from '../hooks/useProcesses';
import { usePositions } from '../hooks/usePositions';
import { useCompanies } from '../hooks/useCompanies';
import { useDeleteProcess } from '../hooks/useProcesses';
import Loading from '../components/Loading';
import ApplicationCard from '../components/ApplicationCard';
import ApplicationDetailPanel from '../components/ApplicationDetailPanel';
import { Filter, Search, X } from 'lucide-react';

const KANBAN_COLUMNS = [
  { id: 'applied', label: 'Applied', statuses: ['applied'] },
  { id: 'screening', label: 'Screening', statuses: ['screening'] },
  { id: 'interviewing', label: 'Interviewing', statuses: ['interviewing', 'tech_test'] },
  { id: 'final', label: 'Final Round', statuses: ['final_round', 'offer'] },
  { id: 'closed', label: 'Closed', statuses: ['rejected', 'accepted', 'withdrew', 'ghosted'] },
];

export default function Applications() {
  const { data: processes, isLoading } = useProcesses();
  const { data: positions } = usePositions();
  const { data: companies } = useCompanies();
  const deleteProcess = useDeleteProcess();

  const [searchParams, setSearchParams] = useSearchParams();
  const [selectedProcessId, setSelectedProcessId] = useState<number | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [statusFilter, setStatusFilter] = useState<string[]>([]);

  // Read filter and processId from URL on mount
  useEffect(() => {
    const filterParam = searchParams.get('filter');
    if (filterParam) {
      // Support comma-separated statuses
      setStatusFilter(filterParam.split(','));
    } else {
      setStatusFilter([]);
    }

    // Auto-open detail panel if processId in URL
    const processIdParam = searchParams.get('processId');
    if (processIdParam) {
      const processId = parseInt(processIdParam);
      if (!isNaN(processId)) {
        setSelectedProcessId(processId);
        // Remove processId from URL after opening
        const newParams = new URLSearchParams(searchParams);
        newParams.delete('processId');
        setSearchParams(newParams, { replace: true });
      }
    }
  }, [searchParams, setSearchParams]);

  const handleDelete = async (id: number) => {
    if (window.confirm('Are you sure you want to delete this application?')) {
      try {
        await deleteProcess.mutateAsync(id);
        if (selectedProcessId === id) {
          setSelectedProcessId(null);
        }
      } catch (error) {
        console.error('Failed to delete process:', error);
      }
    }
  };

  if (isLoading) return <Loading />;

  // Get active processes (not closed)
  const activeProcesses = processes?.filter(
    (p) => !['rejected', 'accepted', 'withdrew', 'ghosted'].includes(p.status)
  ) || [];

  const closedProcesses = processes?.filter(
    (p) => ['rejected', 'accepted', 'withdrew', 'ghosted'].includes(p.status)
  ) || [];

  // Filter processes by search and status
  const filteredProcesses = processes?.filter((process) => {
    // Status filter
    if (statusFilter.length > 0 && !statusFilter.includes(process.status)) {
      return false;
    }

    // Search filter
    if (!searchQuery) return true;
    const position = positions?.find((p) => p.id === process.job_position_id);
    const company = companies?.find((c) => c.id === position?.company_id);
    const searchLower = searchQuery.toLowerCase();
    return (
      position?.title.toLowerCase().includes(searchLower) ||
      company?.name.toLowerCase().includes(searchLower) ||
      process.status.toLowerCase().includes(searchLower)
    );
  }) || [];

  const clearFilters = () => {
    setStatusFilter([]);
    setSearchParams({});
  };

  // Group processes by column
  const getProcessesForColumn = (columnStatuses: string[]) => {
    return filteredProcesses.filter((p) => columnStatuses.includes(p.status));
  };

  const selectedProcess = processes?.find((p) => p.id === selectedProcessId);
  const selectedPosition = selectedProcess
    ? positions?.find((p) => p.id === selectedProcess.job_position_id)
    : null;
  const selectedCompany = selectedPosition
    ? companies?.find((c) => c.id === selectedPosition.company_id)
    : null;

  return (
    <div className="space-y-6">
      {/* Header with Search */}
      <div>
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-display font-bold text-navy-900">My Applications</h1>
            <p className="mt-1 text-sm text-anthracite/70">
              {activeProcesses.length} active • {closedProcesses.length} closed
            </p>
          </div>
          {statusFilter.length > 0 && (
            <div className="flex items-center gap-2">
              <div className="flex flex-wrap gap-2 max-w-md">
                {statusFilter.map((status) => (
                  <span
                    key={status}
                    className="inline-flex items-center gap-1 px-3 py-1 bg-honey-100 text-honey-700 rounded-md text-xs font-semibold"
                  >
                    {status.replace('_', ' ')}
                  </span>
                ))}
              </div>
              <button
                onClick={clearFilters}
                className="flex items-center gap-1 px-3 py-1.5 bg-red-100 text-red-700 rounded-lg hover:bg-red-200 transition-all text-xs font-semibold whitespace-nowrap"
              >
                <X className="w-3.5 h-3.5" />
                Clear
              </button>
            </div>
          )}
        </div>
      </div>

      {/* Search and Filters */}
      <div className="flex gap-3">
        <div className="flex-1 relative">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-anthracite/40" />
          <input
            type="text"
            placeholder="Search applications..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-12 pr-4 py-3 border-2 border-sand bg-white rounded-xl text-anthracite placeholder-anthracite/40 focus:outline-none focus:border-honey-500 transition-all"
          />
        </div>
        <button
          onClick={() => setShowFilters(!showFilters)}
          className={`
            px-4 py-3 border-2 rounded-xl font-semibold transition-all flex items-center gap-2
            ${showFilters
              ? 'border-honey-500 bg-honey-50 text-honey-700'
              : 'border-sand text-anthracite/70 hover:border-honey-300'
            }
          `}
        >
          <Filter className="w-5 h-5" />
          Filters
        </button>
      </div>

      {/* Kanban Board */}
      <div className="flex gap-4 overflow-x-auto pb-4">
        {KANBAN_COLUMNS.map((column) => {
          const columnProcesses = getProcessesForColumn(column.statuses);

          return (
            <div key={column.id} className="flex-shrink-0 w-full lg:w-[280px]">
              {/* Column Header */}
              <div className="mb-3 flex items-center justify-between">
                <h3 className="text-sm font-bold text-navy-900 uppercase tracking-wide">
                  {column.label}
                </h3>
                <span className="text-xs font-semibold text-anthracite/50 bg-sand/30 px-2 py-1 rounded-full">
                  {columnProcesses.length}
                </span>
              </div>

              {/* Column Content */}
              <div className="space-y-3">
                {columnProcesses.length === 0 ? (
                  <div className="bg-sand/10 border-2 border-dashed border-sand/50 rounded-xl p-4 text-center">
                    <p className="text-xs text-anthracite/40">No applications</p>
                  </div>
                ) : (
                  columnProcesses.map((process) => {
                    const position = positions?.find((p) => p.id === process.job_position_id);
                    const company = companies?.find((c) => c.id === position?.company_id);

                    if (!position || !company) return null;

                    return (
                      <ApplicationCard
                        key={process.id}
                        process={process}
                        position={position}
                        company={company}
                        onClick={() => setSelectedProcessId(process.id)}
                        onDelete={() => handleDelete(process.id)}
                        compact={column.id === 'closed'}
                      />
                    );
                  })
                )}
              </div>
            </div>
          );
        })}
      </div>

      {/* Detail Panel */}
      {selectedProcess && selectedPosition && selectedCompany && (
        <ApplicationDetailPanel
          process={selectedProcess}
          position={selectedPosition}
          company={selectedCompany}
          onClose={() => setSelectedProcessId(null)}
        />
      )}
    </div>
  );
}
