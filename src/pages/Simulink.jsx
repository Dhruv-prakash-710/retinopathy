import { useState, useMemo } from 'react';
import './Simulink.css';

/* ── Icons ── */
const IconSliders = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><line x1="4" y1="21" x2="4" y2="14"/><line x1="4" y1="10" x2="4" y2="3"/><line x1="12" y1="21" x2="12" y2="12"/><line x1="12" y1="8" x2="12" y2="3"/><line x1="20" y1="21" x2="20" y2="16"/><line x1="20" y1="12" x2="20" y2="3"/><line x1="1" y1="14" x2="7" y2="14"/><line x1="9" y1="8" x2="15" y2="8"/><line x1="17" y1="16" x2="23" y2="16"/></svg>
);
const IconActivity = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>
);
const IconAlertTriangle = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"/><path d="M12 9v4"/><path d="M12 17h.01"/></svg>
);
const IconCheckCircle = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
);
const IconClock = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
);
const IconWifi = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M5 12.55a11 11 0 0 1 14.08 0"/><path d="M1.42 9a16 16 0 0 1 21.16 0"/><path d="M8.53 16.11a6 6 0 0 1 6.95 0"/><line x1="12" y1="20" x2="12.01" y2="20"/></svg>
);
const IconServer = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="2" y="2" width="20" height="8" rx="2" ry="2"/><rect x="2" y="14" width="20" height="8" rx="2" ry="2"/><line x1="6" y1="6" x2="6.01" y2="6"/><line x1="6" y1="18" x2="6.01" y2="18"/></svg>
);
const IconUsers = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
);
const IconArrowRight = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M5 12h14"/><path d="m12 5 7 7-7 7"/></svg>
);
const IconZap = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>
);
const IconTarget = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="6"/><circle cx="12" cy="12" r="2"/></svg>
);

const PHCS_DATA = [
  { name: 'PHC Rampur', district: 'Rampur', state: 'UP', dailyCapacity: 60, bandwidth: 2 },
  { name: 'PHC Bareilly', district: 'Bareilly', state: 'UP', dailyCapacity: 45, bandwidth: 1.5 },
  { name: 'PHC Shahjahanpur', district: 'Shahjahanpur', state: 'UP', dailyCapacity: 35, bandwidth: 1 },
  { name: 'PHC Pilibhit', district: 'Pilibhit', state: 'UP', dailyCapacity: 40, bandwidth: 2 },
  { name: 'PHC Lakhimpur', district: 'Lakhimpur Kheri', state: 'UP', dailyCapacity: 30, bandwidth: 0.5 },
  { name: 'PHC Sitapur', district: 'Sitapur', state: 'UP', dailyCapacity: 50, bandwidth: 2 },
  { name: 'PHC Hardoi', district: 'Hardoi', state: 'UP', dailyCapacity: 25, bandwidth: 0.5 },
  { name: 'PHC Unnao', district: 'Unnao', state: 'UP', dailyCapacity: 55, bandwidth: 3 },
  { name: 'PHC Lucknow Rural', district: 'Lucknow', state: 'UP', dailyCapacity: 70, bandwidth: 5 },
  { name: 'PHC Kanpur Dehat', district: 'Kanpur Dehat', state: 'UP', dailyCapacity: 38, bandwidth: 1 },
];

const PRESETS = [
  { label: 'Small Rural', phcs: 3, img: 30, bw: 1, gpu: 100, docs: 1, icon: '🏘️', desc: '3 PHCs · Low bandwidth' },
  { label: 'Medium District', phcs: 8, img: 50, bw: 2, gpu: 200, docs: 3, icon: '🏥', desc: '8 PHCs · Standard setup' },
  { label: 'Large Urban', phcs: 15, img: 80, bw: 5, gpu: 500, docs: 5, icon: '🏙️', desc: '15 PHCs · High throughput' },
];

export default function Simulink() {
  const [numPHCs, setNumPHCs] = useState(8);
  const [imagesPerPHC, setImagesPerPHC] = useState(50);
  const [avgBandwidth, setAvgBandwidth] = useState(2);
  const [gpuCapacity, setGpuCapacity] = useState(200);
  const [numDoctors, setNumDoctors] = useState(3);
  const [avgImageSizeMB, setAvgImageSizeMB] = useState(5);
  const [reviewTimeSeconds, setReviewTimeSeconds] = useState(28);
  const [operatingHours, setOperatingHours] = useState(8);
  const [referableRate, setReferableRate] = useState(18);
  const [activePreset, setActivePreset] = useState('Medium District');

  const sim = useMemo(() => {
    const dailyImages = numPHCs * imagesPerPHC;
    const annualImages = dailyImages * 300;
    const annualPatients = annualImages;
    const uploadTimePerImage = (avgImageSizeMB * 8) / avgBandwidth;
    const maxImagesPerPHCBandwidth = Math.floor((operatingHours * 3600) / uploadTimePerImage);
    const bandwidthLimited = imagesPerPHC > maxImagesPerPHCBandwidth;
    const gpuTimePerImage = 12.4;
    const maxGPUDaily = Math.floor((operatingHours * 3600) / gpuTimePerImage);
    const gpuUtilization = Math.min((dailyImages / Math.max(gpuCapacity * operatingHours / 8, 1)) * 100, 100);
    const gpuLimited = dailyImages > maxGPUDaily;
    const referableCases = Math.ceil(dailyImages * (referableRate / 100));
    const maxReviewsPerDoctor = Math.floor((operatingHours * 3600) / reviewTimeSeconds);
    const totalReviewCapacity = numDoctors * maxReviewsPerDoctor;
    const doctorUtilization = Math.min((referableCases / Math.max(totalReviewCapacity, 1)) * 100, 100);
    const doctorLimited = referableCases > totalReviewCapacity;
    const avgLatency = uploadTimePerImage + gpuTimePerImage + (doctorLimited ? reviewTimeSeconds * 2 : reviewTimeSeconds);

    let bottleneck = 'none';
    let bottleneckLabel = 'No bottleneck — system operating within capacity';
    let bottleneckSeverity = 'success';
    if (bandwidthLimited) { bottleneck = 'bandwidth'; bottleneckLabel = `Bandwidth constrained: ${avgBandwidth} Mbps insufficient for ${imagesPerPHC} images/PHC/day`; bottleneckSeverity = 'danger'; }
    else if (gpuLimited) { bottleneck = 'gpu'; bottleneckLabel = `GPU overloaded: ${dailyImages} images/day exceeds ${maxGPUDaily} capacity`; bottleneckSeverity = 'danger'; }
    else if (doctorLimited) { bottleneck = 'doctors'; bottleneckLabel = `Review bottleneck: ${referableCases} referable cases exceed ${totalReviewCapacity} review slots`; bottleneckSeverity = 'warning'; }

    const queueHistory = [];
    let queue = 0;
    for (let hour = 0; hour < operatingHours; hour++) {
      const incoming = dailyImages / operatingHours;
      const processed = Math.min(queue + incoming, maxGPUDaily / operatingHours);
      queue = Math.max(0, queue + incoming - processed);
      queueHistory.push({ hour: hour + 1, depth: Math.round(queue) });
    }

    const annualTarget = 100000;
    const targetProgress = Math.min((annualPatients / annualTarget) * 100, 100);

    // Health score (0-100)
    const bwScore = bandwidthLimited ? 30 : 100;
    const gpuScore = gpuLimited ? 20 : Math.max(0, 100 - parseFloat(gpuUtilization));
    const docScore = doctorLimited ? 20 : Math.max(0, 100 - parseFloat(doctorUtilization));
    const healthScore = Math.round((bwScore + gpuScore + docScore) / 3);

    return {
      dailyImages, annualImages, annualPatients,
      uploadTimePerImage: uploadTimePerImage.toFixed(1), maxImagesPerPHCBandwidth, bandwidthLimited,
      gpuUtilization: gpuUtilization.toFixed(1), gpuLimited, maxGPUDaily,
      referableCases, totalReviewCapacity, doctorUtilization: doctorUtilization.toFixed(1), doctorLimited,
      avgLatency: avgLatency.toFixed(1), bottleneck, bottleneckLabel, bottleneckSeverity,
      queueHistory, annualTarget, targetProgress: targetProgress.toFixed(1),
      healthScore,
    };
  }, [numPHCs, imagesPerPHC, avgBandwidth, gpuCapacity, numDoctors, avgImageSizeMB, reviewTimeSeconds, operatingHours, referableRate]);

  const pipelineStages = [
    { label: 'Image Acquisition', icon: '📷', sublabel: `${sim.dailyImages} img/day`, status: sim.bandwidthLimited ? 'warning' : 'ok' },
    { label: 'Upload & Transfer', icon: '📡', sublabel: `${sim.uploadTimePerImage}s/img`, status: sim.bandwidthLimited ? 'error' : 'ok' },
    { label: 'Quality Gate', icon: '🔍', sublabel: '~4.2% reject', status: 'ok' },
    { label: 'AI Processing', icon: '🧠', sublabel: `${sim.gpuUtilization}% GPU`, status: sim.gpuLimited ? 'error' : parseFloat(sim.gpuUtilization) > 80 ? 'warning' : 'ok' },
    { label: 'Doctor Review', icon: '🩺', sublabel: `${sim.referableCases} cases`, status: sim.doctorLimited ? 'error' : parseFloat(sim.doctorUtilization) > 80 ? 'warning' : 'ok' },
    { label: 'Patient Report', icon: '📋', sublabel: 'Auto-gen', status: 'ok' },
  ];

  const paramGroups = [
    {
      title: 'Infrastructure',
      icon: '🏗️',
      params: [
        { label: 'Number of PHCs', value: numPHCs, set: setNumPHCs, min: 1, max: 50, step: 1, unit: '' },
        { label: 'Images per PHC / Day', value: imagesPerPHC, set: setImagesPerPHC, min: 10, max: 200, step: 5, unit: '' },
        { label: 'Avg Bandwidth (Mbps)', value: avgBandwidth, set: setAvgBandwidth, min: 0.5, max: 10, step: 0.5, unit: '' },
      ],
    },
    {
      title: 'Processing',
      icon: '⚡',
      params: [
        { label: 'GPU Capacity (img/8hr)', value: gpuCapacity, set: setGpuCapacity, min: 50, max: 2000, step: 50, unit: '' },
        { label: 'Image Size (MB)', value: avgImageSizeMB, set: setAvgImageSizeMB, min: 1, max: 20, step: 1, unit: '' },
      ],
    },
    {
      title: 'Clinical',
      icon: '🩻',
      params: [
        { label: 'Reviewing Doctors', value: numDoctors, set: setNumDoctors, min: 1, max: 20, step: 1, unit: '' },
        { label: 'Review Time (sec)', value: reviewTimeSeconds, set: setReviewTimeSeconds, min: 10, max: 120, step: 2, unit: 's' },
        { label: 'Operating Hours / Day', value: operatingHours, set: setOperatingHours, min: 4, max: 16, step: 1, unit: 'h' },
        { label: 'Referable DR Rate (%)', value: referableRate, set: setReferableRate, min: 5, max: 40, step: 1, unit: '%' },
      ],
    },
  ];

  const healthColor = sim.healthScore >= 70 ? 'var(--color-success)' : sim.healthScore >= 40 ? 'var(--color-warning)' : 'var(--color-danger)';
  const healthLabel = sim.healthScore >= 70 ? 'Healthy' : sim.healthScore >= 40 ? 'Strained' : 'Critical';

  return (
    <div className="simulink-container animate-fade-in">
      {/* ── Header with Presets ── */}
      <div className="sim-hero">
        <div className="sim-hero-text">
          <h1>Simulink Resource Allocation</h1>
          <p className="text-muted text-sm">Telemedicine pipeline simulation — model throughput, constraints, and optimize for district-level deployment.</p>
        </div>
        <div className="sim-presets">
          {PRESETS.map(preset => (
            <button
              key={preset.label}
              className={`sim-preset-btn ${activePreset === preset.label ? 'active' : ''}`}
              title={preset.desc}
              onClick={() => {
                setActivePreset(preset.label);
                setNumPHCs(preset.phcs);
                setImagesPerPHC(preset.img);
                setAvgBandwidth(preset.bw);
                setGpuCapacity(preset.gpu);
                setNumDoctors(preset.docs);
              }}
            >
              <span className="sim-preset-icon">{preset.icon}</span>
              <span className="sim-preset-label">{preset.label}</span>
              <span className="sim-preset-desc">{preset.desc}</span>
            </button>
          ))}
        </div>
      </div>

      {/* ── Pipeline Flow ── */}
      <div className="card pipeline-flow-card">
        <div className="pipeline-flow-header">
          <h3><span className="flex items-center gap-2"><IconActivity /> Pipeline Flow — Live Simulation</span></h3>
          <div className="sim-health-indicator" style={{ '--health-color': healthColor }}>
            <div className="sim-health-ring">
              <svg viewBox="0 0 36 36">
                <path d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" fill="none" stroke="rgba(var(--theme-overlay-color), 0.06)" strokeWidth="3"/>
                <path d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" fill="none" stroke={healthColor} strokeWidth="3" strokeDasharray={`${sim.healthScore}, 100`} strokeLinecap="round" style={{ transition: 'stroke-dasharray 0.8s ease' }}/>
              </svg>
              <span className="sim-health-value">{sim.healthScore}</span>
            </div>
            <span className="sim-health-label" style={{ color: healthColor }}>{healthLabel}</span>
          </div>
        </div>
        <div className="pipeline-flow">
          {pipelineStages.map((stage, i) => (
            <div key={i} className="pipeline-flow-item">
              <div className={`pipeline-block ${stage.status}`}>
                <span className="pipeline-block-icon">{stage.icon}</span>
                <span className="pipeline-block-label">{stage.label}</span>
                <span className="pipeline-block-sublabel">{stage.sublabel}</span>
                {stage.status !== 'ok' && (
                  <span className={`pipeline-block-badge ${stage.status}`}>
                    {stage.status === 'error' ? '!' : '⚠'}
                  </span>
                )}
              </div>
              {i < pipelineStages.length - 1 && (
                <div className={`pipeline-connector ${stage.status}`}>
                  <div className="connector-line"></div>
                  <div className={`connector-dot ${stage.status}`}></div>
                  <div className="connector-line"></div>
                </div>
              )}
            </div>
          ))}
        </div>
      </div>

      {/* ── Main Grid ── */}
      <div className="simulink-grid">
        {/* ── Parameters Panel ── */}
        <div className="card params-panel">
          <div className="params-panel-header">
            <h3><span className="flex items-center gap-2"><IconSliders /> Parameters</span></h3>
            <span className="text-xs text-dim">{numPHCs} PHCs · {sim.dailyImages} img/day</span>
          </div>

          {paramGroups.map((group, gi) => (
            <div key={gi} className="param-section">
              <div className="param-section-title">
                <span>{group.icon}</span>
                <span>{group.title}</span>
              </div>
              {group.params.map((p, pi) => (
                <div key={pi} className="param-group">
                  <div className="param-header">
                    <label>{p.label}</label>
                    <span className="param-value">{p.value}{p.unit}</span>
                  </div>
                  <input type="range" className="range-slider" min={p.min} max={p.max} step={p.step} value={p.value} onChange={e => p.set(Number(e.target.value))} />
                </div>
              ))}
            </div>
          ))}
        </div>

        {/* ── Results Panel ── */}
        <div className="results-panel">
          {/* Bottleneck Alert */}
          <div className={`bottleneck-alert ${sim.bottleneckSeverity}`}>
            <div className="bottleneck-icon-wrap">
              {sim.bottleneck === 'none' ? <IconCheckCircle /> : <IconAlertTriangle />}
            </div>
            <div>
              <div className="bottleneck-title">{sim.bottleneck === 'none' ? 'System Healthy' : 'Bottleneck Detected'}</div>
              <div className="bottleneck-desc">{sim.bottleneckLabel}</div>
            </div>
          </div>

          {/* Metrics Grid */}
          <div className="sim-metrics-grid">
            <div className="sim-metric-card card">
              <div className="sim-metric-icon cyan"><IconWifi /></div>
              <div className="sim-metric-label">Upload Latency</div>
              <div className="sim-metric-value">{sim.uploadTimePerImage}<span className="sim-metric-unit">sec</span></div>
              <div className={`sim-metric-status ${sim.bandwidthLimited ? 'danger' : 'ok'}`}>
                <span className={`status-indicator ${sim.bandwidthLimited ? 'danger' : 'ok'}`}></span>
                {sim.bandwidthLimited ? `Max ${sim.maxImagesPerPHCBandwidth}/PHC` : 'Within capacity'}
              </div>
            </div>
            <div className="sim-metric-card card">
              <div className="sim-metric-icon purple"><IconServer /></div>
              <div className="sim-metric-label">GPU Utilization</div>
              <div className="sim-metric-value">{sim.gpuUtilization}<span className="sim-metric-unit">%</span></div>
              <div className="progress-bar" style={{ marginTop: '0.5rem' }}>
                <div className={`progress-fill ${parseFloat(sim.gpuUtilization) > 90 ? 'progress-fill-danger' : ''}`} style={{ width: `${sim.gpuUtilization}%` }}></div>
              </div>
            </div>
            <div className="sim-metric-card card">
              <div className="sim-metric-icon amber"><IconUsers /></div>
              <div className="sim-metric-label">Doctor Utilization</div>
              <div className="sim-metric-value">{sim.doctorUtilization}<span className="sim-metric-unit">%</span></div>
              <div className="progress-bar" style={{ marginTop: '0.5rem' }}>
                <div className={`progress-fill ${parseFloat(sim.doctorUtilization) > 90 ? 'progress-fill-danger' : ''}`} style={{ width: `${sim.doctorUtilization}%` }}></div>
              </div>
            </div>
            <div className="sim-metric-card card">
              <div className="sim-metric-icon green"><IconClock /></div>
              <div className="sim-metric-label">Avg E2E Latency</div>
              <div className="sim-metric-value">{sim.avgLatency}<span className="sim-metric-unit">sec</span></div>
              <div className={`sim-metric-status ${parseFloat(sim.avgLatency) > 120 ? 'danger' : 'ok'}`}>
                <span className={`status-indicator ${parseFloat(sim.avgLatency) > 120 ? 'danger' : 'ok'}`}></span>
                {parseFloat(sim.avgLatency) > 120 ? 'Exceeds target' : 'Within SLA'}
              </div>
            </div>
          </div>

          {/* Annual Capacity */}
          <div className="card annual-card">
            <div className="annual-card-header">
              <div className="flex items-center gap-2">
                <span className="annual-card-icon"><IconTarget /></span>
                <h3>Annual Capacity Projection</h3>
              </div>
              <span className={`badge badge-dot ${parseFloat(sim.targetProgress) >= 100 ? 'badge-success' : parseFloat(sim.targetProgress) >= 70 ? 'badge-warning' : 'badge-danger'}`}>{parseFloat(sim.targetProgress) >= 100 ? 'Target Met' : 'Below Target'}</span>
            </div>
            <div className="annual-stats">
              {[
                { value: sim.dailyImages.toLocaleString(), label: 'Daily Images', color: 'var(--color-primary-light)' },
                { value: sim.annualPatients.toLocaleString(), label: 'Annual Patients', color: 'var(--color-accent)' },
                { value: sim.referableCases, label: 'Referable / Day', color: 'var(--color-warning)' },
                { value: sim.totalReviewCapacity, label: 'Review Cap / Day', color: 'var(--color-success)' },
              ].map((stat, i) => (
                <div key={i} className="annual-stat-item">
                  <div className="annual-stat-value" style={{ color: stat.color }}>{stat.value}</div>
                  <div className="annual-stat-label">{stat.label}</div>
                </div>
              ))}
            </div>
            <div className="annual-progress-section">
              <div className="flex justify-between text-xs mb-1">
                <span className="text-muted">Progress to 100K target</span>
                <span className="font-semibold" style={{ color: parseFloat(sim.targetProgress) >= 100 ? 'var(--color-success)' : 'var(--color-warning)' }}>{sim.targetProgress}%</span>
              </div>
              <div className="progress-bar"><div className={`progress-fill ${parseFloat(sim.targetProgress) >= 100 ? 'progress-fill-success' : ''}`} style={{ width: `${Math.min(parseFloat(sim.targetProgress), 100)}%` }}></div></div>
            </div>
          </div>

          {/* Queue Chart */}
          <div className="card queue-card">
            <div className="flex justify-between items-center" style={{ marginBottom: '1rem' }}>
              <h3 className="flex items-center gap-2"><IconZap /> Processing Queue Depth</h3>
              <span className="text-xs text-dim">Per operating hour</span>
            </div>
            <div className="queue-chart">
              {sim.queueHistory.map((point, i) => {
                const maxDepth = Math.max(...sim.queueHistory.map(p => p.depth), 1);
                return (
                  <div key={i} className="queue-bar-col">
                    <div className="queue-bar-wrapper">
                      <div className={`queue-bar ${point.depth > 50 ? 'danger' : point.depth > 20 ? 'warning' : 'ok'}`} style={{ height: `${Math.min((point.depth / maxDepth) * 100, 100)}%`, minHeight: point.depth > 0 ? '4px' : '0' }}>
                        {point.depth > 0 && <span className="queue-bar-value">{point.depth}</span>}
                      </div>
                    </div>
                    <span className="queue-bar-label">H{point.hour}</span>
                  </div>
                );
              })}
            </div>
          </div>

          {/* PHC Table */}
          <div className="card phc-table-card">
            <div className="flex justify-between items-center" style={{ marginBottom: '1rem' }}>
              <h3>PHC-Level Allocation</h3>
              <span className="badge badge-info">{numPHCs} Active</span>
            </div>
            <table className="data-table">
              <thead><tr><th>PHC Facility</th><th>District</th><th>Cap/Day</th><th>BW</th><th>Upload</th><th>Status</th></tr></thead>
              <tbody>
                {PHCS_DATA.slice(0, numPHCs).map((phc, i) => {
                  const uploadTime = ((avgImageSizeMB * 8) / phc.bandwidth).toFixed(1);
                  const maxUploads = Math.floor((operatingHours * 3600) / parseFloat(uploadTime));
                  const constrained = phc.dailyCapacity > maxUploads;
                  return (
                    <tr key={i}>
                      <td><span className="font-medium" style={{ color: 'var(--color-text-main)' }}>{phc.name}</span></td>
                      <td className="text-dim">{phc.district}</td>
                      <td>{phc.dailyCapacity}</td>
                      <td><span className={phc.bandwidth < 1 ? 'text-danger font-semibold' : ''}>{phc.bandwidth} Mbps</span></td>
                      <td>{uploadTime}s</td>
                      <td><span className={`badge badge-dot ${constrained ? 'badge-warning' : 'badge-success'}`}>{constrained ? 'Constrained' : 'Healthy'}</span></td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  );
}
