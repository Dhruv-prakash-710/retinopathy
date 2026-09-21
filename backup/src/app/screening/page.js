'use client';

import { useState, useRef } from 'react';
import { useRouter } from 'next/navigation';
import './Screening.css';

export default function Screening() {
  const [isDragging, setIsDragging] = useState(false);
  const [file, setFile] = useState(null);
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [analysisStep, setAnalysisStep] = useState(0);
  const router = useRouter();
  const fileInputRef = useRef(null);

  const steps = [
    "Uploading fundus image...",
    "Image Quality Assessment (Focus, Illumination)...",
    "Retinal Structure Segmentation (Optic Disc, Vessels)...",
    "Lesion Detection (Microaneurysms, Exudates, Hemorrhages)...",
    "DR Severity Grading (Levels 0-4)...",
    "Generating Grad-CAM Explainability Maps...",
    "Finalizing Clinical Report..."
  ];

  const handleDragOver = (e) => {
    e.preventDefault();
    setIsDragging(true);
  };

  const handleDragLeave = () => {
    setIsDragging(false);
  };

  const handleDrop = (e) => {
    e.preventDefault();
    setIsDragging(false);
    if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
      handleFile(e.dataTransfer.files[0]);
    }
  };

  const handleFileInput = (e) => {
    if (e.target.files && e.target.files.length > 0) {
      handleFile(e.target.files[0]);
    }
  };

  const handleFile = (selectedFile) => {
    setFile(selectedFile);
    startMockAnalysis();
  };

  const startMockAnalysis = () => {
    setIsAnalyzing(true);
    let currentStep = 0;
    
    const interval = setInterval(() => {
      currentStep += 1;
      setAnalysisStep(currentStep);
      
      if (currentStep >= steps.length) {
        clearInterval(interval);
        // Navigate to the mock results page
        router.push('/results/demo-8292');
      }
    }, 1500); // 1.5 seconds per mock step
  };

  return (
    <div className="screening-container animate-fade-in">
      <div className="page-header">
        <h1>New Screening</h1>
        <p className="text-muted">Upload a fundus image to initiate the MATLAB analysis pipeline.</p>
      </div>

      <div className="card upload-card">
        {!isAnalyzing ? (
          <div 
            className={`dropzone ${isDragging ? 'drag-active' : ''}`}
            onDragOver={handleDragOver}
            onDragLeave={handleDragLeave}
            onDrop={handleDrop}
            onClick={() => fileInputRef.current?.click()}
          >
            <div className="upload-icon">📸</div>
            <h3>Drag & Drop Fundus Image</h3>
            <p className="text-muted">or click to browse from your portable camera</p>
            <p className="file-hints text-sm mt-4">Supported formats: JPEG, PNG, TIFF (Max 20MB)</p>
            <input 
              type="file" 
              ref={fileInputRef} 
              onChange={handleFileInput} 
              accept="image/jpeg, image/png, image/tiff" 
              style={{ display: 'none' }} 
            />
          </div>
        ) : (
          <div className="analysis-state">
            <div className="image-preview-container">
              <div className="scanline-overlay"></div>
              {/* If we had a real file, we'd use URL.createObjectURL(file) - for now just an icon/placeholder */}
              <div className="mock-preview-image">
                 {file ? file.name : "Fundus Image"}
              </div>
            </div>
            
            <div className="analysis-progress">
              <h3 className="progress-title">MATLAB Pipeline Running</h3>
              <p className="step-text text-primary">{steps[Math.min(analysisStep, steps.length - 1)]}</p>
              
              <div className="progress-bar-container mt-4">
                <div 
                  className="progress-fill active" 
                  style={{ width: `${(Math.min(analysisStep, steps.length) / steps.length) * 100}%` }}
                ></div>
              </div>
              <p className="text-sm text-muted mt-2 text-right">
                {Math.round((Math.min(analysisStep, steps.length) / steps.length) * 100)}%
              </p>
            </div>
          </div>
        )}
      </div>

      <div className="info-cards grid-2 mt-4">
        <div className="card">
          <h4>Required Quality Criteria</h4>
          <ul className="criteria-list text-sm text-muted mt-2">
            <li>Minimum resolution: 1024x1024 pixels</li>
            <li>Centered macula and optic disc</li>
            <li>Adequate illumination without severe glare</li>
            <li>Focus clear enough to identify major vessels</li>
          </ul>
        </div>
        <div className="card">
          <h4>Security & Privacy</h4>
          <p className="text-sm text-muted mt-2">
            All images are processed securely. Patient identifiers are stripped before entering the analysis pipeline. Results are stored encrypted in compliance with healthcare standards.
          </p>
        </div>
      </div>
    </div>
  );
}
