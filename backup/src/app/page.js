import './Dashboard.css';
import Link from 'next/link';

export default function Dashboard() {
  const recentScreenings = [
    { id: 'DR-8291', patient: 'P-1042', date: '2026-08-31', quality: 'Adequate', grade: 'Level 2', status: 'Pending Review' },
    { id: 'DR-8290', patient: 'P-0921', date: '2026-08-31', quality: 'Adequate', grade: 'Level 0', status: 'Approved' },
    { id: 'DR-8289', patient: 'P-1133', date: '2026-08-30', quality: 'Reject', grade: 'N/A', status: 'Recapture Needed' },
    { id: 'DR-8288', patient: 'P-0844', date: '2026-08-30', quality: 'Adequate', grade: 'Level 3', status: 'Approved' },
  ];

  return (
    <div className="dashboard-container animate-fade-in">
      <div className="dashboard-header">
        <div>
          <h1>Pipeline Overview</h1>
          <p className="text-muted">Simulink Telemedicine Resource Allocation Dashboard</p>
        </div>
        <Link href="/screening" className="btn btn-primary">
          <span style={{marginRight: '8px'}}>+</span> New Screening
        </Link>
      </div>

      <div className="stats-grid">
        <div className="stat-card card">
          <div className="stat-title">Daily Processing Capacity</div>
          <div className="stat-value">2,500 <span className="stat-unit">images</span></div>
          <div className="stat-change positive">↑ 12% vs last week</div>
        </div>
        <div className="stat-card card">
          <div className="stat-title">Average Processing Time</div>
          <div className="stat-value">12.4 <span className="stat-unit">sec</span></div>
          <div className="stat-change positive">↓ 1.2s optimization</div>
        </div>
        <div className="stat-card card">
          <div className="stat-title">Network Bandwidth Load</div>
          <div className="stat-value">42 <span className="stat-unit">%</span></div>
          <div className="stat-change neutral">Stable</div>
        </div>
        <div className="stat-card card">
          <div className="stat-title">Review Queue</div>
          <div className="stat-value">18 <span className="stat-unit">patients</span></div>
          <div className="stat-change negative">Requires attention</div>
        </div>
      </div>

      <div className="dashboard-content">
        <div className="recent-screenings card">
          <div className="card-header">
            <h3>Recent Screenings</h3>
            <button className="btn btn-secondary text-sm">View All</button>
          </div>
          <div className="table-responsive">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Scan ID</th>
                  <th>Patient ID</th>
                  <th>Date</th>
                  <th>Image Quality</th>
                  <th>AI Grade</th>
                  <th>Status</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {recentScreenings.map((scan) => (
                  <tr key={scan.id}>
                    <td className="font-medium">{scan.id}</td>
                    <td>{scan.patient}</td>
                    <td>{scan.date}</td>
                    <td>
                      <span className={`badge ${scan.quality === 'Adequate' ? 'badge-success' : 'badge-danger'}`}>
                        {scan.quality}
                      </span>
                    </td>
                    <td>
                      {scan.grade === 'N/A' ? (
                        <span className="text-muted">N/A</span>
                      ) : (
                        <span className={`grade-indicator ${scan.grade !== 'Level 0' ? 'referable' : 'normal'}`}>
                          {scan.grade}
                        </span>
                      )}
                    </td>
                    <td>{scan.status}</td>
                    <td>
                      <Link href={`/results/${scan.id}`} className="action-link">
                        Review
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        <div className="system-health card">
          <h3>MATLAB Pipeline Status</h3>
          <div className="health-metrics mt-4">
            <div className="metric-item">
              <div className="metric-header">
                <span>Quality Assessment Module</span>
                <span className="text-success">Online</span>
              </div>
              <div className="progress-bar"><div className="progress-fill" style={{width: '100%'}}></div></div>
            </div>
            <div className="metric-item mt-4">
              <div className="metric-header">
                <span>Structure Segmentation Model</span>
                <span className="text-success">Online</span>
              </div>
              <div className="progress-bar"><div className="progress-fill" style={{width: '100%'}}></div></div>
            </div>
            <div className="metric-item mt-4">
              <div className="metric-header">
                <span>Grad-CAM Explainability Gen</span>
                <span className="text-success">Online</span>
              </div>
              <div className="progress-bar"><div className="progress-fill" style={{width: '100%'}}></div></div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
