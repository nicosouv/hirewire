import { useQuery } from '@tanstack/react-query';
import { apiClient } from '../services/api';
import { Trophy, Star, Flame, Target, Award } from 'lucide-react';

interface UserStats {
  total_points: number;
  level: number;
  current_streak: number;
  achievements_count: number;
  applications_count: number;
  interviews_count: number;
}

interface Achievement {
  id: number;
  code: string;
  name: string;
  description: string;
  icon: string;
  points: number;
  rarity: string;
  category: string;
}

interface UserAchievement {
  id: number;
  unlocked_at: string;
  is_new: boolean;
  achievement: Achievement;
}

interface GamificationDashboard {
  stats: UserStats;
  recent_achievements: UserAchievement[];
  progress_to_next_level: number;
  next_level_points: number;
}

export default function GamificationWidget() {
  const { data, isLoading, error } = useQuery<GamificationDashboard>({
    queryKey: ['gamification'],
    queryFn: async () => {
      const response = await apiClient.get('/gamification/dashboard');
      return response.data;
    }
  });

  if (isLoading) {
    return (
      <div className="bg-gradient-to-br from-purple-50 to-pink-50 rounded-2xl border border-purple-200/50 p-6">
        <div className="animate-pulse flex space-x-4">
          <div className="flex-1 space-y-4">
            <div className="h-4 bg-purple-200 rounded w-3/4"></div>
            <div className="h-3 bg-purple-200 rounded w-1/2"></div>
          </div>
        </div>
      </div>
    );
  }

  if (error || !data) {
    return null;
  }

  const { stats, recent_achievements, progress_to_next_level, next_level_points } = data;

  const rarityColors = {
    common: 'from-gray-400 to-gray-500',
    rare: 'from-blue-400 to-blue-600',
    epic: 'from-purple-400 to-purple-600',
    legendary: 'from-amber-400 to-amber-600'
  };

  return (
    <div className="space-y-4">
      {/* Stats Card */}
      <div className="bg-gradient-to-br from-purple-50 to-pink-50 rounded-2xl border border-purple-200/50 p-6">
        <div className="flex items-center gap-3 mb-4">
          <div className="w-10 h-10 bg-gradient-to-br from-purple-500 to-pink-500 rounded-xl flex items-center justify-center shadow-lg">
            <Trophy className="w-5 h-5 text-white" />
          </div>
          <div>
            <h3 className="text-lg font-bold text-navy-900">Your Progress</h3>
            <p className="text-sm text-anthracite/60">Level {stats.level} • {stats.total_points} XP</p>
          </div>
        </div>

        {/* Level Progress Bar */}
        <div className="mb-6">
          <div className="flex justify-between items-center mb-2">
            <span className="text-xs font-semibold text-navy-900">Level {stats.level}</span>
            <span className="text-xs text-anthracite/60">{stats.total_points} / {next_level_points} XP</span>
          </div>
          <div className="w-full bg-purple-200/50 rounded-full h-3 overflow-hidden">
            <div
              className="h-full bg-gradient-to-r from-purple-500 to-pink-500 rounded-full transition-all duration-500 shadow-lg"
              style={{ width: `${Math.min(progress_to_next_level, 100)}%` }}
            />
          </div>
        </div>

        {/* Quick Stats */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          <div className="bg-white rounded-xl p-3 border border-purple-200/30">
            <div className="flex items-center gap-2 mb-1">
              <Target className="w-4 h-4 text-purple-500" />
              <span className="text-xs text-anthracite/60">Applications</span>
            </div>
            <p className="text-xl font-bold text-navy-900">{stats.applications_count}</p>
          </div>

          <div className="bg-white rounded-xl p-3 border border-purple-200/30">
            <div className="flex items-center gap-2 mb-1">
              <Star className="w-4 h-4 text-amber-500" />
              <span className="text-xs text-anthracite/60">Interviews</span>
            </div>
            <p className="text-xl font-bold text-navy-900">{stats.interviews_count}</p>
          </div>

          <div className="bg-white rounded-xl p-3 border border-purple-200/30">
            <div className="flex items-center gap-2 mb-1">
              <Flame className="w-4 h-4 text-orange-500" />
              <span className="text-xs text-anthracite/60">Streak</span>
            </div>
            <p className="text-xl font-bold text-navy-900">{stats.current_streak}</p>
          </div>

          <div className="bg-white rounded-xl p-3 border border-purple-200/30">
            <div className="flex items-center gap-2 mb-1">
              <Award className="w-4 h-4 text-green-500" />
              <span className="text-xs text-anthracite/60">Badges</span>
            </div>
            <p className="text-xl font-bold text-navy-900">{stats.achievements_count}</p>
          </div>
        </div>
      </div>

      {/* Recent Achievements */}
      {recent_achievements.length > 0 && (
        <div className="bg-white rounded-2xl border border-sand/30 p-6">
          <h3 className="text-lg font-bold text-navy-900 mb-4 flex items-center gap-2">
            <Award className="w-5 h-5 text-honey-600" />
            Recent Achievements
          </h3>

          <div className="space-y-3">
            {recent_achievements.slice(0, 3).map((ua) => (
              <div
                key={ua.id}
                className="flex items-center gap-3 p-3 bg-gradient-to-r from-ivory/50 to-sand/30 rounded-xl hover:shadow-md transition-all group relative overflow-hidden"
              >
                {/* Rarity shine effect */}
                <div className={`absolute inset-0 bg-gradient-to-r ${rarityColors[ua.achievement.rarity as keyof typeof rarityColors]} opacity-5`} />

                <div className="text-3xl relative z-10">{ua.achievement.icon}</div>

                <div className="flex-1 relative z-10">
                  <div className="flex items-center gap-2">
                    <h4 className="font-bold text-navy-900 group-hover:text-honey-600 transition-colors">
                      {ua.achievement.name}
                    </h4>
                    {ua.is_new && (
                      <span className="px-2 py-0.5 bg-gradient-to-r from-honey-500 to-honey-600 text-white text-xs font-bold rounded-full">
                        NEW
                      </span>
                    )}
                  </div>
                  <p className="text-xs text-anthracite/60">{ua.achievement.description}</p>
                </div>

                <div className="text-right relative z-10">
                  <div className={`px-3 py-1.5 bg-gradient-to-r ${rarityColors[ua.achievement.rarity as keyof typeof rarityColors]} text-white rounded-lg text-xs font-bold shadow-lg`}>
                    +{ua.achievement.points} XP
                  </div>
                  <span className="text-xs text-anthracite/60 mt-1 block capitalize">
                    {ua.achievement.rarity}
                  </span>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
