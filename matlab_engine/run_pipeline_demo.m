function run_pipeline_demo(imagePath)
% RUN_PIPELINE_DEMO End-to-end demonstration of the DR screening pipeline.
%   Processes a fundus image through all stages and displays results
%   in a comprehensive multi-panel figure with clinical summary.
%
%   run_pipeline_demo('path/to/fundus.jpg')
%   run_pipeline_demo()  % Uses a built-in test pattern
%
%   Displays:
%     Panel 1: Original image
%     Panel 2: Enhanced image (CLAHE + illumination norm)
%     Panel 3: Vessel segmentation mask
%     Panel 4: Lesion detection overlays
%     Panel 5: Grad-CAM heatmap
%     Panel 6: Annotated clinical report image

    disp('═══════════════════════════════════════════════════════════');
    disp('  RETINAVISION — PIPELINE DEMONSTRATION');
    disp('═══════════════════════════════════════════════════════════');

    %% ══════════════════════════════════════════════════════════════
    %  1. LOAD OR GENERATE TEST IMAGE
    %% ══════════════════════════════════════════════════════════════
    if nargin < 1 || isempty(imagePath)
        disp('No image provided — generating synthetic fundus test pattern...');
        img = generateSyntheticFundus();
        imagePath = 'synthetic_fundus_test.png';
        imwrite(img, fullfile(tempdir, imagePath));
        imagePath = fullfile(tempdir, imagePath);
        disp(['Saved synthetic fundus to: ' imagePath]);
    else
        if ~isfile(imagePath)
            error('Image not found: %s', imagePath);
        end
    end

    %% ══════════════════════════════════════════════════════════════
    %  2. RUN THE FULL PIPELINE
    %% ══════════════════════════════════════════════════════════════
    disp(' ');
    disp('Running full analysis pipeline...');
    disp('─────────────────────────────────────────────────────────');

    try
        results = main_pipeline(imagePath);
    catch ME
        fprintf('Pipeline error: %s\n', ME.message);
        disp('Attempting partial pipeline for demo...');
        results = runPartialPipeline(imagePath);
    end

    %% ══════════════════════════════════════════════════════════════
    %  3. DISPLAY RESULTS IN MULTI-PANEL FIGURE
    %% ══════════════════════════════════════════════════════════════
    disp(' ');
    disp('Generating visualization...');

    originalImg = imread(imagePath);
    fig = figure('Name', 'RetinaVision DR Pipeline Demo', ...
        'NumberTitle', 'off', ...
        'Color', [0.1 0.1 0.12], ...
        'Position', [50 50 1400 900]);

    % ── Panel 1: Original Image ──
    subplot(2, 3, 1);
    imshow(originalImg);
    title('1. Original Fundus Image', 'Color', 'w', 'FontSize', 11);
    if isfield(results, 'quality')
        xlabel(sprintf('Quality: %s (Score: %d)', ...
            results.qualityGrade, results.quality.gradeScore), ...
            'Color', [0.7 0.7 0.7], 'FontSize', 9);
    end

    % ── Panel 2: Enhanced Image ──
    subplot(2, 3, 2);
    if isfield(results, 'enhancedRGB')
        imshow(results.enhancedRGB);
        title('2. Enhanced (CLAHE + Illumination Norm)', 'Color', 'w', 'FontSize', 11);
    else
        imshow(originalImg);
        title('2. Enhancement Skipped', 'Color', [1 0.5 0], 'FontSize', 11);
    end

    % ── Panel 3: Vessel Segmentation ──
    subplot(2, 3, 3);
    if isfield(results, 'vesselMask')
        vesselDisplay = repmat(im2double(rgb2gray(originalImg)), [1 1 3]);
        vesselOverlay = vesselDisplay;
        vesselOverlay(:,:,1) = vesselOverlay(:,:,1) + 0.3 * double(results.vesselMask);
        vesselOverlay(:,:,2) = vesselOverlay(:,:,2) + 0.5 * double(results.vesselMask);
        vesselOverlay(:,:,3) = vesselOverlay(:,:,3) + 0.3 * double(results.vesselMask);
        vesselOverlay = min(1, vesselOverlay);
        imshow(vesselOverlay);
        title(sprintf('3. Vessel Segmentation (density=%.3f)', ...
            results.vesselMetrics.density), 'Color', 'w', 'FontSize', 11);
    else
        imshow(zeros(size(originalImg, 1), size(originalImg, 2)));
        title('3. Vessel Segmentation (unavailable)', 'Color', [1 0.5 0], 'FontSize', 11);
    end

    % ── Panel 4: Lesion Detection Overlay ──
    subplot(2, 3, 4);
    lesionOverlay = im2double(originalImg);
    lesionCount = 0;
    if isfield(results, 'maMask')
        for ch = 1:3
            c = lesionOverlay(:,:,ch);
            c(results.maMask) = [0 1 1];
            lesionOverlay(:,:,ch) = c;
        end
        % Color MA pixels cyan
        lesionOverlay(:,:,1) = lesionOverlay(:,:,1) .* ~results.maMask;
        lesionOverlay(:,:,2) = min(1, lesionOverlay(:,:,2) + 0.8 * double(results.maMask));
        lesionOverlay(:,:,3) = min(1, lesionOverlay(:,:,3) + 0.8 * double(results.maMask));
        lesionCount = lesionCount + results.lesions.microaneurysms;
    end
    if isfield(results, 'hardExudateMask')
        lesionOverlay(:,:,1) = min(1, lesionOverlay(:,:,1) + 0.7 * double(results.hardExudateMask));
        lesionOverlay(:,:,2) = min(1, lesionOverlay(:,:,2) + 0.6 * double(results.hardExudateMask));
        lesionCount = lesionCount + results.lesions.hardExudates;
    end
    if isfield(results, 'hemorrhageMask')
        lesionOverlay(:,:,1) = min(1, lesionOverlay(:,:,1) + 0.8 * double(results.hemorrhageMask));
        lesionCount = lesionCount + results.lesions.hemorrhages.totalCount;
    end
    imshow(lesionOverlay);
    title(sprintf('4. Lesion Detection (%d lesions)', lesionCount), ...
        'Color', 'w', 'FontSize', 11);

    % ── Panel 5: Grad-CAM Heatmap ──
    subplot(2, 3, 5);
    if isfield(results, 'gradcam')
        heatmap = results.gradcam;
        if ~isequal(size(heatmap), [size(originalImg,1), size(originalImg,2)])
            heatmap = imresize(heatmap, [size(originalImg,1), size(originalImg,2)]);
        end
        heatRGB = ind2rgb(im2uint8(heatmap), jet(256));
        blended = 0.5 * im2double(originalImg) + 0.5 * heatRGB;
        imshow(blended);
        if isfield(results, 'gradcamDetails')
            xlabel(sprintf('Usefulness: %s (%.1f%%)', ...
                results.gradcamDetails.usefulnessRating, ...
                results.gradcamDetails.clinicalUsefulness), ...
                'Color', [0.7 0.7 0.7], 'FontSize', 9);
        end
    else
        imshow(zeros(size(originalImg, 1), size(originalImg, 2)));
    end
    title('5. Grad-CAM Attention Map', 'Color', 'w', 'FontSize', 11);

    % ── Panel 6: Annotated Clinical Report ──
    subplot(2, 3, 6);
    if isfield(results, 'annotatedOverlay')
        imshow(results.annotatedOverlay);
    else
        % Generate on the fly
        try
            [annotated, ~] = generate_annotated_overlay(originalImg, results);
            imshow(annotated);
        catch
            imshow(originalImg);
        end
    end
    title('6. Annotated Clinical Report', 'Color', 'w', 'FontSize', 11);

    %% ══════════════════════════════════════════════════════════════
    %  4. PRINT CLINICAL SUMMARY TO CONSOLE
    %% ══════════════════════════════════════════════════════════════
    disp(' ');
    disp('─────────────────────────────────────────────────────────');
    disp('  CLINICAL SUMMARY');
    disp('─────────────────────────────────────────────────────────');

    if isfield(results, 'grading')
        fprintf('  Diagnosis:    Level %d — %s\n', results.grading.level, results.grading.label);
        fprintf('  Confidence:   %.1f%%\n', results.grading.confidence);
        fprintf('  Referable:    %s\n', mat2str(results.grading.referable));
        fprintf('  Action:       %s\n', results.grading.recommendedAction);
    end

    if isfield(results, 'dmeDetails')
        fprintf('  DME:          %s', results.dmeDetails.severity);
        if results.dmeDetails.csme
            fprintf(' (CSME ✗)');
        end
        fprintf('\n');
    end

    fprintf('  Quality:      %s\n', results.qualityGrade);
    fprintf('  Processing:   %.1f seconds\n', results.processingTime);

    if isfield(results, 'lesions')
        fprintf('\n  Lesions Found:\n');
        fprintf('    Microaneurysms:      %d\n', results.lesions.microaneurysms);
        fprintf('    Hard Exudates:       %d\n', results.lesions.hardExudates);
        fprintf('    Soft Exudates:       %d\n', results.lesions.softExudates);
        if isfield(results.lesions, 'hemorrhages')
            fprintf('    Hemorrhages:         %d (dot:%d, blot:%d, flame:%d)\n', ...
                results.lesions.hemorrhages.totalCount, ...
                results.lesions.hemorrhages.dotHemorrhages.count, ...
                results.lesions.hemorrhages.blotHemorrhages.count, ...
                results.lesions.hemorrhages.flameHemorrhages.count);
        end
        if isfield(results.lesions, 'irma')
            fprintf('    IRMA:                %d\n', results.lesions.irma.totalCount);
        end
    end

    disp('─────────────────────────────────────────────────────────');
    disp(' ');

    %% ══════════════════════════════════════════════════════════════
    %  5. EXPORT RESULTS AS JSON-COMPATIBLE STRUCT
    %% ══════════════════════════════════════════════════════════════
    % Remove non-serializable fields (masks, images)
    exportResults = results;
    fieldsToRemove = {'enhancedRGB', 'enhancedGreen', 'odMask', 'maculaMask', ...
        'vesselMask', 'maMask', 'hardExudateMask', 'softExudateMask', ...
        'hemorrhageMask', 'nvMask', 'dmeMask', 'irmaMask', 'gradcam', ...
        'annotatedOverlay'};

    for f = 1:length(fieldsToRemove)
        if isfield(exportResults, fieldsToRemove{f})
            exportResults = rmfield(exportResults, fieldsToRemove{f});
        end
    end

    % Remove mask fields from nested structs
    if isfield(exportResults, 'lesions') && isfield(exportResults.lesions, 'hemorrhages')
        if isfield(exportResults.lesions.hemorrhages, 'dotHemorrhages')
            exportResults.lesions.hemorrhages.dotHemorrhages = ...
                rmfield(exportResults.lesions.hemorrhages.dotHemorrhages, 'mask');
            exportResults.lesions.hemorrhages.blotHemorrhages = ...
                rmfield(exportResults.lesions.hemorrhages.blotHemorrhages, 'mask');
            exportResults.lesions.hemorrhages.flameHemorrhages = ...
                rmfield(exportResults.lesions.hemorrhages.flameHemorrhages, 'mask');
        end
    end

    % Save JSON
    jsonPath = fullfile(tempdir, 'retinavision_demo_results.json');
    try
        jsonText = jsonencode(exportResults, 'PrettyPrint', true);
        fid = fopen(jsonPath, 'w');
        fprintf(fid, '%s', jsonText);
        fclose(fid);
        fprintf('Results exported to: %s\n', jsonPath);
    catch
        disp('Note: JSON export requires MATLAB R2021a+ (jsonencode with PrettyPrint)');
    end

    disp('═══════════════════════════════════════════════════════════');
    disp('  DEMO COMPLETE');
    disp('═══════════════════════════════════════════════════════════');

end

%% ══════════════════════════════════════════════════════════════
%  SYNTHETIC FUNDUS GENERATOR (for demo when no real image available)
%% ══════════════════════════════════════════════════════════════
function img = generateSyntheticFundus()
% Generate a synthetic fundus-like test pattern for demonstration

    sz = 512;
    [X, Y] = meshgrid(1:sz, 1:sz);
    cx = sz/2; cy = sz/2;

    % Circular FOV with dark borders
    dist = sqrt((X - cx).^2 + (Y - cy).^2);
    fovMask = dist < sz * 0.42;
    fovGrad = max(0, 1 - (dist / (sz * 0.42)).^2);

    % Background: orange-red fundus color
    R = fovGrad * 0.7;
    G = fovGrad * 0.35;
    B = fovGrad * 0.12;

    % Optic disc (bright yellowish region)
    odDist = sqrt((X - sz*0.7).^2 + (Y - cy).^2);
    odMask = exp(-odDist.^2 / (2 * 25^2));
    R = R + odMask * 0.3;
    G = G + odMask * 0.25;
    B = B + odMask * 0.15;

    % Fovea (dark spot)
    fovDist = sqrt((X - sz*0.45).^2 + (Y - cy).^2);
    fovDark = exp(-fovDist.^2 / (2 * 15^2)) * 0.15;
    R = R - fovDark;
    G = G - fovDark;

    % Simulate vessels (dark lines radiating from OD)
    for angle = [0 30 60 90 120 150 180 210 240 270 300 330]
        theta = angle * pi / 180;
        for t = 20:2:sz*0.4
            vx = round(sz*0.7 + t * cos(theta) + 3*sin(t*0.05));
            vy = round(cy + t * sin(theta) + 3*cos(t*0.05));
            if vx > 3 && vx < sz-3 && vy > 3 && vy < sz-3
                R(vy-1:vy+1, vx-1:vx+1) = R(vy-1:vy+1, vx-1:vx+1) * 0.6;
                G(vy-1:vy+1, vx-1:vx+1) = G(vy-1:vy+1, vx-1:vx+1) * 0.5;
                B(vy-1:vy+1, vx-1:vx+1) = B(vy-1:vy+1, vx-1:vx+1) * 0.7;
            end
        end
    end

    % Add some synthetic microaneurysms (small dark dots)
    rng(42);
    for k = 1:8
        mx = randi([sz*0.3, sz*0.6]);
        my = randi([sz*0.3, sz*0.7]);
        if fovMask(my, mx)
            maDist = sqrt((X - mx).^2 + (Y - my).^2);
            maDot = exp(-maDist.^2 / (2 * 2^2)) * 0.1;
            G = G - maDot;
        end
    end

    % Add some synthetic hard exudates (small bright spots)
    for k = 1:5
        ex = randi([sz*0.35, sz*0.55]);
        ey = randi([sz*0.35, sz*0.65]);
        if fovMask(ey, ex)
            heDist = sqrt((X - ex).^2 + (Y - ey).^2);
            heDot = exp(-heDist.^2 / (2 * 4^2)) * 0.15;
            R = R + heDot;
            G = G + heDot * 0.8;
        end
    end

    % Clip and convert
    R = max(0, min(1, R)) .* fovMask;
    G = max(0, min(1, G)) .* fovMask;
    B = max(0, min(1, B)) .* fovMask;

    img = im2uint8(cat(3, R, G, B));
end

%% ══════════════════════════════════════════════════════════════
%  PARTIAL PIPELINE (fallback when full pipeline fails)
%% ══════════════════════════════════════════════════════════════
function results = runPartialPipeline(imagePath)
% Minimal pipeline for demo purposes when full pipeline encounters errors

    img = imread(imagePath);
    results = struct();
    results.imagePath = imagePath;
    results.timestamp = datestr(now);
    results.qualityGrade = 'Gradeable';
    results.quality = struct('gradeScore', 80, 'compositeFocus', 75);
    results.status = 'Partial';
    results.processingTime = 0;

    % Attempt preprocessing
    try
        [qualityGrade, qualityMetrics, ~] = assess_quality(img);
        results.qualityGrade = qualityGrade;
        results.quality = qualityMetrics;
    catch
    end

    % Attempt enhancement
    try
        [enhRGB, enhGreen] = enhance_fundus(img, results.qualityGrade);
        results.enhancedRGB = enhRGB;
        results.enhancedGreen = enhGreen;
    catch
    end

    results.grading = struct('level', 0, 'label', 'Unable to grade', ...
        'confidence', 0, 'referable', false, ...
        'recommendedAction', 'Manual review required');
    results.lesions = struct('microaneurysms', 0, 'hardExudates', 0, ...
        'softExudates', 0, 'hemorrhages', struct('totalCount', 0, ...
        'dotHemorrhages', struct('count', 0), ...
        'blotHemorrhages', struct('count', 0), ...
        'flameHemorrhages', struct('count', 0)));

end
