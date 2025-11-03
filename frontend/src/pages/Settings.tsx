import React, { useState, useEffect } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '../services/api';
import Loading from '../components/Loading';
import ErrorMessage from '../components/ErrorMessage';
import { Briefcase, MapPin, DollarSign, Lock, Shield, Trash2, Download, Check } from 'lucide-react';

interface Language {
  language: string;
  proficiency: string;
}

interface LocationPreferences {
  remote: boolean;
  hybrid: boolean;
  onsite: boolean;
  cities: string[];
}

interface Profile {
  id?: number;
  user_id?: number;
  current_job_title?: string;
  target_job_title?: string;
  years_of_experience?: number;
  industries?: string[];
  skills?: string[];
  education_level?: string;
  certifications?: string[];
  languages?: Language[];
  work_authorization?: string;
  location_preferences?: LocationPreferences;
  salary_expectations_min?: number;
  salary_expectations_max?: number;
  current_salary?: number;
  preferred_interview_language?: string;
  ai_interview_prep_enabled?: boolean;
  profile_visibility?: string;
  data_processing_consent?: boolean;
  data_processing_consent_date?: string;
  created_at?: string;
  updated_at?: string;
}

type TabType = 'profile' | 'security' | 'privacy';

export default function Settings() {
  const queryClient = useQueryClient();
  const [activeTab, setActiveTab] = useState<TabType>('profile');
  const [formData, setFormData] = useState<Partial<Profile>>({});
  const [skillsInput, setSkillsInput] = useState('');
  const [industriesInput, setIndustriesInput] = useState('');
  const [citiesInput, setCitiesInput] = useState('');

  // Password change state
  const [passwordData, setPasswordData] = useState({
    current_password: '',
    new_password: '',
    confirm_password: ''
  });

  // Email change state
  const [emailData, setEmailData] = useState({
    new_email: '',
    password: ''
  });

  // Fetch profile
  const { data: profile, isLoading, error } = useQuery<Profile>({
    queryKey: ['profile'],
    queryFn: async () => {
      const response = await apiClient.get('/profile');
      return response.data;
    }
  });

  // Initialize form data when profile loads
  useEffect(() => {
    if (profile) {
      setFormData(profile);
      setSkillsInput(profile.skills?.join(', ') || '');
      setIndustriesInput(profile.industries?.join(', ') || '');
      setCitiesInput(profile.location_preferences?.cities?.join(', ') || '');
    }
  }, [profile]);

  // Update profile mutation
  const updateMutation = useMutation({
    mutationFn: async (data: Partial<Profile>) => {
      const response = await apiClient.patch('/profile', data);
      return response.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['profile'] });
      alert('Profile updated successfully!');
    },
    onError: (error: any) => {
      alert('Failed to update profile: ' + (error.response?.data?.detail || error.message));
    }
  });

  // Consent mutation
  const consentMutation = useMutation({
    mutationFn: async (consent: boolean) => {
      const response = await apiClient.post('/profile/consent', { consent });
      return response.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['profile'] });
      alert('Consent updated successfully!');
    }
  });

  // Export data mutation
  const exportMutation = useMutation({
    mutationFn: async () => {
      const response = await apiClient.post('/profile/export');
      return response.data;
    },
    onSuccess: (data) => {
      alert(data.message);
    }
  });

  // Delete account mutation
  const deleteMutation = useMutation({
    mutationFn: async () => {
      const response = await apiClient.delete('/profile');
      return response.data;
    },
    onSuccess: (data) => {
      alert(data.message);
    }
  });

  // Change password mutation
  const changePasswordMutation = useMutation({
    mutationFn: async (data: { current_password: string; new_password: string }) => {
      const response = await apiClient.post('/auth/change-password', data);
      return response.data;
    },
    onSuccess: () => {
      alert('Password updated successfully!');
      setPasswordData({ current_password: '', new_password: '', confirm_password: '' });
    },
    onError: (error: any) => {
      alert('Failed to update password: ' + (error.response?.data?.detail || error.message));
    }
  });

  // Change email mutation
  const changeEmailMutation = useMutation({
    mutationFn: async (data: { new_email: string; password: string }) => {
      const response = await apiClient.post('/auth/change-email', data);
      return response.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['profile'] });
      alert('Email updated successfully! Please log in again with your new email.');
      setEmailData({ new_email: '', password: '' });
    },
    onError: (error: any) => {
      alert('Failed to update email: ' + (error.response?.data?.detail || error.message));
    }
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    // Parse skills and industries from comma-separated strings
    const dataToSubmit: Partial<Profile> = {
      ...formData,
      skills: skillsInput ? skillsInput.split(',').map(s => s.trim()).filter(Boolean) : [],
      industries: industriesInput ? industriesInput.split(',').map(s => s.trim()).filter(Boolean) : [],
    };

    // Parse location preferences with cities
    if (formData.location_preferences) {
      dataToSubmit.location_preferences = {
        ...formData.location_preferences,
        cities: citiesInput ? citiesInput.split(',').map(s => s.trim()).filter(Boolean) : []
      };
    }

    updateMutation.mutate(dataToSubmit);
  };

  const handleDeleteAccount = () => {
    const confirmed = window.confirm(
      'Are you sure you want to delete your account? This action will be scheduled for 30 days from now. You can cancel it anytime before then.'
    );
    if (confirmed) {
      deleteMutation.mutate();
    }
  };

  const handlePasswordChange = (e: React.FormEvent) => {
    e.preventDefault();

    if (passwordData.new_password !== passwordData.confirm_password) {
      alert('New passwords do not match');
      return;
    }

    if (passwordData.new_password.length < 8) {
      alert('New password must be at least 8 characters');
      return;
    }

    changePasswordMutation.mutate({
      current_password: passwordData.current_password,
      new_password: passwordData.new_password
    });
  };

  const handleEmailChange = (e: React.FormEvent) => {
    e.preventDefault();

    changeEmailMutation.mutate({
      new_email: emailData.new_email,
      password: emailData.password
    });
  };

  if (isLoading) {
    return <Loading />;
  }

  if (error) {
    return <ErrorMessage message="Failed to load profile settings" />;
  }

  const inputClassName = "w-full border-2 border-sand/50 rounded-xl px-4 py-3 focus:outline-none focus:border-honey-500 focus:ring-2 focus:ring-honey-500/20 transition-all bg-ivory/30 font-medium text-navy-900 placeholder:text-anthracite/40";
  const labelClassName = "block text-sm font-semibold text-navy-900 mb-2";
  const cardClassName = "bg-white rounded-2xl border border-sand/30 p-8 hover:shadow-xl transition-all duration-300";

  return (
    <div className="max-w-7xl mx-auto">
      {/* Modern Header */}
      <div className="mb-10">
        <h1 className="text-5xl font-bold bg-gradient-to-r from-honey-600 via-honey-500 to-navy-900 bg-clip-text text-transparent mb-3">
          Settings
        </h1>
        <p className="text-anthracite/70 text-lg font-medium">
          Personalize your experience and manage your account
        </p>
      </div>

      {/* Modern Tab Navigation */}
      <div className="mb-10">
        <nav className="flex gap-4 bg-white rounded-2xl p-2 border border-sand/30 shadow-sm inline-flex">
          <button
            onClick={() => setActiveTab('profile')}
            className={`px-6 py-3 rounded-xl font-semibold transition-all duration-200 ${
              activeTab === 'profile'
                ? 'bg-gradient-to-r from-honey-500 to-honey-600 text-white shadow-lg shadow-honey-500/30'
                : 'text-anthracite/60 hover:text-navy-900 hover:bg-sand/30'
            }`}
          >
            <div className="flex items-center gap-2">
              <Briefcase className="w-4 h-4" />
              Profile
            </div>
          </button>
          <button
            onClick={() => setActiveTab('security')}
            className={`px-6 py-3 rounded-xl font-semibold transition-all duration-200 ${
              activeTab === 'security'
                ? 'bg-gradient-to-r from-honey-500 to-honey-600 text-white shadow-lg shadow-honey-500/30'
                : 'text-anthracite/60 hover:text-navy-900 hover:bg-sand/30'
            }`}
          >
            <div className="flex items-center gap-2">
              <Lock className="w-4 h-4" />
              Security
            </div>
          </button>
          <button
            onClick={() => setActiveTab('privacy')}
            className={`px-6 py-3 rounded-xl font-semibold transition-all duration-200 ${
              activeTab === 'privacy'
                ? 'bg-gradient-to-r from-honey-500 to-honey-600 text-white shadow-lg shadow-honey-500/30'
                : 'text-anthracite/60 hover:text-navy-900 hover:bg-sand/30'
            }`}
          >
            <div className="flex items-center gap-2">
              <Shield className="w-4 h-4" />
              Privacy
            </div>
          </button>
        </nav>
      </div>

      {/* Profile Tab */}
      {activeTab === 'profile' && (
        <form onSubmit={handleSubmit} className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Professional Info Card */}
            <div className={cardClassName}>
              <div className="flex items-center gap-3 mb-6">
                <div className="w-12 h-12 bg-gradient-to-br from-honey-400 to-honey-600 rounded-2xl flex items-center justify-center shadow-lg">
                  <Briefcase className="w-6 h-6 text-white" />
                </div>
                <div>
                  <h2 className="text-xl font-bold text-navy-900">Professional</h2>
                  <p className="text-sm text-anthracite/60">Your career details</p>
                </div>
              </div>

              <div className="space-y-5">
                <div>
                  <label className={labelClassName}>Current Job Title</label>
                  <input
                    type="text"
                    value={formData.current_job_title || ''}
                    onChange={(e) => setFormData({ ...formData, current_job_title: e.target.value })}
                    className={inputClassName}
                    placeholder="Senior Software Engineer"
                  />
                </div>

                <div>
                  <label className={labelClassName}>Target Job Title</label>
                  <input
                    type="text"
                    value={formData.target_job_title || ''}
                    onChange={(e) => setFormData({ ...formData, target_job_title: e.target.value })}
                    className={inputClassName}
                    placeholder="Engineering Manager"
                  />
                </div>

                <div>
                  <label className={labelClassName}>Years of Experience</label>
                  <select
                    value={formData.years_of_experience || ''}
                    onChange={(e) => setFormData({ ...formData, years_of_experience: parseInt(e.target.value) || undefined })}
                    className={inputClassName}
                  >
                    <option value="">Select...</option>
                    <option value="1">0-2 years</option>
                    <option value="4">3-5 years</option>
                    <option value="7">5-10 years</option>
                    <option value="12">10+ years</option>
                  </select>
                </div>

                <div>
                  <label className={labelClassName}>Education Level</label>
                  <select
                    value={formData.education_level || ''}
                    onChange={(e) => setFormData({ ...formData, education_level: e.target.value })}
                    className={inputClassName}
                  >
                    <option value="">Select...</option>
                    <option value="High School">High School</option>
                    <option value="Bachelor">Bachelor's Degree</option>
                    <option value="Master">Master's Degree</option>
                    <option value="PhD">PhD</option>
                    <option value="Bootcamp">Bootcamp</option>
                    <option value="Self-taught">Self-taught</option>
                  </select>
                </div>
              </div>
            </div>

            {/* Skills & Industries Card */}
            <div className={cardClassName}>
              <div className="flex items-center gap-3 mb-6">
                <div className="w-12 h-12 bg-gradient-to-br from-sky-400 to-sky-600 rounded-2xl flex items-center justify-center shadow-lg">
                  <svg className="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </div>
                <div>
                  <h2 className="text-xl font-bold text-navy-900">Skills</h2>
                  <p className="text-sm text-anthracite/60">Your expertise</p>
                </div>
              </div>

              <div className="space-y-5">
                <div>
                  <label className={labelClassName}>Skills</label>
                  <input
                    type="text"
                    value={skillsInput}
                    onChange={(e) => setSkillsInput(e.target.value)}
                    className={inputClassName}
                    placeholder="Python, React, SQL, AWS"
                  />
                  <p className="text-xs text-anthracite/50 mt-2">Separate with commas</p>
                </div>

                <div>
                  <label className={labelClassName}>Industries</label>
                  <input
                    type="text"
                    value={industriesInput}
                    onChange={(e) => setIndustriesInput(e.target.value)}
                    className={inputClassName}
                    placeholder="Technology, Finance, Healthcare"
                  />
                  <p className="text-xs text-anthracite/50 mt-2">Separate with commas</p>
                </div>
              </div>
            </div>
          </div>

          {/* Location Preferences Card */}
          <div className={cardClassName}>
            <div className="flex items-center gap-3 mb-6">
              <div className="w-12 h-12 bg-gradient-to-br from-emerald-400 to-emerald-600 rounded-2xl flex items-center justify-center shadow-lg">
                <MapPin className="w-6 h-6 text-white" />
              </div>
              <div>
                <h2 className="text-xl font-bold text-navy-900">Location Preferences</h2>
                <p className="text-sm text-anthracite/60">Where you want to work</p>
              </div>
            </div>

            <div className="space-y-5">
              <div className="flex gap-6">
                <label className="flex items-center gap-3 cursor-pointer group">
                  <div className="relative">
                    <input
                      type="checkbox"
                      checked={formData.location_preferences?.remote || false}
                      onChange={(e) => setFormData({
                        ...formData,
                        location_preferences: {
                          ...formData.location_preferences,
                          remote: e.target.checked,
                          hybrid: formData.location_preferences?.hybrid || false,
                          onsite: formData.location_preferences?.onsite || false,
                          cities: formData.location_preferences?.cities || []
                        }
                      })}
                      className="w-6 h-6 rounded-lg border-2 border-sand/50 checked:bg-honey-500 checked:border-honey-500 focus:ring-2 focus:ring-honey-500/20 transition-all"
                    />
                  </div>
                  <span className="text-sm font-semibold text-navy-900 group-hover:text-honey-600 transition-colors">Remote</span>
                </label>

                <label className="flex items-center gap-3 cursor-pointer group">
                  <div className="relative">
                    <input
                      type="checkbox"
                      checked={formData.location_preferences?.hybrid || false}
                      onChange={(e) => setFormData({
                        ...formData,
                        location_preferences: {
                          ...formData.location_preferences,
                          remote: formData.location_preferences?.remote || false,
                          hybrid: e.target.checked,
                          onsite: formData.location_preferences?.onsite || false,
                          cities: formData.location_preferences?.cities || []
                        }
                      })}
                      className="w-6 h-6 rounded-lg border-2 border-sand/50 checked:bg-honey-500 checked:border-honey-500 focus:ring-2 focus:ring-honey-500/20 transition-all"
                    />
                  </div>
                  <span className="text-sm font-semibold text-navy-900 group-hover:text-honey-600 transition-colors">Hybrid</span>
                </label>

                <label className="flex items-center gap-3 cursor-pointer group">
                  <div className="relative">
                    <input
                      type="checkbox"
                      checked={formData.location_preferences?.onsite || false}
                      onChange={(e) => setFormData({
                        ...formData,
                        location_preferences: {
                          ...formData.location_preferences,
                          remote: formData.location_preferences?.remote || false,
                          hybrid: formData.location_preferences?.hybrid || false,
                          onsite: e.target.checked,
                          cities: formData.location_preferences?.cities || []
                        }
                      })}
                      className="w-6 h-6 rounded-lg border-2 border-sand/50 checked:bg-honey-500 checked:border-honey-500 focus:ring-2 focus:ring-honey-500/20 transition-all"
                    />
                  </div>
                  <span className="text-sm font-semibold text-navy-900 group-hover:text-honey-600 transition-colors">On-site</span>
                </label>
              </div>

              <div>
                <label className={labelClassName}>Preferred Cities</label>
                <input
                  type="text"
                  value={citiesInput}
                  onChange={(e) => setCitiesInput(e.target.value)}
                  className={inputClassName}
                  placeholder="San Francisco, New York, Austin"
                />
                <p className="text-xs text-anthracite/50 mt-2">Separate with commas</p>
              </div>
            </div>
          </div>

          {/* Salary Information Card */}
          <div className={cardClassName}>
            <div className="flex items-center gap-3 mb-6">
              <div className="w-12 h-12 bg-gradient-to-br from-purple-400 to-purple-600 rounded-2xl flex items-center justify-center shadow-lg">
                <DollarSign className="w-6 h-6 text-white" />
              </div>
              <div>
                <h2 className="text-xl font-bold text-navy-900">Salary Expectations</h2>
                <p className="text-sm text-anthracite/60">Optional • Private information</p>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
              <div>
                <label className={labelClassName}>Minimum (USD)</label>
                <input
                  type="number"
                  value={formData.salary_expectations_min || ''}
                  onChange={(e) => setFormData({ ...formData, salary_expectations_min: parseInt(e.target.value) || undefined })}
                  className={inputClassName}
                  placeholder="120,000"
                  min="0"
                />
              </div>

              <div>
                <label className={labelClassName}>Maximum (USD)</label>
                <input
                  type="number"
                  value={formData.salary_expectations_max || ''}
                  onChange={(e) => setFormData({ ...formData, salary_expectations_max: parseInt(e.target.value) || undefined })}
                  className={inputClassName}
                  placeholder="150,000"
                  min="0"
                />
              </div>
            </div>
          </div>

          {/* Save Button */}
          <div className="flex justify-end pt-4">
            <button
              type="submit"
              disabled={updateMutation.isPending}
              className="px-8 py-4 bg-gradient-to-r from-honey-500 to-honey-600 text-white font-bold rounded-xl shadow-lg shadow-honey-500/30 hover:shadow-xl hover:shadow-honey-500/40 hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:scale-100 transition-all duration-200"
            >
              <div className="flex items-center gap-2">
                {updateMutation.isPending ? (
                  <>
                    <svg className="animate-spin h-5 w-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                    </svg>
                    Saving...
                  </>
                ) : (
                  <>
                    <Check className="w-5 h-5" />
                    Save Changes
                  </>
                )}
              </div>
            </button>
          </div>
        </form>
      )}

      {/* Security Tab */}
      {activeTab === 'security' && (
        <div className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Change Email Card */}
            <div className={cardClassName}>
              <div className="flex items-center gap-3 mb-6">
                <div className="w-12 h-12 bg-gradient-to-br from-blue-400 to-blue-600 rounded-2xl flex items-center justify-center shadow-lg">
                  <svg className="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 12a4 4 0 10-8 0 4 4 0 008 0zm0 0v1.5a2.5 2.5 0 005 0V12a9 9 0 10-9 9m4.5-1.206a8.959 8.959 0 01-4.5 1.207" />
                  </svg>
                </div>
                <div>
                  <h2 className="text-xl font-bold text-navy-900">Change Email</h2>
                  <p className="text-sm text-anthracite/60">Update your email address</p>
                </div>
              </div>

              <form onSubmit={handleEmailChange} className="space-y-5">
                <div>
                  <label className={labelClassName}>New Email Address</label>
                  <input
                    type="email"
                    value={emailData.new_email}
                    onChange={(e) => setEmailData({ ...emailData, new_email: e.target.value })}
                    className={inputClassName}
                    placeholder="your.new.email@example.com"
                    required
                  />
                </div>

                <div>
                  <label className={labelClassName}>Current Password</label>
                  <input
                    type="password"
                    value={emailData.password}
                    onChange={(e) => setEmailData({ ...emailData, password: e.target.value })}
                    className={inputClassName}
                    placeholder="For verification"
                    required
                  />
                </div>

                <button
                  type="submit"
                  disabled={changeEmailMutation.isPending}
                  className="w-full px-6 py-3 bg-gradient-to-r from-blue-500 to-blue-600 text-white font-bold rounded-xl shadow-lg shadow-blue-500/30 hover:shadow-xl hover:shadow-blue-500/40 hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:scale-100 transition-all duration-200"
                >
                  {changeEmailMutation.isPending ? 'Updating...' : 'Update Email'}
                </button>
              </form>
            </div>

            {/* Change Password Card */}
            <div className={cardClassName}>
              <div className="flex items-center gap-3 mb-6">
                <div className="w-12 h-12 bg-gradient-to-br from-red-400 to-red-600 rounded-2xl flex items-center justify-center shadow-lg">
                  <Lock className="w-6 h-6 text-white" />
                </div>
                <div>
                  <h2 className="text-xl font-bold text-navy-900">Change Password</h2>
                  <p className="text-sm text-anthracite/60">Update your password</p>
                </div>
              </div>

              <form onSubmit={handlePasswordChange} className="space-y-5">
                <div>
                  <label className={labelClassName}>Current Password</label>
                  <input
                    type="password"
                    value={passwordData.current_password}
                    onChange={(e) => setPasswordData({ ...passwordData, current_password: e.target.value })}
                    className={inputClassName}
                    placeholder="Enter current password"
                    required
                  />
                </div>

                <div>
                  <label className={labelClassName}>New Password</label>
                  <input
                    type="password"
                    value={passwordData.new_password}
                    onChange={(e) => setPasswordData({ ...passwordData, new_password: e.target.value })}
                    className={inputClassName}
                    placeholder="Min 8 characters"
                    minLength={8}
                    required
                  />
                </div>

                <div>
                  <label className={labelClassName}>Confirm New Password</label>
                  <input
                    type="password"
                    value={passwordData.confirm_password}
                    onChange={(e) => setPasswordData({ ...passwordData, confirm_password: e.target.value })}
                    className={inputClassName}
                    placeholder="Confirm new password"
                    minLength={8}
                    required
                  />
                </div>

                <button
                  type="submit"
                  disabled={changePasswordMutation.isPending}
                  className="w-full px-6 py-3 bg-gradient-to-r from-red-500 to-red-600 text-white font-bold rounded-xl shadow-lg shadow-red-500/30 hover:shadow-xl hover:shadow-red-500/40 hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:scale-100 transition-all duration-200"
                >
                  {changePasswordMutation.isPending ? 'Updating...' : 'Update Password'}
                </button>
              </form>
            </div>
          </div>
        </div>
      )}

      {/* Privacy Tab */}
      {activeTab === 'privacy' && (
        <div className="space-y-6">
          {/* GDPR Consent Card */}
          <div className={`${cardClassName} bg-gradient-to-br from-sky-50 to-blue-50 border-sky-200`}>
            <div className="flex items-center gap-3 mb-6">
              <div className="w-12 h-12 bg-gradient-to-br from-sky-400 to-sky-600 rounded-2xl flex items-center justify-center shadow-lg">
                <Shield className="w-6 h-6 text-white" />
              </div>
              <div>
                <h2 className="text-xl font-bold text-navy-900">AI Data Processing</h2>
                <p className="text-sm text-anthracite/60">GDPR Compliance</p>
              </div>
            </div>

            <div className="space-y-6">
              <p className="text-sm text-navy-900 leading-relaxed">
                To use AI-powered features (Interview Prep, Salary Negotiation), we need your explicit consent to process your profile data with AI services (OpenAI/Claude).
              </p>

              <label className="flex items-start gap-4 cursor-pointer group p-4 bg-white rounded-xl border-2 border-sky-200 hover:border-sky-400 transition-all">
                <input
                  type="checkbox"
                  checked={formData.data_processing_consent || false}
                  onChange={(e) => {
                    consentMutation.mutate(e.target.checked);
                    setFormData({ ...formData, data_processing_consent: e.target.checked });
                  }}
                  className="w-6 h-6 mt-0.5 rounded-lg border-2 border-sand/50 checked:bg-honey-500 checked:border-honey-500 focus:ring-2 focus:ring-honey-500/20 transition-all flex-shrink-0"
                />
                <span className="text-sm font-semibold text-navy-900 group-hover:text-honey-600 transition-colors">
                  I consent to AI processing of my profile data for interview preparation and career insights.
                </span>
              </label>

              {formData.data_processing_consent && formData.data_processing_consent_date && (
                <div className="flex items-center gap-2 text-xs text-anthracite/60 bg-white rounded-xl p-3 border border-sky-200">
                  <Check className="w-4 h-4 text-green-500" />
                  Consent given on: {new Date(formData.data_processing_consent_date).toLocaleDateString()}
                </div>
              )}

              <p className="text-xs text-anthracite/60 leading-relaxed">
                You can revoke this consent at any time. Your data will never be shared with third parties.
              </p>
            </div>
          </div>

          {/* Data Management Card */}
          <div className={cardClassName}>
            <div className="flex items-center gap-3 mb-6">
              <div className="w-12 h-12 bg-gradient-to-br from-indigo-400 to-indigo-600 rounded-2xl flex items-center justify-center shadow-lg">
                <Download className="w-6 h-6 text-white" />
              </div>
              <div>
                <h2 className="text-xl font-bold text-navy-900">Your Data</h2>
                <p className="text-sm text-anthracite/60">Export or delete your information</p>
              </div>
            </div>

            <div className="space-y-4">
              <button
                onClick={() => exportMutation.mutate()}
                disabled={exportMutation.isPending}
                className="w-full px-6 py-4 bg-white border-2 border-indigo-200 text-indigo-600 font-bold rounded-xl hover:bg-indigo-50 hover:border-indigo-400 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200 flex items-center justify-center gap-2"
              >
                <Download className="w-5 h-5" />
                {exportMutation.isPending ? 'Requesting...' : 'Export My Data'}
              </button>

              <button
                onClick={handleDeleteAccount}
                disabled={deleteMutation.isPending}
                className="w-full px-6 py-4 bg-white border-2 border-red-200 text-red-600 font-bold rounded-xl hover:bg-red-50 hover:border-red-400 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200 flex items-center justify-center gap-2"
              >
                <Trash2 className="w-5 h-5" />
                {deleteMutation.isPending ? 'Processing...' : 'Delete Account'}
              </button>

              <p className="text-xs text-anthracite/60 text-center pt-2">
                Account deletion is scheduled for 30 days. You can cancel anytime before then.
              </p>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
