function [hardExudateMask, softExudateMask, exudateDetails] = detect_exudates(enhancedGreen, rgbImg, vesselMask, odMask)
% DETECT_EXUDATES Detects hard and soft exudates in fundus images.
%   Hard exudates (HE): bright yellow/white deposits with sharp edges
%   Soft exudates / Cotton-wool spots (CWS): pale, fluffy, diffuse lesions
%
%   [hardExudateMask, softExudateMask, exudateDetails] = detect_exudates(enhancedGreen, rgbImg, vesselMask, odMask)

    if nargin < 4
        odMask = false(size(enhancedGreen));
    end

    imgDouble = im2double(enhancedGreen);
    [rows, cols] = size(imgDouble);

    % Use RGB color information if available
    if nargin >= 2 && size(rgbImg, 3) == 3
        rgbDouble = im2double(rgbImg);
        hasColor = true;
    else
        hasColor = false;
    end

    exudateDetails = struct();
    exudateDetails.hardExudates = struct('count', 0, 'totalArea', 0, 'locations', []);
    exudateDetails.softExudates = struct('count', 0, 'totalArea', 0, 'locations', []);

    %% ══════════════════════════════════════════════════════════════
    %  HARD EXUDATE DETECTION
    %  Bright, well-defined lesions with high contrast against background
    %% ══════════════════════════════════════════════════════════════

    %% Step 1: Morphological reconstruction to extract bright regions
    % Top-hat to enhance bright structures against a dark background
    se_large = strel('disk', 15);
    topHat = imtophat(imgDouble, se_large);

    % Morphological reconstruction from eroded markers
    se_erode = strel('disk', 3);
    eroded = imerode(imgDouble, se_erode);
    reconstructed = imreconstruct(eroded, imgDouble);
    brightResidual = imgDouble - reconstructed;

    % Combine top-hat and reconstruction residual
    brightMap = 0.5 * topHat + 0.5 * brightResidual;
    brightMap = (brightMap - min(brightMap(:))) / (max(brightMap(:)) - min(brightMap(:)) + eps);

    %% Step 2: Color-based refinement (if RGB available)
    if hasColor
        % Hard exudates are yellowish — high R, high G, low B relative
        R = rgbDouble(:,:,1);
        G = rgbDouble(:,:,2);
        B = rgbDouble(:,:,3);

        % Yellow-white color indicator
        yellowScore = (R + G) / 2 - B;
        yellowScore = max(0, yellowScore);
        yellowScore = yellowScore / (max(yellowScore(:)) + eps);

        brightMap = 0.6 * brightMap + 0.4 * yellowScore;
    end

    %% Step 3: Thresholding
    heThreshold = graythresh(brightMap) * 1.5;
    heThreshold = max(heThreshold, 0.2);
    heThreshold = min(heThreshold, 0.85);
    heBW = brightMap > heThreshold;

    %% Step 4: Exclude non-exudate regions
    % Remove vessels
    vesselDilated = imdilate(vesselMask, strel('disk', 3));
    heBW(vesselDilated) = 0;

    % Remove optic disc (the OD is also bright)
    odDilated = imdilate(odMask, strel('disk', 15));
    heBW(odDilated) = 0;

    % Remove small noise
    heBW = bwareaopen(heBW, 5);

    %% Step 5: Shape filtering for hard exudates
    cc_he = bwconncomp(heBW);
    stats_he = regionprops(cc_he, brightMap, 'Area', 'Perimeter', 'Centroid', ...
        'EquivDiameter', 'Eccentricity', 'MeanIntensity', 'Solidity');

    heValidIdx = [];
    heMinArea = 5;
    heMaxArea = 2000;  % Hard exudates can vary widely in size

    for i = 1:cc_he.NumObjects
        area = stats_he(i).Area;
        solidity = stats_he(i).Solidity;

        % Hard exudates are relatively solid (compact)
        if area >= heMinArea && area <= heMaxArea && solidity > 0.4
            heValidIdx = [heValidIdx, i];
        end
    end

    hardExudateMask = false(rows, cols);
    heLocations = [];
    for k = 1:length(heValidIdx)
        idx = heValidIdx(k);
        hardExudateMask(cc_he.PixelIdxList{idx}) = true;
        heLocations = [heLocations; stats_he(idx).Centroid];
    end

    exudateDetails.hardExudates.count = length(heValidIdx);
    exudateDetails.hardExudates.totalArea = sum(hardExudateMask(:));
    exudateDetails.hardExudates.locations = heLocations;

    %% ══════════════════════════════════════════════════════════════
    %  SOFT EXUDATE (COTTON-WOOL SPOT) DETECTION
    %  Larger, diffuse, pale regions with fuzzy borders
    %% ══════════════════════════════════════════════════════════════

    %% Step 1: Detect larger diffuse bright regions
    se_cws = strel('disk', 20);
    cws_tophat = imtophat(imgDouble, se_cws);

    % Soft exudates have lower contrast than hard exudates
    % and are larger and more diffuse
    cwsSmoothed = imgaussfilt(cws_tophat, 3);

    %% Step 2: Threshold at a lower level (softer features)
    cwsThreshold = graythresh(cwsSmoothed) * 1.2;
    cwsThreshold = max(cwsThreshold, 0.08);
    cwsBW = cwsSmoothed > cwsThreshold;

    % Exclude vessels, OD, and already-detected hard exudates
    cwsBW(vesselDilated) = 0;
    cwsBW(odDilated) = 0;
    cwsBW(hardExudateMask) = 0;

    cwsBW = bwareaopen(cwsBW, 50);  % CWS are larger than HE

    %% Step 3: Filter by size and shape — CWS are larger and less defined
    cc_cws = bwconncomp(cwsBW);
    stats_cws = regionprops(cc_cws, cwsSmoothed, 'Area', 'Perimeter', 'Centroid', ...
        'EquivDiameter', 'Eccentricity', 'Solidity', 'MeanIntensity');

    cwsValidIdx = [];
    cwsMinArea = 50;
    cwsMaxArea = 5000;

    for i = 1:cc_cws.NumObjects
        area = stats_cws(i).Area;
        solidity = stats_cws(i).Solidity;

        % CWS are larger, less solid (fuzzy edges)
        if area >= cwsMinArea && area <= cwsMaxArea && solidity > 0.3 && solidity < 0.95
            cwsValidIdx = [cwsValidIdx, i];
        end
    end

    softExudateMask = false(rows, cols);
    cwsLocations = [];
    for k = 1:length(cwsValidIdx)
        idx = cwsValidIdx(k);
        softExudateMask(cc_cws.PixelIdxList{idx}) = true;
        cwsLocations = [cwsLocations; stats_cws(idx).Centroid];
    end

    exudateDetails.softExudates.count = length(cwsValidIdx);
    exudateDetails.softExudates.totalArea = sum(softExudateMask(:));
    exudateDetails.softExudates.locations = cwsLocations;

end
