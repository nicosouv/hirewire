import { Link, Outlet, useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import {
  LayoutDashboard,
  Building2,
  Briefcase,
  GitBranch,
  Calendar,
  LogOut,
  User,
  Sparkles
} from 'lucide-react';

export default function Layout() {
  const location = useLocation();
  const navigate = useNavigate();
  const { user, logout } = useAuth();

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
                className="w-10 h-10 object-contain"
              />
              <div>
                <h1 className="text-xl font-display font-bold text-navy-900">
                  HireWire
                </h1>
                <p className="text-xs text-anthracite/60 font-medium -mt-0.5">
                  Interview Tracker
                </p>
              </div>
            </div>

            {/* User menu */}
            {user && (
              <div className="flex items-center gap-4">
                <div className="hidden sm:flex items-center gap-2 px-4 py-2 bg-sand/50 rounded-xl">
                  <div className="w-8 h-8 bg-gradient-to-br from-honey-400 to-honey-500 rounded-lg flex items-center justify-center">
                    <User className="w-4 h-4 text-white" />
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
        <aside className="w-64 min-h-[calc(100vh-4rem)] bg-white border-r border-sand/50 sticky top-16 hidden lg:block">
          <nav className="p-4 space-y-1">
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
                        ? 'bg-gradient-to-r from-honey-500 to-honey-600 text-white shadow-md'
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

          {/* Sidebar footer */}
          <div className="absolute bottom-0 left-0 right-0 p-4 border-t border-sand/50">
            <div className="bg-gradient-to-br from-honey-50 to-sky-50 border border-honey-200/50 rounded-xl p-4">
              <p className="text-xs font-semibold text-navy-900 mb-1">💡 Pro tip</p>
              <p className="text-xs text-anthracite/70">
                Keep your interview notes updated for better insights!
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
