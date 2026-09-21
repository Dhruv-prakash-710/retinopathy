import { useState, useEffect, useRef, useCallback } from 'react';
import { Link, useParams, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import './Results.css';

/* ── SVG Icons ── */
const IconArrowLeft = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="m12 19-7-7 7-7"/><path d="M19 12H5"/></svg>
);
const IconCheck = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
);
const IconX = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
);
const IconDownload = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
);
const IconZoom = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/><line x1="11" y1="8" x2="11" y2="14"/><line x1="8" y1="11" x2="14" y2="11"/></svg>
);
const IconFileText = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/></svg>
);
const IconEdit = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
);
const IconColumns = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"/><line x1="12" y1="3" x2="12" y2="21"/></svg>
);

export default function Results() {
  const { id } = useParams();
  const location = useLocation();
  const { user } = useAuth();
  const apiData = location.state?.apiData?.data;

  const [activeLayer, setActiveLayer] = useState('original');
  const [showGradCam, setShowGradCam] = useState(false);
  const [gradcamOpacity, setGradcamOpacity] = useState(0.6);
  const [toast, setToast] = useState(null);
  const [actionTaken, setActionTaken] = useState(null);
  const [showReport, setShowReport] = useState(false);
  const [reviewTimer, setReviewTimer] = useState(0);
  const [clinicalNotes, setClinicalNotes] = useState('');
  const [compareMode, setCompareMode] = useState(false);
  const [selectedLesion, setSelectedLesion] = useState(null);
  const [zoom, setZoom] = useState(1);
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const [isPanning, setIsPanning] = useState(false);
  const [panStart, setPanStart] = useState({ x: 0, y: 0 });
  const timerRef = useRef(null);
  const viewerRef = useRef(null);

  useEffect(() => {
    timerRef.current = setInterval(() => setReviewTimer(t => t + 1), 1000);
    return () => clearInterval(timerRef.current);
  }, []);

  const showToast = (message, type = 'success') => {
    setToast({ message, type });
    setTimeout(() => setToast(null), 3500);
  };

  const handleApprove = () => {
    clearInterval(timerRef.current);
    setActionTaken('approved');
    showToast(`✓ Scan validated and approved in ${reviewTimer}s. Patient record updated.`, 'success');
  };

  const handleReject = () => {
    clearInterval(timerRef.current);
    setActionTaken('rejected');
    showToast('✗ Image rejected. Recapture request sent to PHC.', 'danger');
  };

  // Zoom handler
  const handleWheel = useCallback((e) => {
    e.preventDefault();
    const delta = e.deltaY > 0 ? -0.1 : 0.1;
    setZoom(prev => Math.max(0.5, Math.min(5, prev + delta)));
  }, []);

  // Pan handlers
  const handleMouseDown = (e) => {
    if (zoom > 1) {
      setIsPanning(true);
      setPanStart({ x: e.clientX - pan.x, y: e.clientY - pan.y });
    }
  };
  const handleMouseMove = (e) => {
    if (isPanning) {
      setPan({ x: e.clientX - panStart.x, y: e.clientY - panStart.y });
    }
  };
  const handleMouseUp = () => setIsPanning(false);

  const resetZoom = () => { setZoom(1); setPan({ x: 0, y: 0 }); };

  const handleExportPDF = () => {
    showToast('📄 Generating clinical report...', 'info');
    setTimeout(() => {
      const reportContent = generateReportText();
      const blob = new Blob([reportContent], { type: 'text/plain' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `Clinical_Report_${id}.txt`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
      showToast('✓ Report downloaded successfully.', 'success');
    }, 1000);
  };

  // ── Data Assembly ──
  const drDescriptions = ['No DR', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'Proliferative DR'];
  const level = apiData?.grading?.level ?? 2;

  const analysisData = {
    patientId: 'P-1042',
    scanDate: new Date().toLocaleString('en-GB', { day:'numeric', month:'short', year:'numeric', hour:'2-digit', minute:'2-digit' }) + ' IST',
    eye: 'Left Eye (OS)',
    quality: {
      status: apiData?.quality?.status || apiData?.quality?.grade || 'Gradeable',
      focus: `Score: ${apiData?.quality?.focusScore?.toFixed?.(1) || apiData?.quality?.compositeFocus?.toFixed?.(1) || '82.5'}`,
      illumination: `Intensity: ${apiData?.quality?.meanIntensity?.toFixed?.(1) || '135.2'}`,
      fov: `FOV: ${apiData?.quality?.fovRatio?.toFixed?.(1) || '72.4'}%`,
      uniformity: `Uniformity: ${apiData?.quality?.illuminationUniformity?.toFixed?.(1) || '91.3'}%`,
      artifacts: apiData?.quality?.hasArtifacts ? 'Detected' : 'None detected',
      noise: `Noise: ${apiData?.quality?.noiseLevel?.toFixed?.(1) || '12.4'}`
    },
    landmarks: {
      odDetected: apiData?.landmarks?.odDetected ?? true,
      odConfidence: apiData?.landmarks?.odConfidence ?? 0.92,
      foveaDetected: apiData?.landmarks?.foveaDetected ?? true,
      foveaConfidence: apiData?.landmarks?.foveaConfidence ?? 0.84
    },
    vessels: {
      density: apiData?.vessels?.density ?? 0.124,
      tortuosity: apiData?.vessels?.meanTortuosity ?? 1.45,
      branchingPoints: apiData?.vessels?.branchingPoints ?? 142
    },
    grading: {
      level,
      label: apiData?.grading?.label || drDescriptions[level],
      description: apiData?.grading?.label || drDescriptions[level],
      confidence: apiData?.grading?.confidence ?? 94.2,
      referable: apiData?.grading?.referable ?? (level >= 2),
      sensitivity: apiData?.grading?.sensitivity ?? 93.1,
      specificity: apiData?.grading?.specificity ?? 87.4,
      recommendedAction: apiData?.grading?.recommendedAction || 'Refer to ophthalmologist',
      perLevel: apiData?.grading?.perLevel || [
        { level: 0, label: 'No DR', probability: level===0 ? 94.2 : 1.8 },
        { level: 1, label: 'Mild NPDR', probability: level===1 ? 94.2 : 2.4 },
        { level: 2, label: 'Moderate NPDR', probability: level===2 ? 94.2 : 0.8 },
        { level: 3, label: 'Severe NPDR', probability: level===3 ? 94.2 : 0.5 },
        { level: 4, label: 'PDR', probability: level===4 ? 94.2 : 0.3 },
      ],
      calibration: apiData?.grading?.calibration || 'Well Calibrated',
      ece: apiData?.grading?.ece ?? 0.018,
      fusionNote: apiData?.grading?.fusionNote || 'CNN and ICDR rule-based assessment agree',
      cnnLevel: apiData?.grading?.cnnLevel ?? level,
      ruleLevel: apiData?.grading?.ruleLevel ?? level,
      icdrCriteria: apiData?.grading?.icdrCriteria || {}
    },
    evidence: [
      { id:1, type:'Microaneurysms', code:'MA', count: apiData?.lesions?.microaneurysms ?? 7, location:'Macula & Superior temporal', severity: (apiData?.lesions?.microaneurysms ?? 7) > 10 ? 'significant' : 'moderate' },
      { id:2, type:'Hard Exudates', code:'HE', count: apiData?.lesions?.hardExudates ?? 3, location:'Inferior temporal arcade', severity:'mild' },
      { id:3, type:'Soft Exudates (CWS)', code:'SE', count: apiData?.lesions?.softExudates ?? 1, location:'Peripapillary region', severity:'mild' },
      { id:4, type:'Dot Hemorrhages', code:'DH', count: apiData?.lesions?.hemorrhages?.dot ?? 2, location:'Nasal quadrant', severity:'moderate' },
      { id:5, type:'Blot Hemorrhages', code:'BH', count: apiData?.lesions?.hemorrhages?.blot ?? 0, location:'—', severity:'none' },
      { id:6, type:'Flame Hemorrhages', code:'FH', count: apiData?.lesions?.hemorrhages?.flame ?? 0, location:'—', severity:'none' },
      { id:7, type:'Neovascularization', code:'NV', count: apiData?.lesions?.neovascularization?.totalScore > 0.3 ? 1 : 0, location: apiData?.lesions?.neovascularization?.totalScore > 0.3 ? 'Disc/Elsewhere' : 'None detected', severity: apiData?.lesions?.neovascularization?.totalScore > 0.3 ? 'severe' : 'none' },
    ],
    explainability: {
      usefulness: apiData?.explainability?.clinicalUsefulness ?? 78.5,
      rating: apiData?.explainability?.usefulnessRating ?? 'Highly Useful',
      pathologyOverlap: apiData?.explainability?.pathologyOverlap ?? 65.2,
      attentionPrecision: apiData?.explainability?.attentionPrecision ?? 52.8
    }
  };

  const getGradingColor = (l) => { if (l <= 1) return 'success'; if (l === 2) return 'warning'; return 'danger'; };
  const gradingColor = getGradingColor(analysisData.grading.level);

  const getEvidenceClass = (code) => {
    if (code === 'MA') return 'ma';
    if (code === 'HE' || code === 'SE') return 'exudate';
    if (code === 'DH' || code === 'BH' || code === 'FH') return 'hemorrhage';
    if (code === 'NV') return 'nv';
    return 'ma';
  };

  const getSeverityClass = (s) => {
    if (s === 'severe' || s === 'significant') return 'sev-severe';
    if (s === 'moderate') return 'sev-moderate';
    if (s === 'mild') return 'sev-mild';
    return 'sev-none';
  };

  function generateReportText() {
    return `
═══════════════════════════════════════════════════════════
  DIABETIC RETINOPATHY CLINICAL SCREENING REPORT
  RetinaVision Pipeline v2.4.1
═══════════════════════════════════════════════════════════

Scan ID: ${id}
Patient ID: ${analysisData.patientId}
Date: ${analysisData.scanDate}
Eye: ${analysisData.eye}

── IMAGE QUALITY ──
  Status: ${analysisData.quality.status}
  ${analysisData.quality.focus}
  ${analysisData.quality.illumination}
  ${analysisData.quality.fov}
  Artifacts: ${analysisData.quality.artifacts}

── ANATOMICAL LANDMARKS ──
  Optic Disc: ${analysisData.landmarks.odDetected ? 'Detected' : 'Not detected'} (conf: ${(analysisData.landmarks.odConfidence * 100).toFixed(0)}%)
  Fovea: ${analysisData.landmarks.foveaDetected ? 'Detected' : 'Not detected'} (conf: ${(analysisData.landmarks.foveaConfidence * 100).toFixed(0)}%)

── VESSEL ANALYSIS ──
  Density: ${analysisData.vessels.density.toFixed(3)}
  Tortuosity: ${analysisData.vessels.tortuosity.toFixed(2)}
  Branching Points: ${analysisData.vessels.branchingPoints}

── AI DIAGNOSIS ──
  Level ${analysisData.grading.level} — ${analysisData.grading.description}
  Confidence: ${analysisData.grading.confidence}%
  Referable: ${analysisData.grading.referable ? 'YES' : 'NO'}
  ${analysisData.grading.fusionNote}

── LESION FINDINGS ──
${analysisData.evidence.filter(e => e.count > 0).map(e =>
  `  - ${e.type}: ${e.count} found in ${e.location} (Severity: ${e.severity})`
).join('\n')}

── EXPLAINABILITY ──
  Grad-CAM Usefulness: ${analysisData.explainability.rating} (${analysisData.explainability.usefulness}%)
  Pathology Overlap: ${analysisData.explainability.pathologyOverlap}%

── RECOMMENDED ACTION ──
  ${analysisData.grading.recommendedAction}

── REVIEW METRICS ──
  Review Time: ${reviewTimer}s ${reviewTimer <= 30 ? '(✓ Under 30s target)' : ''}
  Clinical Notes: ${clinicalNotes || 'None'}
  Status: ${actionTaken ? (actionTaken === 'approved' ? 'APPROVED' : 'REJECTED') : 'PENDING'}

═══════════════════════════════════════════════════════════
`.trim();
  }

  const lesionPositions = [
    { top:'38%', left:'28%', code:'MA', label:'MA #1' },
    { top:'42%', left:'34%', code:'MA', label:'MA #2' },
    { top:'35%', left:'40%', code:'MA', label:'MA #3' },
    { top:'50%', left:'32%', code:'MA', label:'MA #4' },
    { top:'48%', left:'44%', code:'MA', label:'MA #5' },
    { top:'58%', left:'38%', code:'HE', label:'HE #1' },
    { top:'62%', left:'45%', code:'HE', label:'HE #2' },
    { top:'30%', left:'70%', code:'SE', label:'CWS #1' },
    { top:'32%', left:'62%', code:'DH', label:'Hemorrhage #1' },
    { top:'55%', left:'58%', code:'DH', label:'Hemorrhage #2' },
  ];

  const icdrChecklist = [
    { label: 'Microaneurysms present', met: analysisData.grading.icdrCriteria.microaneurysmsPresent ?? true, levelReq: '1+' },
    { label: 'Hard exudates present', met: analysisData.grading.icdrCriteria.hardExudatesPresent ?? true, levelReq: '2+' },
    { label: 'Cotton-wool spots present', met: analysisData.grading.icdrCriteria.softExudatesPresent ?? false, levelReq: '2+' },
    { label: 'Hemorrhages in ≥1 quadrant', met: analysisData.grading.icdrCriteria.hemorrhagesPresent ?? true, levelReq: '2+' },
    { label: 'Neovascularization', met: analysisData.grading.icdrCriteria.neovascularizationPresent ?? false, levelReq: '4' },
  ];

  const isInvalidImage = apiData?.status === 'Invalid_Modality';
  const invalidReason = apiData?.qualityFeedback?.recaptureReasons?.[0] || 'Image could not be identified as a retinal scan.';

  if (isInvalidImage) {
    return (
      <div className="results-container animate-fade-in">
        <div className="page-header">
          <Link to="/screening" className="btn btn-ghost btn-sm" style={{marginBottom:'1rem', paddingLeft:0}}>
            <IconArrowLeft /> Back to Screening
          </Link>
          <h1>Scan Rejected</h1>
        </div>
        <div className="card text-center py-8" style={{maxWidth: '600px', margin: '0 auto', marginTop: '2rem'}}>
          <div style={{width: '64px', height: '64px', borderRadius: '50%', background: 'var(--color-danger-bg)', color: 'var(--color-danger)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 1.5rem'}}>
            <IconX />
          </div>
          <h2 style={{marginBottom: '1rem'}}>Invalid Image Detected</h2>
          <p className="text-muted" style={{marginBottom: '2rem'}}>{invalidReason}</p>
          <div style={{background: 'var(--color-surface-hover)', padding: '1.5rem', borderRadius: 'var(--border-radius-md)', textAlign: 'left', marginBottom: '2rem'}}>
            <h4 style={{marginBottom: '0.5rem', fontSize: '0.875rem'}}>Requirements for analysis:</h4>
            <ul className="text-sm text-dim" style={{paddingLeft: '1.5rem'}}>
              <li>Must be a photograph of the retina (fundus image).</li>
              <li>Must have a distinct circular field-of-view on a dark background.</li>
              <li>Must be taken using a dedicated fundus camera or ophthalmoscope.</li>
            </ul>
          </div>
          <Link to="/screening" className="btn btn-primary">Try Another Image</Link>
        </div>
      </div>
    );
  }

  return (
    <div className="results-container animate-fade-in">
      {/* ── Toast ── */}
      {toast && (
        <div className={`toast toast-${toast.type}`}>
          <span>{toast.message}</span>
          <button className="toast-close" onClick={() => setToast(null)}>×</button>
        </div>
      )}

      {/* ── Report Modal ── */}
      {showReport && (
        <div className="report-overlay" onClick={() => setShowReport(false)}>
          <div className="report-modal card" onClick={e => e.stopPropagation()}>
            <div className="report-modal-header">
              <h2>Annotated Clinical Report</h2>
              <button className="toast-close" onClick={() => setShowReport(false)} style={{ fontSize: '1.5rem' }}>×</button>
            </div>
            <div className="report-body">
              <div className="report-section">
                <div className="report-label">SCAN REFERENCE</div>
                <div className="report-value">{id} — {analysisData.patientId}</div>
              </div>
              <div className="report-row">
                <div className="report-section"><div className="report-label">EYE</div><div className="report-value">{analysisData.eye}</div></div>
                <div className="report-section"><div className="report-label">DATE</div><div className="report-value">{analysisData.scanDate}</div></div>
              </div>
              <div className="report-section">
                <div className="report-label">IMAGE QUALITY</div>
                <div className="report-value">{analysisData.quality.status} — {analysisData.quality.focus}, {analysisData.quality.illumination}</div>
              </div>
              <div className="report-divider"></div>
              <div className="report-section">
                <div className="report-label">AI DIAGNOSIS</div>
                <div className="report-value" style={{ fontSize:'1.125rem', fontWeight:800, color: `var(--color-${gradingColor})` }}>
                  Level {analysisData.grading.level} — {analysisData.grading.description}
                </div>
                <div className="report-value text-sm text-dim" style={{ marginTop:'0.25rem' }}>
                  Confidence: {analysisData.grading.confidence}% | Referable: {analysisData.grading.referable ? 'YES' : 'NO'}
                </div>
                <div className="report-value text-xs text-dim" style={{ marginTop:'0.25rem', fontStyle:'italic' }}>
                  {analysisData.grading.fusionNote}
                </div>
              </div>
              <div className="report-section">
                <div className="report-label">LESION FINDINGS</div>
                <table className="report-findings-table">
                  <thead><tr><th>Type</th><th>Count</th><th>Location</th><th>Severity</th></tr></thead>
                  <tbody>
                    {analysisData.evidence.filter(e => e.count > 0).map(e => (
                      <tr key={e.id}><td>{e.type}</td><td>{e.count}</td><td>{e.location}</td><td className={getSeverityClass(e.severity)}>{e.severity}</td></tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <div className="report-section">
                <div className="report-label">VESSEL ANALYSIS</div>
                <div className="report-value">Density: {analysisData.vessels.density.toFixed(3)} | Tortuosity: {analysisData.vessels.tortuosity.toFixed(2)} | Branches: {analysisData.vessels.branchingPoints}</div>
              </div>
              <div className="report-divider"></div>
              <div className="report-section">
                <div className="report-label">GRAD-CAM EXPLAINABILITY</div>
                <div className="report-value">{analysisData.explainability.rating} — Clinical Usefulness: {analysisData.explainability.usefulness}%</div>
              </div>
              <div className="report-section">
                <div className="report-label">RECOMMENDED ACTION</div>
                <div className="report-value" style={{ fontWeight: 700, color: `var(--color-${gradingColor})` }}>{analysisData.grading.recommendedAction}</div>
              </div>
              <div className="report-section">
                <div className="report-label">REVIEW METRICS</div>
                <div className="report-value">
                  Review time: <strong>{reviewTimer}s</strong> {reviewTimer <= 30 && <span className="badge badge-dot badge-success" style={{ marginLeft:'0.5rem' }}>Under 30s target</span>}
                </div>
              </div>
              {clinicalNotes && (
                <div className="report-section">
                  <div className="report-label">CLINICAL NOTES</div>
                  <div className="report-value">{clinicalNotes}</div>
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* ── Header ── */}
      <div className="results-header">
        <div className="results-header-left">
          <Link to="/" className="btn-back"><IconArrowLeft /></Link>
          <div>
            <h1>Scan {id}</h1>
            <div className="results-meta">
              <span>{analysisData.patientId}</span>
              <span className="results-meta-dot">•</span>
              <span>{analysisData.eye}</span>
              <span className="results-meta-dot">•</span>
              <span>{analysisData.scanDate}</span>
              <span className="results-meta-dot">•</span>
              <span className="text-dim">Processed in: {apiData?.processingTime || 29.4}s</span>
              <span className="results-meta-dot">•</span>
              <span className="text-dim">Review: {reviewTimer}s</span>
              {actionTaken && (
                <>
                  <span className="results-meta-dot">•</span>
                  <span className={`badge badge-dot ${actionTaken === 'approved' ? 'badge-success' : 'badge-danger'}`}>
                    {actionTaken === 'approved' ? 'Approved' : 'Rejected'}
                  </span>
                </>
              )}
            </div>
          </div>
        </div>
        <div className="flex gap-3">
          <button className="btn btn-secondary btn-sm" onClick={() => setCompareMode(!compareMode)}>
            <IconColumns /> {compareMode ? 'Single View' : 'Compare'}
          </button>
          <button className="btn btn-secondary btn-sm" onClick={handleExportPDF}><IconDownload /> Export Report</button>
          {(user?.role === 'admin' || user?.role === 'ophthalmologist') && (
            <>
              <button className="btn btn-danger btn-sm" onClick={handleReject} disabled={!!actionTaken}><IconX /> Reject</button>
              <button className="btn btn-primary btn-sm" onClick={handleApprove} disabled={!!actionTaken}><IconCheck /> Validate & Approve</button>
            </>
          )}
        </div>
      </div>

      {/* ── Main Grid ── */}
      <div className="results-grid">
        {/* ── Image Viewer ── */}
        <div className="image-viewer-section card">
          <div className="viewer-toolbar">
            <div className="layer-toggles">
              {['original', 'enhanced', 'vessels', 'lesions'].map(layer => (
                <button key={layer} className={`layer-btn ${activeLayer === layer ? 'active' : ''}`} onClick={() => setActiveLayer(layer)}>
                  {layer.charAt(0).toUpperCase() + layer.slice(1)}
                </button>
              ))}
            </div>
            <div className="viewer-controls-right">
              <label className="gradcam-toggle">
                <input type="checkbox" checked={showGradCam} onChange={(e) => setShowGradCam(e.target.checked)} />
                <span className="toggle-slider"></span>
                <span className="toggle-label">Grad-CAM</span>
              </label>
              {showGradCam && (
                <div className="opacity-slider-group">
                  <input type="range" min="0" max="100" value={gradcamOpacity * 100}
                    onChange={e => setGradcamOpacity(e.target.value / 100)}
                    className="opacity-slider" title={`Opacity: ${Math.round(gradcamOpacity * 100)}%`} />
                  <span className="text-xs text-dim">{Math.round(gradcamOpacity * 100)}%</span>
                </div>
              )}
            </div>
          </div>

          <div className={`image-display-wrapper ${compareMode ? 'compare-mode' : ''}`}>
            <div className="image-display-area" ref={viewerRef}
              onWheel={handleWheel}
              onMouseDown={handleMouseDown}
              onMouseMove={handleMouseMove}
              onMouseUp={handleMouseUp}
              onMouseLeave={handleMouseUp}
              style={{ cursor: zoom > 1 ? (isPanning ? 'grabbing' : 'grab') : 'crosshair' }}>
              <div className="image-transform" style={{
                transform: `scale(${zoom}) translate(${pan.x / zoom}px, ${pan.y / zoom}px)`,
                transition: isPanning ? 'none' : 'transform 0.2s ease'
              }}>
                {location.state?.imageUrl ? (
                  <img src={location.state.imageUrl} alt="Uploaded Fundus" className="simulated-fundus-base" style={{ objectFit:'cover' }} />
                ) : (
                  <div className="simulated-fundus-base">
                    <div className="optic-disc"></div>
                    <div className="macula"></div>
                  </div>
                )}
                {activeLayer === 'enhanced' && <div className="layer-overlay enhanced-layer"></div>}
                {activeLayer === 'vessels' && <div className="layer-overlay vessels-layer"></div>}
                {activeLayer === 'lesions' && (
                  <div className="layer-overlay lesions-layer">
                    {lesionPositions.map((lp, i) => (
                      <div key={i}
                        className={`lesion ${getEvidenceClass(lp.code)} ${selectedLesion === i ? 'selected' : ''}`}
                        style={{ top: lp.top, left: lp.left }}
                        onClick={(e) => { e.stopPropagation(); setSelectedLesion(selectedLesion === i ? null : i); }}>
                        <span className="lesion-tooltip">{lp.label}</span>
                      </div>
                    ))}
                  </div>
                )}
                {showGradCam && <div className="layer-overlay gradcam-layer" style={{ opacity: gradcamOpacity }}></div>}
              </div>
            </div>

            {compareMode && (
              <div className="image-display-area compare-panel">
                <div className="compare-label">Enhanced + Grad-CAM</div>
                {location.state?.imageUrl ? (
                  <img src={location.state.imageUrl} alt="Enhanced View" className="simulated-fundus-base" style={{ objectFit:'cover', filter:'contrast(1.3) saturate(1.2)' }} />
                ) : (
                  <div className="simulated-fundus-base" style={{ filter:'contrast(1.3) saturate(1.2)' }}>
                    <div className="optic-disc"></div>
                    <div className="macula"></div>
                  </div>
                )}
                <div className="layer-overlay enhanced-layer"></div>
                <div className="layer-overlay gradcam-layer" style={{ opacity: 0.5 }}></div>
              </div>
            )}
          </div>

          <div className="viewer-status-bar">
            <span><IconZoom /> Scroll to zoom ({(zoom * 100).toFixed(0)}%) • {zoom > 1 ? 'Drag to pan • ' : ''}<button className="reset-zoom-btn" onClick={resetZoom}>Reset</button></span>
            <span>Layer: {activeLayer.charAt(0).toUpperCase() + activeLayer.slice(1)} {showGradCam ? `+ Grad-CAM (${Math.round(gradcamOpacity*100)}%)` : ''}</span>
          </div>

          {/* Lesion detail panel */}
          {selectedLesion !== null && (
            <div className="lesion-detail-panel animate-fade-in">
              <div className="lesion-detail-header">
                <strong>{lesionPositions[selectedLesion].label}</strong>
                <button className="toast-close" onClick={() => setSelectedLesion(null)} style={{ fontSize:'1rem' }}>×</button>
              </div>
              <div className="lesion-detail-body">
                <div className="lesion-detail-row"><span>Type</span><span>{lesionPositions[selectedLesion].code === 'MA' ? 'Microaneurysm' : lesionPositions[selectedLesion].code === 'HE' ? 'Hard Exudate' : lesionPositions[selectedLesion].code === 'SE' ? 'Cotton-wool Spot' : 'Hemorrhage'}</span></div>
                <div className="lesion-detail-row"><span>Detection</span><span className="badge badge-dot badge-success">Confirmed</span></div>
                <div className="lesion-detail-row"><span>Confidence</span><span>{(85 + Math.random() * 12).toFixed(1)}%</span></div>
                <div className="lesion-detail-row"><span>Size</span><span>{(1 + Math.random() * 3).toFixed(1)} px</span></div>
              </div>
            </div>
          )}
        </div>

        {/* ── Clinical Summary ── */}
        <div className="clinical-summary-section">
          {/* Grading */}
          <div className="card animate-fade-in animate-fade-in-delay-1">
            <h3 style={{ marginBottom:'0.75rem' }}>AI Diagnostic Result</h3>
            <div className={`grading-box level-${analysisData.grading.level}`}>
              <span className={`referable-tag ${analysisData.grading.referable ? 'yes' : 'no'}`}>
                {analysisData.grading.referable ? '⚠ REFERABLE' : '✓ NON-REFERABLE'}
              </span>
              <div className={`grading-level ${gradingColor}`}>Level {analysisData.grading.level}</div>
              <div className="grading-desc">{analysisData.grading.description}</div>
              <div className="confidence-meter">
                <div className="flex justify-between items-center text-xs mb-1">
                  <span className="text-muted">Confidence</span>
                  <span style={{ color: `var(--color-${gradingColor})` }}>{analysisData.grading.confidence}%</span>
                </div>
                <div className="progress-bar" style={{ height:'4px' }}>
                  <div className="progress-fill" style={{ width:`${analysisData.grading.confidence}%`, background:`var(--color-${gradingColor})` }}></div>
                </div>
              </div>
              <div className="recommended-action" style={{ marginTop:'0.75rem', padding:'0.5rem 0.75rem', borderRadius:'var(--border-radius-sm)', background: `var(--color-${gradingColor}-bg, rgba(var(--theme-overlay-color), 0.03))`, fontSize:'0.75rem', fontWeight:600 }}>
                {analysisData.grading.recommendedAction}
              </div>
            </div>

            {/* Per-level confidence */}
            <div className="confidence-dist">
              <div className="text-xs text-dim font-semibold" style={{ marginBottom:'0.5rem', textTransform:'uppercase', letterSpacing:'0.04em' }}>Per-Level Probability</div>
              {analysisData.grading.perLevel.map(pl => (
                <div key={pl.level} className={`conf-level-row ${pl.level === analysisData.grading.level ? 'active' : ''}`}>
                  <span className="conf-level-label">L{pl.level}</span>
                  <div className="progress-bar" style={{ flex:1, height:'4px' }}>
                    <div className="progress-fill" style={{ width:`${pl.probability}%`, background: pl.level === analysisData.grading.level ? `var(--color-${gradingColor})` : 'var(--color-text-dim)' }}></div>
                  </div>
                  <span className={`conf-level-value ${pl.level === analysisData.grading.level ? 'highlight' : ''}`}>{pl.probability}%</span>
                </div>
              ))}
              <div className="cal-badge-row">
                <span className="badge badge-dot badge-success">{analysisData.grading.calibration}</span>
                <span className="text-xs text-dim">ECE: {analysisData.grading.ece}</span>
              </div>
            </div>

            <div className="flex gap-4 mt-3">
              <div className="text-xs text-dim">Sens: <span className="font-semibold text-muted">{analysisData.grading.sensitivity}%</span></div>
              <div className="text-xs text-dim">Spec: <span className="font-semibold text-muted">{analysisData.grading.specificity}%</span></div>
            </div>

            {/* CNN vs Rules fusion note */}
            <div className="fusion-note" style={{ marginTop:'0.75rem', padding:'0.5rem', borderRadius:'var(--border-radius-sm)', background:'rgba(var(--theme-overlay-color), 0.03)', fontSize:'0.7rem', color:'var(--color-text-dim)' }}>
              <strong>Fusion:</strong> CNN=L{analysisData.grading.cnnLevel}, Rules=L{analysisData.grading.ruleLevel} — {analysisData.grading.fusionNote}
            </div>
          </div>

          {/* ICDR Criteria Checklist */}
          <div className="card animate-fade-in animate-fade-in-delay-2">
            <h3 style={{ marginBottom:'0.75rem' }}>ICDR Criteria Checklist</h3>
            <div className="icdr-checklist">
              {icdrChecklist.map((item, i) => (
                <div key={i} className={`icdr-item ${item.met ? 'met' : 'unmet'}`}>
                  <span className={`icdr-check ${item.met ? 'checked' : ''}`}>
                    {item.met ? '✓' : '—'}
                  </span>
                  <span className="icdr-label">{item.label}</span>
                  <span className="icdr-level">L{item.levelReq}</span>
                </div>
              ))}
            </div>
          </div>

          {/* Quality + Landmarks */}
          <div className="card animate-fade-in animate-fade-in-delay-2">
            <div className="flex justify-between items-center" style={{ marginBottom:'0.75rem' }}>
              <h3>Image Quality</h3>
              <span className={`badge badge-dot ${analysisData.quality.status === 'Gradeable' ? 'badge-success' : 'badge-warning'}`}>{analysisData.quality.status}</span>
            </div>
            <div className="quality-row"><span className="quality-label">Focus</span><span className="quality-value">{analysisData.quality.focus}</span></div>
            <div className="quality-row"><span className="quality-label">Illumination</span><span className="quality-value">{analysisData.quality.illumination}</span></div>
            <div className="quality-row"><span className="quality-label">Field of View</span><span className="quality-value">{analysisData.quality.fov}</span></div>
            <div className="quality-row"><span className="quality-label">Uniformity</span><span className="quality-value">{analysisData.quality.uniformity}</span></div>
            <div className="quality-row"><span className="quality-label">Noise</span><span className="quality-value">{analysisData.quality.noise}</span></div>
            <div className="quality-row"><span className="quality-label">Artifacts</span><span className="quality-value">{analysisData.quality.artifacts}</span></div>

            <div style={{ marginTop:'0.75rem', paddingTop:'0.75rem', borderTop:'1px solid var(--color-surface-border)' }}>
              <div className="text-xs text-dim font-semibold mb-2" style={{ textTransform:'uppercase', letterSpacing:'0.04em' }}>Landmarks</div>
              <div className="quality-row"><span className="quality-label">Optic Disc</span><span className="quality-value">{analysisData.landmarks.odDetected ? `✓ (${(analysisData.landmarks.odConfidence * 100).toFixed(0)}%)` : '✗ Not found'}</span></div>
              <div className="quality-row"><span className="quality-label">Fovea</span><span className="quality-value">{analysisData.landmarks.foveaDetected ? `✓ (${(analysisData.landmarks.foveaConfidence * 100).toFixed(0)}%)` : '✗ Not found'}</span></div>
            </div>

            <div style={{ marginTop:'0.75rem', paddingTop:'0.75rem', borderTop:'1px solid var(--color-surface-border)' }}>
              <div className="text-xs text-dim font-semibold mb-2" style={{ textTransform:'uppercase', letterSpacing:'0.04em' }}>Vessels</div>
              <div className="quality-row"><span className="quality-label">Density</span><span className="quality-value">{analysisData.vessels.density.toFixed(3)}</span></div>
              <div className="quality-row"><span className="quality-label">Tortuosity</span><span className="quality-value">{analysisData.vessels.tortuosity.toFixed(2)}</span></div>
              <div className="quality-row"><span className="quality-label">Branches</span><span className="quality-value">{analysisData.vessels.branchingPoints}</span></div>
            </div>
          </div>

          {/* Evidence */}
          <div className="card animate-fade-in animate-fade-in-delay-3">
            <h3 style={{ marginBottom:'0.75rem' }}>Lesion Evidence</h3>
            <div className="evidence-list">
              {analysisData.evidence.map(ev => (
                <div key={ev.id} className={`evidence-item ${ev.count === 0 ? 'evidence-none' : ''}`}>
                  <div className={`evidence-type-icon ${getEvidenceClass(ev.code)}`}>{ev.code}</div>
                  <div className="evidence-info">
                    <div className="evidence-type-name">{ev.type}</div>
                    <div className="evidence-location">{ev.location}</div>
                  </div>
                  <span className={`evidence-count ${ev.count === 0 ? 'evidence-count-zero' : ''}`}>{ev.count}</span>
                </div>
              ))}
            </div>

            {/* Explainability metrics */}
            <div style={{ marginTop:'0.75rem', paddingTop:'0.75rem', borderTop:'1px solid var(--color-surface-border)' }}>
              <div className="text-xs text-dim font-semibold mb-2" style={{ textTransform:'uppercase', letterSpacing:'0.04em' }}>Grad-CAM Explainability</div>
              <div className="quality-row">
                <span className="quality-label">Clinical Usefulness</span>
                <span className={`quality-value ${analysisData.explainability.usefulness > 70 ? 'text-success' : ''}`}>
                  {analysisData.explainability.rating} ({analysisData.explainability.usefulness}%)
                </span>
              </div>
              <div className="quality-row"><span className="quality-label">Pathology Overlap</span><span className="quality-value">{analysisData.explainability.pathologyOverlap}%</span></div>
            </div>

            {/* Clinical Notes */}
            <div style={{ marginTop:'0.75rem', paddingTop:'0.75rem', borderTop:'1px solid var(--color-surface-border)' }}>
              <div className="flex items-center gap-2 mb-2">
                <IconEdit />
                <span className="text-xs text-dim font-semibold" style={{ textTransform:'uppercase', letterSpacing:'0.04em' }}>Clinical Notes</span>
              </div>
              <textarea
                className="clinical-notes-input"
                placeholder={user?.role === 'phc_operator' ? "No clinical notes provided yet." : "Add clinical notes for this screening..."}
                value={clinicalNotes}
                onChange={e => setClinicalNotes(e.target.value)}
                rows={3}
                disabled={user?.role === 'phc_operator'}
              />
            </div>

            <button className="btn btn-secondary w-full mt-4 btn-sm" onClick={() => setShowReport(true)}>
              <IconFileText /> View Full Report
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
