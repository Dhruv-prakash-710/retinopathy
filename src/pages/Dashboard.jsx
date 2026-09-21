import { useState, useEffect } from 'react';
import { useAuth } from '../context/AuthContext';
import './Dashboard.css';
import { Link } from 'react-router-dom';

/* ── Inline SVG Icons ── */
const IconArrowRight = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M5 12h14"/><path d="m12 5 7 7-7 7"/></svg>
);
const IconCapacity = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M22 12h-4l-3 9L9 3l-3 9H2"/></svg>
);
const IconClock = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
);
const IconWifi = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M5 12.55a11 11 0 0 1 14.08 0"/><path d="M1.42 9a16 16 0 0 1 21.16 0"/><path d="M8.53 16.11a6 6 0 0 1 6.95 0"/><line x1="12" y1="20" x2="12.01" y2="20"/></svg>
);
const IconQueue = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><line x1="19" y1="8" x2="19" y2="14"/><line x1="22" y1="11" x2="16" y2="11"/></svg>
);
const IconAlert = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"/><path d="M12 9v4"/><path d="M12 17h.01"/></svg>
);
const IconUserCheck = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><polyline points="16 11 18 13 22 9"/></svg>
);
const IconActivity = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>
);

export default function Dashboard() {
  const { user } = useAuth();
  
  const allScreenings = [
    { id: 'DR-8291', patient: 'P-1042', facility: 'PHC Rampur, UP', date: '2026-08-31', quality: 'Adequate', grade: 'Level 2', status: 'Pending Review' },
    { id: 'DR-8290', patient: 'P-0921', facility: 'PHC Rampur, UP', date: '2026-08-31', quality: 'Adequate', grade: 'Level 0', status: 'Approved' },
    { id: 'DR-8289', patient: 'P-1133', facility: 'PHC Bareilly, UP', date: '2026-08-30', quality: 'Reject', grade: 'N/A', status: 'Recapture' },
    { id: 'DR-8288', patient: 'P-0844', facility: 'PHC Rampur, UP', date: '2026-08-30', quality: 'Adequate', grade: 'Level 3', status: 'Referred' },
    { id: 'DR-8287', patient: 'P-0715', facility: 'PHC Bareilly, UP', date: '2026-08-29', quality: 'Adequate', grade: 'Level 1', status: 'Approved' },
  ];

  // Filter screenings based on role
  const recentScreenings = allScreenings.filter(scan => {
    if (user?.role === 'admin' || user?.role === 'ophthalmologist') return true;
    return scan.facility === user?.facility;
  });

  return (
    <div className="dashboard-container">
      <div className="dashboard-header animate-fade-in">
        <div className="dashboard-header-text">
          <h1>{user?.role === 'phc_operator' ? 'PHC Dashboard' : user?.role === 'ophthalmologist' ? 'Clinical Overview' : 'System Overview'}</h1>
          <p className="text-muted">
            {user?.role === 'phc_operator' ? `Local screening summary for ${user?.facility}` : 'Simulink Telemedicine Resource Allocation — District Level Program'}
          </p>
        </div>
        {user?.role !== 'ophthalmologist' && (
          <Link to="/screening" className="btn btn-primary">
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
            New Screening
          </Link>
        )}
      </div>

      <div className="stats-grid">
        {/* ADMIN STATS */}
        {user?.role === 'admin' && (
          <>
            <div className="stat-card card animate-fade-in animate-fade-in-delay-1">
              <div className="stat-icon purple"><IconCapacity /></div>
              <div className="stat-title">Daily Processing Capacity</div>
              <div className="stat-value">2,500 <span className="stat-unit">images</span></div>
              <div className="stat-change positive">↑ 12% vs last week</div>
            </div>
            <div className="stat-card card animate-fade-in animate-fade-in-delay-2">
              <div className="stat-icon cyan"><IconClock /></div>
              <div className="stat-title">Average Processing Time</div>
              <div className="stat-value">12.4 <span className="stat-unit">sec</span></div>
              <div className="stat-change positive">↓ 1.2s optimized</div>
            </div>
            <div className="stat-card card animate-fade-in animate-fade-in-delay-3">
              <div className="stat-icon green"><IconWifi /></div>
              <div className="stat-title">Global Network Uptime</div>
              <div className="stat-value">99.9 <span className="stat-unit">%</span></div>
              <div className="stat-change neutral">— Stable</div>
            </div>
            <div className="stat-card card animate-fade-in animate-fade-in-delay-4">
              <div className="stat-icon amber"><IconQueue /></div>
              <div className="stat-title">Total Review Queue</div>
              <div className="stat-value">42 <span className="stat-unit">pending</span></div>
              <div className="stat-change negative">↑ Requires attention</div>
            </div>
          </>
        )}

        {/* DOCTOR STATS */}
        {user?.role === 'ophthalmologist' && (
          <>
            <div className="stat-card card animate-fade-in animate-fade-in-delay-1">
              <div className="stat-icon amber"><IconQueue /></div>
              <div className="stat-title">Pending Reviews (Priority)</div>
              <div className="stat-value">12 <span className="stat-unit">cases</span></div>
              <div className="stat-change negative">4 high risk cases</div>
            </div>
            <div className="stat-card card animate-fade-in animate-fade-in-delay-2">
              <div className="stat-icon purple"><IconUserCheck /></div>
              <div className="stat-title">Reviews Completed Today</div>
              <div className="stat-value">28 <span className="stat-unit">patients</span></div>
              <div className="stat-change positive">↑ 5 vs yesterday</div>
            </div>
            <div className="stat-card card animate-fade-in animate-fade-in-delay-3">
              <div className="stat-icon cyan"><IconClock /></div>
              <div className="stat-title">Avg Time per Review</div>
              <div className="stat-value">28 <span className="stat-unit">sec</span></div>
              <div className="stat-change positive">↓ Efficient</div>
            </div>
            <div className="stat-card card animate-fade-in animate-fade-in-delay-4">
              <div className="stat-icon green"><IconActivity /></div>
              <div className="stat-title">AI Concordance Rate</div>
              <div className="stat-value">94.2 <span className="stat-unit">%</span></div>
              <div className="stat-change neutral">High agreement</div>
            </div>
          </>
        )}

        {/* PHC STATS */}
        {user?.role === 'phc_operator' && (
          <>
            <div className="stat-card card animate-fade-in animate-fade-in-delay-1">
              <div className="stat-icon green"><IconUserCheck /></div>
              <div className="stat-title">Screenings Today</div>
              <div className="stat-value">45 <span className="stat-unit">patients</span></div>
              <div className="stat-change positive">On track for daily goal</div>
            </div>
            <div className="stat-card card animate-fade-in animate-fade-in-delay-2">
              <div className="stat-icon amber"><IconAlert /></div>
              <div className="stat-title">Referable Cases Detected</div>
              <div className="stat-value">3 <span className="stat-unit">Level 2+</span></div>
              <div className="stat-change negative">Pending doctor review</div>
            </div>
            <div className="stat-card card animate-fade-in animate-fade-in-delay-3">
              <div className="stat-icon purple"><IconCapacity /></div>
              <div className="stat-title">Image Quality Reject Rate</div>
              <div className="stat-value">4.2 <span className="stat-unit">%</span></div>
              <div className="stat-change positive">↓ Improved capture quality</div>
            </div>
            <div className="stat-card card animate-fade-in animate-fade-in-delay-4">
              <div className="stat-icon cyan"><IconWifi /></div>
              <div className="stat-title">Cloud Sync Status</div>
              <div className="stat-value">Synced</div>
              <div className="stat-change neutral">Last sync: 2 mins ago</div>
            </div>
          </>
        )}
      </div>

      <div className="dashboard-content animate-fade-in" style={{animationDelay: '0.3s'}}>
        <div className="card" style={{ flex: user?.role === 'phc_operator' ? '1' : 'auto' }}>
          <div className="card-header">
            <h3>{user?.role === 'phc_operator' ? 'Your Recent Screenings' : 'Recent Screenings'}</h3>
            <Link to="/patients" className="btn btn-ghost btn-sm">View All →</Link>
          </div>
          <table className="data-table">
            <thead>
              <tr>
                <th>Scan ID</th>
                <th>Patient</th>
                {(user?.role === 'admin' || user?.role === 'ophthalmologist') && <th>Facility</th>}
                <th>Date</th>
                <th>Quality</th>
                <th>AI Grade</th>
                <th>Status</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {recentScreenings.map((scan) => (
                <tr key={scan.id}>
                  <td><span className="scan-id">{scan.id}</span></td>
                  <td>{scan.patient}</td>
                  {(user?.role === 'admin' || user?.role === 'ophthalmologist') && (
                    <td className="text-dim text-sm">{scan.facility}</td>
                  )}
                  <td className="text-dim">{scan.date}</td>
                  <td>
                    <span className={`badge badge-dot ${scan.quality === 'Adequate' ? 'badge-success' : 'badge-danger'}`}>
                      {scan.quality}
                    </span>
                  </td>
                  <td>
                    {scan.grade === 'N/A' ? (
                      <span className="text-dim">—</span>
                    ) : (
                      <span className={`grade-indicator ${scan.grade === 'Level 0' || scan.grade === 'Level 1' ? 'normal' : 'referable'}`}>
                        {scan.grade}
                      </span>
                    )}
                  </td>
                  <td className="text-dim">{scan.status}</td>
                  <td>
                    <Link to={`/results/${scan.id}`} className="action-link">
                      {user?.role === 'ophthalmologist' ? 'Review' : 'View'} <IconArrowRight />
                    </Link>
                  </td>
                </tr>
              ))}
              {recentScreenings.length === 0 && (
                <tr>
                  <td colSpan={user?.role === 'admin' || user?.role === 'ophthalmologist' ? 8 : 7} style={{textAlign: 'center', padding: '2rem'}}>
                    No recent screenings found.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>

        {/* Hide system health from PHC Operators */}
        {user?.role !== 'phc_operator' && (
          <div className="system-health card">
            <h3>MATLAB Pipeline</h3>
            <div className="health-metrics">
              <div className="metric-item">
                <div className="metric-header">
                  <span>Quality Assessment</span>
                  <span className="text-success font-semibold">Online</span>
                </div>
                <div className="progress-bar"><div className="progress-fill progress-fill-success" style={{width: '100%'}}></div></div>
              </div>
              <div className="metric-item">
                <div className="metric-header">
                  <span>Segmentation Model</span>
                  <span className="text-success font-semibold">Online</span>
                </div>
                <div className="progress-bar"><div className="progress-fill progress-fill-success" style={{width: '100%'}}></div></div>
              </div>
              <div className="metric-item">
                <div className="metric-header">
                  <span>Grad-CAM Engine</span>
                  <span className="text-success font-semibold">Online</span>
                </div>
                <div className="progress-bar"><div className="progress-fill progress-fill-success" style={{width: '100%'}}></div></div>
              </div>
              <div className="metric-item">
                <div className="metric-header">
                  <span>GPU Utilization</span>
                  <span className="text-muted font-semibold">67%</span>
                </div>
                <div className="progress-bar"><div className="progress-fill" style={{width: '67%'}}></div></div>
              </div>
            </div>
          </div>
        )}
        
        {/* District Analytics (Admin Only) */}
        {user?.role === 'admin' && (
          <div className="card animate-fade-in" style={{ animationDelay: '0.4s', width: '100%', marginTop: '1.5rem' }}>
            <h3>District-Level Analytics (Uttar Pradesh Pilot)</h3>
            <div className="flex gap-4" style={{ marginTop: '1rem' }}>
              <div style={{ flex: 1, padding: '1rem', background: 'var(--color-surface)', borderRadius: 'var(--border-radius-sm)', border: '1px solid var(--color-surface-border)' }}>
                <div className="text-xs text-dim mb-1 font-semibold uppercase tracking-wider">Total Screenings</div>
                <div style={{ fontSize: '1.5rem', fontWeight: 800, color: 'var(--color-text-main)' }}>14,285</div>
                <div className="text-xs text-success font-semibold mt-1">↑ 2,104 this month</div>
              </div>
              <div style={{ flex: 1, padding: '1rem', background: 'var(--color-surface)', borderRadius: 'var(--border-radius-sm)', border: '1px solid var(--color-surface-border)' }}>
                <div className="text-xs text-dim mb-1 font-semibold uppercase tracking-wider">Total Referrals (L2+)</div>
                <div style={{ fontSize: '1.5rem', fontWeight: 800, color: 'var(--color-warning)' }}>2,571</div>
                <div className="text-xs text-dim mt-1">18% of total screenings</div>
              </div>
              <div style={{ flex: 1, padding: '1rem', background: 'var(--color-surface)', borderRadius: 'var(--border-radius-sm)', border: '1px solid var(--color-surface-border)' }}>
                <div className="text-xs text-dim mb-1 font-semibold uppercase tracking-wider">High-Risk Clusters</div>
                <div style={{ fontSize: '1.5rem', fontWeight: 800, color: 'var(--color-danger)' }}>Bareilly South</div>
                <div className="text-xs text-dim mt-1">24% referral rate</div>
              </div>
              <div style={{ flex: 1, padding: '1rem', background: 'var(--color-surface)', borderRadius: 'var(--border-radius-sm)', border: '1px solid var(--color-surface-border)' }}>
                <div className="text-xs text-dim mb-1 font-semibold uppercase tracking-wider">Avg Turnaround Time</div>
                <div style={{ fontSize: '1.5rem', fontWeight: 800, color: 'var(--color-primary-light)' }}>2.4 hours</div>
                <div className="text-xs text-success font-semibold mt-1">↓ 45 mins from last week</div>
              </div>
            </div>
          </div>
        )}
        {/* ── Activity Feed ── */}
        {(user?.role === 'admin' || user?.role === 'ophthalmologist') && (
          <div className="card animate-fade-in" style={{ animationDelay: '0.5s', width: '100%', marginTop: '1.5rem' }}>
          <div className="card-header">
            <h3>Recent Activity</h3>
            <span className="text-xs text-dim">Auto-refreshing</span>
          </div>
          <div className="activity-feed">
            {[
              { time: '2 min ago', event: 'Level 4 PDR detected — Patient P-1133 (PHC Bareilly)', type: 'danger', icon: '🔴' },
              { time: '15 min ago', event: 'Image quality rejected — DR-8289. Recapture request sent.', type: 'warning', icon: '🟡' },
              { time: '28 min ago', event: 'Dr. Sharma validated scan DR-8290 (Level 0, No DR) in 24s', type: 'success', icon: '✅' },
              { time: '1 hr ago', event: 'Batch analysis completed — 12 images from PHC Rampur', type: 'info', icon: 'ℹ️' },
              { time: '2 hrs ago', event: 'Model update v3.2: +2.1% sensitivity, ECE improved to 0.018', type: 'info', icon: '📊' },
            ].map((item, i) => (
              <div key={i} className={`activity-item activity-${item.type}`}>
                <span className="activity-icon">{item.icon}</span>
                <div className="activity-content">
                  <span className="activity-event">{item.event}</span>
                  <span className="activity-time">{item.time}</span>
                </div>
              </div>
            ))}
          </div>
        </div>
        )}

        {/* ── Weekly Trend ── */}
        {user?.role === 'admin' && (
          <div className="card animate-fade-in" style={{ animationDelay: '0.6s', width: '100%', marginTop: '1rem' }}>
            <h3 style={{ marginBottom: '1rem' }}>Weekly Screening Trend</h3>
            <div className="sparkline-grid">
              {['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((day, i) => {
                const vals = [340, 380, 420, 395, 450, 280, 190];
                const maxVal = Math.max(...vals);
                return (
                  <div key={day} className="sparkline-bar-group">
                    <div className="sparkline-bar-wrapper">
                      <div className="sparkline-bar" style={{ height: `${(vals[i] / maxVal) * 100}%`, animationDelay: `${i * 0.08}s` }}></div>
                    </div>
                    <span className="sparkline-label">{day}</span>
                    <span className="sparkline-value">{vals[i]}</span>
                  </div>
                );
              })}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
