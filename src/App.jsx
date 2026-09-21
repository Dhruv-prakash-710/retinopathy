import { Routes, Route, useLocation, Navigate } from 'react-router-dom';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useAuth } from './context/AuthContext';
import { useTheme } from './context/ThemeContext';
import Sidebar from './components/Sidebar';
import NotificationPanel from './components/NotificationPanel';
import HelpTour from './components/HelpTour';
import Dashboard from './pages/Dashboard';
import Screening from './pages/Screening';
import Results from './pages/Results';
import Patients from './pages/Patients';
import Login from './pages/Login';
import Settings from './pages/Settings';
import Simulink from './pages/Simulink';
import Validation from './pages/Validation';
import './index.css';

const ROLE_LABELS = {
  admin: 'Administrator',
  ophthalmologist: 'Ophthalmologist',
  phc_operator: 'PHC Operator',
};

const pageTitles = {
  '/': 'Dashboard',
  '/screening': 'New Screening',
  '/patients': 'Patients',
  '/settings': 'Settings',
  '/simulink': 'Simulink Model',
  '/validation': 'Clinical Validation',
};

function ProtectedRoute({ children }) {
  const { isAuthenticated } = useAuth();
  if (!isAuthenticated) return <Navigate to="/login" replace />;
  return children;
}

function RoleProtectedRoute({ children, allowedRoles }) {
  const { user } = useAuth();
  if (!user || !allowedRoles.includes(user.role)) {
    return <Navigate to="/" replace />;
  }
  return children;
}

function AppLayout() {
  const location = useLocation();
  const { user } = useAuth();
  const { theme, toggleTheme } = useTheme();
  const { t, i18n } = useTranslation();
  const [sidebarOpen, setSidebarOpen] = useState(true);
  
  const pageTitles = {
    '/': t('header.titles.dashboard'),
    '/screening': t('header.titles.new_screening'),
    '/patients': t('header.titles.patients'),
    '/settings': t('header.titles.settings'),
    '/simulink': t('header.titles.simulink'),
    '/validation': t('header.titles.validation'),
  };
  
  const isResultsPage = location.pathname.startsWith('/results');
  const currentTitle = isResultsPage ? t('header.titles.results') : pageTitles[location.pathname] || '';
  const [showTour, setShowTour] = useState(() => {
    return user?.role === 'phc_operator' && !localStorage.getItem('rv_tour_dismissed');
  });

  const toggleLanguage = () => {
    const newLang = i18n.language === 'en' ? 'hi' : 'en';
    i18n.changeLanguage(newLang);
  };

  return (
    <div className="app-layout">
      <Sidebar isOpen={sidebarOpen} />
      <main className={`main-content ${sidebarOpen ? '' : 'sidebar-collapsed'}`}>
        <header className="top-header">
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
            <button className="btn-ghost btn-icon" onClick={() => setSidebarOpen(!sidebarOpen)} title="Toggle Sidebar">
              <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><line x1="3" y1="12" x2="21" y2="12"/><line x1="3" y1="6" x2="21" y2="6"/><line x1="3" y1="18" x2="21" y2="18"/></svg>
            </button>
            <div className="header-breadcrumb">
              <span className="text-dim">{t('header.app_name')}</span>
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polyline points="9 18 15 12 9 6"/></svg>
              <span className="font-medium" style={{color:'var(--color-text-secondary)'}}>{currentTitle}</span>
            </div>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
            <button className="btn-ghost btn-sm" onClick={toggleLanguage} title={t('header.language')} style={{ fontWeight: 600, border: '1px solid var(--color-surface-border)', borderRadius: 'var(--border-radius-sm)' }}>
              {i18n.language === 'en' ? 'अ' : 'En'}
            </button>
            <NotificationPanel />
            <button className="btn-ghost btn-icon" onClick={toggleTheme} title={`Switch to ${theme === 'dark' ? 'Light' : 'Dark'} Mode`}>
              {theme === 'dark' ? (
                <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/></svg>
              ) : (
                <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>
              )}
            </button>
            <div className="user-profile">
              <div className="avatar">{user?.name?.split(' ').map(n => n[0]).join('').slice(0,2)}</div>
              <div className="user-details">
                <span className="user-name">{user?.name}</span>
                <span className="user-role">{ROLE_LABELS[user?.role] || user?.role} — {user?.facility}</span>
              </div>
            </div>
          </div>
        </header>
        <div className="content-scroll">
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/screening" element={
              <RoleProtectedRoute allowedRoles={['admin', 'phc_operator']}>
                <Screening />
              </RoleProtectedRoute>
            } />
            <Route path="/results/:id" element={<Results />} />
            <Route path="/patients" element={<Patients />} />
            <Route path="/settings" element={
              <RoleProtectedRoute allowedRoles={['admin']}>
                <Settings />
              </RoleProtectedRoute>
            } />
            <Route path="/simulink" element={
              <RoleProtectedRoute allowedRoles={['admin', 'ophthalmologist']}>
                <Simulink />
              </RoleProtectedRoute>
            } />
            <Route path="/validation" element={
              <RoleProtectedRoute allowedRoles={['admin', 'ophthalmologist']}>
                <Validation />
              </RoleProtectedRoute>
            } />
          </Routes>
        </div>
      </main>
      {showTour && <HelpTour onDismiss={() => setShowTour(false)} />}
    </div>
  );
}

function App() {
  const { isAuthenticated } = useAuth();

  return (
    <Routes>
      <Route path="/login" element={isAuthenticated ? <Navigate to="/" replace /> : <Login />} />
      <Route path="/*" element={
        <ProtectedRoute>
          <AppLayout />
        </ProtectedRoute>
      } />
    </Routes>
  );
}

export default App;
