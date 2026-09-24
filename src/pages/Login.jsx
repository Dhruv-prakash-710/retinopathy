import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import './Login.css';

/* ── Icons ── */
const IconEye = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z" /><circle cx="12" cy="12" r="3" /></svg>
);
const IconShield = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" /></svg>
);
const IconActivity = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M22 12h-4l-3 9L9 3l-3 9H2" /></svg>
);
const IconHome = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" /><polyline points="9 22 9 12 15 12 15 22" /></svg>
);
const IconUser = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" /><circle cx="12" cy="7" r="4" /></svg>
);
const IconLock = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2" /><path d="M7 11V7a5 5 0 0 1 10 0v4" /></svg>
);
const IconBrain = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M9.5 2A2.5 2.5 0 0 1 12 4.5v15a2.5 2.5 0 0 1-4.96.44 2.5 2.5 0 0 1-2.96-3.08 3 3 0 0 1-.34-5.58 2.5 2.5 0 0 1 1.32-4.24 2.5 2.5 0 0 1 1.98-3A2.5 2.5 0 0 1 9.5 2Z" /><path d="M14.5 2A2.5 2.5 0 0 0 12 4.5v15a2.5 2.5 0 0 0 4.96.44 2.5 2.5 0 0 0 2.96-3.08 3 3 0 0 0 .34-5.58 2.5 2.5 0 0 0-1.32-4.24 2.5 2.5 0 0 0-1.98-3A2.5 2.5 0 0 0 14.5 2Z" /></svg>
);
const IconCheck = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polyline points="20 6 9 17 4 12" /></svg>
);
const IconTarget = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10" /><circle cx="12" cy="12" r="6" /><circle cx="12" cy="12" r="2" /></svg>
);
const IconLayers = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polygon points="12 2 2 7 12 12 22 7 12 2" /><polyline points="2 17 12 22 22 17" /><polyline points="2 12 12 17 22 12" /></svg>
);
const IconZap = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2" /></svg>
);

const ROLE_PRESETS = {
  admin: { username: 'admin', password: 'admin123' },
  ophthalmologist: { username: 'drSharma', password: 'doc123' },
  phc_operator: { username: 'phc_rampur', password: 'phc123' },
};

export default function Login() {
  const [selectedRole, setSelectedRole] = useState('admin');
  const [username, setUsername] = useState(ROLE_PRESETS['admin'].username);
  const [password, setPassword] = useState(ROLE_PRESETS['admin'].password);
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const { login } = useAuth();
  const navigate = useNavigate();

  const handleRoleSelect = (role) => {
    setSelectedRole(role);
    setUsername(ROLE_PRESETS[role].username);
    setPassword(ROLE_PRESETS[role].password);
    setError('');
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    setError('');
    setIsLoading(true);
    setTimeout(() => {
      const result = login(username, password);
      if (result.success) {
        navigate('/');
      } else {
        setError(result.error);
      }
      setIsLoading(false);
    }, 1000);
  };

  const handleQuickLogin = (u, p) => {
    setUsername(u);
    setPassword(p);
  };

  return (
    <div className="login-page">
      {/* ── Background ── */}
      <div className="login-bg">
        <div className="orb orb-1"></div>
        <div className="orb orb-2"></div>
        <div className="orb orb-3"></div>
      </div>

      {/* ══ LEFT PANEL ══ */}
      <div className="login-left">
        <div className="hero-logo-row" style={{ animation: 'fadeInUp 0.6s ease-out' }}>
          <div className="hero-logo"><IconEye /></div>
          <div className="hero-logo-text">
            <span className="hero-logo-name">RetinaVision</span>
            <span className="hero-logo-sub">DR Screening Pipeline</span>
          </div>
        </div>

        <div className="hero-headline" style={{ animation: 'fadeInUp 0.6s ease-out 0.1s both' }}>
          <h1>
            AI-Powered<br />
            <span className="gradient-text">Diabetic Retinopathy</span><br />
            Screening for India
          </h1>
          <p className="hero-subtitle">
            Clinically validated, explainable screening pipeline built for deployment
            across 150,000+ Primary Healthcare Centres. Preventing blindness at scale.
          </p>
        </div>

        <div className="feature-pills" style={{ animation: 'fadeInUp 0.6s ease-out 0.2s both' }}>
          <span className="feature-pill"><IconBrain /> Deep Learning Pipeline</span>
          <span className="feature-pill"><IconTarget /> Grad-CAM Explainability</span>
          <span className="feature-pill"><IconLayers /> MATLAB + Simulink</span>
          <span className="feature-pill"><IconZap /> 12s Processing</span>
          <span className="feature-pill"><IconCheck /> ICDR Scale (L0-L4)</span>
          <span className="feature-pill"><IconShield /> Clinical Validation</span>
        </div>

        <div className="hero-stats" style={{ animation: 'fadeInUp 0.6s ease-out 0.3s both' }}>
          <div className="hero-stat">
            <div className="hero-stat-value purple">&gt;90%</div>
            <div className="hero-stat-label">Sensitivity</div>
          </div>
          <div className="hero-stat">
            <div className="hero-stat-value cyan">&gt;85%</div>
            <div className="hero-stat-label">Specificity</div>
          </div>
          <div className="hero-stat">
            <div className="hero-stat-value green">100K+</div>
            <div className="hero-stat-label">Annual Capacity</div>
          </div>
          <div className="hero-stat">
            <div className="hero-stat-value amber">&lt;30s</div>
            <div className="hero-stat-label">Doctor Review</div>
          </div>
        </div>

        {/* Retina Orbit Animation (large screens) */}
        <div className="retina-visual" style={{ animation: 'fadeIn 1s ease-out 0.5s both' }}>
          <div className="retina-ring retina-ring-1"><div className="retina-ring-dot"></div></div>
          <div className="retina-ring retina-ring-2"><div className="retina-ring-dot"></div></div>
          <div className="retina-ring retina-ring-3"></div>
          <div className="retina-core"><div className="retina-core-inner"></div></div>
        </div>

        <div className="trust-row" style={{ animation: 'fadeInUp 0.6s ease-out 0.4s both' }}>
          <span className="trust-badge"><IconShield /> HIPAA Compliant</span>
          <span className="trust-badge"><IconCheck /> Peer Reviewed</span>
          <span className="trust-badge"><IconActivity /> Real-time Monitoring</span>
        </div>
      </div>

      {/* ══ RIGHT PANEL ══ */}
      <div className="login-right">
        <div className="login-card" style={{ animation: 'fadeInUp 0.6s ease-out 0.15s both' }}>
          <h2>Welcome Back</h2>
          <p className="login-subtitle">Sign in to access the screening platform</p>

          <div className="role-selector">
            <button className={`role-btn ${selectedRole === 'admin' ? 'active' : ''}`} onClick={() => handleRoleSelect('admin')}>
              <div className="role-icon"><IconShield /></div>
              <span className="role-name">Admin</span>
            </button>
            <button className={`role-btn ${selectedRole === 'ophthalmologist' ? 'active' : ''}`} onClick={() => handleRoleSelect('ophthalmologist')}>
              <div className="role-icon"><IconActivity /></div>
              <span className="role-name">Doctor</span>
            </button>
            <button className={`role-btn ${selectedRole === 'phc_operator' ? 'active' : ''}`} onClick={() => handleRoleSelect('phc_operator')}>
              <div className="role-icon"><IconHome /></div>
              <span className="role-name">PHC</span>
            </button>
          </div>

          <form onSubmit={handleSubmit} className="login-form">
            <div className="form-group">
              <label className="form-label">Username</label>
              <div className="form-input-wrapper">
                <IconUser />
                <input
                  type="text"
                  className="form-input"
                  placeholder="Enter your username"
                  value={username}
                  onChange={e => { setUsername(e.target.value); setError(''); }}
                  autoComplete="username"
                />
              </div>
            </div>
            <div className="form-group">
              <label className="form-label">Password</label>
              <div className="form-input-wrapper">
                <IconLock />
                <input
                  type="password"
                  className="form-input"
                  placeholder="Enter your password"
                  value={password}
                  onChange={e => { setPassword(e.target.value); setError(''); }}
                  autoComplete="current-password"
                />
              </div>
            </div>

            {error && (
              <div className="form-error">
                <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="12" cy="12" r="10" /><line x1="15" y1="9" x2="9" y2="15" /><line x1="9" y1="9" x2="15" y2="15" /></svg>
                {error}
              </div>
            )}

            <button type="submit" className="login-btn" disabled={isLoading || !username || !password}>
              {isLoading ? (
                <><span className="spinner"></span> Authenticating...</>
              ) : (
                <>Sign In →</>
              )}
            </button>
          </form>


        </div>
      </div>
    </div>
  );
}
