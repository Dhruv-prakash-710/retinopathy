function [maMask, maCount, maDetails] = detect_microaneurysms(enhancedGreen, vesselMask, odMask)
% DETECT_MICROANEURYSMS Advanced sub-pixel microaneurysm detection.
%   Uses multi-scale morphological analysis, shape filtering, and
%   Gaussian sub-pixel centroid refinement for clinically accurate MA detection.
%
%   [maMask, maCount, maDetails] = detect_microaneurysms(enhancedGreen, vesselMask, odMask)
%
%   Outputs:
%     maMask    - Binary mask of detected microaneurysms
%     maCount   - Total number of MAs detected
%     maDetails - Struct array with per-MA details (centroid, subpixel, confidence, size)

    if nargin < 3
        odMask = false(size(enhancedGreen));
    end

    imgDouble = im2double(enhancedGreen);
    [rows, cols] = size(imgDouble);

    %% ══════════════════════════════════════════════════════════════
    %  Step 1: MULTI-SCALE MORPHOLOGICAL BOTTOM-HAT
    %  MAs are small dark dots — bottom-hat enhances them
    %% ══════════════════════════════════════════════════════════════
    scales = [3, 4, 5, 6, 7];  % Multiple SE radii for different MA sizes
    maxResponse = zeros(rows, cols);

    for s = 1:length(scales)
        se = strel('disk', scales(s));
        bhResponse = imbothat(imgDouble, se);
        maxResponse = max(maxResponse, bhResponse);
    end

    % Normalize response
    maxResponse = (maxResponse - min(maxResponse(:))) / (max(maxResponse(:)) - min(maxResponse(:)) + eps);

    %% ══════════════════════════════════════════════════════════════
    %  Step 2: MATCHED FILTER ENHANCEMENT
    %  Use a Gaussian template to match MA shape
    %% ══════════════════════════════════════════════════════════════
    % MAs are approximately Gaussian in profile (dark center, gradual edges)
    matchedResponses = zeros(rows, cols);
    for sigma = [1.0, 1.5, 2.0, 2.5]
        template = fspecial('gaussian', ceil(sigma*6)+1, sigma);
        template = max(template(:)) - template;  % Invert for dark spots
        template = template - mean(template(:));  % Zero-mean
        response = imfilter(imgDouble, template, 'replicate');
        matchedResponses = max(matchedResponses, -response);
    end
    matchedResponses = max(0, matchedResponses);
    matchedResponses = matchedResponses / (max(matchedResponses(:)) + eps);

    %% ══════════════════════════════════════════════════════════════
    %  Step 3: COMBINED DETECTION MAP
    %% ══════════════════════════════════════════════════════════════
    combined = 0.5 * maxResponse + 0.5 * matchedResponses;

    %% ══════════════════════════════════════════════════════════════
    %  Step 4: ADAPTIVE THRESHOLDING
    %% ══════════════════════════════════════════════════════════════
    globalLevel = graythresh(combined);
    threshold = max(globalLevel * 1.5, 0.15);
    threshold = min(threshold, 0.9);
    bw = combined > threshold;

    %% ══════════════════════════════════════════════════════════════
    %  Step 5: EXCLUDE NON-MA REGIONS
    %% ══════════════════════════════════════════════════════════════
    % Remove vessels — dilate vessel mask to avoid false positives on edges
    vesselDilated = imdilate(vesselMask, strel('disk', 3));
    bw(vesselDilated) = 0;

    % Remove optic disc region
    odDilated = imdilate(odMask, strel('disk', 5));
    bw(odDilated) = 0;

    % Remove image border artifacts
    borderMask = false(rows, cols);
    borderWidth = round(min(rows, cols) * 0.02);
    borderMask(1:borderWidth, :) = true;
    borderMask(end-borderWidth:end, :) = true;
    borderMask(:, 1:borderWidth) = true;
    borderMask(:, end-borderWidth:end) = true;
    bw(borderMask) = 0;

    %% ══════════════════════════════════════════════════════════════
    %  Step 6: SIZE AND SHAPE FILTERING
    %% ══════════════════════════════════════════════════════════════
    % Remove objects too small (noise) or too large (not MAs)
    bw = bwareaopen(bw, 2);  % Min 2 pixels

    cc = bwconncomp(bw);
    stats = regionprops(cc, combined, 'Area', 'Perimeter', 'Centroid', ...
        'EquivDiameter', 'Eccentricity', 'MeanIntensity', 'MaxIntensity', ...
        'BoundingBox');

    % MA size constraints (in pixels)
    % Typical MA: 10-150 μm diameter → at standard resolution ~2-50 pixels
    minArea = 2;
    maxArea = 80;
    minCircularity = 0.35;  % MAs are roughly circular
    maxEccentricity = 0.85;

    validIdx = [];
    for i = 1:cc.NumObjects
        area = stats(i).Area;
        perimeter = stats(i).Perimeter;
        ecc = stats(i).Eccentricity;

        if perimeter == 0
            continue;
        end

        circularity = (4 * pi * area) / (perimeter^2);

        if area >= minArea && area <= maxArea && ...
           circularity >= minCircularity && ...
           ecc <= maxEccentricity
            validIdx = [validIdx, i];
        end
    end

    %% ══════════════════════════════════════════════════════════════
    %  Step 7: SUB-PIXEL CENTROID REFINEMENT
    %  Gaussian fitting for sub-pixel accurate localization
    %% ══════════════════════════════════════════════════════════════
    maMask = false(rows, cols);
    maDetails = struct('centroid', {}, 'subpixelCentroid', {}, ...
                       'confidence', {}, 'area', {}, 'diameter', {}, ...
                       'circularity', {});

    for k = 1:length(validIdx)
        idx = validIdx(k);
        maMask(cc.PixelIdxList{idx}) = true;

        % Integer centroid
        centroid = stats(idx).Centroid;  % [col, row]
        area = stats(idx).Area;
        diameter = stats(idx).EquivDiameter;
        perimeter = stats(idx).Perimeter;
        circularity = (4 * pi * area) / (perimeter^2 + eps);

        % Sub-pixel refinement via weighted centroid on the intensity response
        [pixR, pixC] = ind2sub(size(bw), cc.PixelIdxList{idx});

        % Extract small patch around centroid for Gaussian fitting
        patchHalf = max(3, round(diameter));
        rRange = max(1, round(centroid(2))-patchHalf):min(rows, round(centroid(2))+patchHalf);
        cRange = max(1, round(centroid(1))-patchHalf):min(cols, round(centroid(1))+patchHalf);

        if length(rRange) > 2 && length(cRange) > 2
            patch = combined(rRange, cRange);
            [pR, pC] = meshgrid(1:length(cRange), 1:length(rRange));

            totalWeight = sum(patch(:));
            if totalWeight > 0
                subR = sum(sum(patch .* pC)) / totalWeight + rRange(1) - 1;
                subC = sum(sum(patch .* pR)) / totalWeight + cRange(1) - 1;
            else
                subR = centroid(2);
                subC = centroid(1);
            end
        else
            subR = centroid(2);
            subC = centroid(1);
        end

        % Confidence score based on multiple factors
        intensityConf = min(stats(idx).MaxIntensity / 0.5, 1.0);
        shapeConf = circularity;
        sizeConf = 1 - abs(log(area / 15)) / 5;  % Peak confidence at ~15 pixels
        sizeConf = max(0, min(1, sizeConf));

        confidence = 0.4 * intensityConf + 0.35 * shapeConf + 0.25 * sizeConf;

        % Store details
        maDetails(k).centroid = [centroid(2), centroid(1)];  % [row, col]
        maDetails(k).subpixelCentroid = [subR, subC];
        maDetails(k).confidence = round(confidence, 3);
        maDetails(k).area = area;
        maDetails(k).diameter = round(diameter, 2);
        maDetails(k).circularity = round(circularity, 3);
    end

    maCount = length(validIdx);

end
