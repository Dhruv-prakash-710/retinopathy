import { useState, useCallback } from 'react';
import { useAuth } from '../context/AuthContext';
import './Settings.css';

const IconUser = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
);
const IconLock = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
);
const IconBell = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg>
);
const IconGlobe = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><line x1="2" y1="12" x2="22" y2="12"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/></svg>
);
const IconDatabase = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M21 12c0 1.66-4 3-9 3s-9-1.34-9-3"/><path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5"/></svg>
);
const IconCheck = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
);

const DEFAULT_SETTINGS = {
  // Profile
  fullName: '',
  email: 'admin@retinavision.in',
  // Pipeline
  matlabUrl: 'http://localhost:9900/api/v1/predict',
  modelVersion: 'v2.4.1 (Stable - Clinical)',
  gradCamThreshold: 75,
  strictQualityCheck: true,
  // Notifications
  emailAlerts: true,
  dailySummary: true,
  downtimeAlerts: true,
  // Localization
  language: 'en',
  timezone: 'Asia/Kolkata',
  dateFormat: 'DD/MM/YYYY',
  distanceUnit: 'metric',
  // Security
  twoFactor: false,
  sessionTimeout: '30',
  ipWhitelist: '',
  auditLogging: true,
  encryptAtRest: true,
};

export default function Settings() {
  const { user } = useAuth();
  const [activeTab, setActiveTab] = useState('profile');
  const [toast, setToast] = useState(null);

  const getInitialSettings = useCallback(() => ({
    ...DEFAULT_SETTINGS,
    fullName: user?.name || '',
  }), [user]);

  const [settings, setSettings] = useState(getInitialSettings);
  const [savedSettings, setSavedSettings] = useState(getInitialSettings);

  const updateSetting = (key, value) => {
    setSettings(prev => ({ ...prev, [key]: value }));
  };

  const showToast = (message, type = 'success') => {
    setToast({ message, type });
    setTimeout(() => setToast(null), 3500);
  };

  const handleSave = (e) => {
    e.preventDefault();
    setSavedSettings({ ...settings });
    showToast('✓ Settings saved successfully.');
  };

  const handleCancel = () => {
    setSettings({ ...savedSettings });
    showToast('Changes discarded.', 'info');
  };

  if (user?.role !== 'admin') {
    return (
      <div className="settings-container animate-fade-in">
        <div className="card text-center p-8">
          <div style={{ display: 'flex', justifyContent: 'center', marginBottom: '1rem' }}>
            <div style={{ width: 48, height: 48, color: 'var(--color-text-dim)' }}><IconLock /></div>
          </div>
          <h2>Access Denied</h2>
          <p className="text-muted" style={{ marginTop: '0.5rem' }}>You do not have permission to view this page. System settings are restricted to administrators.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="settings-container animate-fade-in">
      {toast && (
        <div className={`toast toast-${toast.type}`}>
          <span>{toast.message}</span>
          <button className="toast-close" onClick={() => setToast(null)}>×</button>
        </div>
      )}

      <div className="page-header">
        <h1>System Settings</h1>
        <p className="text-muted text-sm">Manage application configuration and pipeline parameters.</p>
      </div>

      <div className="settings-layout">
        {/* Sidebar Nav */}
        <div className="settings-sidebar card">
          <nav className="settings-nav">
            <button className={`settings-nav-item ${activeTab === 'profile' ? 'active' : ''}`} onClick={() => setActiveTab('profile')}>
              <IconUser /> Profile & Account
            </button>
            <button className={`settings-nav-item ${activeTab === 'pipeline' ? 'active' : ''}`} onClick={() => setActiveTab('pipeline')}>
              <IconDatabase /> AI Pipeline Engine
            </button>
            <button className={`settings-nav-item ${activeTab === 'notifications' ? 'active' : ''}`} onClick={() => setActiveTab('notifications')}>
              <IconBell /> Notifications
            </button>
            <button className={`settings-nav-item ${activeTab === 'localization' ? 'active' : ''}`} onClick={() => setActiveTab('localization')}>
              <IconGlobe /> Localization
            </button>
            <button className={`settings-nav-item ${activeTab === 'security' ? 'active' : ''}`} onClick={() => setActiveTab('security')}>
              <IconLock /> Security
            </button>
          </nav>
        </div>

        {/* Content Area */}
        <div className="settings-content card">
          <form onSubmit={handleSave}>
            {activeTab === 'profile' && (
              <div className="settings-section animate-fade-in">
                <h3>Profile Settings</h3>
                <p className="text-dim text-sm mb-6">Update your account information.</p>
                
                <div className="form-group">
                  <label className="form-label">Full Name</label>
                  <input type="text" className="form-input" value={settings.fullName} onChange={e => updateSetting('fullName', e.target.value)} />
                </div>
                <div className="form-group">
                  <label className="form-label">Email Address</label>
                  <input type="email" className="form-input" value={settings.email} onChange={e => updateSetting('email', e.target.value)} />
                </div>
                <div className="form-group">
                  <label className="form-label">Role</label>
                  <input type="text" className="form-input" value="System Administrator" disabled />
                </div>
              </div>
            )}

            {activeTab === 'pipeline' && (
              <div className="settings-section animate-fade-in">
                <h3>AI Pipeline Engine</h3>
                <p className="text-dim text-sm mb-6">Configure MATLAB backend connection and model parameters.</p>

                <div className="form-group">
                  <label className="form-label">MATLAB Server URL</label>
                  <input type="text" className="form-input" value={settings.matlabUrl} onChange={e => updateSetting('matlabUrl', e.target.value)} />
                </div>
                <div className="form-group">
                  <label className="form-label">Model Version</label>
                  <select className="form-input" value={settings.modelVersion} onChange={e => updateSetting('modelVersion', e.target.value)}>
                    <option>v2.4.1 (Stable - Clinical)</option>
                    <option>v2.5.0-beta (Experimental)</option>
                    <option>v1.9.0 (Legacy)</option>
                  </select>
                </div>
                
                <div className="form-group">
                  <label className="form-label">Grad-CAM Sensitivity Threshold</label>
                  <div className="flex items-center gap-4">
                    <input type="range" min="0" max="100" value={settings.gradCamThreshold} onChange={e => updateSetting('gradCamThreshold', Number(e.target.value))} className="range-slider" />
                    <span className="text-muted text-sm w-12 text-right">{(settings.gradCamThreshold / 100).toFixed(2)}</span>
                  </div>
                </div>

                <div className="form-toggle">
                  <div>
                    <label className="form-label mb-1">Strict Image Quality Check</label>
                    <div className="text-dim text-xs">Reject scans automatically if focus score is below 0.6</div>
                  </div>
                  <label className="toggle-switch">
                    <input type="checkbox" checked={settings.strictQualityCheck} onChange={e => updateSetting('strictQualityCheck', e.target.checked)} />
                    <span className="toggle-slider"></span>
                  </label>
                </div>
              </div>
            )}

            {activeTab === 'notifications' && (
              <div className="settings-section animate-fade-in">
                <h3>Notification Preferences</h3>
                <p className="text-dim text-sm mb-6">Manage how you receive alerts.</p>
                
                <div className="form-toggle">
                  <div>
                    <label className="form-label mb-1">Email Alerts for Referable Cases</label>
                    <div className="text-dim text-xs">Receive an email immediately when a Level 3 or 4 DR case is detected.</div>
                  </div>
                  <label className="toggle-switch">
                    <input type="checkbox" checked={settings.emailAlerts} onChange={e => updateSetting('emailAlerts', e.target.checked)} />
                    <span className="toggle-slider"></span>
                  </label>
                </div>

                <div className="form-toggle">
                  <div>
                    <label className="form-label mb-1">Daily Summary Report</label>
                    <div className="text-dim text-xs">Receive a summary of all screenings processed across all PHCs.</div>
                  </div>
                  <label className="toggle-switch">
                    <input type="checkbox" checked={settings.dailySummary} onChange={e => updateSetting('dailySummary', e.target.checked)} />
                    <span className="toggle-slider"></span>
                  </label>
                </div>
                
                <div className="form-toggle">
                  <div>
                    <label className="form-label mb-1">System Downtime Alerts</label>
                    <div className="text-dim text-xs">Get notified if the MATLAB engine becomes unreachable.</div>
                  </div>
                  <label className="toggle-switch">
                    <input type="checkbox" checked={settings.downtimeAlerts} onChange={e => updateSetting('downtimeAlerts', e.target.checked)} />
                    <span className="toggle-slider"></span>
                  </label>
                </div>
              </div>
            )}

            {activeTab === 'localization' && (
              <div className="settings-section animate-fade-in">
                <h3>Localization</h3>
                <p className="text-dim text-sm mb-6">Configure regional and language preferences.</p>

                <div className="form-group">
                  <label className="form-label">Interface Language</label>
                  <select className="form-input" value={settings.language} onChange={e => updateSetting('language', e.target.value)}>
                    <option value="en">English</option>
                    <option value="hi">हिन्दी (Hindi)</option>
                    <option value="ta">தமிழ் (Tamil)</option>
                    <option value="te">తెలుగు (Telugu)</option>
                    <option value="bn">বাংলা (Bengali)</option>
                    <option value="mr">मराठी (Marathi)</option>
                  </select>
                </div>

                <div className="form-group">
                  <label className="form-label">Timezone</label>
                  <select className="form-input" value={settings.timezone} onChange={e => updateSetting('timezone', e.target.value)}>
                    <option value="Asia/Kolkata">Asia/Kolkata (IST, UTC+5:30)</option>
                    <option value="Asia/Dhaka">Asia/Dhaka (BST, UTC+6:00)</option>
                    <option value="Asia/Colombo">Asia/Colombo (SLST, UTC+5:30)</option>
                    <option value="UTC">UTC (UTC+0:00)</option>
                  </select>
                </div>

                <div className="form-group">
                  <label className="form-label">Date Format</label>
                  <select className="form-input" value={settings.dateFormat} onChange={e => updateSetting('dateFormat', e.target.value)}>
                    <option value="DD/MM/YYYY">DD/MM/YYYY (31/08/2026)</option>
                    <option value="MM/DD/YYYY">MM/DD/YYYY (08/31/2026)</option>
                    <option value="YYYY-MM-DD">YYYY-MM-DD (2026-08-31)</option>
                    <option value="DD-MMM-YYYY">DD-MMM-YYYY (31-Aug-2026)</option>
                  </select>
                </div>

                <div className="form-toggle">
                  <div>
                    <label className="form-label mb-1">Measurement System</label>
                    <div className="text-dim text-xs">Units used for clinical measurements and distances.</div>
                  </div>
                  <div className="flex gap-2">
                    <button type="button" className={`filter-pill ${settings.distanceUnit === 'metric' ? 'active' : ''}`} onClick={() => updateSetting('distanceUnit', 'metric')}>Metric</button>
                    <button type="button" className={`filter-pill ${settings.distanceUnit === 'imperial' ? 'active' : ''}`} onClick={() => updateSetting('distanceUnit', 'imperial')}>Imperial</button>
                  </div>
                </div>
              </div>
            )}

            {activeTab === 'security' && (
              <div className="settings-section animate-fade-in">
                <h3>Security</h3>
                <p className="text-dim text-sm mb-6">Manage authentication, access control, and audit policies.</p>

                <div className="form-toggle">
                  <div>
                    <label className="form-label mb-1">Two-Factor Authentication</label>
                    <div className="text-dim text-xs">Require a TOTP code in addition to the password on every login.</div>
                  </div>
                  <label className="toggle-switch">
                    <input type="checkbox" checked={settings.twoFactor} onChange={e => updateSetting('twoFactor', e.target.checked)} />
                    <span className="toggle-slider"></span>
                  </label>
                </div>

                <div className="form-group" style={{ marginTop: '1rem' }}>
                  <label className="form-label">Session Timeout (minutes)</label>
                  <select className="form-input" value={settings.sessionTimeout} onChange={e => updateSetting('sessionTimeout', e.target.value)}>
                    <option value="15">15 minutes</option>
                    <option value="30">30 minutes</option>
                    <option value="60">1 hour</option>
                    <option value="120">2 hours</option>
                    <option value="480">8 hours (shift)</option>
                  </select>
                </div>

                <div className="form-group">
                  <label className="form-label">IP Whitelist</label>
                  <input type="text" className="form-input" placeholder="e.g. 192.168.1.0/24, 10.0.0.0/8" value={settings.ipWhitelist} onChange={e => updateSetting('ipWhitelist', e.target.value)} />
                  <div className="text-dim text-xs" style={{ marginTop: '0.375rem' }}>Comma-separated CIDR ranges. Leave empty to allow all IPs.</div>
                </div>

                <div className="form-toggle">
                  <div>
                    <label className="form-label mb-1">Audit Logging</label>
                    <div className="text-dim text-xs">Record all user actions (logins, setting changes, approvals) to an immutable audit log.</div>
                  </div>
                  <label className="toggle-switch">
                    <input type="checkbox" checked={settings.auditLogging} onChange={e => updateSetting('auditLogging', e.target.checked)} />
                    <span className="toggle-slider"></span>
                  </label>
                </div>

                <div className="form-toggle">
                  <div>
                    <label className="form-label mb-1">Encrypt Data at Rest</label>
                    <div className="text-dim text-xs">AES-256 encryption for all stored patient images and clinical reports.</div>
                  </div>
                  <label className="toggle-switch">
                    <input type="checkbox" checked={settings.encryptAtRest} onChange={e => updateSetting('encryptAtRest', e.target.checked)} />
                    <span className="toggle-slider"></span>
                  </label>
                </div>
              </div>
            )}

            <div className="settings-footer">
              <button type="button" className="btn btn-secondary btn-sm" onClick={handleCancel}>Cancel</button>
              <button type="submit" className="btn btn-primary btn-sm"><IconCheck /> Save Changes</button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
}

