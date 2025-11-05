import { Link, Outlet, useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { useState, useEffect, useRef } from 'react';
import { useCompanies } from '../hooks/useCompanies';
import { usePositions } from '../hooks/usePositions';
import QuickAddModal from './QuickAddModal';
import {
  LayoutDashboard,
  Briefcase,
  LogOut,
  User,
  Plus,
  Zap,
  Settings,
  ChevronDown,
  BarChart3
} from 'lucide-react';

const PRO_TIPS = [
  "Coffee before interviews, wine after rejections. ☕🍷",
  "Remember: 'Culture fit' is HR for 'we don't like you'.",
  "Pro tip: Lying about loving agile won't make sprints shorter.",
  "If they ask 'Where do you see yourself in 5 years?', say 'Not here if you keep asking dumb questions'.",
  "The cake is a lie, and so is 'competitive salary'.",
  "Ghosting companies back is the new power move. 👻",
  "If the job description says 'rockstar developer', run. 🎸",
  "Unlimited PTO = Please Take Zero. 🏖️",
  "They said 'fast-paced environment'. They meant chaos.",
  "Adding 'Passionate' to your CV doesn't make you passionate.",
  "Pro tip: Update your LinkedIn. Your mom's not the only one checking.",
  "If they say 'we're like a family', they mean dysfunction included.",
  "Remember: Every rejection is one step closer to unemployment.",
  "Keep your resume updated. And your therapy appointments. 🛋️",
  "Pro tip: Practice your fake smile for video interviews. 😬",
  "They ghosted you? Ghost them on Glassdoor. 💀",
  "Wear pants to video interviews. Trust me on this one.",
  "If they mention 'startup culture', they mean no budget.",
  "Pro tip: LinkedIn Premium won't make recruiters less annoying.",
  "Remember: You're not 'between opportunities', you're unemployed.",
  "Keep your interview notes updated. Or don't. Whatever. 🤷",
  "If they say 'equity', they mean monopoly money. 💸",
];

export default function NewLayout() {
  const location = useLocation();
  const navigate = useNavigate();
  const { user, logout } = useAuth();
  const [proTip, setProTip] = useState(PRO_TIPS[0]);
  const [showQuickAdd, setShowQuickAdd] = useState(false);
  const [showUserMenu, setShowUserMenu] = useState(false);
  const userMenuRef = useRef<HTMLDivElement>(null);
  const { data: companies } = useCompanies();
  const { data: positions } = usePositions();

  useEffect(() => {
    // Change pro tip every 10 seconds
    const interval = setInterval(() => {
      setProTip(PRO_TIPS[Math.floor(Math.random() * PRO_TIPS.length)]);
    }, 10000);

    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    // Close user menu when clicking outside
    const handleClickOutside = (event: MouseEvent) => {
      if (userMenuRef.current && !userMenuRef.current.contains(event.target as Node)) {
        setShowUserMenu(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const navigation = [
    { name: 'Overview', path: '/', icon: LayoutDashboard },
    { name: 'Applications', path: '/applications', icon: Briefcase },
    { name: 'Analytics', path: '/analytics', icon: BarChart3 },
  ];

  const isActive = (path: string) => {
    if (path === '/') {
      return location.pathname === '/';
    }
    return location.pathname.startsWith(path);
  };

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  return (
    <div className="min-h-screen bg-ivory">
      {/* Header */}
      <header className="bg-white border-b border-sand/50 sticky top-0 z-50 shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            {/* Logo */}
            <div className="flex items-center gap-3">
              <img
                src="/logo.png"
                alt="HireWire"
                className="w-50 object-contain"
              />
            </div>

            {/* Quick Add Button - Desktop */}
            <button
              onClick={() => setShowQuickAdd(true)}
              className="hidden lg:flex items-center gap-2 px-6 py-2.5 bg-gradient-to-r from-honey-500 to-honey-600 hover:from-honey-600 hover:to-honey-700 font-semibold rounded-xl shadow-md hover:shadow-lg transition-all transform hover:scale-[1.02]"
            >
              <Plus className="w-5 h-5" />
              Quick Add
            </button>

            {/* User menu */}
            {user && (
              <div className="relative" ref={userMenuRef}>
                <button
                  onClick={() => setShowUserMenu(!showUserMenu)}
                  className="flex items-center gap-2 px-4 py-2 bg-sand/50 rounded-xl hover:bg-sand/70 transition-all"
                >
                  <div className="w-8 h-8 bg-gradient-to-br from-honey-400 to-honey-500 rounded-lg flex items-center justify-center">
                    <User className="w-4 h-4" />
                  </div>
                  <div className="hidden sm:block text-sm text-left">
                    <p className="font-semibold text-navy-900">{user.full_name}</p>
                    <p className="text-xs text-anthracite/60">{user.email}</p>
                  </div>
                  <ChevronDown className={`w-4 h-4 text-anthracite/60 transition-transform ${showUserMenu ? 'rotate-180' : ''}`} />
                </button>

                {/* Dropdown Menu */}
                {showUserMenu && (
                  <div className="absolute right-0 mt-2 w-56 bg-white rounded-xl shadow-lg border border-sand/50 py-2 z-50">
                    <Link
                      to="/settings"
                      onClick={() => setShowUserMenu(false)}
                      className="flex items-center gap-3 px-4 py-2.5 text-sm font-semibold text-anthracite/70 hover:bg-sand/50 hover:text-navy-900 transition-all"
                    >
                      <Settings className="w-4 h-4" />
                      Settings
                    </Link>
                    <div className="border-t border-sand/50 my-1"></div>
                    <button
                      onClick={() => {
                        setShowUserMenu(false);
                        handleLogout();
                      }}
                      className="w-full flex items-center gap-3 px-4 py-2.5 text-sm font-semibold text-red-600 hover:bg-red-50 transition-all"
                    >
                      <LogOut className="w-4 h-4" />
                      Logout
                    </button>
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      </header>

      <div className="flex">
        {/* Sidebar */}
        <aside className="w-64 h-[calc(100vh-4rem)] bg-white border-r border-sand/50 sticky top-16 hidden lg:flex flex-col">
          <nav className="p-4 space-y-1 flex-1 overflow-y-auto">
            {navigation.map((item) => {
              const Icon = item.icon;
              const active = isActive(item.path);

              return (
                <Link
                  key={item.path}
                  to={item.path}
                  className={`
                    flex items-center gap-3 px-4 py-3 text-sm font-semibold rounded-xl transition-all
                    ${
                      active
                        ? 'bg-honey-50 text-honey-700 border-2 border-honey-500 shadow-sm'
                        : 'text-anthracite/70 hover:bg-sand/50 hover:text-navy-900'
                    }
                  `}
                >
                  <Icon className="w-5 h-5" />
                  {item.name}
                </Link>
              );
            })}
          </nav>

          {/* Sidebar footer - always visible */}
          <div className="p-4 border-t border-sand/50 flex-shrink-0 space-y-3">
            <div className="bg-gradient-to-br from-honey-50 to-sky-50 border border-honey-200/50 rounded-xl p-4 transition-all duration-500">
              <p className="text-xs font-semibold text-navy-900 mb-1">💡 Pro tip</p>
              <p className="text-xs text-anthracite/70 leading-relaxed">
                {proTip}
              </p>
            </div>
          </div>
        </aside>

        {/* Mobile navigation */}
        <div className="lg:hidden fixed bottom-0 left-0 right-0 bg-white border-t border-sand/50 z-50 shadow-lg">
          <nav className="flex justify-around items-center h-16 px-2">
            {navigation.map((item) => {
              const Icon = item.icon;
              const active = isActive(item.path);

              return (
                <Link
                  key={item.path}
                  to={item.path}
                  className={`
                    flex flex-col items-center justify-center gap-1 px-3 py-2 rounded-xl transition-all min-w-[60px]
                    ${
                      active
                        ? 'text-honey-600'
                        : 'text-anthracite/60 hover:text-navy-900'
                    }
                  `}
                >
                  <Icon className="w-5 h-5" />
                  <span className="text-[10px] font-semibold">{item.name}</span>
                </Link>
              );
            })}

            {/* Mobile Quick Add Button */}
            <button
              onClick={() => setShowQuickAdd(true)}
              className="flex flex-col items-center justify-center gap-1 px-3 py-2 text-honey-600 min-w-[60px]"
            >
              <div className="w-10 h-10 bg-gradient-to-r from-honey-500 to-honey-600 rounded-full flex items-center justify-center shadow-lg">
                <Plus className="w-5 h-5 " />
              </div>
              <span className="text-[10px] font-semibold">Add</span>
            </button>
          </nav>
        </div>

        {/* Main Content */}
        <main className="flex-1 p-6 lg:p-8 pb-24 lg:pb-8 max-w-7xl mx-auto w-full">
          <Outlet />
        </main>
      </div>

      {/* Quick Add Modal */}
      <QuickAddModal
        isOpen={showQuickAdd}
        onClose={() => setShowQuickAdd(false)}
        companies={companies || []}
        positions={positions || []}
      />
    </div>
  );
}
