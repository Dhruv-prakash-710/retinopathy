function [nvMask, nvDetails] = detect_neovascularization(enhancedGreen, vesselMask, odMask, odCenter, odRadius)
% DETECT_NEOVASCULARIZATION Detects neovascularization in fundus images.
%   Identifies abnormal new vessel growth (NVD near disc, NVE elsewhere)
%   based on vessel density, tortuosity, and branching pattern anomalies.
%
%   [nvMask, nvDetails] = detect_neovascularization(enhancedGreen, vesselMask, odMask, odCenter, odRadius)

    [rows, cols] = size(enhancedGreen);
    imgDouble = im2double(enhancedGreen);

    nvDetails = struct();
    nvDetails.nvdDetected = false;  % NV at Disc
    nvDetails.nveDetected = false;  % NV Elsewhere
    nvDetails.suspiciousRegions = 0;
    nvDetails.nvdScore = 0;
    nvDetails.nveScore = 0;
    nvDetails.totalScore = 0;
    nvDetails.locations = [];

    %% ══════════════════════════════════════════════════════════════
    %  Step 1: VESSEL SKELETON AND LOCAL ANALYSIS
    %% ══════════════════════════════════════════════════════════════
    % Skeletonize vessel mask for topology analysis
    vesselSkel = bwmorph(vesselMask, 'thin', Inf);

    % Find branch points and endpoints
    branchPts = bwmorph(vesselSkel, 'branchpoints');
    endPts = bwmorph(vesselSkel, 'endpoints');

    %% ══════════════════════════════════════════════════════════════
    %  Step 2: LOCAL VESSEL DENSITY MAP
    %% ══════════════════════════════════════════════════════════════
    % Compute vessel density in local windows
    windowSize = round(min(rows, cols) / 10);
    vesselDensity = imfilter(double(vesselMask), ones(windowSize) / windowSize^2, 'replicate');
    branchDensity = imfilter(double(branchPts), ones(windowSize) / windowSize^2, 'replicate');

    % NV regions have abnormally high vessel density and branching
    normalDensity = mean(vesselDensity(vesselDensity > 0));
    normalBranching = mean(branchDensity(branchDensity > 0));

    if normalDensity == 0
        normalDensity = 0.01;
    end
    if normalBranching == 0
        normalBranching = 0.0001;
    end

    %% ══════════════════════════════════════════════════════════════
    %  Step 3: DETECT ABNORMAL VESSEL CLUSTERS
    %% ══════════════════════════════════════════════════════════════
    % Regions with vessel density > 2.5x normal are suspicious
    densityAnomaly = vesselDensity > (normalDensity * 2.5);

    % Regions with branching density > 3x normal are suspicious
    branchAnomaly = branchDensity > (normalBranching * 3.0);

    % Combined anomaly map
    anomalyMap = double(densityAnomaly) * 0.5 + double(branchAnomaly) * 0.5;

    % Additional feature: vessel tortuosity in local regions
    % High tortuosity near anomalous density suggests NV
    % Approximate via the vessel skeleton curvature
    se_dilate = strel('disk', round(windowSize / 2));
    anomalyRegions = imdilate(anomalyMap > 0.3, se_dilate);

    % Remove the optic disc region from general anomaly (handle NVD separately)
    odRegion = imdilate(odMask, strel('disk', round(odRadius * 0.5)));

    %% ══════════════════════════════════════════════════════════════
    %  Step 4: NVD DETECTION (Neovascularization at Disc)
    %% ══════════════════════════════════════════════════════════════
    % NVD: abnormal vessels on or near the optic disc
    nvdSearchRegion = imdilate(odMask, strel('disk', round(odRadius * 1.5)));

    % Vessel features within the NVD search region
    nvdVesselDensity = sum(vesselMask(:) & nvdSearchRegion(:)) / sum(nvdSearchRegion(:));
    nvdBranchCount = sum(branchPts(:) & nvdSearchRegion(:));

    % Normal OD has vessels radiating outward. NVD shows tangled extra vessels.
    % Threshold for NVD detection
    nvdDensityThreshold = normalDensity * 3.0;
    nvdBranchThreshold = 15;

    nvdScore = 0;
    if nvdVesselDensity > nvdDensityThreshold
        nvdScore = nvdScore + 0.5;
    end
    if nvdBranchCount > nvdBranchThreshold
        nvdScore = nvdScore + 0.5;
    end

    nvDetails.nvdScore = round(nvdScore, 2);
    nvDetails.nvdDetected = nvdScore > 0.5;

    %% ══════════════════════════════════════════════════════════════
    %  Step 5: NVE DETECTION (Neovascularization Elsewhere)
    %% ══════════════════════════════════════════════════════════════
    % NVE: abnormal vessels away from the disc
    nveMap = anomalyMap;
    nveMap(nvdSearchRegion) = 0;  % Exclude disc area

    % Remove border artifacts
    borderWidth = round(min(rows, cols) * 0.05);
    nveMap(1:borderWidth, :) = 0;
    nveMap(end-borderWidth:end, :) = 0;
    nveMap(:, 1:borderWidth) = 0;
    nveMap(:, end-borderWidth:end) = 0;

    % Threshold for NVE regions
    nveBW = nveMap > 0.4;
    nveBW = bwareaopen(nveBW, round(windowSize^2 * 0.1));

    cc_nve = bwconncomp(nveBW);
    nveScore = 0;
    nveLocs = [];

    if cc_nve.NumObjects > 0
        stats_nve = regionprops(cc_nve, nveMap, 'Centroid', 'Area', 'MeanIntensity');
        for i = 1:cc_nve.NumObjects
            if stats_nve(i).Area > 20
                nveScore = nveScore + stats_nve(i).MeanIntensity * 0.3;
                nveLocs = [nveLocs; stats_nve(i).Centroid];
            end
        end
        nveScore = min(nveScore, 1.0);
    end

    nvDetails.nveScore = round(nveScore, 2);
    nvDetails.nveDetected = nveScore > 0.3;

    %% ══════════════════════════════════════════════════════════════
    %  Step 6: COMBINE RESULTS
    %% ══════════════════════════════════════════════════════════════
    nvMask = false(rows, cols);

    % Add NVD region to mask if detected
    if nvDetails.nvdDetected
        nvMask = nvMask | (nvdSearchRegion & vesselMask);
        if ~isempty(odCenter)
            nveLocs = [nveLocs; odCenter(2), odCenter(1)];
        end
    end

    % Add NVE regions to mask
    if nvDetails.nveDetected
        nvMask = nvMask | nveBW;
    end

    nvDetails.totalScore = round(max(nvdScore, nveScore), 2);
    nvDetails.suspiciousRegions = cc_nve.NumObjects + double(nvDetails.nvdDetected);
    nvDetails.locations = nveLocs;

end
