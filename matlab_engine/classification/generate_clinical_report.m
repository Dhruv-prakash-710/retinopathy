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
        report.vessels = struct();
        report.vessels.density = results.vesselMetrics.density;
        report.vessels.meanTortuosity = results.vesselMetrics.meanTortuosity;
        report.vessels.branchingPoints = results.vesselMetrics.branchingPoints;

        % New vessel metrics
        if isfield(results.vesselMetrics, 'avRatio')
            report.vessels.avRatio = results.vesselMetrics.avRatio;
        end
        if isfield(results.vesselMetrics, 'venousBeadingScore')
            report.vessels.venousBeadingScore = results.vesselMetrics.venousBeadingScore;
            report.vessels.venousBeadingCount = results.vesselMetrics.venousBeadingCount;
            report.vessels.beadingPerQuadrant = results.vesselMetrics.beadingPerQuadrant;
        end
        if isfield(results.vesselMetrics, 'cdr')
            report.vessels.cupToDiscRatio = results.vesselMetrics.cdr;
            report.vessels.glaucomaSuspect = results.vesselMetrics.glaucomaSuspect;
        end
    end

    %% ══════════════════════════════════════════════════════════════
    %  9. DME (DIABETIC MACULAR EDEMA) FINDINGS
    %% ══════════════════════════════════════════════════════════════
    if isfield(results, 'dmeDetails')
        report.dme = struct();
        report.dme.detected = results.dmeDetails.detected;
        report.dme.severity = results.dmeDetails.severity;
        report.dme.csme = results.dmeDetails.csme;
        report.dme.centralInvolvement = results.dmeDetails.centralInvolvement;
        report.dme.centralThicknessProxy = results.dmeDetails.centralThicknessProxy;
        report.dme.referralRequired = results.dmeDetails.referralRequired;

        if results.dmeDetails.csme
            report.dme.csmeReason = results.dmeDetails.csmeReason;
        end

        if results.dmeDetails.detected
            report.dme.exudatesInMacula = results.dmeDetails.exudatesInMacula;
            report.dme.hemorrhagesInMacula = results.dmeDetails.hemorrhagesInMacula;
        end

        % Add DME to key findings
        if isfield(report, 'summary') && isfield(report.summary, 'keyFindings')
            if results.dmeDetails.csme
                report.summary.keyFindings{end+1} = sprintf('CSME detected — %s', results.dmeDetails.severity);
            elseif results.dmeDetails.detected
                report.summary.keyFindings{end+1} = sprintf('DME: %s', results.dmeDetails.severity);
            end
        end
    end

    %% ══════════════════════════════════════════════════════════════
    %  10. IRMA FINDINGS
    %% ══════════════════════════════════════════════════════════════
    if isfield(results, 'irmaDetails')
        report.irma = struct();
        report.irma.totalCount = results.irmaDetails.totalCount;
        report.irma.totalScore = results.irmaDetails.totalScore;
        report.irma.anyQuadrantPositive = results.irmaDetails.anyQuadrantPositive;
        report.irma.perQuadrant = results.irmaDetails.perQuadrant;

        if results.irmaDetails.totalCount > 0 && isfield(report, 'summary') && isfield(report.summary, 'keyFindings')
            report.summary.keyFindings{end+1} = sprintf('IRMA detected: %d regions', results.irmaDetails.totalCount);
        end
    end

    %% ══════════════════════════════════════════════════════════════
    %  11. ICDR 4-2-1 RULE DETAILS
    %% ══════════════════════════════════════════════════════════════
    if isfield(results, 'grading') && isfield(results.grading, 'rule421')
        report.rule421 = results.grading.rule421;
    end

    %% ══════════════════════════════════════════════════════════════
    %  12. EVIDENCE SENTENCES (from Grad-CAM correlation)
    %% ══════════════════════════════════════════════════════════════
    if isfield(results, 'gradcamDetails') && isfield(results.gradcamDetails, 'evidenceSentences')
        report.evidenceSentences = results.gradcamDetails.evidenceSentences;
    end

    %% ══════════════════════════════════════════════════════════════
    %  13. VALIDATION TIMER
    %  Estimate if the report can be reviewed by an ophthalmologist
    %  in under 30 seconds (target from requirements)
    %% ══════════════════════════════════════════════════════════════
    report.validationTimer = struct();

    % Count information items that need review
    infoItems = 0;
    infoItems = infoItems + 1;  % Primary diagnosis
    infoItems = infoItems + 1;  % Confidence
    infoItems = infoItems + 1;  % Referral recommendation

    if isfield(report, 'summary') && isfield(report.summary, 'keyFindings')
        infoItems = infoItems + length(report.summary.keyFindings);
    end
    if isfield(report, 'dme') && report.dme.detected
        infoItems = infoItems + 2;  % DME severity + CSME
    end

    % Estimated review time: ~2 seconds per info item + 5 seconds for image
    estimatedReviewSeconds = infoItems * 2 + 5;

    report.validationTimer.estimatedReviewSeconds = estimatedReviewSeconds;
    report.validationTimer.meetsTarget = estimatedReviewSeconds <= 30;
    report.validationTimer.targetSeconds = 30;
    report.validationTimer.infoItemCount = infoItems;

    if estimatedReviewSeconds <= 30
        report.validationTimer.status = 'PASS — Report can be validated within 30 seconds';
    else
        report.validationTimer.status = sprintf('WARNING — Estimated review time: %d seconds (exceeds 30s target)', estimatedReviewSeconds);
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
