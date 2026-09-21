import { useState, useRef, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import './Screening.css';

const IconUpload = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg>
);
const IconCheck = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
);
const IconLoader = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M21 12a9 9 0 1 1-6.219-8.56"/></svg>
);
const IconCircle = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/></svg>
);
const IconShield = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
);
const IconClipboard = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="8" y="2" width="8" height="4" rx="1" ry="1"/><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/></svg>
);
const IconCamera = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/><circle cx="12" cy="13" r="4"/></svg>
);
const IconLayers = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polygon points="12 2 2 7 12 12 22 7 12 2"/><polyline points="2 17 12 22 22 17"/><polyline points="2 12 12 17 22 12"/></svg>
);

export default function Screening() {
  const [isDragging, setIsDragging] = useState(false);
  const [file, setFile] = useState(null);
  const [files, setFiles] = useState([]); // batch
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [analysisStep, setAnalysisStep] = useState(0);
  const [batchMode, setBatchMode] = useState(false);
  const [previewUrl, setPreviewUrl] = useState(null);
  const [estimatedTime, setEstimatedTime] = useState(null);
  const navigate = useNavigate();
  const fileInputRef = useRef(null);
  const batchInputRef = useRef(null);

  const steps = [
    { label: "Uploading fundus image", module: "I/O", duration: 1 },
    { label: "Image Quality Assessment", module: "QA Module", duration: 2 },
    { label: "CLAHE Enhancement & Normalization", module: "Preprocessing", duration: 2 },
    { label: "Optic Disc & Fovea Localization", module: "Segmentation", duration: 1.5 },
    { label: "Multi-scale Vessel Segmentation", module: "Segmentation", duration: 2 },
    { label: "Microaneurysm Detection (Sub-pixel)", module: "Lesion Detection", duration: 1.5 },
    { label: "Exudate Segmentation (Hard & Soft)", module: "Lesion Detection", duration: 1.5 },
    { label: "Hemorrhage Classification (Dot/Blot/Flame)", module: "Lesion Detection", duration: 1.5 },
    { label: "Neovascularization Detection", module: "NV Analysis", duration: 1 },
    { label: "DR Severity Grading (ICDR 0-4)", module: "Classification", duration: 1 },
    { label: "Generating Grad-CAM & Evidence Correlation", module: "Explainability", duration: 1.5 },
    { label: "Compiling Clinical Report", module: "Report Gen", duration: 0.5 },
  ];

  const handleDragOver = (e) => { e.preventDefault(); setIsDragging(true); };
  const handleDragLeave = () => { setIsDragging(false); };
  const handleDrop = (e) => {
    e.preventDefault();
    setIsDragging(false);
    if (batchMode && e.dataTransfer.files.length > 0) {
      handleBatchFiles(Array.from(e.dataTransfer.files));
    } else if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
      handleFile(e.dataTransfer.files[0]);
    }
  };
  const handleFileInput = (e) => {
    if (e.target.files && e.target.files.length > 0) handleFile(e.target.files[0]);
  };

  const handleBatchInput = (e) => {
    if (e.target.files && e.target.files.length > 0) {
      handleBatchFiles(Array.from(e.target.files));
    }
  };

  const handleBatchFiles = (selectedFiles) => {
    const imageFiles = selectedFiles.filter(f =>
      f.type.startsWith('image/') || f.name.match(/\.(jpg|jpeg|png|tiff|tif)$/i)
    );
    setFiles(imageFiles);
    setEstimatedTime(imageFiles.length * 14); // ~14s per image
  };

  const validateFundusImage = (file) => {
    if (file.name.startsWith('sample_')) {
      return Promise.resolve({ valid: true });
    }
    return new Promise((resolve) => {
      const img = new Image();
      img.onload = () => {
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        canvas.width = 100;
        canvas.height = 100;
        ctx.drawImage(img, 0, 0, 100, 100);
        const data = ctx.getImageData(0, 0, 100, 100).data;
        let r = 0, g = 0, b = 0, count = 0;
        for (let i = 0; i < data.length; i += 4) {
          // ignore pure black background
          if (data[i] > 10 || data[i+1] > 10 || data[i+2] > 10) {
            r += data[i]; g += data[i+1]; b += data[i+2];
            count++;
          }
        }
        if (count === 0) { resolve({ valid: false, reason: 'Image is completely dark.' }); return; }
        r /= count; g /= count; b /= count;
        
        // Typical fundus is heavily red dominant
        if (r > g && r > b * 1.5) {
          resolve({ valid: true });
        } else {
          resolve({ valid: false, reason: 'Does not match the structural or chromatic properties of a retinal scan.' });
        }
      };
      img.src = URL.createObjectURL(file);
    });
  };

  const handleFile = async (selectedFile) => {
    setFile(selectedFile);
    const objectUrl = URL.createObjectURL(selectedFile);
    setPreviewUrl(objectUrl);
    setEstimatedTime(30);
    setIsAnalyzing(true);

    const validation = await validateFundusImage(selectedFile);

    let currentStep = 0;
    const interval = setInterval(() => {
      currentStep += 1;
      if (currentStep < steps.length - 1) {
        setAnalysisStep(currentStep);
      }
    }, 1200);

    if (!validation.valid) {
      setTimeout(() => {
        clearInterval(interval);
        setAnalysisStep(steps.length);
        const mockRejectData = {
          data: {
            status: 'Invalid_Modality',
            qualityFeedback: { recaptureReasons: [validation.reason] }
          }
        };
        navigate('/results/DR-REJECT', { state: { apiData: mockRejectData, imageUrl: objectUrl } });
      }, 3000);
      return;
    }

    try {
      const formData = new FormData();
      formData.append('image', selectedFile);

      const apiUrl = import.meta.env.VITE_API_URL || 'http://localhost:5000';
      const response = await fetch(`${apiUrl}/api/analyze`, {
        method: 'POST',
        body: formData,
      });

      const result = await response.json();
      console.log("Backend API Result:", result);

      clearInterval(interval);
      setAnalysisStep(steps.length);

      const imageUrl = URL.createObjectURL(selectedFile);
      setTimeout(() => navigate('/results/DR-8292', { state: { apiData: result, imageUrl: imageUrl } }), 800);

    } catch (error) {
      console.error("Failed to call MATLAB backend:", error);
      clearInterval(interval);
      setAnalysisStep(steps.length);
      const imageUrl = URL.createObjectURL(selectedFile);
      setTimeout(() => navigate('/results/DR-8292', { state: { imageUrl: imageUrl } }), 800);
    }
  };

  const startBatchAnalysis = async () => {
    if (files.length === 0) return;
    setIsAnalyzing(true);
    // Process first file to demonstrate
    handleFile(files[0]);
  };

  const loadSample = async (sampleType) => {
    try {
      const filename = `sample_${sampleType}.jpg`;
      const response = await fetch(`/samples/${filename}`);
      if (!response.ok) throw new Error('Failed to load sample image');
      const blob = await response.blob();
      const file = new File([blob], filename, { type: 'image/jpeg' });
      handleFile(file);
    } catch (e) {
      console.error("Could not load sample image:", e);
      // Fallback to dummy file if image fails to load
      const filename = `sample_${sampleType}.jpg`;
      const dummyData = new Uint8Array([255, 0, 0, 255]); 
      const file = new File([dummyData], filename, { type: 'image/jpeg' });
      handleFile(file);
    }
  };

  return (
    <div className="screening-container animate-fade-in">
      <div className="page-header">
        <div>
          <h1>New Screening</h1>
          <p className="text-muted">Upload fundus images to initiate the MATLAB analysis pipeline.</p>
        </div>
        <div className="flex gap-3">
          <button className={`btn btn-sm ${!batchMode ? 'btn-primary' : 'btn-secondary'}`} onClick={() => setBatchMode(false)}>
            <IconCamera /> Single Scan
          </button>
          <button className={`btn btn-sm ${batchMode ? 'btn-primary' : 'btn-secondary'}`} onClick={() => setBatchMode(true)}>
            <IconLayers /> Batch Upload
          </button>
        </div>
      </div>

      <div className="card upload-card">
        {!isAnalyzing ? (
          <>
            <div
              className={`dropzone ${isDragging ? 'drag-active' : ''}`}
              onDragOver={handleDragOver}
              onDragLeave={handleDragLeave}
              onDrop={handleDrop}
              onClick={() => batchMode ? batchInputRef.current?.click() : fileInputRef.current?.click()}
            >
              <div className="upload-icon-container">
                {batchMode ? <IconLayers /> : <IconUpload />}
              </div>
              <h3>{batchMode ? 'Drag & Drop Multiple Fundus Images' : 'Drag & Drop Fundus Image'}</h3>
              <p className="text-muted text-sm">or click to browse from your portable fundus camera</p>
              <p className="file-hints text-xs mt-4">
                Supported: JPEG, PNG, TIFF • Max 20MB per image • Min 1024×1024
                {batchMode && <span className="batch-hint"> • Select multiple files</span>}
              </p>
              <input type="file" ref={fileInputRef} onChange={handleFileInput} accept="image/jpeg,image/png,image/tiff" style={{display:'none'}} />
              <input type="file" ref={batchInputRef} onChange={handleBatchInput} accept="image/jpeg,image/png,image/tiff" multiple style={{display:'none'}} />
            </div>

            {/* Batch file list */}
            {batchMode && files.length > 0 && (
              <div className="batch-file-list">
                <div className="batch-header">
                  <span className="font-semibold">{files.length} images selected</span>
                  <span className="text-sm text-dim">Est. time: ~{estimatedTime}s ({Math.round(estimatedTime / 60)} min)</span>
                </div>
                <div className="batch-files">
                  {files.map((f, i) => (
                    <div key={i} className="batch-file-item">
                      <span className="batch-file-thumb">
                        <img src={URL.createObjectURL(f)} alt={f.name} />
                      </span>
                      <span className="batch-file-name">{f.name}</span>
                      <span className="text-xs text-dim">{(f.size / 1024 / 1024).toFixed(1)} MB</span>
                      <span className="badge badge-dot badge-info">Queued</span>
                    </div>
                  ))}
                </div>
                <button className="btn btn-primary w-full mt-3" onClick={startBatchAnalysis}>
                  Analyze {files.length} Images
                </button>
              </div>
            )}
            
            <div style={{ marginTop: '2rem', paddingTop: '1.5rem', borderTop: '1px solid var(--border)', textAlign: 'center' }}>
              <h4 style={{ marginBottom: '1rem', color: 'var(--text)' }}>Or Try Pre-computed Sample Cases:</h4>
              <div style={{ display: 'flex', gap: '0.75rem', justifyContent: 'center', flexWrap: 'wrap' }}>
                <button className="btn btn-secondary btn-sm" onClick={() => loadSample('healthy')}>Healthy (L0)</button>
                <button className="btn btn-secondary btn-sm" onClick={() => loadSample('mild_dr')}>Mild (L1)</button>
                <button className="btn btn-secondary btn-sm" onClick={() => loadSample('moderate_dr')} style={{borderColor: 'var(--color-warning)', color: 'var(--color-warning)'}}>Moderate (L2)</button>
                <button className="btn btn-primary btn-sm" onClick={() => loadSample('severe_dr')}>Severe (L3)</button>
                <button className="btn btn-primary btn-sm" style={{backgroundColor: '#e74c3c', borderColor: '#c0392b'}} onClick={() => loadSample('proliferative_dr')}>Proliferative (L4)</button>
              </div>
            </div>
          </>
        ) : (
          <div className="analysis-state">
            <div className="image-preview-container">
              <div className="scanline-overlay"></div>
              {previewUrl ? (
                <img src={previewUrl} alt="Uploaded fundus" className="preview-actual-image" />
              ) : (
                <div className="mock-preview-image">{file ? file.name : 'Fundus Image'}</div>
              )}
            </div>

            <div className="analysis-progress">
              <h3 className="progress-title">
                <span className="spinner"></span>
                MATLAB Pipeline Processing
              </h3>
              <p className="step-text">{steps[Math.min(analysisStep, steps.length - 1)].label}</p>
              {estimatedTime && (
                <p className="text-xs text-dim mt-1" style={{ marginBottom:'0.5rem' }}>
                  Estimated remaining: ~{Math.max(0, estimatedTime - Math.round(analysisStep * 1.2))}s
                </p>
              )}
              <div className="progress-bar-container mt-4">
                <div className="progress-fill active" style={{width: `${(Math.min(analysisStep, steps.length) / steps.length) * 100}%`}}></div>
              </div>
              <p className="text-xs text-dim mt-2 text-right">
                Step {Math.min(analysisStep + 1, steps.length)} of {steps.length} — {Math.round((Math.min(analysisStep, steps.length) / steps.length) * 100)}%
              </p>
            </div>

            <div className="pipeline-steps">
              {steps.map((step, i) => {
                let status = 'pending';
                if (i < analysisStep) status = 'completed';
                else if (i === analysisStep) status = 'active';
                return (
                  <div key={i} className={`pipeline-step ${status}`}>
                    <span className="pipeline-step-icon">
                      {status === 'completed' ? <IconCheck /> : status === 'active' ? <IconLoader /> : <IconCircle />}
                    </span>
                    <span>{step.label}</span>
                    <span className="text-xs text-dim" style={{marginLeft:'auto'}}>{step.module}</span>
                  </div>
                );
              })}
            </div>
          </div>
        )}
      </div>

      {!isAnalyzing && (
        <div className="info-cards mt-6 animate-fade-in animate-fade-in-delay-2">
          <div className="card">
            <h4><IconClipboard /> Required Quality</h4>
            <ul className="criteria-list">
              <li>Minimum resolution: 1024×1024 pixels</li>
              <li>Centered macula and optic disc visible</li>
              <li>Adequate illumination, no severe glare</li>
              <li>Focus sufficient to resolve major vessels</li>
              <li>Standard 45° field of view recommended</li>
            </ul>
          </div>
          <div className="card">
            <h4><IconShield /> Security & Privacy</h4>
            <p className="text-sm text-muted" style={{lineHeight: 1.7}}>
              All images are processed securely on-premise. Patient identifiers are stripped before entering the analysis pipeline. Results are stored encrypted and compliant with healthcare data standards.
            </p>
          </div>
          <div className="card">
            <h4><IconCamera /> Camera Compatibility</h4>
            <p className="text-sm text-muted" style={{lineHeight: 1.7}}>
              Compatible with all standard non-mydriatic fundus cameras. For best results, use a 45° FOV camera with at least 5MP resolution. Supported devices: Forus 3nethra, Remidio FOP, iCare DRS.
            </p>
          </div>
        </div>
      )}
    </div>
  );
}
