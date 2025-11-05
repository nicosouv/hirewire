import { useState, useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import SankeyChart from '../components/SankeyChart';
import { apiClient } from '../services/api';
import Loading from '../components/Loading';
import ErrorMessage from '../components/ErrorMessage';
import { TrendingUp, GitBranch, Calendar, Filter, BarChart3, Building2 } from 'lucide-react';

type ViewType = 'status' | 'company';

interface SankeyData {
  nodes: Array<{ label: string; color: string }>;
  links: {
    source: number[];
    target: number[];
    value: number[];
  };
  total_processes?: number;
  total_companies?: number;
  filters: {
    start_date: string | null;
    end_date: string | null;
    outcome_filter?: string | null;
    limit?: number;
  };
}

interface AnalyticsOverview {
  total_applications: number;
  active_applications: number;
  total_interviews: number;
  offers_accepted: number;
  offers_received: number;
  total_companies: number;
  avg_days_to_outcome: number;
  conversion_rate: number;
  first_interview_rate: number;
}

export default function Analytics() {
  const [viewType, setViewType] = useState<ViewType>('status');
  const [dateRange, setDateRange] = useState<'all' | '1m' | '3m' | '6m' | '1y' | 'custom'>('all');
  const [customStartDate, setCustomStartDate] = useState('');
  const [customEndDate, setCustomEndDate] = useState('');
  const [outcomeFilter, setOutcomeFilter] = useState<string | null>(null);
  const [companyLimit, setCompanyLimit] = useState(10);

  // Calculate date range
  const { startDate, endDate } = useMemo(() => {
    if (dateRange === 'custom') {
      return {
        startDate: customStartDate || undefined,
        endDate: customEndDate || undefined
      };
    }

    if (dateRange === 'all') {
      return { startDate: undefined, endDate: undefined };
    }

    const end = new Date();
    const start = new Date();

    switch (dateRange) {
      case '1m':
        start.setMonth(start.getMonth() - 1);
        break;
      case '3m':
        start.setMonth(start.getMonth() - 3);
        break;
      case '6m':
        start.setMonth(start.getMonth() - 6);
        break;
      case '1y':
        start.setFullYear(start.getFullYear() - 1);
        break;
    }

    return {
      startDate: start.toISOString().split('T')[0],
      endDate: end.toISOString().split('T')[0]
    };
  }, [dateRange, customStartDate, customEndDate]);

  // Fetch overview stats
  const { data: overview } = useQuery<AnalyticsOverview>({
    queryKey: ['analytics-overview'],
    queryFn: async () => {
      const response = await apiClient.get('/analytics/stats/overview');
      return response.data;
    }
  });

  // Fetch Sankey data based on view type
  const { data: sankeyData, isLoading, error } = useQuery<SankeyData>({
    queryKey: ['sankey', viewType, startDate, endDate, outcomeFilter, companyLimit],
    queryFn: async () => {
      const endpoint = viewType === 'status'
        ? '/analytics/sankey/status-flow'
        : '/analytics/sankey/company-flow';

      const params = new URLSearchParams();
      if (startDate) params.append('start_date', startDate);
      if (endDate) params.append('end_date', endDate);
      if (outcomeFilter && viewType === 'status') params.append('outcome_filter', outcomeFilter);
      if (viewType === 'company') params.append('limit', companyLimit.toString());

      const response = await apiClient.get(`${endpoint}?${params}`);
      return response.data;
    }
  });

  if (isLoading) return <Loading />;
  if (error) return <ErrorMessage message="Failed to load analytics data" />;

  return (
    <div className="space-y-8">
      {/* Header */}
      <div>
        <h1 className="text-4xl font-display font-bold text-navy-900 flex items-center gap-3">
          <BarChart3 className="w-10 h-10 text-honey-500" />
          Analytics Dashboard
        </h1>
        <p className="mt-2 text-lg text-anthracite/70">
          Visualize your job search journey with interactive flow diagrams
        </p>
      </div>

      {/* Overview Stats */}
      {overview && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          <div className="bg-gradient-to-br from-blue-50 to-blue-100 rounded-2xl p-6 border-2 border-blue-200">
            <div className="flex items-center gap-3 mb-2">
              <TrendingUp className="w-5 h-5 text-blue-600" />
              <p className="text-sm font-medium text-blue-700">Conversion Rate</p>
            </div>
            <p className="text-3xl font-display font-bold text-blue-900">{overview.conversion_rate}%</p>
            <p className="text-xs text-blue-600/70 mt-1">
              {overview.offers_accepted} offers from {overview.total_applications} applications
            </p>
          </div>

          <div className="bg-gradient-to-br from-purple-50 to-purple-100 rounded-2xl p-6 border-2 border-purple-200">
            <div className="flex items-center gap-3 mb-2">
              <Calendar className="w-5 h-5 text-purple-600" />
              <p className="text-sm font-medium text-purple-700">First Interview Rate</p>
            </div>
            <p className="text-3xl font-display font-bold text-purple-900">{overview.first_interview_rate}%</p>
            <p className="text-xs text-purple-600/70 mt-1">
              of applications get at least one interview
            </p>
          </div>

          <div className="bg-gradient-to-br from-green-50 to-green-100 rounded-2xl p-6 border-2 border-green-200">
            <div className="flex items-center gap-3 mb-2">
              <Building2 className="w-5 h-5 text-green-600" />
              <p className="text-sm font-medium text-green-700">Companies Applied</p>
            </div>
            <p className="text-3xl font-display font-bold text-green-900">{overview.total_companies}</p>
            <p className="text-xs text-green-600/70 mt-1">
              {overview.active_applications} active processes
            </p>
          </div>

          <div className="bg-gradient-to-br from-honey-50 to-honey-100 rounded-2xl p-6 border-2 border-honey-200">
            <div className="flex items-center gap-3 mb-2">
              <TrendingUp className="w-5 h-5 text-honey-600" />
              <p className="text-sm font-medium text-honey-700">Avg. Time to Outcome</p>
            </div>
            <p className="text-3xl font-display font-bold text-honey-900">{overview.avg_days_to_outcome}</p>
            <p className="text-xs text-honey-600/70 mt-1">days on average</p>
          </div>
        </div>
      )}

      {/* Filters */}
      <div className="bg-white rounded-2xl border-2 border-sand/30 p-6 shadow-sm">
        <div className="flex items-center gap-3 mb-4">
          <Filter className="w-5 h-5 text-honey-600" />
          <h2 className="text-xl font-display font-bold text-navy-900">Filters</h2>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          {/* View Type Toggle */}
          <div>
            <label className="block text-sm font-semibold text-navy-900 mb-2">
              <GitBranch className="w-4 h-4 inline mr-1" />
              View Type
            </label>
            <div className="flex gap-2">
              <button
                onClick={() => setViewType('status')}
                className={`flex-1 px-4 py-2 rounded-xl font-semibold transition-all ${
                  viewType === 'status'
                    ? 'bg-gradient-to-r from-honey-500 to-honey-600 text-white shadow-lg'
                    : 'bg-sand/30 text-anthracite/70 hover:bg-sand/50'
                }`}
              >
                Status Flow
              </button>
              <button
                onClick={() => setViewType('company')}
                className={`flex-1 px-4 py-2 rounded-xl font-semibold transition-all ${
                  viewType === 'company'
                    ? 'bg-gradient-to-r from-honey-500 to-honey-600 text-white shadow-lg'
                    : 'bg-sand/30 text-anthracite/70 hover:bg-sand/50'
                }`}
              >
                By Company
              </button>
            </div>
          </div>

          {/* Date Range */}
          <div>
            <label className="block text-sm font-semibold text-navy-900 mb-2">
              <Calendar className="w-4 h-4 inline mr-1" />
              Date Range
            </label>
            <select
              value={dateRange}
              onChange={(e) => setDateRange(e.target.value as typeof dateRange)}
              className="w-full border-2 border-sand/50 rounded-xl px-4 py-2 focus:outline-none focus:border-honey-500 focus:ring-2 focus:ring-honey-500/20 bg-ivory/30 font-medium"
            >
              <option value="all">All Time</option>
              <option value="1m">Last Month</option>
              <option value="3m">Last 3 Months</option>
              <option value="6m">Last 6 Months</option>
              <option value="1y">Last Year</option>
              <option value="custom">Custom Range</option>
            </select>
          </div>

          {/* Outcome Filter (Status view only) */}
          {viewType === 'status' && (
            <div>
              <label className="block text-sm font-semibold text-navy-900 mb-2">
                Outcome Filter
              </label>
              <select
                value={outcomeFilter || ''}
                onChange={(e) => setOutcomeFilter(e.target.value || null)}
                className="w-full border-2 border-sand/50 rounded-xl px-4 py-2 focus:outline-none focus:border-honey-500 focus:ring-2 focus:ring-honey-500/20 bg-ivory/30 font-medium"
              >
                <option value="">All Outcomes</option>
                <option value="accepted">Accepted</option>
                <option value="rejected">Rejected</option>
                <option value="ghosted">Ghosted</option>
                <option value="withdrew">Withdrew</option>
              </select>
            </div>
          )}

          {/* Company Limit (Company view only) */}
          {viewType === 'company' && (
            <div>
              <label className="block text-sm font-semibold text-navy-900 mb-2">
                Top Companies
              </label>
              <select
                value={companyLimit}
                onChange={(e) => setCompanyLimit(Number(e.target.value))}
                className="w-full border-2 border-sand/50 rounded-xl px-4 py-2 focus:outline-none focus:border-honey-500 focus:ring-2 focus:ring-honey-500/20 bg-ivory/30 font-medium"
              >
                <option value="5">Top 5</option>
                <option value="10">Top 10</option>
                <option value="15">Top 15</option>
                <option value="20">Top 20</option>
              </select>
            </div>
          )}
        </div>

        {/* Custom Date Range Inputs */}
        {dateRange === 'custom' && (
          <div className="grid grid-cols-2 gap-4 mt-4">
            <div>
              <label className="block text-sm font-semibold text-navy-900 mb-2">Start Date</label>
              <input
                type="date"
                value={customStartDate}
                onChange={(e) => setCustomStartDate(e.target.value)}
                className="w-full border-2 border-sand/50 rounded-xl px-4 py-2 focus:outline-none focus:border-honey-500 focus:ring-2 focus:ring-honey-500/20 bg-ivory/30 font-medium"
              />
            </div>
            <div>
              <label className="block text-sm font-semibold text-navy-900 mb-2">End Date</label>
              <input
                type="date"
                value={customEndDate}
                onChange={(e) => setCustomEndDate(e.target.value)}
                className="w-full border-2 border-sand/50 rounded-xl px-4 py-2 focus:outline-none focus:border-honey-500 focus:ring-2 focus:ring-honey-500/20 bg-ivory/30 font-medium"
              />
            </div>
          </div>
        )}
      </div>

      {/* Sankey Diagram */}
      <div className="bg-white rounded-2xl border-2 border-sand/30 p-6 shadow-sm">
        <div className="mb-4">
          <h2 className="text-2xl font-display font-bold text-navy-900 flex items-center gap-2">
            <GitBranch className="w-6 h-6 text-honey-500" />
            {viewType === 'status' ? 'Application Status Flow' : 'Company to Outcome Flow'}
          </h2>
          <p className="text-sm text-anthracite/60 mt-1">
            {viewType === 'status'
              ? 'Track how your applications progress through each stage'
              : `Flow from top ${companyLimit} companies to outcomes`
            }
            {sankeyData?.total_processes && ` • ${sankeyData.total_processes} total processes`}
          </p>
        </div>

        {sankeyData && sankeyData.nodes.length > 0 ? (
          <div className="w-full bg-white rounded-lg">
            <SankeyChart
              nodes={sankeyData.nodes}
              links={sankeyData.links}
              height={700}
            />
          </div>
        ) : (
          <div className="text-center py-16 bg-sand/10 rounded-2xl border-2 border-dashed border-sand/50">
            <GitBranch className="w-16 h-16 text-honey-500 mx-auto mb-4" />
            <h3 className="text-xl font-display font-bold text-navy-900 mb-2">
              No Data Available
            </h3>
            <p className="text-anthracite/60 max-w-md mx-auto">
              {outcomeFilter
                ? `No applications with outcome "${outcomeFilter}" found for the selected date range.`
                : 'No application data found for the selected filters. Try adjusting the date range.'
              }
            </p>
          </div>
        )}
      </div>

      {/* Insights */}
      {sankeyData && sankeyData.nodes.length > 0 && (
        <div className="bg-gradient-to-br from-honey-50 to-honey-100 rounded-2xl border-2 border-honey-200 p-6">
          <h3 className="text-lg font-display font-bold text-honey-900 mb-3">
            💡 Quick Insights
          </h3>
          <ul className="space-y-2 text-sm text-honey-800">
            {viewType === 'status' && (
              <>
                <li>• Wider flows indicate more applications progressing to that stage</li>
                <li>• Track where most applications drop off in your funnel</li>
                <li>• Use filters to analyze specific outcomes or time periods</li>
              </>
            )}
            {viewType === 'company' && (
              <>
                <li>• See which companies you've applied to most frequently</li>
                <li>• Identify companies with better success rates</li>
                <li>• Adjust "Top Companies" filter to show more or fewer companies</li>
              </>
            )}
          </ul>
        </div>
      )}
    </div>
  );
}
