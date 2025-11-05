import { DollarSign, MapPin, Clock, MoreVertical, Trash2, Edit, ArrowRight } from 'lucide-react';
import { useState } from 'react';
import type { Process, Position, Company } from '../types';

interface ApplicationCardProps {
  process: Process;
  position: Position;
  company: Company;
  onClick?: () => void;
  onDelete?: () => void;
  onEdit?: () => void;
  compact?: boolean;
}

const STATUS_COLORS: Record<string, string> = {
  applied: 'bg-blue-500',
  screening: 'bg-purple-500',
  interviewing: 'bg-honey-500',
  tech_test: 'bg-indigo-500',
  final_round: 'bg-orange-500',
  offer: 'bg-green-500',
  rejected: 'bg-red-500',
  accepted: 'bg-emerald-500',
  ghosted: 'bg-gray-500',
  withdrew: 'bg-slate-500',
};

export default function ApplicationCard({
  process,
  position,
  company,
  onClick,
  onDelete,
  onEdit,
  compact = false,
}: ApplicationCardProps) {
  const [showMenu, setShowMenu] = useState(false);

  const daysAgo = Math.floor(
    (Date.now() - new Date(process.application_date).getTime()) / (1000 * 60 * 60 * 24)
  );

  const getTimeText = () => {
    if (daysAgo === 0) return 'Today';
    if (daysAgo === 1) return 'Yesterday';
    return `${daysAgo}d ago`;
  };

  const statusColor = STATUS_COLORS[process.status] || 'bg-gray-500';

  return (
    <div
      role="button"
      tabIndex={0}
      onClick={onClick}
      onKeyDown={(e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          onClick?.();
        }
      }}
      className={`
        bg-white rounded-xl border-2 border-sand/50 hover:border-honey-300
        transition-all cursor-pointer group hover:shadow-md
        ${compact ? 'p-3' : 'p-4'}
      `}
    >
      {/* Status Bar */}
      <div className={`h-1 ${statusColor} rounded-full mb-3`} />

      {/* Header */}
      <div className="flex justify-between items-start mb-2">
        <div className="flex-1 min-w-0">
          <h3 className="font-display font-bold text-navy-900 text-base truncate group-hover:text-honey-600 transition-colors">
            {position.title}
          </h3>
          <p className="text-sm text-anthracite/70 font-medium truncate">
            {company.name}
          </p>
        </div>

        {/* Actions Menu */}
        <div className="relative">
          <button
            aria-label="More options"
            onClick={(e) => {
              e.stopPropagation();
              setShowMenu(!showMenu);
            }}
            className="p-1 hover:bg-sand/50 rounded-lg opacity-0 group-hover:opacity-100 transition-opacity"
          >
            <MoreVertical className="w-4 h-4 text-anthracite/60" />
          </button>

          {showMenu && (
            <>
              <div
                className="fixed inset-0 z-10"
                onClick={(e) => {
                  e.stopPropagation();
                  setShowMenu(false);
                }}
              />
              <div className="absolute right-0 mt-1 w-40 bg-white rounded-lg shadow-lg border border-sand/50 py-1 z-20">
                {onEdit && (
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      onEdit();
                      setShowMenu(false);
                    }}
                    className="w-full px-4 py-2 text-left text-sm flex items-center gap-2 hover:bg-sand/30 text-anthracite"
                  >
                    <Edit className="w-4 h-4" />
                    Edit
                  </button>
                )}
                {onDelete && (
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      onDelete();
                      setShowMenu(false);
                    }}
                    className="w-full px-4 py-2 text-left text-sm flex items-center gap-2 hover:bg-red-50 text-red-600"
                  >
                    <Trash2 className="w-4 h-4" />
                    Delete
                  </button>
                )}
              </div>
            </>
          )}
        </div>
      </div>

      {/* Metadata */}
      {!compact && (
        <div className="space-y-1.5 mb-3">
          {position.location && (
            <div className="flex items-center gap-1.5 text-xs text-anthracite/60">
              <MapPin className="w-3.5 h-3.5" />
              <span>{position.location}</span>
            </div>
          )}
          {(position.salary_min || position.salary_max) && (
            <div className="flex items-center gap-1.5 text-xs text-anthracite/60">
              <DollarSign className="w-3.5 h-3.5" />
              <span>
                {position.salary_min && position.salary_max
                  ? `${position.salary_min}-${position.salary_max}k`
                  : position.salary_min
                  ? `${position.salary_min}k+`
                  : `Up to ${position.salary_max}k`}
              </span>
            </div>
          )}
        </div>
      )}

      {/* Status Badge */}
      <div className="flex items-center justify-between">
        <span className="inline-flex items-center gap-1 px-2 py-1 bg-sand/30 text-anthracite/70 text-xs font-semibold rounded-md capitalize">
          {process.status.replace('_', ' ')}
        </span>

        <div className="flex items-center gap-1 text-xs text-anthracite/50">
          <Clock className="w-3 h-3" />
          <span>{getTimeText()}</span>
        </div>
      </div>

      {/* Source */}
      {!compact && process.source && (
        <div className="mt-2 text-xs text-anthracite/50">
          via {process.source}
        </div>
      )}

      {/* Hover Arrow */}
      <div className="flex justify-end mt-2 opacity-0 group-hover:opacity-100 transition-opacity">
        <ArrowRight className="w-4 h-4 text-honey-500" />
      </div>
    </div>
  );
}
