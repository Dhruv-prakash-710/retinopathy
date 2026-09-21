'use client';

import { useState, use } from 'react';
import Link from 'next/link';
import './Results.css';

export default function Results({ params }) {
  // In Next.js 14+ with App router, params might be a Promise in some contexts, but usually it's fine.
  // We'll safely access it.
  const resolvedParams = use(params);
  const { id } = resolvedParams;
  
  const [activeLayer, setActiveLayer] = useState('original');
  const [showGradCam, setShowGradCam] = useState(false);

  // Mock data for the demonstration
  const analysisData = {
    patientId: 'P-1042',
    scanDate: '2026-08-31',
    quality: {
      status: 'Adequate',
      focus: 'Good',
      illumination: 'Normalized (CLAHE applied)',
      fov: 'Standard 45°'
    },
    grading: {
      level: 2,
      description: 'Moderate Non-Proliferative DR',
      confidence: 94.2
    },
    evidence: [
      { id: 1, type: 'Microaneurysms', count: 7, location: 'Macula & Superior temporal' },
      { id: 2, type: 'Hard Exudates', count: 3, location: 'Inferior temporal' },
      { id: 3, type: 'Hemorrhages', count: 1, location: 'Nasal' }
    ]
  };

  return (
    <div className="results-container animate-fade-in">
      <div className="results-header">
        <div className="flex items-center gap-4">
          <Link href="/" className="btn btn-secondary text-sm">← Back</Link>
          <div>
            <h1>Scan Analysis: {id}</h1>
            <p className="text-muted">Patient: {analysisData.patientId} • Scanned: {analysisData.scanDate}</p>
          </div>
        </div>
        <div className="flex gap-4">
          <button className="btn btn-danger">Reject Image</button>
          <button className="btn btn-primary">Validate & Approve</button>
        </div>
      </div>

      <div className="results-grid">
        {/* Left Column: Image Viewer */}
        <div className="image-viewer-section card">
          <div className="viewer-controls">
            <div className="layer-toggles">
              <button 
                className={`layer-btn ${activeLayer === 'original' ? 'active' : ''}`}
                onClick={() => setActiveLayer('original')}
              >
                Original
              </button>
              <button 
                className={`layer-btn ${activeLayer === 'enhanced' ? 'active' : ''}`}
                onClick={() => setActiveLayer('enhanced')}
              >
                Enhanced
              </button>
              <button 
                className={`layer-btn ${activeLayer === 'vessels' ? 'active' : ''}`}
                onClick={() => setActiveLayer('vessels')}
              >
                Vessels
              </button>
              <button 
                className={`layer-btn ${activeLayer === 'lesions' ? 'active' : ''}`}
                onClick={() => setActiveLayer('lesions')}
              >
                Lesions
              </button>
            </div>
            
            <label className="gradcam-toggle">
              <input 
                type="checkbox" 
                checked={showGradCam} 
                onChange={(e) => setShowGradCam(e.target.checked)} 
              />
              <span className="toggle-slider"></span>
              <span className="toggle-label">Show Grad-CAM</span>
            </label>
          </div>

          <div className="image-display-area">
            {/* Simulated Image Layers using CSS for the demo */}
            <div className="simulated-fundus-base">
              <div className="optic-disc"></div>
              <div className="macula"></div>
            </div>
            
            {activeLayer === 'enhanced' && (
              <div className="layer-overlay enhanced-layer"></div>
            )}
            
            {activeLayer === 'vessels' && (
              <div className="layer-overlay vessels-layer"></div>
            )}
            
            {activeLayer === 'lesions' && (
              <div className="layer-overlay lesions-layer">
                <div className="lesion ma" style={{top: '40%', left: '30%'}}></div>
                <div className="lesion ma" style={{top: '45%', left: '35%'}}></div>
                <div className="lesion exudate" style={{top: '60%', left: '40%'}}></div>
                <div className="lesion hemorrhage" style={{top: '30%', left: '60%'}}></div>
              </div>
            )}

            {showGradCam && (
              <div className="layer-overlay gradcam-layer"></div>
            )}
          </div>
          
          <div className="viewer-footer text-sm text-muted mt-4 text-center">
            Interactive viewer: Scroll to zoom, click and drag to pan.
          </div>
        </div>

        {/* Right Column: Clinical Summary */}
        <div className="clinical-summary-section flex-col gap-6">
          <div className="card">
            <h3>Diagnostic Result</h3>
            <div className="grading-box mt-4">
              <div className="grading-level referable">Level {analysisData.grading.level}</div>
              <div className="grading-desc">{analysisData.grading.description}</div>
              <div className="confidence-meter mt-4">
                <div className="flex justify-between text-sm mb-1">
                  <span>AI Confidence Score</span>
                  <span className="font-medium">{analysisData.grading.confidence}%</span>
                </div>
                <div className="progress-bar">
                  <div className="progress-fill" style={{width: `${analysisData.grading.confidence}%`}}></div>
                </div>
              </div>
            </div>
          </div>

          <div className="card">
            <h3>Image Quality Assessment</h3>
            <div className="quality-metrics mt-4">
              <div className="flex justify-between py-2 border-b">
                <span className="text-muted">Overall Status</span>
                <span className="badge badge-success">{analysisData.quality.status}</span>
              </div>
              <div className="flex justify-between py-2 border-b text-sm">
                <span className="text-muted">Focus</span>
                <span>{analysisData.quality.focus}</span>
              </div>
              <div className="flex justify-between py-2 border-b text-sm">
                <span className="text-muted">Illumination</span>
                <span>{analysisData.quality.illumination}</span>
              </div>
              <div className="flex justify-between py-2 text-sm">
                <span className="text-muted">Field of View</span>
                <span>{analysisData.quality.fov}</span>
              </div>
            </div>
          </div>

          <div className="card">
            <h3>Lesion-Level Evidence</h3>
            <div className="evidence-list mt-4">
              {analysisData.evidence.map(ev => (
                <div key={ev.id} className="evidence-item">
                  <div className="evidence-header">
                    <span className="font-medium">{ev.type}</span>
                    <span className="evidence-count">{ev.count} detected</span>
                  </div>
                  <div className="evidence-location text-sm text-muted">
                    {ev.location}
                  </div>
                </div>
              ))}
            </div>
            <button className="btn btn-secondary w-full mt-4">
              Generate PDF Report
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
