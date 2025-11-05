import { createContext, useContext, useState, useEffect, type ReactNode } from 'react';
import { apiClient } from '../services/api';

interface User {
  id: number;
  email: string;
  first_name: string;
  last_name: string;
  full_name: string;
  is_superuser: boolean;
}

interface AuthContextType {
  user: User | null;
  token: string | null;
  login: (email: string, password: string) => Promise<void>;
  register: (email: string, password: string, firstName: string, lastName: string) => Promise<void>;
  logout: () => void;
  isAuthenticated: boolean;
  isLoading: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [token, setToken] = useState<string | null>(localStorage.getItem('token'));
  const [isLoading, setIsLoading] = useState(true);

  // Load user on mount if token exists
  useEffect(() => {
    const loadUser = async () => {
      const storedToken = localStorage.getItem('token');
      if (storedToken) {
        try {
          apiClient.defaults.headers.common['Authorization'] = `Bearer ${storedToken}`;
          const response = await apiClient.get('/auth/me');
          setUser(response.data);
          setToken(storedToken);
        } catch (error) {
          console.error('Failed to load user:', error);
          localStorage.removeItem('token');
          delete apiClient.defaults.headers.common['Authorization'];
        }
      }
      setIsLoading(false);
    };

    loadUser();
  }, []);

  const login = async (email: string, password: string) => {
    const response = await apiClient.post('/auth/login/json', { email, password });
    const { access_token } = response.data;

    localStorage.setItem('token', access_token);
    apiClient.defaults.headers.common['Authorization'] = `Bearer ${access_token}`;
    setToken(access_token);

    // Fetch user info
    const userResponse = await apiClient.get('/auth/me');
    setUser(userResponse.data);
  };

  const register = async (email: string, password: string, firstName: string, lastName: string) => {
    await apiClient.post('/auth/register', {
      email,
      password,
      first_name: firstName,
      last_name: lastName,
    });

    // Auto-login after registration
    await login(email, password);
  };

  const logout = () => {
    localStorage.removeItem('token');
    delete apiClient.defaults.headers.common['Authorization'];
    setToken(null);
    setUser(null);
  };

  const value = {
    user,
    token,
    login,
    register,
    logout,
    isAuthenticated: !!user,
    isLoading,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
