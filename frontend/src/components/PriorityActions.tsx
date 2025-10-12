import { AlertCircle, Calendar, Clock, MessageSquare, ArrowRight } from 'lucide-react';
import { Link } from 'react-router-dom';
import type { Process, Position, Company, Interview } from '../types';

interface PriorityAction {
  id: string;
  title: string;
  subtitle: string;
  priority: 'high' | 'medium' | 'low';
  icon: React.ReactNode;
  link?: string;
  processId?: number;
  daysAgo?: number;
}

interface PriorityActionsProps {
  processes: Process[];
  positions: Position[];
  companies: Company[];
  interviews: Interview[];
}

export default function PriorityActions({
  processes,
  positions,
  companies,
  interviews,
}: PriorityActionsProps) {
  const actions: PriorityAction[] = [];

  const now = new Date();
  const tomorrow = new Date(now);
  tomorrow.setDate(tomorrow.getDate() + 1);
  const nextWeek = new Date(now);
  nextWeek.setDate(nextWeek.getDate() + 7);

  // 1. Upcoming interviews (within 48 hours) - HIGH PRIORITY
  const upcomingInterviews = interviews.filter(i => {
    const interviewDate = new Date(i.scheduled_date);
    const hoursUntil = (interviewDate.getTime() - now.getTime()) / (1000 * 60 * 60);
    return i.status === 'scheduled' && hoursUntil > 0 && hoursUntil <= 48;
  });

  upcomingInterviews.forEach(interview => {
    const process = processes.find(p => p.id === interview.process_id);
    const position = positions.find(p => p.id === process?.job_position_id);
    const company = companies.find(c => c.id === position?.company_id);

    if (position && company && process) {
      const interviewDate = new Date(interview.scheduled_date);
      const hoursUntil = Math.round((interviewDate.getTime() - now.getTime()) / (1000 * 60 * 60));

      actions.push({
        id: `interview-${interview.id}`,
        title: `Interview ${hoursUntil < 24 ? 'tomorrow' : 'in ' + Math.floor(hoursUntil / 24) + ' days'}`,
        subtitle: `${position.title} at ${company.name}`,
        priority: hoursUntil < 24 ? 'high' : 'medium',
        icon: <Calendar className="w-5 h-5" />,
        link: `/applications?processId=${process.id}`,
        processId: process.id,
      });
    }
  });

  // 2. Applications without follow-up (> 7 days) - MEDIUM PRIORITY
  const staleApplications = processes.filter(p => {
    if (['rejected', 'accepted', 'withdrew', 'ghosted'].includes(p.status)) return false;

    const daysAgo = Math.floor(
      (now.getTime() - new Date(p.application_date).getTime()) / (1000 * 60 * 60 * 24)
    );

    // Check if no recent interviews
    const hasRecentInterview = interviews.some(i => {
      if (i.process_id !== p.id) return false;
      const interviewDaysAgo = Math.floor(
        (now.getTime() - new Date(i.scheduled_date).getTime()) / (1000 * 60 * 60 * 24)
      );
      return interviewDaysAgo <= 7;
    });

    return daysAgo >= 7 && !hasRecentInterview;
  });

  staleApplications.slice(0, 2).forEach(process => {
    const position = positions.find(p => p.id === process.job_position_id);
    const company = companies.find(c => c.id === position?.company_id);
    const daysAgo = Math.floor(
      (now.getTime() - new Date(process.application_date).getTime()) / (1000 * 60 * 60 * 24)
    );

    if (position && company) {
      actions.push({
        id: `followup-${process.id}`,
        title: `Follow up needed`,
        subtitle: `${position.title} at ${company.name} (applied ${daysAgo}d ago)`,
        priority: daysAgo > 14 ? 'high' : 'medium',
        icon: <MessageSquare className="w-5 h-5" />,
        link: `/applications?processId=${process.id}`,
        processId: process.id,
        daysAgo,
      });
    }
  });

  // 3. Applications in "interviewing" status without scheduled interviews - MEDIUM PRIORITY
  const interviewingWithoutScheduled = processes.filter(p => {
    if (p.status !== 'interviewing' && p.status !== 'tech_test') return false;

    const hasScheduledInterview = interviews.some(i =>
      i.process_id === p.id && i.status === 'scheduled'
    );

    return !hasScheduledInterview;
  });

  interviewingWithoutScheduled.slice(0, 1).forEach(process => {
    const position = positions.find(p => p.id === process.job_position_id);
    const company = companies.find(c => c.id === position?.company_id);

    if (position && company) {
      actions.push({
        id: `schedule-${process.id}`,
        title: `Schedule next interview`,
        subtitle: `${position.title} at ${company.name}`,
        priority: 'medium',
        icon: <Clock className="w-5 h-5" />,
        link: `/applications?processId=${process.id}`,
        processId: process.id,
      });
    }
  });

  // 4. Recent applications (< 3 days) to prepare - LOW PRIORITY
  const recentApplications = processes.filter(p => {
    if (['rejected', 'accepted', 'withdrew', 'ghosted'].includes(p.status)) return false;

    const daysAgo = Math.floor(
      (now.getTime() - new Date(p.application_date).getTime()) / (1000 * 60 * 60 * 24)
    );

    return daysAgo >= 1 && daysAgo <= 3 && p.status === 'applied';
  });

  recentApplications.slice(0, 1).forEach(process => {
    const position = positions.find(p => p.id === process.job_position_id);
    const company = companies.find(c => c.id === position?.company_id);
    const daysAgo = Math.floor(
      (now.getTime() - new Date(process.application_date).getTime()) / (1000 * 60 * 60 * 24)
    );

    if (position && company) {
      actions.push({
        id: `prepare-${process.id}`,
        title: `Prepare for potential screening`,
        subtitle: `${position.title} at ${company.name}`,
        priority: 'low',
        icon: <AlertCircle className="w-5 h-5" />,
        link: `/applications?processId=${process.id}`,
        processId: process.id,
      });
    }
  });

  // Sort by priority
  const priorityOrder = { high: 0, medium: 1, low: 2 };
  const sortedActions = actions.sort((a, b) => priorityOrder[a.priority] - priorityOrder[b.priority]);

  // Take top 4 actions
  const topActions = sortedActions.slice(0, 4);

  if (topActions.length === 0) {
    return null;
  }

  const getPriorityColor = (priority: 'high' | 'medium' | 'low') => {
    switch (priority) {
      case 'high':
        return 'from-red-50 to-red-100 border-red-300 text-red-700';
      case 'medium':
        return 'from-honey-50 to-honey-100 border-honey-300 text-honey-700';
      case 'low':
        return 'from-blue-50 to-blue-100 border-blue-300 text-blue-700';
    }
  };

  const getPriorityIconColor = (priority: 'high' | 'medium' | 'low') => {
    switch (priority) {
      case 'high':
        return 'bg-red-500';
      case 'medium':
        return 'bg-honey-500';
      case 'low':
        return 'bg-blue-500';
    }
  };

  return (
    <section>
      <div className="mb-4">
        <h2 className="text-2xl font-display font-bold text-navy-900 flex items-center gap-2">
          <AlertCircle className="w-6 h-6 text-red-500" />
          Priority Actions
        </h2>
        <p className="text-sm text-anthracite/60 mt-1">
          {topActions.length} {topActions.length === 1 ? 'item' : 'items'} need your attention
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {topActions.map((action) => (
          <Link
            key={action.id}
            to={action.link || '/applications'}
            className={`
              group block p-5 rounded-xl border-2 transition-all hover:shadow-lg
              bg-gradient-to-br ${getPriorityColor(action.priority)}
            `}
          >
            <div className="flex items-start gap-4">
              <div className={`p-3 ${getPriorityIconColor(action.priority)} rounded-xl shadow-md flex-shrink-0`}>
                <div>
                  {action.icon}
                </div>
              </div>
              <div className="flex-1 min-w-0">
                <h3 className="font-display font-bold text-navy-900 mb-1 group-hover:text-opacity-80 transition-colors">
                  {action.title}
                </h3>
                <p className="text-sm text-anthracite/70 line-clamp-2">
                  {action.subtitle}
                </p>
                {action.priority === 'high' && (
                  <div className="mt-2">
                    <span className="inline-flex items-center gap-1 px-2 py-1 bg-red-200 text-red-800 text-xs font-bold rounded-md">
                      <AlertCircle className="w-3 h-3" />
                      URGENT
                    </span>
                  </div>
                )}
              </div>
              <ArrowRight className="w-5 h-5 text-navy-900/40 group-hover:text-navy-900 group-hover:translate-x-1 transition-all flex-shrink-0" />
            </div>
          </Link>
        ))}
      </div>
    </section>
  );
}
