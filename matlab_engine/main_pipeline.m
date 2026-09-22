function [results] = main_pipeline(imagePath)
% MAIN_PIPELINE Complete Retinal Image Analysis Pipeline for DR Screening.
%   Integrates all analysis modules: quality assessment, enhancement,
%   segmentation, lesion detection, DME, IRMA, DR grading, explainability,
%   and annotated visual report generation.
%
%   results = main_pipeline('path/to/fundus.jpg')

    disp('═══════════════════════════════════════════════════════════');
    disp('  RETINAVISION — DR SCREENING PIPELINE v2.5.0');
    disp('═══════════════════════════════════════════════════════════');
    tic;

    %% ══════════════════════════════════════════════════════════════
    %  1. LOAD IMAGE
    %% ══════════════════════════════════════════════════════════════
    disp('[1/12] Loading image...');
    try
        img = imread(imagePath);
    catch ME
        error('Failed to load image: %s', ME.message);
    end

    results = struct();
    results.imagePath = imagePath;
    results.timestamp = datestr(now, 'dd-mmm-yyyy HH:MM:SS');

    %% ══════════════════════════════════════════════════════════════
    %  1b. IMAGE MODALITY VALIDATION
    %% ══════════════════════════════════════════════════════════════
    disp('[1.5/12] Validating Image Modality...');
    [isValidFundus, invalidReason] = validate_fundus(img);
    
    if ~isValidFundus
        disp(['       ✗ Image REJECTED — Invalid Modality: ' invalidReason]);
        results.status = 'Invalid_Modality';
        results.qualityGrade = 'Ungradeable';
        results.qualityFeedback = struct('recaptureReasons', {{invalidReason}}, 'suggestions', {{'Please ensure you are uploading a valid retinal fundus scan.'}});
        results.processingTime = toc;
        return;
    end
    disp('       ✓ Valid fundus image detected');

    %% ══════════════════════════════════════════════════════════════
    %  2. IMAGE QUALITY ASSESSMENT (3-tier grading)
    %% ══════════════════════════════════════════════════════════════
    disp('[2/12] Image Quality Assessment...');
    [qualityGrade, qualityMetrics, qualityFeedback] = assess_quality(img);

    results.qualityGrade = qualityGrade;
    results.quality = qualityMetrics;
    results.qualityFeedback = qualityFeedback;

    fprintf('       Quality Grade: %s (Score: %d)\n', qualityGrade, qualityMetrics.gradeScore);

    % Reject ungradeable images with detailed feedback
    if strcmp(qualityGrade, 'Ungradeable')
        disp('       ✗ Image REJECTED — Ungradeable');
        disp('       Recapture reasons:');
        for i = 1:length(qualityFeedback.recaptureReasons)
            fprintf('         • %s\n', qualityFeedback.recaptureReasons{i});
        end
        results.status = 'Rejected';
        results.processingTime = toc;
        return;
    end

    %% ══════════════════════════════════════════════════════════════
    %  3. IMAGE ENHANCEMENT (adaptive based on quality)
    %% ══════════════════════════════════════════════════════════════
    disp('[3/12] Adaptive Enhancement (CLAHE, illumination norm, denoising)...');
    [enhancedRGB, enhancedGreen] = enhance_fundus(img, qualityGrade);

    results.enhancedRGB = enhancedRGB;
    results.enhancedGreen = enhancedGreen;

    if strcmp(qualityGrade, 'Borderline')
        disp('       ↳ Borderline image — enhanced with aggressive parameters');
    end

    %% ══════════════════════════════════════════════════════════════
    %  4. OPTIC DISC LOCALIZATION
    %% ══════════════════════════════════════════════════════════════
    disp('[4/12] Optic Disc & Fovea Localization...');
    [odMask, odCenter, odRadius, odConfidence] = localize_optic_disc(enhancedGreen);

    results.odMask = odMask;
    results.odCenter = odCenter;
    results.odRadius = odRadius;
    results.odConfidence = odConfidence;

    fprintf('       OD: center=[%d,%d], radius=%d, confidence=%.2f\n', ...
        odCenter(1), odCenter(2), odRadius, odConfidence);

    % Fovea localization
    [foveaCenter, foveaConfidence, maculaMask] = localize_fovea(enhancedGreen, odMask, odCenter, odRadius);

    results.foveaCenter = foveaCenter;
    results.foveaConfidence = foveaConfidence;
    results.maculaMask = maculaMask;

    fprintf('       Fovea: center=[%d,%d], confidence=%.2f\n', ...
        foveaCenter(1), foveaCenter(2), foveaConfidence);

    %% ══════════════════════════════════════════════════════════════
    %  5. VESSEL SEGMENTATION
    %% ══════════════════════════════════════════════════════════════
    disp('[5/12] Multi-scale Vessel Segmentation...');
    [vesselMask, vesselMetrics] = segment_vessels(enhancedGreen, odMask);

    results.vesselMask = vesselMask;
    results.vesselMetrics = vesselMetrics;

    fprintf('       Vessels: density=%.3f, tortuosity=%.2f, branches=%d\n', ...
        vesselMetrics.density, vesselMetrics.meanTortuosity, vesselMetrics.branchingPoints);

    %% ══════════════════════════════════════════════════════════════
    %  6. LESION DETECTION (all types)
    %% ══════════════════════════════════════════════════════════════
    disp('[6/12] Comprehensive Lesion Detection...');
    results.lesions = struct();

    % Microaneurysms (sub-pixel detection)
    disp('       ↳ Microaneurysms...');
    [maMask, maCount, maDetails] = detect_microaneurysms(enhancedGreen, vesselMask, odMask);
    results.maMask = maMask;
    results.lesions.microaneurysms = maCount;
    results.lesions.maDetails = maDetails;
    fprintf('         Found: %d microaneurysms\n', maCount);

    % Hard & Soft Exudates
    disp('       ↳ Exudates (hard & soft)...');
    [hardExMask, softExMask, exDetails] = detect_exudates(enhancedGreen, img, vesselMask, odMask);
    results.hardExudateMask = hardExMask;
    results.softExudateMask = softExMask;
    results.lesions.hardExudates = exDetails.hardExudates.count;
    results.lesions.softExudates = exDetails.softExudates.count;
    results.lesions.exudateDetails = exDetails;
    fprintf('         Found: %d hard exudates, %d soft exudates\n', ...
        exDetails.hardExudates.count, exDetails.softExudates.count);

    % Hemorrhages (dot, blot, flame)
    disp('       ↳ Hemorrhages...');
    [hemMask, hemDetails] = detect_hemorrhages(enhancedGreen, vesselMask, odMask, maMask);
    results.hemorrhageMask = hemMask;
    results.lesions.hemorrhages = hemDetails;
    fprintf('         Found: %d dot, %d blot, %d flame hemorrhages\n', ...
        hemDetails.dotHemorrhages.count, hemDetails.blotHemorrhages.count, ...
        hemDetails.flameHemorrhages.count);

    % Neovascularization
    disp('       ↳ Neovascularization...');
    [nvMask, nvDetails] = detect_neovascularization(enhancedGreen, vesselMask, odMask, odCenter, odRadius);
    results.nvMask = nvMask;
    results.lesions.neovascularization = nvDetails;
    if nvDetails.nvdDetected || nvDetails.nveDetected
        fprintf('         ⚠ NV DETECTED (NVD=%s, NVE=%s, score=%.2f)\n', ...
            string(nvDetails.nvdDetected), string(nvDetails.nveDetected), nvDetails.totalScore);
    else
        disp('         No neovascularization detected');
    end

    %% ══════════════════════════════════════════════════════════════
    %  6.5. DIABETIC MACULAR EDEMA (DME) DETECTION
    %% ══════════════════════════════════════════════════════════════
    disp('[7/12] Diabetic Macular Edema Detection...');
    try
        [dmeMask, dmeDetails] = detect_dme(hardExMask, hemMask, foveaCenter, odRadius, maculaMask);
        results.dmeMask = dmeMask;
        results.dmeDetails = dmeDetails;

        fprintf('       DME: %s', dmeDetails.severity);
        if dmeDetails.csme
            fprintf(' (CSME DETECTED)');
        end
        fprintf('\n');
        if dmeDetails.referralRequired
            fprintf('       ⚠ DME Referral: %s\n', dmeDetails.referralUrgency);
        end
    catch ME
        disp(['       ⚠ DME detection failed: ' ME.message]);
        results.dmeDetails = struct('detected', false, 'severity', 'Unknown', ...
            'csme', false, 'referralRequired', false);
    end

    %% ══════════════════════════════════════════════════════════════
    %  6.6. IRMA DETECTION
    %% ══════════════════════════════════════════════════════════════
    disp('[8/12] IRMA (Intraretinal Microvascular Abnormalities) Detection...');
    try
        [irmaMask, irmaDetails] = detect_irma(enhancedGreen, vesselMask, odMask, odCenter, odRadius, foveaCenter);
        results.irmaMask = irmaMask;
        results.irmaDetails = irmaDetails;
        results.lesions.irma = irmaDetails;

        if irmaDetails.totalCount > 0
            fprintf('       IRMA: %d regions detected (any quadrant: %s)\n', ...
                irmaDetails.totalCount, string(irmaDetails.anyQuadrantPositive));
        else
            disp('       No IRMA detected');
        end
    catch ME
        disp(['       ⚠ IRMA detection failed: ' ME.message]);
        results.irmaDetails = struct('totalCount', 0, 'totalScore', 0, 'anyQuadrantPositive', false);
    end

    %% ══════════════════════════════════════════════════════════════
    %  7. QUADRANT-LEVEL HEMORRHAGE COUNTING
    %  Required for proper ICDR 4-2-1 rule
    %% ══════════════════════════════════════════════════════════════
    [rows, cols] = size(enhancedGreen);
    midRow = round((odCenter(1) + foveaCenter(1)) / 2);
    midCol = round((odCenter(2) + foveaCenter(2)) / 2);
    [X, Y] = meshgrid(1:cols, 1:rows);

    quadMasks = cell(4, 1);
    quadMasks{1} = Y <= midRow & X >= midCol;
    quadMasks{2} = Y <= midRow & X < midCol;
    quadMasks{3} = Y > midRow & X >= midCol;
    quadMasks{4} = Y > midRow & X < midCol;

    hemPerQuadrant = zeros(1, 4);
    for q = 1:4
        hemInQ = hemMask & quadMasks{q};
        cc_q = bwconncomp(hemInQ);
        hemPerQuadrant(q) = cc_q.NumObjects;
    end

    %% ══════════════════════════════════════════════════════════════
    %  8. DR SEVERITY GRADING (with full 4-2-1 rule data)
    %% ══════════════════════════════════════════════════════════════
    disp('[9/12] DR Severity Grading (CNN + ICDR 4-2-1 rule)...');
    modelPath = fullfile(fileparts(mfilename('fullpath')), 'trained_dr_model.mat');

    % Prepare lesion counts with quadrant-level data
    lesionCounts = struct();
    lesionCounts.ma = maCount;
    lesionCounts.hardExudates = exDetails.hardExudates.count;
    lesionCounts.softExudates = exDetails.softExudates.count;
    lesionCounts.dotHemorrhages = hemDetails.dotHemorrhages.count;
    lesionCounts.blotHemorrhages = hemDetails.blotHemorrhages.count;
    lesionCounts.flameHemorrhages = hemDetails.flameHemorrhages.count;
    lesionCounts.nvScore = nvDetails.totalScore;

    % Quadrant-level data for ICDR 4-2-1 rule
    lesionCounts.hemorrhagesPerQuadrant = hemPerQuadrant;
    lesionCounts.irmaAnyQuadrant = results.irmaDetails.anyQuadrantPositive;
    lesionCounts.irmaCount = results.irmaDetails.totalCount;
    if isfield(results, 'vesselMetrics') && isfield(results.vesselMetrics, 'beadingPerQuadrant')
        lesionCounts.venousBeadingPerQuadrant = results.vesselMetrics.beadingPerQuadrant;
    else
        lesionCounts.venousBeadingPerQuadrant = [0 0 0 0];
    end

    try
        [severityLevel, confidence, referable, gradeDetails] = ...
            grade_dr_severity(enhancedGreen, modelPath, lesionCounts);

        results.grading = gradeDetails;

        fprintf('       Grade: Level %d — %s (Confidence: %.1f%%)\n', ...
            severityLevel, gradeDetails.label, confidence);
        fprintf('       Referable: %s | Action: %s\n', ...
            string(referable), gradeDetails.recommendedAction);
    catch ME
        disp(['       ⚠ Could not grade: ' ME.message]);
        disp('       Using rule-based grading only...');

        results.grading = struct();
        results.grading.level = getRuleBasedLevel(lesionCounts);
        results.grading.label = getDRLabel(results.grading.level);
        results.grading.confidence = 75;
        results.grading.referable = results.grading.level >= 2;
        results.grading.recommendedAction = getDRAction(results.grading.level);
        results.grading.fusionNote = 'Rule-based grading only (model unavailable)';
    end

    % DME is an INDEPENDENT referral criterion
    if isfield(results, 'dmeDetails') && results.dmeDetails.referralRequired
        results.dmeReferral = true;
        if ~results.grading.referable
            disp('       ⚠ DME referral OVERRIDES non-referable DR grade');
        end
    else
        results.dmeReferral = false;
    end

    %% ══════════════════════════════════════════════════════════════
    %  9. EXPLAINABILITY (Grad-CAM + evidence correlation)
    %% ══════════════════════════════════════════════════════════════
    disp('[10/12] Generating Grad-CAM & Evidence Correlation...');

    lesionMasks = struct();
    lesionMasks.maMask = maMask;
    lesionMasks.hardExudateMask = hardExMask;
    lesionMasks.softExudateMask = softExMask;
    lesionMasks.hemorrhageMask = hemMask;
    lesionMasks.nvMask = nvMask;

    try
        [heatmap, gradcamDetails] = generate_gradcam(enhancedGreen, modelPath, lesionMasks);
        results.gradcam = heatmap;
        results.gradcamDetails = gradcamDetails;
        fprintf('       Grad-CAM usefulness: %s (%.1f%%)\n', ...
            gradcamDetails.usefulnessRating, gradcamDetails.clinicalUsefulness);
        if isfield(gradcamDetails, 'attentionCoherence')
            fprintf('       Attention coherence: %s (%.1f%%)\n', ...
                gradcamDetails.coherenceRating, gradcamDetails.attentionCoherence);
        end
    catch ME
        disp(['       ⚠ Grad-CAM failed: ' ME.message]);
        results.gradcam = zeros(size(enhancedGreen));
        results.gradcamDetails = struct('clinicalUsefulness', 0, ...
            'usefulnessRating', 'Unavailable', 'evidenceSentences', {{}});
    end

    %% ══════════════════════════════════════════════════════════════
    %  10. ANNOTATED VISUAL REPORT
    %% ══════════════════════════════════════════════════════════════
    disp('[11/12] Generating Annotated Visual Report...');
    try
        [annotatedImg, overlayDetails] = generate_annotated_overlay(img, results);
        results.annotatedOverlay = annotatedImg;
        results.overlayDetails = overlayDetails;
        fprintf('       Annotated overlay: %d annotations drawn\n', overlayDetails.totalAnnotations);
    catch ME
        disp(['       ⚠ Annotated overlay failed: ' ME.message]);
    end

    %% ══════════════════════════════════════════════════════════════
    %  11. CLINICAL REPORT GENERATION
    %% ══════════════════════════════════════════════════════════════
    disp('[12/12] Compiling Clinical Report...');
    results.clinicalReport = generate_clinical_report(results);
    results.status = 'Completed';
    results.processingTime = toc;

    disp('═══════════════════════════════════════════════════════════');
    fprintf('  PIPELINE COMPLETE — %.1f seconds\n', results.processingTime);
    fprintf('  Diagnosis: Level %d — %s\n', results.grading.level, results.grading.label);
    if isfield(results, 'dmeDetails') && results.dmeDetails.detected
        fprintf('  DME: %s', results.dmeDetails.severity);
        if results.dmeDetails.csme
            fprintf(' (CSME)');
        end
        fprintf('\n');
    end
    if results.dmeReferral && ~results.grading.referable
        disp('  ⚠ INDEPENDENT DME REFERRAL — even though DR is non-referable');
    end
    disp('═══════════════════════════════════════════════════════════');

end

%% ── Helper Functions ──

function level = getRuleBasedLevel(lc)
    if lc.nvScore > 0.3
        level = 4;
    elseif (lc.dotHemorrhages + lc.blotHemorrhages + lc.flameHemorrhages) >= 20
        level = 3;
    elseif lc.ma > 0 && (lc.hardExudates > 0 || lc.dotHemorrhages > 0)
        level = 2;
    elseif lc.ma > 0
        level = 1;
    else
        level = 0;
    end
end

function label = getDRLabel(level)
    labels = {'No DR', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'Proliferative DR'};
    label = labels{level + 1};
end

function action = getDRAction(level)
    actions = {'Routine screening in 12 months', ...
               'Repeat screening in 6-12 months', ...
               'Refer to ophthalmologist within 4-8 weeks', ...
               'URGENT: Refer within 1-2 weeks', ...
               'URGENT: Immediate referral'};
    action = actions{level + 1};
end
