import { Link } from 'react-router-dom';
import { useDashboard } from '../hooks/useDashboard';
import { useProcesses } from '../hooks/useProcesses';
import { useCompanies } from '../hooks/useCompanies';
import { usePositions } from '../hooks/usePositions';
import { useInterviews } from '../hooks/useInterviews';
import Loading from '../components/Loading';
import ErrorMessage from '../components/ErrorMessage';
import PriorityActions from '../components/PriorityActions';
import { TrendingUp, Briefcase, Calendar, Award, ArrowRight, Zap } from 'lucide-react';

export default function NewDashboard() {
  const { data: dashboard, isLoading, error } = useDashboard();
  const { data: processes } = useProcesses();
  const { data: companies } = useCompanies();
  const { data: positions } = usePositions();
  const { data: interviews } = useInterviews();

  if (isLoading) return <Loading />;
  if (error) return <ErrorMessage message="Failed to load dashboard data" />;
  if (!dashboard) return null;

  const { stats } = dashboard;

  // Get active processes
  const activeProcesses = processes?.filter(p =>
    !['rejected', 'accepted', 'withdrew', 'ghosted'].includes(p.status)
  ) || [];

  return (
    <div className="space-y-8">
      {/* Hero Section */}
      <div>
        <h1 className="text-4xl font-display font-bold text-navy-900">
          Welcome back! 👋
        </h1>
        <p className="mt-2 text-lg text-anthracite/70">
          Here's what's happening with your job search
        </p>
      </div>

      {/* Stats Cards - Simplified */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <Link to="/applications?filter=applied,screening,interviewing,tech_test,final_round,offer" className="block group">
          <div className="bg-gradient-to-br from-blue-50 to-blue-100 rounded-2xl p-6 border-2 border-blue-200 hover:border-blue-400 transition-all hover:shadow-lg">
            <div className="flex justify-between items-start mb-3">
              <div className="p-3 bg-blue-500 rounded-xl shadow-md">
                <Briefcase className="w-6 h-6" />
              </div>
              <ArrowRight className="w-5 h-5 text-blue-400 opacity-0 group-hover:opacity-100 transition-opacity" />
            </div>
            <p className="text-sm font-medium text-blue-700 mb-1">Active Applications</p>
            <p className="text-4xl font-display font-bold text-blue-900">{stats.active_processes}</p>
            <p className="text-xs text-blue-600/70 mt-2">of {stats.total_applications} total</p>
          </div>
        </Link>

        <Link to="/applications?filter=interviewing" className="block group">
          <div className="bg-gradient-to-br from-purple-50 to-purple-100 rounded-2xl p-6 border-2 border-purple-200 hover:border-purple-400 transition-all hover:shadow-lg">
            <div className="flex justify-between items-start mb-3">
              <div className="p-3 bg-purple-500 rounded-xl shadow-md">
                <Calendar className="w-6 h-6 " />
              </div>
              <ArrowRight className="w-5 h-5 text-purple-400 opacity-0 group-hover:opacity-100 transition-opacity" />
            </div>
            <p className="text-sm font-medium text-purple-700 mb-1">Interviews</p>
            <p className="text-4xl font-display font-bold text-purple-900">{stats.total_interviews}</p>
            <p className="text-xs text-purple-600/70 mt-2">completed so far</p>
          </div>
        </Link>

        <div className="bg-gradient-to-br from-green-50 to-green-100 rounded-2xl p-6 border-2 border-green-200">
          <div className="flex justify-between items-start mb-3">
            <div className="p-3 bg-green-500 rounded-xl shadow-md">
              <Award className="w-6 h-6 " />
            </div>
          </div>
          <p className="text-sm font-medium text-green-700 mb-1">Offers Received</p>
          <p className="text-4xl font-display font-bold text-green-900">{stats.offers_received}</p>
          <p className="text-xs text-green-600/70 mt-2">{stats.acceptance_rate}% acceptance rate</p>
        </div>

        <div className="bg-gradient-to-br from-honey-50 to-honey-100 rounded-2xl p-6 border-2 border-honey-200">
          <div className="flex justify-between items-start mb-3">
            <div className="p-3 bg-honey-500 rounded-xl shadow-md">
              <TrendingUp className="w-6 h-6 " />
            </div>
          </div>
          <p className="text-sm font-medium text-honey-700 mb-1">Avg. Duration</p>
          <p className="text-4xl font-display font-bold text-honey-900">{stats.avg_process_duration_days}</p>
          <p className="text-xs text-honey-600/70 mt-2">days to outcome</p>
        </div>
      </div>

      {/* Priority Actions */}
      <PriorityActions
        processes={processes || []}
        positions={positions || []}
        companies={companies || []}
        interviews={interviews || []}
      />

      {/* Quick Overview */}
      {activeProcesses.length > 0 && (
        <section>
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-2xl font-display font-bold text-navy-900 flex items-center gap-2">
              <Zap className="w-6 h-6 text-honey-500" />
              Recent Activity
            </h2>
            <Link
              to="/applications"
              className="text-honey-600 hover:text-honey-700 font-semibold text-sm flex items-center gap-1"
            >
              View all <ArrowRight className="w-4 h-4" />
            </Link>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {activeProcesses.slice(0, 6).map((process) => {
              const position = positions?.find(p => p.id === process.job_position_id);
              const company = companies?.find(c => c.id === position?.company_id);

              if (!position || !company) return null;

              const daysAgo = Math.floor(
                (Date.now() - new Date(process.application_date).getTime()) / (1000 * 60 * 60 * 24)
              );

              return (
                <Link
                  key={process.id}
                  to="/applications"
                  className="block p-4 bg-white border-2 border-sand/50 hover:border-honey-300 rounded-xl transition-all group"
                >
                  <div className="flex justify-between items-start mb-2">
                    <div className="flex-1 min-w-0">
                      <h3 className="font-semibold text-navy-900 truncate group-hover:text-honey-600 transition-colors">
                        {position.title}
                      </h3>
                      <p className="text-sm text-anthracite/60 truncate">{company.name}</p>
                    </div>
                    <ArrowRight className="w-4 h-4 text-honey-500 opacity-0 group-hover:opacity-100 transition-opacity flex-shrink-0 ml-2" />
                  </div>
                  <div className="flex items-center justify-between mt-3">
                    <span className="px-2 py-1 bg-sand/30 text-anthracite/70 text-xs font-semibold rounded-md capitalize">
                      {process.status.replace('_', ' ')}
                    </span>
                    <span className="text-xs text-anthracite/50">
                      {daysAgo === 0 ? 'Today' : `${daysAgo}d ago`}
                    </span>
                  </div>
                </Link>
              );
            })}
          </div>
        </section>
      )}

      {/* Empty State */}
      {activeProcesses.length === 0 && (
        <div className="text-center py-16 bg-sand/10 rounded-2xl border-2 border-dashed border-sand/50">
          <div className="inline-flex items-center justify-center w-20 h-20 bg-honey-100 rounded-full mb-4">
            <Briefcase className="w-10 h-10 text-honey-500" />
          </div>
          <h3 className="text-xl font-display font-bold text-navy-900 mb-2">
            Ready to start your job search?
          </h3>
          <p className="text-anthracite/60 mb-6 max-w-md mx-auto">
            Track applications, schedule interviews, and land your dream job.
          </p>
          <Link
            to="/applications"
            className="inline-flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-honey-500 to-honey-600 hover:from-honey-600 hover:to-honey-700  font-semibold rounded-xl shadow-md hover:shadow-lg transition-all"
          >
            <Briefcase className="w-5 h-5" />
            Add Your First Application
          </Link>
        </div>
      )}
    </div>
  );
}
