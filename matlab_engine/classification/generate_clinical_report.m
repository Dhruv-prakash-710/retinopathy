function [report] = generate_clinical_report(results)
% GENERATE_CLINICAL_REPORT Compiles all analysis results into a structured clinical report.
%   Designed for ophthalmologist validation in under 30 seconds.
%
%   [report] = generate_clinical_report(results)
%
%   Input:  results - struct from main_pipeline
%   Output: report  - structured report with all clinical findings

    report = struct();

    %% ══════════════════════════════════════════════════════════════
    %  1. HEADER INFORMATION
    %% ══════════════════════════════════════════════════════════════
    report.header = struct();
    report.header.generatedAt = datestr(now, 'dd-mmm-yyyy HH:MM:SS');
    report.header.pipelineVersion = '2.4.1-Clinical';
    report.header.imagePath = results.imagePath;
    report.header.reportType = 'Automated DR Screening Report';

    %% ══════════════════════════════════════════════════════════════
    %  2. IMAGE QUALITY SUMMARY
    %% ══════════════════════════════════════════════════════════════
    report.quality = struct();
    if isfield(results, 'quality')
        report.quality.grade = results.qualityGrade;
        report.quality.focusScore = results.quality.compositeFocus;
        report.quality.illumination = results.quality.meanIntensity;
        report.quality.fovRatio = results.quality.fovRatio;
        report.quality.hasArtifacts = results.quality.hasArtifacts;
        report.quality.adequate = strcmp(results.qualityGrade, 'Gradeable') || ...
                                  strcmp(results.qualityGrade, 'Borderline');
    else
        report.quality.grade = 'Unknown';
        report.quality.adequate = false;
    end

    %% ══════════════════════════════════════════════════════════════
    %  3. ANATOMICAL LANDMARKS
    %% ══════════════════════════════════════════════════════════════
    report.landmarks = struct();
    if isfield(results, 'odCenter')
        report.landmarks.opticDiscDetected = true;
        report.landmarks.odCenter = results.odCenter;
        report.landmarks.odRadius = results.odRadius;
        report.landmarks.odConfidence = results.odConfidence;
    else
        report.landmarks.opticDiscDetected = false;
    end

    if isfield(results, 'foveaCenter')
        report.landmarks.foveaDetected = true;
        report.landmarks.foveaCenter = results.foveaCenter;
        report.landmarks.foveaConfidence = results.foveaConfidence;
    else
        report.landmarks.foveaDetected = false;
    end

    %% ══════════════════════════════════════════════════════════════
    %  4. LESION FINDINGS
    %% ══════════════════════════════════════════════════════════════
    report.lesions = struct();

    % Microaneurysms
    if isfield(results, 'lesions') && isfield(results.lesions, 'microaneurysms')
        report.lesions.microaneurysms = struct();
        report.lesions.microaneurysms.count = results.lesions.microaneurysms;
        report.lesions.microaneurysms.present = results.lesions.microaneurysms > 0;
        report.lesions.microaneurysms.clinicalSignificance = getSignificance('MA', results.lesions.microaneurysms);
    end

    % Hard exudates
    if isfield(results, 'lesions') && isfield(results.lesions, 'hardExudates')
        report.lesions.hardExudates = struct();
        report.lesions.hardExudates.count = results.lesions.hardExudates;
        report.lesions.hardExudates.present = results.lesions.hardExudates > 0;
        report.lesions.hardExudates.clinicalSignificance = getSignificance('HE', results.lesions.hardExudates);
    end

    % Soft exudates
    if isfield(results, 'lesions') && isfield(results.lesions, 'softExudates')
        report.lesions.softExudates = struct();
        report.lesions.softExudates.count = results.lesions.softExudates;
        report.lesions.softExudates.present = results.lesions.softExudates > 0;
    end

    % Hemorrhages
    if isfield(results, 'lesions') && isfield(results.lesions, 'hemorrhages')
        report.lesions.hemorrhages = results.lesions.hemorrhages;
    end

    % Neovascularization
    if isfield(results, 'lesions') && isfield(results.lesions, 'neovascularization')
        report.lesions.neovascularization = results.lesions.neovascularization;
    end

    %% ══════════════════════════════════════════════════════════════
    %  5. DR GRADING
    %% ══════════════════════════════════════════════════════════════
    if isfield(results, 'grading')
        report.grading = results.grading;
    end

    %% ══════════════════════════════════════════════════════════════
    %  6. EXPLAINABILITY
    %% ══════════════════════════════════════════════════════════════
    if isfield(results, 'gradcamDetails')
        report.explainability = struct();
        report.explainability.clinicalUsefulness = results.gradcamDetails.clinicalUsefulness;
        report.explainability.usefulnessRating = results.gradcamDetails.usefulnessRating;
        report.explainability.evidenceCorrelation = results.gradcamDetails.evidenceCorrelation;
    end

    %% ══════════════════════════════════════════════════════════════
    %  7. CLINICAL SUMMARY (30-second review format)
    %% ══════════════════════════════════════════════════════════════
    report.summary = struct();

    if isfield(results, 'grading')
        report.summary.primaryDiagnosis = results.grading.label;
        report.summary.severity = results.grading.level;
        report.summary.confidence = results.grading.confidence;
        report.summary.referralRequired = results.grading.referable;
        report.summary.recommendedAction = results.grading.recommendedAction;

        % Urgency classification
        if results.grading.level >= 4
            report.summary.urgency = 'CRITICAL';
        elseif results.grading.level >= 3
            report.summary.urgency = 'URGENT';
        elseif results.grading.level >= 2
            report.summary.urgency = 'ROUTINE REFERRAL';
        else
            report.summary.urgency = 'ROUTINE FOLLOW-UP';
        end

        % Evidence summary (key findings in bullet points)
        findings = {};
        if isfield(results, 'lesions')
            if isfield(results.lesions, 'microaneurysms') && results.lesions.microaneurysms > 0
                findings{end+1} = sprintf('%d microaneurysms detected', results.lesions.microaneurysms);
            end
            if isfield(results.lesions, 'hardExudates') && results.lesions.hardExudates > 0
                findings{end+1} = sprintf('%d hard exudates', results.lesions.hardExudates);
            end
            if isfield(results.lesions, 'softExudates') && results.lesions.softExudates > 0
                findings{end+1} = sprintf('%d cotton-wool spots', results.lesions.softExudates);
            end
            if isfield(results.lesions, 'hemorrhages')
                totalHem = results.lesions.hemorrhages.totalCount;
                if totalHem > 0
                    findings{end+1} = sprintf('%d hemorrhages', totalHem);
                end
            end
            if isfield(results.lesions, 'neovascularization') && results.lesions.neovascularization.totalScore > 0.3
                findings{end+1} = 'Neovascularization detected';
            end
        end
        report.summary.keyFindings = findings;

        if isfield(results.grading, 'fusionNote')
            report.summary.algorithmNote = results.grading.fusionNote;
        end
    end

    %% ══════════════════════════════════════════════════════════════
    %  8. VESSEL ANALYSIS
    %% ══════════════════════════════════════════════════════════════
    if isfield(results, 'vesselMetrics')
        report.vessels = results.vesselMetrics;
    end

end

%% Helper: Clinical significance of lesion counts
function sig = getSignificance(type, count)
    switch type
        case 'MA'
            if count == 0, sig = 'None';
            elseif count <= 5, sig = 'Mild';
            elseif count <= 15, sig = 'Moderate';
            else, sig = 'Significant';
            end
        case 'HE'
            if count == 0, sig = 'None';
            elseif count <= 3, sig = 'Mild';
            elseif count <= 10, sig = 'Moderate';
            else, sig = 'Significant';
            end
        otherwise
            sig = 'Present';
    end
end
