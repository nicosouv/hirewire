import { Link } from 'react-router-dom';
import { useDashboard } from '../hooks/useDashboard';
import { useProcesses } from '../hooks/useProcesses';
import { useCompanies } from '../hooks/useCompanies';
import { usePositions } from '../hooks/usePositions';
import Loading from '../components/Loading';
import ErrorMessage from '../components/ErrorMessage';
import { TrendingUp, Briefcase, Calendar, Award, BarChart3, Building2, ArrowRight } from 'lucide-react';

export default function Dashboard() {
  const { data: dashboard, isLoading, error } = useDashboard();
  const { data: processes } = useProcesses();
  const { data: companies } = useCompanies();
  const { data: positions } = usePositions();

  if (isLoading) return <Loading />;
  if (error) return <ErrorMessage message="Failed to load dashboard data" />;
  if (!dashboard) return null;

  const { stats, processes_by_status, interviews_by_type, top_companies, monthly_activity } = dashboard;

  // Get most recent active processes
  const activeProcesses = processes?.filter(p =>
    !['rejected', 'accepted', 'withdrew', 'ghosted'].includes(p.status)
  ).slice(0, 5) || [];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-display font-bold text-navy-900">Dashboard</h1>
        <p className="mt-2 text-anthracite/70">Overview of your job search progress</p>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <Link to="/processes" className="block">
          <StatCard
            title="Total Applications"
            value={stats.total_applications}
            icon={<Briefcase className="w-6 h-6" />}
            color="blue"
          />
        </Link>
        <Link to="/processes" className="block">
          <StatCard
            title="Active Processes"
            value={stats.active_processes}
            icon={<TrendingUp className="w-6 h-6" />}
            color="green"
          />
        </Link>
        <Link to="/interviews" className="block">
          <StatCard
            title="Total Interviews"
            value={stats.total_interviews}
            icon={<Calendar className="w-6 h-6" />}
            color="purple"
          />
        </Link>
        <StatCard
          title="Offers Received"
          value={stats.offers_received}
          icon={<Award className="w-6 h-6" />}
          color="yellow"
        />
      </div>

      {/* Active Processes Quick View */}
      {activeProcesses.length > 0 && (
        <div className="bg-white rounded-2xl shadow-card border border-sand/50 p-6">
          <div className="flex justify-between items-center mb-6">
            <h3 className="text-xl font-display font-semibold text-navy-900 flex items-center gap-2">
              <TrendingUp className="w-6 h-6 text-honey-600" />
              Active Applications
            </h3>
            <Link
              to="/processes"
              className="text-honey-600 hover:text-honey-700 font-semibold text-sm flex items-center gap-1"
            >
              View All <ArrowRight className="w-4 h-4" />
            </Link>
          </div>
          <div className="space-y-3">
            {activeProcesses.map((process) => {
              const position = positions?.find(p => p.id === process.job_position_id);
              const company = companies?.find(c => c.id === position?.company_id);
              return (
                <Link
                  key={process.id}
                  to={`/processes/${process.id}`}
                  className="block p-4 bg-sand/20 hover:bg-sand/40 rounded-xl transition-all group"
                >
                  <div className="flex justify-between items-center">
                    <div>
                      <h4 className="font-semibold text-navy-900 group-hover:text-honey-600 transition-colors flex items-center gap-2">
                        {position?.title || 'Unknown Position'}
                        <ArrowRight className="w-4 h-4 opacity-0 group-hover:opacity-100 transition-opacity" />
                      </h4>
                      <p className="text-sm text-anthracite/60">
                        {company?.name || 'Unknown Company'}
                      </p>
                    </div>
                    <span className="px-3 py-1 bg-honey-50 text-honey-700 text-xs font-semibold rounded-lg capitalize">
                      {process.status.replace('_', ' ')}
                    </span>
                  </div>
                </Link>
              );
            })}
          </div>
        </div>
      )}

      {/* Additional Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="bg-white rounded-lg shadow p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-2">Success Rate</h3>
          <p className="text-3xl font-bold text-green-600">{stats.acceptance_rate}%</p>
          <p className="text-sm text-gray-500 mt-1">Offer acceptance rate</p>
        </div>
        <div className="bg-white rounded-lg shadow p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-2">Average Duration</h3>
          <p className="text-3xl font-bold text-blue-600">{stats.avg_process_duration_days} days</p>
          <p className="text-sm text-gray-500 mt-1">From application to outcome</p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Processes by Status */}
        <div className="bg-white rounded-lg shadow p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Processes by Status</h3>
          <div className="space-y-3">
            {processes_by_status.map((item) => (
              <div key={item.status} className="flex justify-between items-center">
                <span className="text-gray-700 capitalize">{item.status.replace('_', ' ')}</span>
                <span className="font-semibold text-gray-900">{item.count}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Interviews by Type */}
        <div className="bg-white rounded-lg shadow p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Interviews by Type</h3>
          <div className="space-y-3">
            {interviews_by_type.map((item) => (
              <div key={item.interview_type} className="flex justify-between items-center">
                <span className="text-gray-700 capitalize">{item.interview_type}</span>
                <span className="font-semibold text-gray-900">{item.count}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Top Companies */}
      <div className="bg-white rounded-lg shadow p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Top Companies</h3>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead>
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Company
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Applications
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Interviews
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Offers
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {top_companies.map((company) => (
                <tr key={company.company_name}>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                    {company.company_name}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {company.application_count}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {company.interview_count}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {company.offer_count}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Monthly Activity */}
      <div className="bg-white rounded-lg shadow p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Monthly Activity</h3>
        <div className="space-y-4">
          {monthly_activity.map((month) => (
            <div key={month.month} className="border-l-4 border-primary-500 pl-4">
              <div className="flex justify-between items-center">
                <span className="font-medium text-gray-900">{month.month}</span>
                <div className="flex gap-4 text-sm">
                  <span className="text-gray-600">📝 {month.applications} apps</span>
                  <span className="text-gray-600">💬 {month.interviews} interviews</span>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

interface StatCardProps {
  title: string;
  value: number;
  icon: React.ReactNode;
  color: 'blue' | 'green' | 'purple' | 'yellow';
}

function StatCard({ title, value, icon, color }: StatCardProps) {
  const colorClasses = {
    blue: 'from-blue-400 to-blue-500',
    green: 'from-green-400 to-green-500',
    purple: 'from-purple-400 to-purple-500',
    yellow: 'from-honey-400 to-honey-500',
  };

  return (
    <div className="bg-white rounded-2xl shadow-card border border-sand/50 p-6 hover:shadow-soft transition-all group cursor-pointer">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm text-anthracite/60 font-medium">{title}</p>
          <p className="text-3xl font-display font-bold text-navy-900 mt-2">{value}</p>
        </div>
        <div className={`p-3 rounded-xl bg-gradient-to-br ${colorClasses[color]} shadow-md group-hover:scale-110 transition-transform`}>
          {icon}
        </div>
      </div>
    </div>
  );
}
