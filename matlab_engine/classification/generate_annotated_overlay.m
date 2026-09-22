function [annotatedImg, overlayDetails] = generate_annotated_overlay(originalRGB, results, options)
% GENERATE_ANNOTATED_OVERLAY Creates a clinically annotated fundus image.
%   Draws lesion markers, Grad-CAM overlay, anatomical landmarks, and
%   diagnostic labels for single-glance ophthalmologist review.
%
%   [annotatedImg, overlayDetails] = generate_annotated_overlay(originalRGB, results, options)
%
%   Inputs:
%     originalRGB - Original RGB fundus image
%     results     - Complete results struct from main_pipeline
%     options     - (optional) struct with:
%       .showGradCAM      - bool (default: true)
%       .gradCAMAlpha     - overlay opacity 0-1 (default: 0.35)
%       .showLesions      - bool (default: true)
%       .showLandmarks    - bool (default: true)
%       .showDiagnosis    - bool (default: true)
%       .showLegend       - bool (default: true)
%       .savePath         - file path to save (empty = don't save)
%
%   Outputs:
%     annotatedImg   - Annotated RGB image (uint8)
%     overlayDetails - Struct with annotation counts and metadata

    if nargin < 3 || isempty(options)
        options = struct();
    end

    % Default options
    showGradCAM = getOpt(options, 'showGradCAM', true);
    gradCAMAlpha = getOpt(options, 'gradCAMAlpha', 0.35);
    showLesions = getOpt(options, 'showLesions', true);
    showLandmarks = getOpt(options, 'showLandmarks', true);
    showDiagnosis = getOpt(options, 'showDiagnosis', true);
    showLegend = getOpt(options, 'showLegend', true);
    savePath = getOpt(options, 'savePath', '');

    [rows, cols, ~] = size(originalRGB);
    annotatedImg = im2double(originalRGB);

    overlayDetails = struct();
    overlayDetails.annotationCount = 0;
    overlayDetails.lesionMarkersDrawn = 0;

    %% ══════════════════════════════════════════════════════════════
    %  1. GRAD-CAM HEATMAP OVERLAY
    %% ══════════════════════════════════════════════════════════════
    if showGradCAM && isfield(results, 'gradcam')
        heatmap = results.gradcam;

        % Resize heatmap to match image if needed
        if ~isequal(size(heatmap), [rows, cols])
            heatmap = imresize(heatmap, [rows, cols]);
        end

        % Normalize to [0, 1]
        heatmap = (heatmap - min(heatmap(:))) / (max(heatmap(:)) - min(heatmap(:)) + eps);

        % Create jet-like colormap overlay
        heatRGB = zeros(rows, cols, 3);
        heatRGB(:,:,1) = min(max(2*heatmap - 0.5, 0), 1);     % Red channel
        heatRGB(:,:,2) = min(max(1 - 2*abs(heatmap - 0.5), 0), 1); % Green channel
        heatRGB(:,:,3) = min(max(1 - 2*heatmap, 0), 1);        % Blue channel

        % Blend with original (only where heatmap is significant)
        blendMask = repmat(heatmap > 0.15, [1 1 3]);
        alphaMap = repmat(heatmap * gradCAMAlpha, [1 1 3]);

        annotatedImg = annotatedImg .* (1 - alphaMap .* blendMask) + ...
                       heatRGB .* alphaMap .* blendMask;
        annotatedImg = max(0, min(1, annotatedImg));

        overlayDetails.gradCAMApplied = true;
    end

    %% ══════════════════════════════════════════════════════════════
    %  2. ANATOMICAL LANDMARK MARKERS
    %% ══════════════════════════════════════════════════════════════
    if showLandmarks
        % Optic Disc — green circle
        if isfield(results, 'odCenter') && isfield(results, 'odRadius')
            annotatedImg = drawCircle(annotatedImg, results.odCenter, ...
                results.odRadius, [0 1 0.3], 2);
            overlayDetails.annotationCount = overlayDetails.annotationCount + 1;
        end

        % Fovea — cyan crosshair
        if isfield(results, 'foveaCenter')
            annotatedImg = drawCrosshair(annotatedImg, results.foveaCenter, ...
                15, [0 1 1], 2);
            overlayDetails.annotationCount = overlayDetails.annotationCount + 1;
        end
    end

    %% ══════════════════════════════════════════════════════════════
    %  3. LESION MARKERS (color-coded bounding boxes)
    %% ══════════════════════════════════════════════════════════════
    if showLesions
        % Microaneurysms — cyan dots
        if isfield(results, 'maMask') && any(results.maMask(:))
            [annotatedImg, nMarkers] = drawLesionMarkers(annotatedImg, ...
                results.maMask, [0 0.9 1], 'circle', 4);
            overlayDetails.lesionMarkersDrawn = overlayDetails.lesionMarkersDrawn + nMarkers;
        end

        % Hard Exudates — yellow outlines
        if isfield(results, 'hardExudateMask') && any(results.hardExudateMask(:))
            [annotatedImg, nMarkers] = drawLesionMarkers(annotatedImg, ...
                results.hardExudateMask, [1 0.9 0], 'contour', 1);
            overlayDetails.lesionMarkersDrawn = overlayDetails.lesionMarkersDrawn + nMarkers;
        end

        % Soft Exudates — white outlines
        if isfield(results, 'softExudateMask') && any(results.softExudateMask(:))
            [annotatedImg, nMarkers] = drawLesionMarkers(annotatedImg, ...
                results.softExudateMask, [1 1 1], 'contour', 1);
            overlayDetails.lesionMarkersDrawn = overlayDetails.lesionMarkersDrawn + nMarkers;
        end

        % Hemorrhages — red outlines
        if isfield(results, 'hemorrhageMask') && any(results.hemorrhageMask(:))
            [annotatedImg, nMarkers] = drawLesionMarkers(annotatedImg, ...
                results.hemorrhageMask, [1 0.2 0.1], 'contour', 2);
            overlayDetails.lesionMarkersDrawn = overlayDetails.lesionMarkersDrawn + nMarkers;
        end

        % Neovascularization — magenta outlines
        if isfield(results, 'nvMask') && any(results.nvMask(:))
            [annotatedImg, nMarkers] = drawLesionMarkers(annotatedImg, ...
                results.nvMask, [1 0 0.8], 'contour', 2);
            overlayDetails.lesionMarkersDrawn = overlayDetails.lesionMarkersDrawn + nMarkers;
        end

        % DME region — orange semi-transparent overlay
        if isfield(results, 'dmeMask') && any(results.dmeMask(:))
            dmeAlpha = 0.25;
            dmeColor = [1 0.6 0];
            for ch = 1:3
                channel = annotatedImg(:,:,ch);
                channel(results.dmeMask) = channel(results.dmeMask) * (1 - dmeAlpha) + dmeColor(ch) * dmeAlpha;
                annotatedImg(:,:,ch) = channel;
            end
            overlayDetails.lesionMarkersDrawn = overlayDetails.lesionMarkersDrawn + 1;
        end

        % IRMA — yellow-green markers
        if isfield(results, 'irmaMask') && any(results.irmaMask(:))
            [annotatedImg, nMarkers] = drawLesionMarkers(annotatedImg, ...
                results.irmaMask, [0.7 1 0], 'contour', 1);
            overlayDetails.lesionMarkersDrawn = overlayDetails.lesionMarkersDrawn + nMarkers;
        end
    end

    %% ══════════════════════════════════════════════════════════════
    %  4. DIAGNOSIS BADGE (top-right corner)
    %% ══════════════════════════════════════════════════════════════
    if showDiagnosis && isfield(results, 'grading')
        level = results.grading.level;
        label = results.grading.label;
        confidence = results.grading.confidence;

        % Color based on severity
        switch level
            case 0, badgeColor = [0.2 0.8 0.3];   % Green
            case 1, badgeColor = [0.9 0.85 0.1];   % Yellow
            case 2, badgeColor = [1 0.6 0.1];      % Orange
            case 3, badgeColor = [1 0.3 0.1];      % Red-Orange
            case 4, badgeColor = [1 0 0.1];         % Red
            otherwise, badgeColor = [0.5 0.5 0.5];
        end

        % Draw badge background (top-right)
        badgeH = round(rows * 0.06);
        badgeW = round(cols * 0.35);
        badgeR1 = 10;
        badgeR2 = 10 + badgeH;
        badgeC1 = cols - badgeW - 10;
        badgeC2 = cols - 10;

        % Clamp to image bounds
        badgeR2 = min(badgeR2, rows);
        badgeC2 = min(badgeC2, cols);

        for ch = 1:3
            annotatedImg(badgeR1:badgeR2, badgeC1:badgeC2, ch) = ...
                annotatedImg(badgeR1:badgeR2, badgeC1:badgeC2, ch) * 0.3 + badgeColor(ch) * 0.7;
        end

        % Draw urgency indicator for referable cases
        if results.grading.referable
            % Red border around the badge
            thickness = 3;
            for t = 0:thickness-1
                r1 = max(1, badgeR1-t); r2 = min(rows, badgeR2+t);
                c1 = max(1, badgeC1-t); c2 = min(cols, badgeC2+t);
                annotatedImg(r1, c1:c2, 1) = 1;
                annotatedImg(r1, c1:c2, 2:3) = 0;
                annotatedImg(r2, c1:c2, 1) = 1;
                annotatedImg(r2, c1:c2, 2:3) = 0;
                annotatedImg(r1:r2, c1, 1) = 1;
                annotatedImg(r1:r2, c1, 2:3) = 0;
                annotatedImg(r1:r2, c2, 1) = 1;
                annotatedImg(r1:r2, c2, 2:3) = 0;
            end
        end

        overlayDetails.annotationCount = overlayDetails.annotationCount + 1;
        overlayDetails.diagnosisBadge = struct('label', label, ...
            'confidence', confidence, 'level', level);
    end

    %% ══════════════════════════════════════════════════════════════
    %  5. LEGEND (bottom-left corner)
    %% ══════════════════════════════════════════════════════════════
    if showLegend
        legendColors = {
            [0 0.9 1],   'MA (Microaneurysms)'
            [1 0.9 0],   'HE (Hard Exudates)'
            [1 1 1],     'CWS (Cotton-wool Spots)'
            [1 0.2 0.1], 'Hemorrhages'
            [1 0 0.8],   'Neovascularization'
            [1 0.6 0],   'DME Region'
            [0.7 1 0],   'IRMA'
            [0 1 0.3],   'Optic Disc'
            [0 1 1],     'Fovea'
        };

        legendH = size(legendColors, 1) * round(rows * 0.025) + 20;
        legendW = round(cols * 0.22);
        legendR1 = rows - legendH - 10;
        legendC1 = 10;

        % Semi-transparent background
        legendR2 = min(rows - 10, legendR1 + legendH);
        legendC2 = min(cols - 10, legendC1 + legendW);

        for ch = 1:3
            annotatedImg(legendR1:legendR2, legendC1:legendC2, ch) = ...
                annotatedImg(legendR1:legendR2, legendC1:legendC2, ch) * 0.3;
        end

        % Draw color swatches
        swatchSize = round(rows * 0.015);
        yOffset = legendR1 + 10;
        for k = 1:size(legendColors, 1)
            color = legendColors{k, 1};
            sr1 = yOffset;
            sr2 = min(rows, yOffset + swatchSize);
            sc1 = legendC1 + 10;
            sc2 = min(cols, sc1 + swatchSize);

            if sr2 <= rows && sc2 <= cols
                for ch = 1:3
                    annotatedImg(sr1:sr2, sc1:sc2, ch) = color(ch);
                end
            end

            yOffset = yOffset + round(rows * 0.025);
        end

        overlayDetails.annotationCount = overlayDetails.annotationCount + 1;
    end

    %% ══════════════════════════════════════════════════════════════
    %  6. PIPELINE VERSION STAMP (bottom-right)
    %% ══════════════════════════════════════════════════════════════
    % Small semi-transparent version stamp
    stampH = round(rows * 0.025);
    stampW = round(cols * 0.2);
    stampR1 = rows - stampH - 10;
    stampC1 = cols - stampW - 10;
    stampR2 = min(rows, stampR1 + stampH);
    stampC2 = min(cols, stampC1 + stampW);

    if stampR1 > 0 && stampC1 > 0
        for ch = 1:3
            annotatedImg(stampR1:stampR2, stampC1:stampC2, ch) = ...
                annotatedImg(stampR1:stampR2, stampC1:stampC2, ch) * 0.5;
        end
    end

    %% ══════════════════════════════════════════════════════════════
    %  7. CONVERT TO UINT8 AND OPTIONALLY SAVE
    %% ══════════════════════════════════════════════════════════════
    annotatedImg = im2uint8(max(0, min(1, annotatedImg)));

    if ~isempty(savePath)
        imwrite(annotatedImg, savePath);
        overlayDetails.savedTo = savePath;
        fprintf('Annotated image saved to: %s\n', savePath);
    end

    overlayDetails.imageSize = [rows, cols];
    overlayDetails.totalAnnotations = overlayDetails.annotationCount + overlayDetails.lesionMarkersDrawn;

end

%% ══════════════════════════════════════════════════════════════
%  LOCAL HELPER FUNCTIONS
%% ══════════════════════════════════════════════════════════════

function val = getOpt(opts, field, default)
    if isfield(opts, field)
        val = opts.(field);
    else
        val = default;
    end
end

function img = drawCircle(img, center, radius, color, thickness)
% Draw a circle on the image
    [rows, cols, ~] = size(img);
    [X, Y] = meshgrid(1:cols, 1:rows);
    dist = sqrt((X - center(2)).^2 + (Y - center(1)).^2);

    for t = 0:thickness-1
        ring = abs(dist - radius - t) < 1.0;
        for ch = 1:3
            channel = img(:,:,ch);
            channel(ring) = color(ch);
            img(:,:,ch) = channel;
        end
    end
end

function img = drawCrosshair(img, center, armLength, color, thickness)
% Draw a crosshair marker
    [rows, cols, ~] = size(img);
    r = center(1); c = center(2);

    for t = -floor(thickness/2):floor(thickness/2)
        % Horizontal arm
        r1 = max(1, min(rows, r + t));
        cRange = max(1, c-armLength):min(cols, c+armLength);
        for ch = 1:3
            img(r1, cRange, ch) = color(ch);
        end

        % Vertical arm
        c1 = max(1, min(cols, c + t));
        rRange = max(1, r-armLength):min(rows, r+armLength);
        for ch = 1:3
            img(rRange, c1, ch) = color(ch);
        end
    end
end

function [img, nMarkers] = drawLesionMarkers(img, mask, color, style, thickness)
% Draw markers for detected lesions
    nMarkers = 0;

    if strcmp(style, 'contour')
        % Draw contour outlines around connected components
        se = strel('disk', max(1, thickness));
        dilated = imdilate(mask, se);
        contour = dilated & ~mask;

        for ch = 1:3
            channel = img(:,:,ch);
            channel(contour) = color(ch);
            img(:,:,ch) = channel;
        end

        cc = bwconncomp(mask);
        nMarkers = cc.NumObjects;

    elseif strcmp(style, 'circle')
        % Draw small circles around centroids
        cc = bwconncomp(mask);
        stats = regionprops(cc, 'Centroid', 'EquivDiameter');

        for i = 1:cc.NumObjects
            center = [round(stats(i).Centroid(2)), round(stats(i).Centroid(1))];
            radius = max(round(stats(i).EquivDiameter / 2) + 3, thickness + 2);
            img = drawCircle(img, center, radius, color, 1);
            nMarkers = nMarkers + 1;
        end
    end
end
