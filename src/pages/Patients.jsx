import { useState, useMemo } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import './Patients.css';

const MOCK_PATIENTS = [
  { id:'P-1042', name:'Ramesh Gupta', age:58, gender:'M', facility:'PHC Rampur', lastScan:'2026-08-31', scans:3, latestGrade:'Level 2', status:'Under Review',
    history: [
      { date:'2026-08-31', scanId:'DR-8291', grade:'Level 2', quality:'Adequate', action:'Referred' },
      { date:'2026-07-15', scanId:'DR-7812', grade:'Level 1', quality:'Adequate', action:'Follow-up 6mo' },
      { date:'2026-03-10', scanId:'DR-6501', grade:'Level 0', quality:'Adequate', action:'Routine 12mo' },
    ]},
  { id:'P-0921', name:'Sunita Devi', age:62, gender:'F', facility:'PHC Rampur', lastScan:'2026-08-31', scans:2, latestGrade:'Level 0', status:'No DR',
    history: [
      { date:'2026-08-31', scanId:'DR-8290', grade:'Level 0', quality:'Adequate', action:'Routine 12mo' },
      { date:'2025-09-01', scanId:'DR-5120', grade:'Level 0', quality:'Adequate', action:'Routine 12mo' },
    ]},
  { id:'P-1133', name:'Arun Yadav', age:45, gender:'M', facility:'PHC Bareilly', lastScan:'2026-08-30', scans:1, latestGrade:'N/A', status:'Recapture',
    history: [
      { date:'2026-08-30', scanId:'DR-8289', grade:'N/A', quality:'Rejected', action:'Recapture' },
    ]},
  { id:'P-0844', name:'Kavita Mishra', age:70, gender:'F', facility:'PHC Rampur', lastScan:'2026-08-30', scans:4, latestGrade:'Level 3', status:'Referred',
    history: [
      { date:'2026-08-30', scanId:'DR-8288', grade:'Level 3', quality:'Adequate', action:'Urgent referral' },
      { date:'2026-06-20', scanId:'DR-7310', grade:'Level 2', quality:'Adequate', action:'Referred' },
      { date:'2026-01-15', scanId:'DR-5920', grade:'Level 1', quality:'Borderline', action:'Follow-up 6mo' },
      { date:'2025-07-10', scanId:'DR-4200', grade:'Level 0', quality:'Adequate', action:'Routine 12mo' },
    ]},
  { id:'P-0715', name:'Mohan Lal', age:55, gender:'M', facility:'PHC Bareilly', lastScan:'2026-08-29', scans:2, latestGrade:'Level 1', status:'Mild DR',
    history: [
      { date:'2026-08-29', scanId:'DR-8287', grade:'Level 1', quality:'Adequate', action:'Follow-up 6mo' },
      { date:'2026-02-20', scanId:'DR-6120', grade:'Level 0', quality:'Adequate', action:'Routine 12mo' },
    ]},
  { id:'P-0603', name:'Geeta Rani', age:48, gender:'F', facility:'PHC Rampur', lastScan:'2026-08-28', scans:1, latestGrade:'Level 0', status:'No DR',
    history: [
      { date:'2026-08-28', scanId:'DR-8270', grade:'Level 0', quality:'Adequate', action:'Routine 12mo' },
    ]},
  { id:'P-0512', name:'Vijay Kumar', age:66, gender:'M', facility:'PHC Bareilly', lastScan:'2026-08-27', scans:5, latestGrade:'Level 4', status:'PDR - Urgent',
    history: [
      { date:'2026-08-27', scanId:'DR-8261', grade:'Level 4', quality:'Adequate', action:'Immediate referral' },
      { date:'2026-06-10', scanId:'DR-7210', grade:'Level 3', quality:'Adequate', action:'Urgent referral' },
      { date:'2026-03-05', scanId:'DR-6380', grade:'Level 2', quality:'Adequate', action:'Referred' },
      { date:'2025-12-01', scanId:'DR-5500', grade:'Level 2', quality:'Borderline', action:'Referred' },
      { date:'2025-06-20', scanId:'DR-4010', grade:'Level 1', quality:'Adequate', action:'Follow-up 6mo' },
    ]},
  { id:'P-0401', name:'Priya Sharma', age:52, gender:'F', facility:'PHC Rampur', lastScan:'2026-08-25', scans:2, latestGrade:'Level 1', status:'Mild DR',
    history: [
      { date:'2026-08-25', scanId:'DR-8210', grade:'Level 1', quality:'Adequate', action:'Follow-up 6mo' },
      { date:'2026-02-10', scanId:'DR-6050', grade:'Level 0', quality:'Adequate', action:'Routine 12mo' },
    ]},
  { id:'P-0310', name:'Ravi Tiwari', age:61, gender:'M', facility:'PHC Bareilly', lastScan:'2026-08-22', scans:3, latestGrade:'Level 2', status:'Under Review',
    history: [
      { date:'2026-08-22', scanId:'DR-8180', grade:'Level 2', quality:'Adequate', action:'Referred' },
      { date:'2026-04-15', scanId:'DR-6800', grade:'Level 1', quality:'Adequate', action:'Follow-up 6mo' },
      { date:'2025-10-20', scanId:'DR-5300', grade:'Level 1', quality:'Adequate', action:'Follow-up 6mo' },
    ]},
];

const ITEMS_PER_PAGE = 5;

export default function Patients() {
  const { user } = useAuth();
  const [search, setSearch] = useState('');
  const [filterStatus, setFilterStatus] = useState('all');
  const [currentPage, setCurrentPage] = useState(1);
  const [expandedPatient, setExpandedPatient] = useState(null);
  const [sortBy, setSortBy] = useState('lastScan');
  const [sortDir, setSortDir] = useState('desc');

  const filtered = useMemo(() => {
    let result = MOCK_PATIENTS.filter(p => {
      const matchesSearch = p.name.toLowerCase().includes(search.toLowerCase()) || p.id.toLowerCase().includes(search.toLowerCase());
      const matchesFilter = filterStatus === 'all' || (filterStatus === 'referable' && parseInt(p.latestGrade.replace('Level ','')) >= 2) || (filterStatus === 'clear' && p.latestGrade === 'Level 0') || (filterStatus === 'urgent' && (p.status === 'PDR - Urgent' || p.status === 'Referred'));
      const matchesFacility = user?.role === 'admin' || user?.role === 'ophthalmologist' || p.facility === user?.facility;
      return matchesSearch && matchesFilter && matchesFacility;
    });

    result.sort((a, b) => {
      let cmp = 0;
      if (sortBy === 'lastScan') cmp = a.lastScan.localeCompare(b.lastScan);
      else if (sortBy === 'name') cmp = a.name.localeCompare(b.name);
      else if (sortBy === 'grade') cmp = a.latestGrade.localeCompare(b.latestGrade);
      return sortDir === 'asc' ? cmp : -cmp;
    });

    return result;
  }, [search, filterStatus, user, sortBy, sortDir]);

  const totalPages = Math.ceil(filtered.length / ITEMS_PER_PAGE);
  const paginated = filtered.slice((currentPage - 1) * ITEMS_PER_PAGE, currentPage * ITEMS_PER_PAGE);

  const toggleSort = (field) => {
    if (sortBy === field) setSortDir(d => d === 'asc' ? 'desc' : 'asc');
    else { setSortBy(field); setSortDir('desc'); }
  };

  const getStatusBadge = (status) => {
    if (status === 'No DR' || status === 'Mild DR') return 'badge-success';
    if (status === 'Under Review' || status === 'Recapture') return 'badge-warning';
    return 'badge-danger';
  };

  const getGradeColor = (grade) => {
    if (grade === 'N/A') return '';
    const lvl = parseInt(grade.replace('Level ', ''));
    if (lvl <= 1) return 'normal';
    return 'referable';
  };

  const handleExport = () => {
    const csv = ['Patient ID,Name,Age,Gender,Facility,Last Scan,Scans,Latest Grade,Status'];
    filtered.forEach(p => {
      csv.push(`${p.id},${p.name},${p.age},${p.gender},${p.facility},${p.lastScan},${p.scans},${p.latestGrade},${p.status}`);
    });
    const blob = new Blob([csv.join('\n')], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `patients_export_${new Date().toISOString().slice(0, 10)}.csv`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
  };

  return (
    <div className="patients-container animate-fade-in">
      <div className="page-header flex justify-between items-center">
        <div>
          <h1>Patients</h1>
          <p className="text-muted text-sm">{user?.role === 'admin' ? 'All facilities' : user?.facility} — {filtered.length} patients</p>
        </div>
        <button className="btn btn-secondary btn-sm" onClick={handleExport}>
          <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
          Export CSV
        </button>
      </div>

      <div className="card">
        <div className="patients-toolbar">
          <div className="search-box">
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
            <input type="text" placeholder="Search by name or ID..." value={search} onChange={e => { setSearch(e.target.value); setCurrentPage(1); }} className="form-input search-input" />
          </div>
          <div className="filter-pills">
            {['all','referable','urgent','clear'].map(f => (
              <button key={f} className={`filter-pill ${filterStatus === f ? 'active' : ''}`} onClick={() => { setFilterStatus(f); setCurrentPage(1); }}>
                {f === 'all' ? 'All' : f === 'referable' ? 'Referable (2+)' : f === 'urgent' ? 'Urgent' : 'Clear'}
              </button>
            ))}
          </div>
        </div>

        <table className="data-table">
          <thead>
            <tr>
              <th onClick={() => toggleSort('id')} style={{ cursor: 'pointer' }}>Patient ID {sortBy === 'id' ? (sortDir === 'asc' ? '↑' : '↓') : ''}</th>
              <th onClick={() => toggleSort('name')} style={{ cursor: 'pointer' }}>Name {sortBy === 'name' ? (sortDir === 'asc' ? '↑' : '↓') : ''}</th>
              <th>Age / Sex</th>
              {(user?.role === 'admin' || user?.role === 'ophthalmologist') && <th>Facility</th>}
              <th>Scans</th>
              <th onClick={() => toggleSort('grade')} style={{ cursor: 'pointer' }}>Latest Grade {sortBy === 'grade' ? (sortDir === 'asc' ? '↑' : '↓') : ''}</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {paginated.map(p => (
              <>
                <tr key={p.id} className={expandedPatient === p.id ? 'expanded-row' : ''}>
                  <td><span className="scan-id">{p.id}</span></td>
                  <td className="font-medium" style={{color:'var(--color-text-main)'}}>{p.name}</td>
                  <td className="text-dim">{p.age} / {p.gender}</td>
                  {(user?.role === 'admin' || user?.role === 'ophthalmologist') && <td className="text-dim text-sm">{p.facility}</td>}
                  <td>{p.scans}</td>
                  <td>
                    {p.latestGrade === 'N/A' ? <span className="text-dim">—</span> : (
                      <span className={`grade-indicator ${getGradeColor(p.latestGrade)}`}>{p.latestGrade}</span>
                    )}
                  </td>
                  <td><span className={`badge badge-dot ${getStatusBadge(p.status)}`}>{p.status}</span></td>
                  <td>
                    <div className="flex gap-2">
                      <button
                        className="action-link"
                        onClick={() => setExpandedPatient(expandedPatient === p.id ? null : p.id)}
                        style={{ background: 'none', border: 'none', cursor: 'pointer', fontFamily: 'inherit' }}
                      >
                        {expandedPatient === p.id ? 'Hide ▲' : 'History ▼'}
                      </button>
                      <Link to={`/results/DR-${p.id.replace('P-','8')}`} className="action-link">View →</Link>
                    </div>
                  </td>
                </tr>

                {/* Expanded Detail Row */}
                {expandedPatient === p.id && (
                  <tr key={`${p.id}-detail`} className="detail-row">
                    <td colSpan={user?.role === 'admin' || user?.role === 'ophthalmologist' ? 8 : 7}>
                      <div className="patient-detail-panel animate-fade-in">
                        <div className="detail-header">
                          <h4>Screening Timeline — {p.name}</h4>
                          <span className="text-xs text-dim">{p.history.length} screenings on record</span>
                        </div>
                        <div className="timeline">
                          {p.history.map((h, i) => (
                            <div key={i} className={`timeline-item ${i === 0 ? 'latest' : ''}`}>
                              <div className="timeline-dot"></div>
                              <div className="timeline-content">
                                <div className="timeline-date">{h.date}</div>
                                <div className="timeline-details">
                                  <Link to={`/results/${h.scanId}`} className="scan-id">{h.scanId}</Link>
                                  <span className={`grade-indicator ${getGradeColor(h.grade)}`}>{h.grade}</span>
                                  <span className={`badge badge-dot ${h.quality === 'Rejected' ? 'badge-danger' : h.quality === 'Borderline' ? 'badge-warning' : 'badge-success'}`}>
                                    {h.quality}
                                  </span>
                                  <span className="text-sm text-dim">{h.action}</span>
                                </div>
                              </div>
                            </div>
                          ))}
                        </div>
                        {p.history.length >= 2 && (
                          <div className="progression-note">
                            {parseInt(p.history[0].grade?.replace('Level ', '') || 0) > parseInt(p.history[p.history.length - 1].grade?.replace('Level ', '') || 0)
                              ? <span className="text-danger font-semibold">⚠ Disease progression detected over {p.history.length} screenings</span>
                              : <span className="text-success font-semibold">✓ Stable or improving over {p.history.length} screenings</span>
                            }
                          </div>
                        )}
                      </div>
                    </td>
                  </tr>
                )}
              </>
            ))}
            {filtered.length === 0 && (
              <tr><td colSpan={8} style={{textAlign:'center',padding:'2rem',color:'var(--color-text-dim)'}}>No patients found</td></tr>
            )}
          </tbody>
        </table>

        {/* Pagination */}
        {totalPages > 1 && (
          <div className="pagination">
            <button className="pagination-btn" disabled={currentPage === 1} onClick={() => setCurrentPage(p => p - 1)}>← Prev</button>
            <div className="pagination-pages">
              {Array.from({ length: totalPages }, (_, i) => i + 1).map(page => (
                <button key={page} className={`pagination-page ${currentPage === page ? 'active' : ''}`} onClick={() => setCurrentPage(page)}>
                  {page}
                </button>
              ))}
            </div>
            <button className="pagination-btn" disabled={currentPage === totalPages} onClick={() => setCurrentPage(p => p + 1)}>Next →</button>
          </div>
        )}
      </div>
    </div>
  );
}
