function [foveaCenter, foveaConfidence, maculaMask] = localize_fovea(enhancedGreen, odMask, odCenter, odRadius)
% LOCALIZE_FOVEA Localizes the fovea center using anatomical landmarks.
%   The fovea is the darkest region in the macula, located approximately
%   2.5 optic disc diameters temporal to the optic disc center.
%
%   [foveaCenter, foveaConfidence, maculaMask] = localize_fovea(enhancedGreen, odMask, odCenter, odRadius)
%
%   Inputs:
%     enhancedGreen - Enhanced green channel image
%     odMask        - Binary mask of the optic disc
%     odCenter      - [row, col] center of the optic disc
%     odRadius      - Estimated radius of the optic disc
%
%   Outputs:
%     foveaCenter     - [row, col] estimated fovea center
%     foveaConfidence - Confidence score [0-1]
%     maculaMask      - Binary mask of the macular region

    [rows, cols] = size(enhancedGreen);
    imgDouble = im2double(enhancedGreen);

    %% ══════════════════════════════════════════════════════════════
    %  Step 1: Estimate search region based on OD position
    %% ══════════════════════════════════════════════════════════════
    % The fovea is approximately 2.5 OD diameters from the OD center,
    % in the temporal direction (towards the center of the image)

    % Determine laterality: if OD is on the left half -> right eye (fovea to the right)
    % if OD is on the right half -> left eye (fovea to the left)
    if odCenter(2) < cols / 2
        % Right eye: fovea is to the right of the OD
        foveaSearchCol = round(odCenter(2) + 2.5 * odRadius * 2);
    else
        % Left eye: fovea is to the left of the OD
        foveaSearchCol = round(odCenter(2) - 2.5 * odRadius * 2);
    end

    % Fovea is roughly at the same vertical level as the OD
    foveaSearchRow = odCenter(1);

    % Clamp to image bounds
    foveaSearchCol = max(1, min(cols, foveaSearchCol));
    foveaSearchRow = max(1, min(rows, foveaSearchRow));

    %% ══════════════════════════════════════════════════════════════
    %  Step 2: Define the macular search region
    %% ══════════════════════════════════════════════════════════════
    searchRadius = round(odRadius * 3);  % Search within 3 OD radii of estimated position

    [X, Y] = meshgrid(1:cols, 1:rows);
    searchMask = (X - foveaSearchCol).^2 + (Y - foveaSearchRow).^2 <= searchRadius^2;

    % Exclude the optic disc region
    searchMask = searchMask & ~odMask;

    % Ensure we have a valid search region
    if sum(searchMask(:)) < 100
        % Fallback: search in the central region of the image
        searchMask = (X - cols/2).^2 + (Y - rows/2).^2 <= (min(rows,cols)/4)^2;
        searchMask = searchMask & ~odMask;
    end

    %% ══════════════════════════════════════════════════════════════
    %  Step 3: Find the darkest region (fovea)
    %% ══════════════════════════════════════════════════════════════
    % Smooth the image to avoid noise-based minima
    smoothed = imgaussfilt(imgDouble, odRadius * 0.5);

    % Mask out non-search regions with a high value
    searchImg = smoothed;
    searchImg(~searchMask) = 1.0;

    % Find the minimum intensity location
    [minVal, minIdx] = min(searchImg(:));
    [foveaRow, foveaCol] = ind2sub(size(searchImg), minIdx);

    % Refine by computing the centroid of the darkest region
    darkThreshold = minVal + 0.05;  % Region within 5% of minimum
    darkRegion = searchImg <= darkThreshold & searchMask;
    darkRegion = bwareaopen(darkRegion, 10);

    stats = regionprops(darkRegion, searchImg, 'WeightedCentroid', 'Area');
    if ~isempty(stats)
        [~, largestIdx] = max([stats.Area]);
        wc = stats(largestIdx).WeightedCentroid;
        foveaCol = round(wc(1));
        foveaRow = round(wc(2));
    end

    foveaCenter = [foveaRow, foveaCol];

    %% ══════════════════════════════════════════════════════════════
    %  Step 4: Compute confidence score
    %% ══════════════════════════════════════════════════════════════
    % Higher confidence if:
    % 1. The fovea is significantly darker than surrounding tissue
    % 2. The position is consistent with anatomical expectations

    % Darkness contrast
    foveaRegion = searchImg(max(1,foveaRow-10):min(rows,foveaRow+10), ...
                            max(1,foveaCol-10):min(cols,foveaCol+10));
    surroundRegion = searchImg(searchMask);
    darknessContrast = (mean(surroundRegion(:)) - mean(foveaRegion(:))) / mean(surroundRegion(:));
    darknessContrast = max(0, min(darknessContrast, 1));

    % Positional consistency — distance from expected position
    expectedDist = sqrt((foveaRow - foveaSearchRow)^2 + (foveaCol - foveaSearchCol)^2);
    positionScore = max(0, 1 - expectedDist / searchRadius);

    foveaConfidence = 0.6 * darknessContrast + 0.4 * positionScore;

    %% ══════════════════════════════════════════════════════════════
    %  Step 5: Create macular mask (region around fovea)
    %% ══════════════════════════════════════════════════════════════
    macularRadius = round(odRadius * 2);  % Macula ~2 OD radii in diameter
    maculaMask = (X - foveaCol).^2 + (Y - foveaRow).^2 <= macularRadius^2;

end
