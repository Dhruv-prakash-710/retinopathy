function [irmaMask, irmaDetails] = detect_irma(enhancedGreen, vesselMask, odMask, odCenter, odRadius, foveaCenter)
% DETECT_IRMA Intraretinal Microvascular Abnormality (IRMA) detection.
%   IRMAs are dilated, tortuous capillaries that represent abnormal
%   shunt vessels within the retina. They are a key ICDR criterion
%   for Severe NPDR (Level 3) under the "4-2-1 rule":
%     - ≥20 hemorrhages in each of 4 quadrants, OR
%     - Venous beading in ≥2 quadrants, OR
%     - IRMA in ≥1 quadrant  ← this module
%
%   [irmaMask, irmaDetails] = detect_irma(enhancedGreen, vesselMask, odMask, odCenter, odRadius, foveaCenter)
%
%   Inputs:
%     enhancedGreen - Enhanced green channel image
%     vesselMask    - Binary mask of the vessel network
%     odMask        - Binary mask of the optic disc
%     odCenter      - [row, col] center of the optic disc
%     odRadius      - Optic disc radius
%     foveaCenter   - [row, col] center of the fovea
%
%   Outputs:
%     irmaMask    - Binary mask of detected IRMA regions
%     irmaDetails - Struct with IRMA count, per-quadrant analysis, score

    [rows, cols] = size(enhancedGreen);
    imgDouble = im2double(enhancedGreen);

    irmaDetails = struct();
    irmaDetails.totalCount = 0;
    irmaDetails.totalScore = 0;
    irmaDetails.perQuadrant = struct('count', {0,0,0,0}, 'score', {0,0,0,0});
    irmaDetails.locations = [];
    irmaDetails.anyQuadrantPositive = false;

    %% ══════════════════════════════════════════════════════════════
    %  Step 1: DEFINE RETINAL QUADRANTS
    %  Divide fundus into 4 quadrants using OD-Fovea axis
    %% ══════════════════════════════════════════════════════════════
    % The OD-fovea line defines the horizontal anatomical axis
    % Perpendicular bisector defines the vertical axis
    midRow = round((odCenter(1) + foveaCenter(1)) / 2);
    midCol = round((odCenter(2) + foveaCenter(2)) / 2);

    [X, Y] = meshgrid(1:cols, 1:rows);

    % Quadrants: Superior-Temporal, Superior-Nasal, Inferior-Temporal, Inferior-Nasal
    quadrantMasks = cell(4, 1);
    quadrantMasks{1} = Y <= midRow & X >= midCol;  % Superior-Temporal
    quadrantMasks{2} = Y <= midRow & X < midCol;   % Superior-Nasal
    quadrantMasks{3} = Y > midRow & X >= midCol;   % Inferior-Temporal
    quadrantMasks{4} = Y > midRow & X < midCol;    % Inferior-Nasal

    %% ══════════════════════════════════════════════════════════════
    %  Step 2: EXTRACT CAPILLARY BED (non-major-vessel regions)
    %  IRMAs exist in the capillary bed between major vessels
    %% ══════════════════════════════════════════════════════════════
    % Dilate major vessels to define exclusion zone
    vesselDilated = imdilate(vesselMask, strel('disk', 5));
    odDilated = imdilate(odMask, strel('disk', round(odRadius * 0.5)));

    % Retinal area mask (non-background)
    retinalMask = imgDouble > 0.03;
    retinalMask = imfill(retinalMask, 'holes');

    % Capillary bed = retinal area minus major vessels and OD
    capillaryBed = retinalMask & ~vesselDilated & ~odDilated;

    %% ══════════════════════════════════════════════════════════════
    %  Step 3: DETECT SMALL TORTUOUS VESSEL-LIKE STRUCTURES
    %  IRMAs appear as small, irregular, tortuous vessel fragments
    %% ══════════════════════════════════════════════════════════════
    % Multi-scale morphological analysis to find thin dark structures
    % that are NOT part of the main vessel tree

    % Bottom-hat at small scales to find thin dark linear structures
    irmaResponse = zeros(rows, cols);
    for r = [2, 3, 4, 5]
        se = strel('disk', r);
        bh = imbothat(imgDouble, se);
        irmaResponse = max(irmaResponse, bh);
    end

    % Normalize
    irmaResponse = (irmaResponse - min(irmaResponse(:))) / (max(irmaResponse(:)) - min(irmaResponse(:)) + eps);

    % Apply only in the capillary bed
    irmaResponse = irmaResponse .* double(capillaryBed);

    %% ══════════════════════════════════════════════════════════════
    %  Step 4: MULTI-ORIENTATION FILTERING (line detector)
    %  IRMAs are small linear/tortuous structures — detect with oriented filters
    %% ══════════════════════════════════════════════════════════════
    lineResponse = zeros(rows, cols);
    lineLength = 9;  % Small line kernel for capillary-sized structures

    for angle = 0:15:165
        se_line = strel('line', lineLength, angle);
        opened = imopen(irmaResponse, se_line);
        lineResponse = max(lineResponse, opened);
    end

    % Combine morphological and line responses
    combined = 0.6 * irmaResponse + 0.4 * lineResponse;

    %% ══════════════════════════════════════════════════════════════
    %  Step 5: THRESHOLD AND SHAPE FILTERING
    %% ══════════════════════════════════════════════════════════════
    threshold = graythresh(combined(combined > 0)) * 1.5;
    threshold = max(threshold, 0.12);
    threshold = min(threshold, 0.8);

    irmaBW = combined > threshold;
    irmaBW = irmaBW & capillaryBed;

    % Remove very small noise
    irmaBW = bwareaopen(irmaBW, 5);

    % Remove border artifacts
    borderWidth = round(min(rows, cols) * 0.03);
    borderMask = false(rows, cols);
    borderMask(1:borderWidth, :) = true;
    borderMask(end-borderWidth:end, :) = true;
    borderMask(:, 1:borderWidth) = true;
    borderMask(:, end-borderWidth:end) = true;
    irmaBW(borderMask) = 0;

    %% ══════════════════════════════════════════════════════════════
    %  Step 6: CLASSIFY IRMA CANDIDATES BY SHAPE
    %  IRMAs are: elongated (not round like MAs), small (smaller than
    %  major vessels), tortuous (not straight lines)
    %% ══════════════════════════════════════════════════════════════
    cc = bwconncomp(irmaBW);
    stats = regionprops(cc, combined, 'Area', 'Perimeter', 'Centroid', ...
        'Eccentricity', 'MajorAxisLength', 'MinorAxisLength', ...
        'Solidity', 'Orientation', 'MeanIntensity');

    irmaMask = false(rows, cols);
    irmaLocs = [];
    irmaScores = [];

    for i = 1:cc.NumObjects
        area = stats(i).Area;
        ecc = stats(i).Eccentricity;
        solidity = stats(i).Solidity;
        majorAxis = stats(i).MajorAxisLength;
        minorAxis = stats(i).MinorAxisLength;
        perimeter = stats(i).Perimeter;
        centroid = stats(i).Centroid;

        if perimeter == 0
            continue;
        end

        circularity = (4 * pi * area) / (perimeter^2);
        aspectRatio = majorAxis / (minorAxis + eps);

        % IRMA criteria:
        % 1. Size: larger than MAs (>10 px) but smaller than major vessels (<500 px)
        % 2. Shape: elongated (eccentricity > 0.5) but NOT perfectly linear (solidity < 0.9)
        % 3. Tortuous: low circularity indicates irregular path
        % 4. Not too compact (that would be a hemorrhage or MA)

        isRightSize = area >= 10 && area <= 500;
        isElongated = ecc > 0.5 && aspectRatio > 1.5;
        isTortuous = circularity < 0.6 && solidity > 0.25 && solidity < 0.85;
        isNotRound = circularity < 0.7;  % Exclude round objects (MAs, dots)

        if isRightSize && isElongated && isTortuous && isNotRound
            irmaMask(cc.PixelIdxList{i}) = true;
            irmaLocs = [irmaLocs; centroid];

            % Score based on how IRMA-like the candidate is
            sizeScore = 1 - abs(log(area / 50)) / 5;
            sizeScore = max(0, min(1, sizeScore));
            shapeScore = (1 - circularity) * ecc;
            intensityScore = min(stats(i).MeanIntensity / 0.3, 1.0);

            score = 0.35 * sizeScore + 0.40 * shapeScore + 0.25 * intensityScore;
            irmaScores = [irmaScores; score];
        end
    end

    irmaDetails.totalCount = size(irmaLocs, 1);
    irmaDetails.locations = irmaLocs;

    if ~isempty(irmaScores)
        irmaDetails.totalScore = round(mean(irmaScores), 3);
    end

    %% ══════════════════════════════════════════════════════════════
    %  Step 7: PER-QUADRANT ANALYSIS
    %% ══════════════════════════════════════════════════════════════
    quadrantNames = {'SuperiorTemporal', 'SuperiorNasal', 'InferiorTemporal', 'InferiorNasal'};
    anyPositive = false;

    for q = 1:4
        qMask = irmaMask & quadrantMasks{q};
        cc_q = bwconncomp(qMask);
        qCount = cc_q.NumObjects;

        % Per-quadrant score
        if qCount > 0
            qArea = sum(qMask(:));
            qScore = min(qCount / 5 + qArea / 200, 1.0);
            anyPositive = true;
        else
            qScore = 0;
        end

        irmaDetails.perQuadrant(q).name = quadrantNames{q};
        irmaDetails.perQuadrant(q).count = qCount;
        irmaDetails.perQuadrant(q).score = round(qScore, 3);
    end

    irmaDetails.anyQuadrantPositive = anyPositive;

end
