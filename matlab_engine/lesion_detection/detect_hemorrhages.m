function [hemorrhageMask, hemorrhageDetails] = detect_hemorrhages(enhancedGreen, vesselMask, odMask, maMask)
% DETECT_HEMORRHAGES Detects and classifies retinal hemorrhages.
%   Identifies dot hemorrhages, blot hemorrhages, and flame-shaped hemorrhages
%   using morphological analysis and shape classification.
%
%   [hemorrhageMask, hemorrhageDetails] = detect_hemorrhages(enhancedGreen, vesselMask, odMask, maMask)

    if nargin < 4
        maMask = false(size(enhancedGreen));
    end
    if nargin < 3
        odMask = false(size(enhancedGreen));
    end

    imgDouble = im2double(enhancedGreen);
    [rows, cols] = size(imgDouble);

    hemorrhageDetails = struct();
    hemorrhageDetails.dotHemorrhages = struct('count', 0, 'mask', false(rows, cols), 'locations', []);
    hemorrhageDetails.blotHemorrhages = struct('count', 0, 'mask', false(rows, cols), 'locations', []);
    hemorrhageDetails.flameHemorrhages = struct('count', 0, 'mask', false(rows, cols), 'locations', []);
    hemorrhageDetails.totalCount = 0;

    %% ══════════════════════════════════════════════════════════════
    %  Step 1: DARK LESION ENHANCEMENT
    %  Hemorrhages appear as dark (red) regions in the green channel
    %% ══════════════════════════════════════════════════════════════
    % Multi-scale bottom-hat to enhance dark regions of various sizes
    darkMap = zeros(rows, cols);
    for r = [5, 8, 12, 18, 25]
        se = strel('disk', r);
        bh = imbothat(imgDouble, se);
        darkMap = max(darkMap, bh);
    end

    darkMap = (darkMap - min(darkMap(:))) / (max(darkMap(:)) - min(darkMap(:)) + eps);

    %% ══════════════════════════════════════════════════════════════
    %  Step 2: THRESHOLD AND EXCLUDE NON-HEMORRHAGE REGIONS
    %% ══════════════════════════════════════════════════════════════
    threshold = graythresh(darkMap) * 1.3;
    threshold = max(threshold, 0.1);
    threshold = min(threshold, 0.8);

    darkBW = darkMap > threshold;

    % Exclude vessels (major source of false positives)
    vesselDilated = imdilate(vesselMask, strel('disk', 4));
    darkBW(vesselDilated) = 0;

    % Exclude optic disc
    odDilated = imdilate(odMask, strel('disk', 10));
    darkBW(odDilated) = 0;

    % Exclude already-detected microaneurysms
    maDilated = imdilate(maMask, strel('disk', 2));
    darkBW(maDilated) = 0;

    % Remove very small objects (noise)
    darkBW = bwareaopen(darkBW, 8);

    % Remove image border
    borderWidth = round(min(rows, cols) * 0.03);
    borderMask = false(rows, cols);
    borderMask(1:borderWidth, :) = true;
    borderMask(end-borderWidth:end, :) = true;
    borderMask(:, 1:borderWidth) = true;
    borderMask(:, end-borderWidth:end) = true;
    darkBW(borderMask) = 0;

    %% ══════════════════════════════════════════════════════════════
    %  Step 3: CLASSIFY HEMORRHAGE TYPES BY SHAPE
    %% ══════════════════════════════════════════════════════════════
    cc = bwconncomp(darkBW);
    stats = regionprops(cc, darkMap, 'Area', 'Perimeter', 'Centroid', ...
        'EquivDiameter', 'Eccentricity', 'MajorAxisLength', 'MinorAxisLength', ...
        'Orientation', 'Solidity', 'MeanIntensity');

    hemorrhageMask = false(rows, cols);
    dotMask = false(rows, cols);
    blotMask = false(rows, cols);
    flameMask = false(rows, cols);

    dotLocs = [];
    blotLocs = [];
    flameLocs = [];

    for i = 1:cc.NumObjects
        area = stats(i).Area;
        perimeter = stats(i).Perimeter;
        ecc = stats(i).Eccentricity;
        solidity = stats(i).Solidity;
        majorAxis = stats(i).MajorAxisLength;
        minorAxis = stats(i).MinorAxisLength;
        centroid = stats(i).Centroid;

        if perimeter == 0
            continue;
        end

        circularity = (4 * pi * area) / (perimeter^2);
        aspectRatio = majorAxis / (minorAxis + eps);

        %% ── DOT HEMORRHAGES ──
        % Small, round, similar to MAs but slightly larger
        if area >= 8 && area <= 150 && circularity > 0.4 && ecc < 0.7
            dotMask(cc.PixelIdxList{i}) = true;
            hemorrhageMask(cc.PixelIdxList{i}) = true;
            dotLocs = [dotLocs; centroid];

        %% ── BLOT HEMORRHAGES ──
        % Larger, roughly round/oval, deep retinal hemorrhages
        elseif area > 150 && area <= 3000 && circularity > 0.25 && aspectRatio < 3.0 && solidity > 0.4
            blotMask(cc.PixelIdxList{i}) = true;
            hemorrhageMask(cc.PixelIdxList{i}) = true;
            blotLocs = [blotLocs; centroid];

        %% ── FLAME-SHAPED HEMORRHAGES ──
        % Elongated, following the nerve fiber layer pattern
        elseif area > 50 && area <= 5000 && aspectRatio >= 3.0 && ecc > 0.7
            flameMask(cc.PixelIdxList{i}) = true;
            hemorrhageMask(cc.PixelIdxList{i}) = true;
            flameLocs = [flameLocs; centroid];
        end
    end

    %% ══════════════════════════════════════════════════════════════
    %  Step 4: POPULATE RESULTS
    %% ══════════════════════════════════════════════════════════════
    hemorrhageDetails.dotHemorrhages.count = size(dotLocs, 1);
    hemorrhageDetails.dotHemorrhages.mask = dotMask;
    hemorrhageDetails.dotHemorrhages.locations = dotLocs;

    hemorrhageDetails.blotHemorrhages.count = size(blotLocs, 1);
    hemorrhageDetails.blotHemorrhages.mask = blotMask;
    hemorrhageDetails.blotHemorrhages.locations = blotLocs;

    hemorrhageDetails.flameHemorrhages.count = size(flameLocs, 1);
    hemorrhageDetails.flameHemorrhages.mask = flameMask;
    hemorrhageDetails.flameHemorrhages.locations = flameLocs;

    hemorrhageDetails.totalCount = size(dotLocs, 1) + size(blotLocs, 1) + size(flameLocs, 1);

end
