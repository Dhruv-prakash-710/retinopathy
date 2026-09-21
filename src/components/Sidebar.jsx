import { useLocation, Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useTranslation } from 'react-i18next';
import './Sidebar.css';
/* ── SVG Icons ── */
const IconEye = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/></svg>
);
const IconDashboard = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="3" width="7" height="9" rx="1"/><rect x="14" y="3" width="7" height="5" rx="1"/><rect x="14" y="12" width="7" height="9" rx="1"/><rect x="3" y="16" width="7" height="5" rx="1"/></svg>
);
const IconScan = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M3 7V5a2 2 0 0 1 2-2h2"/><path d="M17 3h2a2 2 0 0 1 2 2v2"/><path d="M21 17v2a2 2 0 0 1-2 2h-2"/><path d="M7 21H5a2 2 0 0 1-2-2v-2"/><circle cx="12" cy="12" r="4"/></svg>
);
const IconUsers = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
);
const IconSettings = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/><circle cx="12" cy="12" r="3"/></svg>
);
const IconLogout = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>
);
const IconSimulink = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>
);
const IconValidation = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
);
const ROLE_LABELS = {
  admin: 'Administrator',
  ophthalmologist: 'Ophthalmologist',
  phc_operator: 'PHC Operator',
};

export default function Sidebar({ isOpen }) {
  const location = useLocation();
  const navigate = useNavigate();
  const { user, logout } = useAuth();
  const { t } = useTranslation();
  const pathname = location.pathname;

  const mainNavItems = [
    { label: t('sidebar.dashboard'), path: '/', icon: <IconDashboard /> },
    { label: t('sidebar.new_screening'), path: '/screening', icon: <IconScan />, roles: ['admin', 'phc_operator'] },
    { label: t('sidebar.patients'), path: '/patients', icon: <IconUsers /> },
  ];

  const analyticsNavItems = [
    { label: t('sidebar.simulink'), path: '/simulink', icon: <IconSimulink />, roles: ['admin', 'ophthalmologist'] },
    { label: t('sidebar.validation'), path: '/validation', icon: <IconValidation />, roles: ['admin', 'ophthalmologist'] },
  ];

  const systemNavItems = [
    { label: t('sidebar.settings'), path: '/settings', icon: <IconSettings />, roles: ['admin'] },
  ];

  const isActive = (path) => {
    if (path === '/') return pathname === '/';
    return pathname.startsWith(path);
  };

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const filteredMain = mainNavItems.filter(item => !item.roles || item.roles.includes(user?.role));
  const filteredAnalytics = analyticsNavItems.filter(item => !item.roles || item.roles.includes(user?.role));
  const filteredSystem = systemNavItems.filter(item => !item.roles || item.roles.includes(user?.role));


  return (
    <aside className={`sidebar ${isOpen ? '' : 'collapsed'}`}>
      <div className="sidebar-header">
        <div className="logo-mark"><IconEye /></div>
        <div className="sidebar-brand">
          <span className="sidebar-brand-name">Drishti RetinaVision</span>
          <span className="sidebar-brand-sub">By Team RetinaX</span>
        </div>
      </div>

      <div className="sidebar-section-label">Main Menu</div>
      <nav className="sidebar-nav">
        {filteredMain.map((item) => (
          <Link key={item.path} to={item.path} className={`nav-item ${isActive(item.path) ? 'active' : ''}`}>
            <span className="nav-icon">{item.icon}</span>
            <span className="nav-label">{item.label}</span>
          </Link>
        ))}

        {filteredAnalytics.length > 0 && (
          <>
            <div className="sidebar-section-label" style={{padding:'1rem 0.25rem 0.5rem'}}>Analytics</div>
            {filteredAnalytics.map((item) => (
              <Link key={item.path} to={item.path} className={`nav-item ${isActive(item.path) ? 'active' : ''}`}>
                <span className="nav-icon">{item.icon}</span>
                <span className="nav-label">{item.label}</span>
              </Link>
            ))}
          </>
        )}

        {filteredSystem.length > 0 && (
          <>
            <div className="sidebar-section-label" style={{padding:'1rem 0.25rem 0.5rem'}}>System</div>
            {filteredSystem.map((item) => (
              <Link key={item.path} to={item.path} className={`nav-item ${isActive(item.path) ? 'active' : ''}`}>
                <span className="nav-icon">{item.icon}</span>
                <span className="nav-label">{item.label}</span>
              </Link>
            ))}
          </>
        )}
      </nav>

      <div className="sidebar-footer">
        <div className="pipeline-status-card">
          <div className="pipeline-status-header">
            <span className="pipeline-status-label">Pipeline Status</span>
            <span className="pipeline-status-value"><span className="status-dot"></span>Active</span>
          </div>
          <div className="progress-bar"><div className="progress-fill progress-fill-success" style={{width:'100%'}}></div></div>
          <div className="pipeline-status-detail">All 3 modules online • Latency: 12ms</div>
        </div>

        <div className="sidebar-user-card">
          <div className="sidebar-user-info">
            <div className="sidebar-user-avatar">{user?.name?.split(' ').map(n => n[0]).join('').slice(0,2)}</div>
            <div>
              <div className="sidebar-user-name">{user?.name}</div>
              <div className="sidebar-user-role">{ROLE_LABELS[user?.role] || user?.role}</div>
            </div>
          </div>
          <button className="btn-ghost btn-icon sidebar-logout-btn" onClick={handleLogout} title="Sign Out">
            <IconLogout />
          </button>
        </div>
      </div>
    </aside>
  );
}
