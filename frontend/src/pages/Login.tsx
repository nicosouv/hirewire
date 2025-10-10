import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { LogIn, Mail, Lock, Sparkles } from 'lucide-react';

export default function Login() {
  const navigate = useNavigate();
  const { login } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setIsLoading(true);

    try {
      await login(email, password);
      navigate('/');
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Login failed. Please check your credentials.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-ivory via-sand to-ivory flex items-center justify-center p-4">
      {/* Background decoration */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-40 -right-40 w-80 h-80 bg-honey-200 rounded-full mix-blend-multiply filter blur-xl opacity-30 animate-blob"></div>
        <div className="absolute -bottom-40 -left-40 w-80 h-80 bg-sky-200 rounded-full mix-blend-multiply filter blur-xl opacity-30 animate-blob animation-delay-2000"></div>
        <div className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 w-80 h-80 bg-navy-200 rounded-full mix-blend-multiply filter blur-xl opacity-20 animate-blob animation-delay-4000"></div>
      </div>

      <div className="w-full max-w-md relative z-10">
        {/* Logo and header */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-20 h-20 mb-4">
            <img
              src="/logo.png"
              alt="HireWire"
              className="w-full h-full object-contain"
            />
          </div>
          <h1 className="text-4xl font-display font-bold text-navy-900 mb-2">
            HireWire
          </h1>
          <p className="text-anthracite/60 font-medium">
            Track your interview journey
          </p>
        </div>

        {/* Login card */}
        <div className="bg-white rounded-2xl shadow-soft p-8 border border-sand/50">
          <div className="mb-6">
            <h2 className="text-2xl font-display font-semibold text-navy-900 mb-1">
              Welcome back
            </h2>
            <p className="text-anthracite/60 text-sm">
              Sign in to continue to your dashboard
            </p>
          </div>

          <form className="space-y-5" onSubmit={handleSubmit}>
            {error && (
              <div className="bg-red-50 border-l-4 border-red-500 text-red-800 px-4 py-3 rounded-lg">
                <p className="text-sm font-medium">{error}</p>
              </div>
            )}

            <div>
              <label htmlFor="email" className="block text-sm font-semibold text-navy-900 mb-2">
                Email address
              </label>
              <div className="relative">
                <div className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none">
                  <Mail className="h-5 w-5 text-anthracite/40" />
                </div>
                <input
                  id="email"
                  name="email"
                  type="email"
                  autoComplete="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="block w-full pl-11 pr-4 py-3 border border-sand bg-ivory/50 rounded-xl text-anthracite placeholder-anthracite/40 focus:outline-none focus:ring-2 focus:ring-honey-500 focus:border-transparent transition-all"
                  placeholder="you@example.com"
                />
              </div>
            </div>

            <div>
              <label htmlFor="password" className="block text-sm font-semibold text-navy-900 mb-2">
                Password
              </label>
              <div className="relative">
                <div className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none">
                  <Lock className="h-5 w-5 text-anthracite/40" />
                </div>
                <input
                  id="password"
                  name="password"
                  type="password"
                  autoComplete="current-password"
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="block w-full pl-11 pr-4 py-3 border border-sand bg-ivory/50 rounded-xl text-anthracite placeholder-anthracite/40 focus:outline-none focus:ring-2 focus:ring-honey-500 focus:border-transparent transition-all"
                  placeholder="••••••••"
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={isLoading}
              className="w-full flex items-center justify-center gap-2 py-3.5 px-4 bg-gradient-to-r from-honey-500 to-honey-600 hover:from-honey-600 hover:to-honey-700 text-white font-semibold rounded-xl shadow-md hover:shadow-lg focus:outline-none focus:ring-2 focus:ring-honey-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed transition-all transform hover:scale-[1.02] active:scale-[0.98]"
            >
              {isLoading ? (
                <>
                  <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                  Signing in...
                </>
              ) : (
                <>
                  <LogIn className="w-5 h-5" />
                  Sign in
                </>
              )}
            </button>
          </form>

          {/* Divider */}
          <div className="relative my-6">
            <div className="absolute inset-0 flex items-center">
              <div className="w-full border-t border-sand"></div>
            </div>
            <div className="relative flex justify-center text-sm">
              <span className="px-4 bg-white text-anthracite/60 font-medium">
                New to HireWire?
              </span>
            </div>
          </div>

          {/* Register link */}
          <Link
            to="/register"
            className="w-full flex justify-center py-3 px-4 border-2 border-navy-900 rounded-xl text-navy-900 font-semibold hover:bg-navy-900 hover:text-white focus:outline-none focus:ring-2 focus:ring-navy-900 focus:ring-offset-2 transition-all"
          >
            Create an account
          </Link>

          {/* Demo account info */}
          <div className="mt-6 p-4 bg-honey-50 border border-honey-200 rounded-xl">
            <p className="text-xs text-center text-anthracite/70 font-medium">
              <span className="block mb-1 text-honey-700 font-semibold">Demo account</span>
              <span className="font-mono">admin@hirewire.com</span>
              <span className="mx-2 text-honey-500">•</span>
              <span className="font-mono">secret</span>
            </p>
          </div>
        </div>

        {/* Footer */}
        <p className="text-center mt-6 text-sm text-anthracite/50">
          © 2025 HireWire. Track smarter, interview better.
        </p>
      </div>
    </div>
  );
}
