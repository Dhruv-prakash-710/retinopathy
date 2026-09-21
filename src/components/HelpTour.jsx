import { useState, useEffect } from 'react';
import './HelpTour.css';

const tourSteps = [
  {
    title: 'Welcome to RetinaVision! 👁️',
    description: 'This AI-powered screening system helps you detect Diabetic Retinopathy quickly and accurately. Let\'s take a quick tour of the key features.',
    target: null
  },
  {
    title: 'New Screening',
    description: 'Click "New Screening" to upload a fundus image. Simply drag & drop or click to browse. The MATLAB pipeline will analyze it automatically.',
    target: 'screening'
  },
  {
    title: 'Results & Diagnosis',
    description: 'After analysis, view the AI diagnosis with lesion detection, Grad-CAM explanations, and DR severity grading. Ophthalmologists can validate results in under 30 seconds.',
    target: 'results'
  },
  {
    title: 'Patient Registry',
    description: 'Track all patients and their screening history. Filter by status, search by ID, and export records.',
    target: 'patients'
  },
  {
    title: 'Simulink Optimization',
    description: 'Model and optimize the telemedicine workflow — adjust PHC count, bandwidth, GPU capacity, and doctor availability to find the optimal resource allocation.',
    target: 'simulink'
  },
  {
    title: 'You\'re All Set! 🎉',
    description: 'Start by uploading your first fundus image. The system will guide you through each step. For questions, contact the district coordinator.',
    target: null
  }
];

export default function HelpTour({ onDismiss }) {
  const [currentStep, setCurrentStep] = useState(0);
  const [visible, setVisible] = useState(true);

  const step = tourSteps[currentStep];
  const isLast = currentStep === tourSteps.length - 1;
  const isFirst = currentStep === 0;

  const handleNext = () => {
    if (isLast) {
      handleDismiss();
    } else {
      setCurrentStep(prev => prev + 1);
    }
  };

  const handlePrev = () => {
    if (!isFirst) setCurrentStep(prev => prev - 1);
  };

  const handleDismiss = () => {
    setVisible(false);
    localStorage.setItem('rv_tour_dismissed', 'true');
    onDismiss?.();
  };

  if (!visible) return null;

  return (
    <div className="help-tour-overlay">
      <div className="help-tour-card">
        <button className="help-tour-close" onClick={handleDismiss}>×</button>

        <div className="help-tour-progress">
          {tourSteps.map((_, i) => (
            <div key={i} className={`progress-dot ${i === currentStep ? 'active' : i < currentStep ? 'completed' : ''}`} />
          ))}
        </div>

        <div className="help-tour-content">
          <h3>{step.title}</h3>
          <p>{step.description}</p>
        </div>

        <div className="help-tour-actions">
          <button className="help-tour-skip" onClick={handleDismiss}>
            Don't show again
          </button>
          <div className="flex gap-2">
            {!isFirst && (
              <button className="btn btn-secondary btn-sm" onClick={handlePrev}>Back</button>
            )}
            <button className="btn btn-primary btn-sm" onClick={handleNext}>
              {isLast ? 'Get Started' : 'Next'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
