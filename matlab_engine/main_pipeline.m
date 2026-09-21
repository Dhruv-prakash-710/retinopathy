function [results] = main_pipeline(imagePath)
% MAIN_PIPELINE Complete Retinal Image Analysis Pipeline for DR Screening.
%   Integrates all analysis modules: quality assessment, enhancement,
%   segmentation, lesion detection, DR grading, and explainability.
%
%   results = main_pipeline('path/to/fundus.jpg')

    disp('═══════════════════════════════════════════════════════════');
    disp('  RETINAVISION — DR SCREENING PIPELINE v2.4.1');
    disp('═══════════════════════════════════════════════════════════');
    tic;

    %% ══════════════════════════════════════════════════════════════
    %  1. LOAD IMAGE
    %% ══════════════════════════════════════════════════════════════
    disp('[1/9] Loading image...');
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
    disp('[1.5/9] Validating Image Modality...');
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
    disp('[2/9] Image Quality Assessment...');
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
    disp('[3/9] Adaptive Enhancement (CLAHE, illumination norm, denoising)...');
    [enhancedRGB, enhancedGreen] = enhance_fundus(img, qualityGrade);

    results.enhancedRGB = enhancedRGB;
    results.enhancedGreen = enhancedGreen;

    if strcmp(qualityGrade, 'Borderline')
        disp('       ↳ Borderline image — enhanced with aggressive parameters');
    end

    %% ══════════════════════════════════════════════════════════════
    %  4. OPTIC DISC LOCALIZATION
    %% ══════════════════════════════════════════════════════════════
    disp('[4/9] Optic Disc & Fovea Localization...');
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
    disp('[5/9] Multi-scale Vessel Segmentation...');
    [vesselMask, vesselMetrics] = segment_vessels(enhancedGreen, odMask);

    results.vesselMask = vesselMask;
    results.vesselMetrics = vesselMetrics;

    fprintf('       Vessels: density=%.3f, tortuosity=%.2f, branches=%d\n', ...
        vesselMetrics.density, vesselMetrics.meanTortuosity, vesselMetrics.branchingPoints);

    %% ══════════════════════════════════════════════════════════════
    %  6. LESION DETECTION (all types)
    %% ══════════════════════════════════════════════════════════════
    disp('[6/9] Comprehensive Lesion Detection...');
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
    %  7. DR SEVERITY GRADING
    %% ══════════════════════════════════════════════════════════════
    disp('[7/9] DR Severity Grading (CNN + ICDR rules)...');
    modelPath = fullfile(fileparts(mfilename('fullpath')), 'trained_dr_model.mat');

    % Prepare lesion counts for rule-based verification
    lesionCounts = struct();
    lesionCounts.ma = maCount;
    lesionCounts.hardExudates = exDetails.hardExudates.count;
    lesionCounts.softExudates = exDetails.softExudates.count;
    lesionCounts.dotHemorrhages = hemDetails.dotHemorrhages.count;
    lesionCounts.blotHemorrhages = hemDetails.blotHemorrhages.count;
    lesionCounts.flameHemorrhages = hemDetails.flameHemorrhages.count;
    lesionCounts.nvScore = nvDetails.totalScore;

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

        % Fallback: use rule-based grading from lesion counts
        results.grading = struct();
        results.grading.level = getRuleBasedLevel(lesionCounts);
        results.grading.label = getDRLabel(results.grading.level);
        results.grading.confidence = 75;
        results.grading.referable = results.grading.level >= 2;
        results.grading.recommendedAction = getDRAction(results.grading.level);
        results.grading.fusionNote = 'Rule-based grading only (model unavailable)';
    end

    %% ══════════════════════════════════════════════════════════════
    %  8. EXPLAINABILITY (Grad-CAM + evidence correlation)
    %% ══════════════════════════════════════════════════════════════
    disp('[8/9] Generating Grad-CAM & Evidence Correlation...');

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
    catch ME
        disp(['       ⚠ Grad-CAM failed: ' ME.message]);
        results.gradcam = zeros(size(enhancedGreen));
        results.gradcamDetails = struct('clinicalUsefulness', 0, 'usefulnessRating', 'Unavailable');
    end

    %% ══════════════════════════════════════════════════════════════
    %  9. CLINICAL REPORT GENERATION
    %% ══════════════════════════════════════════════════════════════
    disp('[9/9] Compiling Clinical Report...');
    results.clinicalReport = generate_clinical_report(results);
    results.status = 'Completed';
    results.processingTime = toc;

    disp('═══════════════════════════════════════════════════════════');
    fprintf('  PIPELINE COMPLETE — %.1f seconds\n', results.processingTime);
    fprintf('  Diagnosis: Level %d — %s\n', results.grading.level, results.grading.label);
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
