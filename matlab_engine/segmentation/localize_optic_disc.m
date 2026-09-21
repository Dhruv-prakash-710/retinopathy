function [odMask, odCenter, odRadius, odConfidence] = localize_optic_disc(enhancedGreen)
% LOCALIZE_OPTIC_DISC Advanced optic disc localization with adaptive radius.
%   Uses multi-method approach: brightness search + Hough circle detection +
%   morphological validation for robust OD boundary estimation.
%
%   [odMask, odCenter, odRadius, odConfidence] = localize_optic_disc(enhancedGreen)
%
%   Outputs:
%     odMask       - Binary mask of the optic disc region
%     odCenter     - [row, col] center of the optic disc
%     odRadius     - Estimated radius in pixels
%     odConfidence - Localization confidence [0-1]

    imgDouble = im2double(enhancedGreen);
    [rows, cols] = size(imgDouble);

    %% ══════════════════════════════════════════════════════════════
    %  Step 1: Brightness-based initial localization
    %% ══════════════════════════════════════════════════════════════
    % Heavily smooth to eliminate small bright lesions (exudates)
    sigma = round(min(rows, cols) * 0.03);
    smoothed = imgaussfilt(imgDouble, sigma);

    % Find the brightest region
    [~, maxIdx] = max(smoothed(:));
    [brightRow, brightCol] = ind2sub(size(smoothed), maxIdx);

    %% ══════════════════════════════════════════════════════════════
    %  Step 2: Adaptive radius estimation
    %% ══════════════════════════════════════════════════════════════
    % OD radius is approximately 1/14 of the image width for standard 45° FOV
    % Adapt based on image resolution
    estimatedRadius = round(min(rows, cols) / 14);
    radiusRange = [round(estimatedRadius * 0.6), round(estimatedRadius * 1.5)];

    %% ══════════════════════════════════════════════════════════════
    %  Step 3: Hough Circle Detection around bright region
    %% ══════════════════════════════════════════════════════════════
    % Extract ROI around the brightest point for focused circle detection
    roiHalf = round(estimatedRadius * 3);
    r1 = max(1, brightRow - roiHalf);
    r2 = min(rows, brightRow + roiHalf);
    c1 = max(1, brightCol - roiHalf);
    c2 = min(cols, brightCol + roiHalf);

    roi = imgDouble(r1:r2, c1:c2);

    % Edge detection for Hough transform
    roiEdges = edge(roi, 'canny', [0.1 0.3]);

    % Attempt circular Hough transform
    houghSuccess = false;
    try
        [centers, radii, metric] = imfindcircles(roiEdges, radiusRange, ...
            'ObjectPolarity', 'bright', ...
            'Sensitivity', 0.92, ...
            'EdgeThreshold', 0.1);

        if ~isempty(centers)
            % Select the circle with highest metric near the bright center
            % Convert ROI coordinates back to full image coordinates
            bestCenter = [centers(1,2) + r1 - 1, centers(1,1) + c1 - 1];
            bestRadius = round(radii(1));
            houghConfidence = min(metric(1), 1.0);
            houghSuccess = true;
        end
    catch
        % imfindcircles might not be available or fail
        houghSuccess = false;
    end

    %% ══════════════════════════════════════════════════════════════
    %  Step 4: Morphological validation
    %% ══════════════════════════════════════════════════════════════
    % Threshold the bright region around the initial estimate
    localROI = smoothed(r1:r2, c1:c2);
    threshLevel = graythresh(localROI) * 1.2;
    threshLevel = min(threshLevel, 0.95);
    brightMask = localROI > threshLevel;
    brightMask = imfill(brightMask, 'holes');
    brightMask = bwareaopen(brightMask, round(pi * radiusRange(1)^2 * 0.3));

    morphSuccess = false;
    if sum(brightMask(:)) > 50
        stats = regionprops(brightMask, 'Centroid', 'EquivDiameter', 'Circularity');
        if ~isempty(stats)
            % Find the most circular region
            circularities = [stats.Circularity];
            [~, bestIdx] = max(circularities);
            morphCenter = [stats(bestIdx).Centroid(2) + r1 - 1, ...
                          stats(bestIdx).Centroid(1) + c1 - 1];
            morphRadius = round(stats(bestIdx).EquivDiameter / 2);
            morphCircularity = stats(bestIdx).Circularity;
            morphSuccess = true;
        end
    end

    %% ══════════════════════════════════════════════════════════════
    %  Step 5: Combine results from multiple methods
    %% ══════════════════════════════════════════════════════════════
    if houghSuccess && morphSuccess
        % Weighted average of both methods
        w_hough = houghConfidence;
        w_morph = morphCircularity * 0.8;
        wTotal = w_hough + w_morph;

        odCenter = round((bestCenter * w_hough + morphCenter * w_morph) / wTotal);
        odRadius = round((bestRadius * w_hough + morphRadius * w_morph) / wTotal);
        odConfidence = min((w_hough + w_morph) / 2 + 0.1, 1.0);
    elseif houghSuccess
        odCenter = round(bestCenter);
        odRadius = bestRadius;
        odConfidence = houghConfidence * 0.8;
    elseif morphSuccess
        odCenter = round(morphCenter);
        odRadius = morphRadius;
        odConfidence = morphCircularity * 0.6;
    else
        % Fallback: use brightness peak with estimated radius
        odCenter = [brightRow, brightCol];
        odRadius = estimatedRadius;
        odConfidence = 0.3;
    end

    % Clamp radius to reasonable range
    odRadius = max(radiusRange(1), min(radiusRange(2), odRadius));

    % Ensure center is within image bounds
    odCenter(1) = max(odRadius + 1, min(rows - odRadius, odCenter(1)));
    odCenter(2) = max(odRadius + 1, min(cols - odRadius, odCenter(2)));

    %% ══════════════════════════════════════════════════════════════
    %  Step 6: Generate OD mask
    %% ══════════════════════════════════════════════════════════════
    [X, Y] = meshgrid(1:cols, 1:rows);
    odMask = (X - odCenter(2)).^2 + (Y - odCenter(1)).^2 <= odRadius^2;

end
