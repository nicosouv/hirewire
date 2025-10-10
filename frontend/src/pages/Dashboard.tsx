import { useDashboard } from '../hooks/useDashboard';
import Loading from '../components/Loading';
import ErrorMessage from '../components/ErrorMessage';

export default function Dashboard() {
  const { data: dashboard, isLoading, error } = useDashboard();

  if (isLoading) return <Loading />;
  if (error) return <ErrorMessage message="Failed to load dashboard data" />;
  if (!dashboard) return null;

  const { stats, processes_by_status, interviews_by_type, top_companies, monthly_activity } = dashboard;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Dashboard</h1>
        <p className="mt-2 text-gray-600">Overview of your job search progress</p>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard
          title="Total Applications"
          value={stats.total_applications}
          icon="📝"
          color="blue"
        />
        <StatCard
          title="Active Processes"
          value={stats.active_processes}
          icon="🔄"
          color="green"
        />
        <StatCard
          title="Total Interviews"
          value={stats.total_interviews}
          icon="💬"
          color="purple"
        />
        <StatCard
          title="Offers Received"
          value={stats.offers_received}
          icon="🎉"
          color="yellow"
        />
      </div>

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
  icon: string;
  color: 'blue' | 'green' | 'purple' | 'yellow';
}

function StatCard({ title, value, icon, color }: StatCardProps) {
  const colorClasses = {
    blue: 'bg-blue-50 text-blue-600',
    green: 'bg-green-50 text-green-600',
    purple: 'bg-purple-50 text-purple-600',
    yellow: 'bg-yellow-50 text-yellow-600',
  };

  return (
    <div className="bg-white rounded-lg shadow p-6">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm text-gray-600">{title}</p>
          <p className="text-3xl font-bold text-gray-900 mt-2">{value}</p>
        </div>
        <div className={`text-4xl p-3 rounded-lg ${colorClasses[color]}`}>
          {icon}
        </div>
      </div>
    </div>
  );
}
