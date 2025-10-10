import { Sparkles } from 'lucide-react';

export default function Loading() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-ivory via-sand to-ivory flex items-center justify-center">
      <div className="text-center">
        {/* Animated logo */}
        <div className="relative inline-flex items-center justify-center mb-6">
          {/* Spinning ring */}
          <div className="absolute w-24 h-24 border-4 border-honey-200 border-t-honey-500 rounded-full animate-spin"></div>
          {/* Logo */}
          <div className="w-20 h-20 flex items-center justify-center">
            <img
              src="/logo.png"
              alt="HireWire"
              className="w-full h-full object-contain animate-pulse"
            />
          </div>
        </div>

        {/* Text */}
        <h2 className="text-xl font-display font-bold text-navy-900 mb-2">
          HireWire
        </h2>
        <p className="text-sm text-anthracite/60 font-medium animate-pulse">
          Loading...
        </p>
      </div>
    </div>
  );
}
