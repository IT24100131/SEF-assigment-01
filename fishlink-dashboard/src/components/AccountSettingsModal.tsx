import React, { useState, useEffect } from 'react';
import { User, Shield, Key, Mail, CheckCircle, AlertCircle, X, Save, RefreshCw, Eye, EyeOff, Calendar, Trash2, AlertTriangle } from 'lucide-react';
import axios from 'axios';
import { API_BASE_URL, formatErrorMessage } from '../config/api';

interface UserProfile {
  id: number;
  fullName: string;
  email: string;
  role: string;
  createdAt: string;
}

interface AccountSettingsModalProps {
  onClose: () => void;
  onUserUpdated?: (user: UserProfile) => void;
}

export const AccountSettingsModal: React.FC<AccountSettingsModalProps> = ({ onClose, onUserUpdated }) => {
  const [activeTab, setActiveTab] = useState<'profile' | 'security' | 'danger'>('profile');
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  // Form states
  const [fullName, setFullName] = useState('');
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showCurrentPass, setShowCurrentPass] = useState(false);
  const [showNewPass, setShowNewPass] = useState(false);

  // Delete account confirmation
  const [deleteConfirmation, setDeleteConfirmation] = useState('');

  const getAuthHeader = () => ({
    headers: { Authorization: `Bearer ${localStorage.getItem('token')}` }
  });

  useEffect(() => {
    const fetchUser = async () => {
      setLoading(true);
      setError('');
      try {
        const res = await axios.get<UserProfile>(`${API_BASE_URL}/api/Users/me`, getAuthHeader());
        setProfile(res.data);
        setFullName(res.data.fullName);
      } catch (err: any) {
        // Fallback to token payload if endpoint fails
        try {
          const token = localStorage.getItem('token') ?? '';
          if (token) {
            const payload = JSON.parse(atob(token.split('.')[1]));
            const fallbackUser: UserProfile = {
              id: Number(payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'] ?? payload['nameid'] ?? 0),
              fullName: payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name'] ?? `${payload['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'] || 'User'}`,
              email: payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress'] ?? 'user@fishlink.com',
              role: payload['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'] ?? localStorage.getItem('role') ?? 'User',
              createdAt: new Date().toISOString()
            };
            setProfile(fallbackUser);
            setFullName(fallbackUser.fullName);
          }
        } catch {
          setError(formatErrorMessage(err, 'Failed to load user profile.'));
        }
      } finally {
        setLoading(false);
      }
    };

    fetchUser();
  }, []);

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setSuccess('');

    if (activeTab === 'security' && newPassword) {
      if (newPassword.length < 6) {
        setError('New password must be at least 6 characters long.');
        return;
      }
      if (newPassword !== confirmPassword) {
        setError('New passwords do not match.');
        return;
      }
      if (!currentPassword) {
        setError('Please enter your current password to set a new password.');
        return;
      }
    }

    setSaving(true);
    try {
      const payload: { fullName: string; currentPassword?: string; newPassword?: string } = {
        fullName: fullName.trim()
      };

      if (newPassword) {
        payload.currentPassword = currentPassword;
        payload.newPassword = newPassword;
      }

      const res = await axios.put(`${API_BASE_URL}/api/Users/profile`, payload, getAuthHeader());
      const updatedUser = res.data?.user || { ...profile, fullName };
      setProfile(updatedUser);
      setSuccess('Account settings updated successfully!');
      setCurrentPassword('');
      setNewPassword('');
      setConfirmPassword('');
      if (onUserUpdated) onUserUpdated(updatedUser);
      setTimeout(() => {
        setSuccess('');
      }, 3500);
    } catch (err: any) {
      setError(formatErrorMessage(err, 'Failed to update account settings.'));
    } finally {
      setSaving(false);
    }
  };

  const handleDeleteAccount = async () => {
    if (deleteConfirmation.trim().toUpperCase() !== 'DELETE') {
      setError('Please type DELETE in the box below to confirm account deletion.');
      return;
    }

    if (!window.confirm('Are you ABSOLUTELY SURE you want to delete your account? This action cannot be undone.')) {
      return;
    }

    setDeleting(true);
    setError('');
    try {
      await axios.delete(`${API_BASE_URL}/api/Users/me`, getAuthHeader());
      alert('Your account has been deleted successfully.');
      localStorage.removeItem('token');
      localStorage.removeItem('role');
      window.location.href = '/';
    } catch (err: any) {
      setError(formatErrorMessage(err, 'Failed to delete account.'));
      setDeleting(false);
    }
  };

  const getRoleBadgeStyle = (r: string) => {
    switch (r) {
      case 'Fisherman': return { bg: '#e0f2fe', color: '#0369a1', border: '#7dd3fc' };
      case 'Buyer': return { bg: '#ede9fe', color: '#6d28d9', border: '#c4b5fd' };
      case 'Admin': return { bg: '#fef3c7', color: '#b45309', border: '#fcd34d' };
      case 'Logistics': return { bg: '#dcfce7', color: '#15803d', border: '#86efac' };
      default: return { bg: '#f1f5f9', color: '#475569', border: '#cbd5e1' };
    }
  };

  const badgeStyle = getRoleBadgeStyle(profile?.role || '');

  return (
    <div style={{
      position: 'fixed',
      inset: 0,
      backgroundColor: 'rgba(15, 23, 42, 0.65)',
      backdropFilter: 'blur(3px)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      zIndex: 1000,
      padding: '20px'
    }}>
      <div style={{
        background: '#ffffff',
        borderRadius: '16px',
        width: '100%',
        maxWidth: '580px',
        boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.25)',
        overflow: 'hidden',
        display: 'flex',
        flexDirection: 'column',
        maxHeight: '90vh'
      }}>
        {/* Header */}
        <div style={{
          background: activeTab === 'danger'
            ? 'linear-gradient(135deg, #991b1b 0%, #b91c1c 100%)'
            : 'linear-gradient(135deg, #03396c 0%, #005b96 100%)',
          color: 'white',
          padding: '24px 28px',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          transition: 'background 0.3s'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
            <div style={{
              width: '52px',
              height: '52px',
              borderRadius: '50%',
              background: 'rgba(255, 255, 255, 0.2)',
              border: '2px solid rgba(255, 255, 255, 0.4)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: '1.4rem',
              fontWeight: 700
            }}>
              {activeTab === 'danger'
                ? <AlertTriangle size={26} color="#ffffff" />
                : (profile?.fullName ? profile.fullName.charAt(0).toUpperCase() : <User size={24} />)}
            </div>
            <div>
              <h3 style={{ margin: 0, fontSize: '1.25rem', fontWeight: 700, color: 'white' }}>
                {activeTab === 'danger' ? 'Delete Account' : 'Account Settings'}
              </h3>
              <p style={{ margin: '4px 0 0', fontSize: '0.85rem', opacity: 0.85 }}>
                {activeTab === 'danger' ? 'Irreversible permanent account removal' : 'Manage your profile and security credentials'}
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            style={{
              background: 'rgba(255, 255, 255, 0.15)',
              border: 'none',
              borderRadius: '50%',
              width: '36px',
              height: '36px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: 'white',
              cursor: 'pointer',
              transition: 'background 0.2s'
            }}
          >
            <X size={20} />
          </button>
        </div>

        {/* Tab Navigation */}
        <div style={{
          display: 'flex',
          borderBottom: '1px solid #e2e8f0',
          background: '#f8fafc',
          padding: '0 24px',
          gap: '4px'
        }}>
          <button
            type="button"
            onClick={() => { setActiveTab('profile'); setError(''); setSuccess(''); }}
            style={{
              padding: '14px 16px',
              background: 'none',
              border: 'none',
              borderBottom: activeTab === 'profile' ? '3px solid #005b96' : '3px solid transparent',
              color: activeTab === 'profile' ? '#005b96' : '#64748b',
              fontWeight: activeTab === 'profile' ? 700 : 500,
              fontSize: '0.9rem',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '8px'
            }}
          >
            <User size={16} /> Profile
          </button>
          <button
            type="button"
            onClick={() => { setActiveTab('security'); setError(''); setSuccess(''); }}
            style={{
              padding: '14px 16px',
              background: 'none',
              border: 'none',
              borderBottom: activeTab === 'security' ? '3px solid #005b96' : '3px solid transparent',
              color: activeTab === 'security' ? '#005b96' : '#64748b',
              fontWeight: activeTab === 'security' ? 700 : 500,
              fontSize: '0.9rem',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '8px'
            }}
          >
            <Key size={16} /> Password
          </button>
          <button
            type="button"
            onClick={() => { setActiveTab('danger'); setError(''); setSuccess(''); }}
            style={{
              padding: '14px 16px',
              background: 'none',
              border: 'none',
              borderBottom: activeTab === 'danger' ? '3px solid #dc2626' : '3px solid transparent',
              color: activeTab === 'danger' ? '#dc2626' : '#94a3b8',
              fontWeight: activeTab === 'danger' ? 700 : 500,
              fontSize: '0.9rem',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
              marginLeft: 'auto'
            }}
          >
            <Trash2 size={16} /> Delete Account
          </button>
        </div>

        {/* Body Form */}
        <div style={{ padding: '24px 28px', overflowY: 'auto', flex: 1 }}>
          {loading ? (
            <div style={{ textAlign: 'center', padding: '40px', color: '#64748b' }}>
              <RefreshCw size={28} style={{ animation: 'spin 1s linear infinite', marginBottom: '12px' }} />
              <p style={{ margin: 0 }}>Loading your account details...</p>
            </div>
          ) : (
            <>
              {/* Feedback Banners */}
              {error && (
                <div style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '10px',
                  background: '#fee2e2',
                  border: '1px solid #fca5a5',
                  borderRadius: '8px',
                  padding: '12px 16px',
                  marginBottom: '18px'
                }}>
                  <AlertCircle color="#ef4444" size={18} style={{ flexShrink: 0 }} />
                  <p style={{ margin: 0, color: '#991b1b', fontSize: '0.88rem' }}>{error}</p>
                </div>
              )}

              {success && (
                <div style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '10px',
                  background: '#ecfdf5',
                  border: '1px solid #6ee7b7',
                  borderRadius: '8px',
                  padding: '12px 16px',
                  marginBottom: '18px'
                }}>
                  <CheckCircle color="#10b981" size={18} style={{ flexShrink: 0 }} />
                  <p style={{ margin: 0, color: '#065f46', fontSize: '0.88rem', fontWeight: 600 }}>{success}</p>
                </div>
              )}

              {/* Tab 1: Profile Info */}
              {activeTab === 'profile' && (
                <form onSubmit={handleSave} id="accountSettingsForm" style={{ display: 'flex', flexDirection: 'column', gap: '18px' }}>
                  {/* Account overview card */}
                  <div style={{
                    background: '#f8fafc',
                    border: '1px solid #e2e8f0',
                    borderRadius: '10px',
                    padding: '16px',
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'center'
                  }}>
                    <div>
                      <p style={{ margin: 0, fontSize: '0.8rem', color: '#64748b' }}>Account Role & Status</p>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginTop: '4px' }}>
                        <span style={{
                          padding: '3px 10px',
                          borderRadius: '12px',
                          fontSize: '0.8rem',
                          fontWeight: 700,
                          background: badgeStyle.bg,
                          color: badgeStyle.color,
                          border: `1px solid ${badgeStyle.border}`
                        }}>
                          {profile?.role}
                        </span>
                        <span style={{ fontSize: '0.8rem', color: '#059669', display: 'flex', alignItems: 'center', gap: '4px', fontWeight: 600 }}>
                          <CheckCircle size={14} /> Active
                        </span>
                      </div>
                    </div>
                    {profile?.createdAt && (
                      <div style={{ textAlign: 'right' }}>
                        <p style={{ margin: 0, fontSize: '0.78rem', color: '#64748b', display: 'flex', alignItems: 'center', gap: '4px' }}>
                          <Calendar size={13} /> Joined
                        </p>
                        <p style={{ margin: '2px 0 0', fontSize: '0.82rem', fontWeight: 600, color: '#334155' }}>
                          {new Date(profile.createdAt).toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' })}
                        </p>
                      </div>
                    )}
                  </div>

                  {/* Full Name */}
                  <div className="form-group">
                    <label style={{ fontSize: '0.88rem', fontWeight: 600, color: '#334155', marginBottom: '6px' }}>
                      Full Name
                    </label>
                    <input
                      type="text"
                      required
                      value={fullName}
                      onChange={e => setFullName(e.target.value)}
                      placeholder="Your full name"
                      style={{
                        padding: '11px 14px',
                        border: '1px solid #cbd5e1',
                        borderRadius: '8px',
                        fontSize: '0.95rem'
                      }}
                    />
                  </div>

                  {/* Email (Read Only) */}
                  <div className="form-group">
                    <label style={{ fontSize: '0.88rem', fontWeight: 600, color: '#334155', marginBottom: '6px', display: 'flex', justifyContent: 'space-between' }}>
                      <span>Email Address</span>
                      <span style={{ fontSize: '0.75rem', color: '#64748b' }}>Primary identifier</span>
                    </label>
                    <div style={{ position: 'relative' }}>
                      <input
                        type="email"
                        disabled
                        value={profile?.email || ''}
                        style={{
                          padding: '11px 14px 11px 36px',
                          border: '1px solid #e2e8f0',
                          borderRadius: '8px',
                          background: '#f1f5f9',
                          color: '#475569',
                          fontSize: '0.95rem',
                          width: '100%',
                          boxSizing: 'border-box',
                          cursor: 'not-allowed'
                        }}
                      />
                      <Mail size={16} style={{ position: 'absolute', left: '12px', top: '14px', color: '#94a3b8' }} />
                    </div>
                  </div>
                </form>
              )}

              {/* Tab 2: Security & Password */}
              {activeTab === 'security' && (
                <form onSubmit={handleSave} id="accountSettingsForm" style={{ display: 'flex', flexDirection: 'column', gap: '18px' }}>
                  <div style={{
                    background: '#eff6ff',
                    border: '1px solid #bfdbfe',
                    borderRadius: '8px',
                    padding: '12px 16px',
                    fontSize: '0.85rem',
                    color: '#1e40af',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '10px'
                  }}>
                    <Shield size={18} style={{ flexShrink: 0 }} />
                    <span>To change your password, provide your current password followed by your new password.</span>
                  </div>

                  {/* Current Password */}
                  <div className="form-group">
                    <label style={{ fontSize: '0.88rem', fontWeight: 600, color: '#334155', marginBottom: '6px' }}>
                      Current Password
                    </label>
                    <div style={{ position: 'relative' }}>
                      <input
                        type={showCurrentPass ? 'text' : 'password'}
                        value={currentPassword}
                        onChange={e => setCurrentPassword(e.target.value)}
                        placeholder="Enter current password"
                        style={{
                          padding: '11px 40px 11px 14px',
                          border: '1px solid #cbd5e1',
                          borderRadius: '8px',
                          fontSize: '0.95rem',
                          width: '100%',
                          boxSizing: 'border-box'
                        }}
                      />
                      <button
                        type="button"
                        onClick={() => setShowCurrentPass(!showCurrentPass)}
                        style={{
                          position: 'absolute',
                          right: '12px',
                          top: '12px',
                          background: 'none',
                          border: 'none',
                          cursor: 'pointer',
                          color: '#94a3b8'
                        }}
                      >
                        {showCurrentPass ? <EyeOff size={18} /> : <Eye size={18} />}
                      </button>
                    </div>
                  </div>

                  {/* New Password */}
                  <div className="form-group">
                    <label style={{ fontSize: '0.88rem', fontWeight: 600, color: '#334155', marginBottom: '6px' }}>
                      New Password
                    </label>
                    <div style={{ position: 'relative' }}>
                      <input
                        type={showNewPass ? 'text' : 'password'}
                        value={newPassword}
                        onChange={e => setNewPassword(e.target.value)}
                        placeholder="At least 6 characters"
                        style={{
                          padding: '11px 40px 11px 14px',
                          border: '1px solid #cbd5e1',
                          borderRadius: '8px',
                          fontSize: '0.95rem',
                          width: '100%',
                          boxSizing: 'border-box'
                        }}
                      />
                      <button
                        type="button"
                        onClick={() => setShowNewPass(!showNewPass)}
                        style={{
                          position: 'absolute',
                          right: '12px',
                          top: '12px',
                          background: 'none',
                          border: 'none',
                          cursor: 'pointer',
                          color: '#94a3b8'
                        }}
                      >
                        {showNewPass ? <EyeOff size={18} /> : <Eye size={18} />}
                      </button>
                    </div>
                  </div>

                  {/* Confirm New Password */}
                  <div className="form-group">
                    <label style={{ fontSize: '0.88rem', fontWeight: 600, color: '#334155', marginBottom: '6px' }}>
                      Confirm New Password
                    </label>
                    <input
                      type="password"
                      value={confirmPassword}
                      onChange={e => setConfirmPassword(e.target.value)}
                      placeholder="Re-type new password"
                      style={{
                        padding: '11px 14px',
                        border: '1px solid #cbd5e1',
                        borderRadius: '8px',
                        fontSize: '0.95rem'
                      }}
                    />
                  </div>
                </form>
              )}

              {/* Tab 3: Danger Zone / Delete Account */}
              {activeTab === 'danger' && (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
                  <div style={{
                    background: '#fef2f2',
                    border: '1px solid #fecaca',
                    borderRadius: '12px',
                    padding: '20px',
                    display: 'flex',
                    flexDirection: 'column',
                    gap: '12px'
                  }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '10px', color: '#991b1b' }}>
                      <AlertTriangle size={24} style={{ flexShrink: 0 }} />
                      <h4 style={{ margin: 0, fontSize: '1rem', fontWeight: 700 }}>
                        Warning: Permanent Action
                      </h4>
                    </div>
                    <p style={{ margin: 0, fontSize: '0.88rem', color: '#7f1d1d', lineHeight: 1.5 }}>
                      Deleting your account will permanently delete all your data from <strong>FishLink AI</strong>, including:
                    </p>
                    <ul style={{ margin: '0 0 0 20px', padding: 0, fontSize: '0.84rem', color: '#991b1b', lineHeight: 1.6 }}>
                      <li>All your registered fish catch listings</li>
                      <li>Any active bids or marketplace orders</li>
                      <li>Saved buyer preferences and history</li>
                      <li>Your login credentials and account profile</li>
                    </ul>
                    <p style={{ margin: 0, fontSize: '0.84rem', color: '#b91c1c', fontWeight: 600 }}>
                      This action CANNOT be undone.
                    </p>
                  </div>

                  <div style={{
                    background: '#ffffff',
                    border: '1px solid #e2e8f0',
                    borderRadius: '10px',
                    padding: '18px'
                  }}>
                    <label style={{ display: 'block', fontSize: '0.88rem', fontWeight: 600, color: '#334155', marginBottom: '8px' }}>
                      To confirm deletion, please type <span style={{ color: '#dc2626', fontWeight: 700 }}>DELETE</span> below:
                    </label>
                    <input
                      type="text"
                      value={deleteConfirmation}
                      onChange={e => { setDeleteConfirmation(e.target.value); setError(''); }}
                      placeholder="Type DELETE"
                      style={{
                        padding: '11px 14px',
                        border: '2px solid #cbd5e1',
                        borderRadius: '8px',
                        fontSize: '0.95rem',
                        width: '100%',
                        boxSizing: 'border-box',
                        letterSpacing: '1px',
                        fontWeight: 600,
                        textTransform: 'uppercase'
                      }}
                    />

                    <div style={{ marginTop: '16px' }}>
                      <button
                        type="button"
                        onClick={handleDeleteAccount}
                        disabled={deleting || deleteConfirmation.trim().toUpperCase() !== 'DELETE'}
                        style={{
                          width: '100%',
                          padding: '12px 20px',
                          background: deleteConfirmation.trim().toUpperCase() === 'DELETE' ? '#dc2626' : '#f87171',
                          color: 'white',
                          border: 'none',
                          borderRadius: '8px',
                          fontSize: '0.92rem',
                          fontWeight: 700,
                          cursor: deleteConfirmation.trim().toUpperCase() === 'DELETE' ? 'pointer' : 'not-allowed',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          gap: '10px',
                          transition: 'background 0.2s',
                          opacity: deleting ? 0.7 : 1
                        }}
                      >
                        {deleting ? (
                          <>
                            <RefreshCw size={18} style={{ animation: 'spin 1s linear infinite' }} />
                            Deleting Account...
                          </>
                        ) : (
                          <>
                            <Trash2 size={18} /> Permanently Delete My Account
                          </>
                        )}
                      </button>
                    </div>
                  </div>
                </div>
              )}
            </>
          )}
        </div>

        {/* Footer Actions (Only for Profile and Security tabs) */}
        {activeTab !== 'danger' && (
          <div style={{
            padding: '16px 28px',
            background: '#f8fafc',
            borderTop: '1px solid #e2e8f0',
            display: 'flex',
            justifyContent: 'flex-end',
            gap: '12px'
          }}>
            <button
              type="button"
              className="btn-outline"
              onClick={onClose}
              style={{ padding: '10px 18px', fontSize: '0.9rem', borderRadius: '8px' }}
            >
              Cancel
            </button>
            <button
              type="submit"
              form="accountSettingsForm"
              disabled={saving || loading}
              className="btn-primary"
              style={{
                padding: '10px 22px',
                fontSize: '0.9rem',
                borderRadius: '8px',
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                marginTop: 0,
                opacity: saving ? 0.7 : 1
              }}
            >
              {saving ? (
                <>
                  <RefreshCw size={16} style={{ animation: 'spin 1s linear infinite' }} />
                  Saving...
                </>
              ) : (
                <>
                  <Save size={16} /> Save Changes
                </>
              )}
            </button>
          </div>
        )}
      </div>
    </div>
  );
};
