import { Link, Outlet, useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { useState, useEffect } from 'react';
import {
  LayoutDashboard,
  Building2,
  Briefcase,
  GitBranch,
  Calendar,
  LogOut,
  User
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

export default function Layout() {
  const location = useLocation();
  const navigate = useNavigate();
  const { user, logout } = useAuth();
  const [proTip, setProTip] = useState(PRO_TIPS[0]);

  useEffect(() => {
    // Change pro tip every 10 seconds
    const interval = setInterval(() => {
      setProTip(PRO_TIPS[Math.floor(Math.random() * PRO_TIPS.length)]);
    }, 10000);

    return () => clearInterval(interval);
  }, []);

  const navigation = [
    { name: 'Dashboard', path: '/', icon: LayoutDashboard },
    { name: 'Companies', path: '/companies', icon: Building2 },
    { name: 'Job Positions', path: '/positions', icon: Briefcase },
    { name: 'Processes', path: '/processes', icon: GitBranch },
    { name: 'Interviews', path: '/interviews', icon: Calendar },
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

            {/* User menu */}
            {user && (
              <div className="flex items-center gap-4">
                <div className="hidden sm:flex items-center gap-2 px-4 py-2 bg-sand/50 rounded-xl">
                  <div className="w-8 h-8 bg-gradient-to-br from-honey-400 to-honey-500 rounded-lg flex items-center justify-center">
                    <User className="w-4 h-4" />
                  </div>
                  <div className="text-sm">
                    <p className="font-semibold text-navy-900">{user.full_name}</p>
                    <p className="text-xs text-anthracite/60">{user.email}</p>
                  </div>
                </div>
                <button
                  onClick={handleLogout}
                  className="flex items-center gap-2 px-4 py-2 text-sm font-semibold text-anthracite/70 hover:text-navy-900 hover:bg-sand/50 rounded-xl transition-all"
                >
                  <LogOut className="w-4 h-4" />
                  <span className="hidden sm:inline">Logout</span>
                </button>
              </div>
            )}
          </div>
        </div>
      </header>

      <div className="flex max-w-7xl mx-auto">
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
          <div className="p-4 border-t border-sand/50 flex-shrink-0">
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
          </nav>
        </div>

        {/* Main Content */}
        <main className="flex-1 p-6 lg:p-8 pb-24 lg:pb-8">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
