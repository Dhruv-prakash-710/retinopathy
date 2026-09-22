function [vesselMask, vesselMetrics] = segment_vessels(enhancedGreen, odMask)
% SEGMENT_VESSELS Advanced multi-scale vessel segmentation.
%   Uses Frangi vesselness filter + Gabor filtering + morphological
%   analysis for robust extraction of the retinal vascular network.
%
%   [vesselMask, vesselMetrics] = segment_vessels(enhancedGreen, odMask)
%
%   Outputs:
%     vesselMask   - Binary mask of the vessel network
%     vesselMetrics - struct with tortuosity, density, branching points

    imgDouble = im2double(enhancedGreen);
    [rows, cols] = size(imgDouble);

    %% ══════════════════════════════════════════════════════════════
    %  Step 1: MULTI-SCALE FRANGI VESSELNESS FILTER
    %% ══════════════════════════════════════════════════════════════
    % Vessels are elongated dark structures of varying widths
    % Frangi filter uses eigenvalues of the Hessian matrix

    % Invert image so vessels become bright
    invImg = 1 - imgDouble;

    scales = [1.0, 1.5, 2.0, 3.0, 4.0];  % Multiple scales for different vessel widths
    vesselness = zeros(rows, cols);

    for s = 1:length(scales)
        sigma = scales(s);

        % Compute Hessian matrix components
        [Dxx, Dxy, Dyy] = hessian2D(invImg, sigma);

        % Compute eigenvalues
        [lambda1, lambda2] = eigenvaluesOfHessian(Dxx, Dxy, Dyy);

        % Frangi vesselness measure
        % For dark vessels on bright background (inverted, so bright on dark)
        beta = 0.5;
        c = 0.15;

        Rb = lambda1 ./ (lambda2 + eps);
        S = sqrt(lambda1.^2 + lambda2.^2);

        Vo = exp(-Rb.^2 / (2 * beta^2)) .* (1 - exp(-S.^2 / (2 * c^2)));

        % Only keep elongated structures (lambda2 < 0 in original)
        Vo(lambda2 > 0) = 0;
        Vo(isnan(Vo)) = 0;

        % Max response across scales
        vesselness = max(vesselness, Vo);
    end

    % Normalize vesselness response
    vesselness = (vesselness - min(vesselness(:))) / (max(vesselness(:)) - min(vesselness(:)) + eps);

    %% ══════════════════════════════════════════════════════════════
    %  Step 2: GABOR FILTER BANK (multi-orientation)
    %% ══════════════════════════════════════════════════════════════
    orientations = 0:15:165;  % 12 orientations
    gaborResponse = zeros(rows, cols);

    wavelength = 6;
    gaborSigma = 2.5;

    for theta = orientations
        thetaRad = theta * pi / 180;

        % Create Gabor kernel
        gaborFilter = gabor(wavelength, theta, ...
            'SpatialFrequencyBandwidth', 1.0, ...
            'SpatialAspectRatio', 0.5);

        response = imgaborfilt(invImg, gaborFilter);
        gaborResponse = max(gaborResponse, abs(response));
    end

    % Normalize Gabor response
    gaborResponse = (gaborResponse - min(gaborResponse(:))) / (max(gaborResponse(:)) - min(gaborResponse(:)) + eps);

    %% ══════════════════════════════════════════════════════════════
    %  Step 3: MORPHOLOGICAL BOTTOM-HAT (complementary)
    %% ══════════════════════════════════════════════════════════════
    se = strel('disk', 8);
    bottomHat = imbothat(imgDouble, se);
    bottomHat = (bottomHat - min(bottomHat(:))) / (max(bottomHat(:)) - min(bottomHat(:)) + eps);

    %% ══════════════════════════════════════════════════════════════
    %  Step 4: COMBINE MULTI-METHOD RESPONSES
    %% ══════════════════════════════════════════════════════════════
    combined = 0.45 * vesselness + 0.35 * gaborResponse + 0.20 * bottomHat;

    %% ══════════════════════════════════════════════════════════════
    %  Step 5: HYSTERESIS THRESHOLDING
    %% ══════════════════════════════════════════════════════════════
    highThresh = graythresh(combined) * 1.3;
    lowThresh = highThresh * 0.4;

    % Clamp thresholds
    highThresh = min(highThresh, 0.95);
    lowThresh = max(lowThresh, 0.05);

    highMask = combined >= highThresh;
    lowMask = combined >= lowThresh;

    % Use high-confidence seeds and grow into low-threshold regions
    bw = imreconstruct(highMask, lowMask);

    %% ══════════════════════════════════════════════════════════════
    %  Step 6: POST-PROCESSING
    %% ══════════════════════════════════════════════════════════════
    % Remove small isolated noise
    bw = bwareaopen(bw, 30);

    % Morphological closing to connect nearby vessel segments
    se_close = strel('disk', 1);
    bw = imclose(bw, se_close);

    % Thin the vessel mask to get a cleaner representation
    bwThin = bwmorph(bw, 'thin', Inf);

    % Exclude optic disc region
    odDilated = imdilate(odMask, strel('disk', 10));
    bw(odDilated) = 0;
    bwThin(odDilated) = 0;

    vesselMask = bw;

    %% ══════════════════════════════════════════════════════════════
    %  Step 7: COMPUTE VESSEL METRICS
    %% ══════════════════════════════════════════════════════════════
    vesselMetrics = struct();

    % Vessel density (ratio of vessel pixels to retinal area)
    retinalMask = imgDouble > 0.03;
    if sum(retinalMask(:)) > 0
        vesselMetrics.density = sum(vesselMask(:) & retinalMask(:)) / sum(retinalMask(:));
    else
        vesselMetrics.density = sum(vesselMask(:)) / (rows * cols);
    end

    % Branching points (using skeleton)
    branchPoints = bwmorph(bwThin, 'branchpoints');
    vesselMetrics.branchingPoints = sum(branchPoints(:));

    % Endpoint count
    endPoints = bwmorph(bwThin, 'endpoints');
    vesselMetrics.endPoints = sum(endPoints(:));

    % Tortuosity estimate — ratio of vessel path length to straight-line distance
    % Simplified: use labeled segments
    cc = bwconncomp(bwThin);
    tortuosities = [];
    for i = 1:min(cc.NumObjects, 50)  % Analyze up to 50 segments
        [segR, segC] = ind2sub(size(bwThin), cc.PixelIdxList{i});
        if length(segR) > 10
            pathLength = length(segR);
            straightLine = sqrt((segR(end)-segR(1))^2 + (segC(end)-segC(1))^2);
            if straightLine > 0
                tortuosities = [tortuosities, pathLength / straightLine];
            end
        end
    end

    if ~isempty(tortuosities)
        vesselMetrics.meanTortuosity = mean(tortuosities);
        vesselMetrics.maxTortuosity = max(tortuosities);
    else
        vesselMetrics.meanTortuosity = 1.0;
        vesselMetrics.maxTortuosity = 1.0;
    end

    vesselMetrics.totalVesselPixels = sum(vesselMask(:));
    vesselMetrics.skeletonLength = sum(bwThin(:));

    %% ══════════════════════════════════════════════════════════════
    %  Step 8: VENOUS BEADING DETECTION
    %  Venous beading in ≥2 quadrants is an ICDR criterion for Severe NPDR
    %  Beading = caliber variation along vessel centerline (CV > threshold)
    %% ══════════════════════════════════════════════════════════════
    vesselMetrics.venousBeadingScore = 0;
    vesselMetrics.venousBeadingCount = 0;
    vesselMetrics.beadingPerQuadrant = [0, 0, 0, 0];

    % Compute local vessel width along skeleton
    distMap = bwdist(~bw);  % Distance transform — values = half-width
    skelWidths = distMap .* double(bwThin);  % Width at each skeleton pixel

    % Analyze width variation along each vessel segment
    cc_skel = bwconncomp(bwThin);
    beadingSegments = 0;

    for i = 1:min(cc_skel.NumObjects, 100)
        segPixels = cc_skel.PixelIdxList{i};
        if length(segPixels) < 20
            continue;  % Too short to assess beading
        end

        widths = distMap(segPixels);
        widths = widths(widths > 0);

        if length(widths) > 10
            % Coefficient of Variation along the segment
            cv = std(widths) / (mean(widths) + eps);

            % Beading threshold: CV > 0.25 suggests irregular caliber
            if cv > 0.25 && mean(widths) > 2  % Only for larger vessels (veins)
                beadingSegments = beadingSegments + 1;

                % Determine quadrant of this segment
                [segR, segC] = ind2sub(size(bwThin), segPixels);
                meanR = mean(segR); meanC = mean(segC);
                midR = rows / 2; midC = cols / 2;

                if meanR <= midR && meanC >= midC
                    vesselMetrics.beadingPerQuadrant(1) = vesselMetrics.beadingPerQuadrant(1) + 1;
                elseif meanR <= midR && meanC < midC
                    vesselMetrics.beadingPerQuadrant(2) = vesselMetrics.beadingPerQuadrant(2) + 1;
                elseif meanR > midR && meanC >= midC
                    vesselMetrics.beadingPerQuadrant(3) = vesselMetrics.beadingPerQuadrant(3) + 1;
                else
                    vesselMetrics.beadingPerQuadrant(4) = vesselMetrics.beadingPerQuadrant(4) + 1;
                end
            end
        end
    end

    vesselMetrics.venousBeadingCount = beadingSegments;
    vesselMetrics.venousBeadingScore = min(beadingSegments / 10, 1.0);

    %% ══════════════════════════════════════════════════════════════
    %  Step 9: ARTERIOVENOUS (A/V) CLASSIFICATION
    %  Separate arterioles (brighter, thinner) from venules (darker, wider)
    %% ══════════════════════════════════════════════════════════════
    % Intensity-based A/V separation
    vesselIntensities = imgDouble(vesselMask);
    vesselWidthValues = distMap(vesselMask);

    if ~isempty(vesselIntensities) && length(vesselIntensities) > 50
        % Use median split: brighter vessels tend to be arterioles
        medianIntensity = median(vesselIntensities);

        arteryMask = vesselMask & (imgDouble > medianIntensity);
        veinMask = vesselMask & (imgDouble <= medianIntensity);

        arteryArea = sum(arteryMask(:));
        veinArea = sum(veinMask(:));

        vesselMetrics.avRatio = round(arteryArea / (veinArea + eps), 3);
        vesselMetrics.arteryPixels = arteryArea;
        vesselMetrics.veinPixels = veinArea;

        % Mean width comparison
        arteryWidths = distMap(arteryMask);
        veinWidths = distMap(veinMask);
        vesselMetrics.meanArteryWidth = round(mean(arteryWidths(arteryWidths > 0)), 2);
        vesselMetrics.meanVeinWidth = round(mean(veinWidths(veinWidths > 0)), 2);
    else
        vesselMetrics.avRatio = 1.0;
        vesselMetrics.arteryPixels = 0;
        vesselMetrics.veinPixels = 0;
        vesselMetrics.meanArteryWidth = 0;
        vesselMetrics.meanVeinWidth = 0;
    end

    %% ══════════════════════════════════════════════════════════════
    %  Step 10: CUP-TO-DISC RATIO (CDR) ESTIMATION
    %  Basic CDR for glaucoma co-screening (bonus clinical value)
    %  Uses brightness thresholding within OD mask
    %% ══════════════════════════════════════════════════════════════
    if any(odMask(:))
        odRegion = imgDouble;
        odRegion(~odMask) = 0;

        % The optic cup is the brighter central region within the OD
        odPixels = imgDouble(odMask);
        cupThreshold = prctile(odPixels, 75);  % Top 25% brightest pixels = cup

        cupMask = odMask & (imgDouble > cupThreshold);
        cupMask = imfill(cupMask, 'holes');
        cupMask = bwareaopen(cupMask, round(sum(odMask(:)) * 0.05));

        cupArea = sum(cupMask(:));
        discArea = sum(odMask(:));

        if discArea > 0
            vesselMetrics.cdr = round(sqrt(cupArea / discArea), 3);  % Vertical CDR approximation
        else
            vesselMetrics.cdr = 0;
        end

        % CDR > 0.6 is suspicious for glaucoma
        vesselMetrics.glaucomaSuspect = vesselMetrics.cdr > 0.6;
    else
        vesselMetrics.cdr = 0;
        vesselMetrics.glaucomaSuspect = false;
    end

end

%% ══════════════════════════════════════════════════════════════
%  LOCAL HELPER FUNCTIONS
%% ══════════════════════════════════════════════════════════════

function [Dxx, Dxy, Dyy] = hessian2D(I, sigma)
% HESSIAN2D Computes the 2D Hessian matrix components of an image
    % Create derivative of Gaussian kernels
    kernelSize = ceil(3 * sigma) * 2 + 1;
    x = -floor(kernelSize/2):floor(kernelSize/2);
    [X, Y] = meshgrid(x, x);

    DGaussxx = (X.^2 / sigma^4 - 1/sigma^2) .* exp(-(X.^2 + Y.^2)/(2*sigma^2));
    DGaussxy = (X .* Y / sigma^4) .* exp(-(X.^2 + Y.^2)/(2*sigma^2));
    DGaussyy = (Y.^2 / sigma^4 - 1/sigma^2) .* exp(-(X.^2 + Y.^2)/(2*sigma^2));

    Dxx = imfilter(I, DGaussxx, 'replicate');
    Dxy = imfilter(I, DGaussxy, 'replicate');
    Dyy = imfilter(I, DGaussyy, 'replicate');

    % Scale normalization
    Dxx = sigma^2 * Dxx;
    Dxy = sigma^2 * Dxy;
    Dyy = sigma^2 * Dyy;
end

function [lambda1, lambda2] = eigenvaluesOfHessian(Dxx, Dxy, Dyy)
% EIGENVALUESOFHESSIAN Compute sorted eigenvalues of 2x2 Hessian per pixel
    tmp = sqrt((Dxx - Dyy).^2 + 4*Dxy.^2);

    mu1 = 0.5*(Dxx + Dyy + tmp);
    mu2 = 0.5*(Dxx + Dyy - tmp);

    % Sort: |lambda1| <= |lambda2|
    check = abs(mu1) > abs(mu2);
    lambda1 = mu1;
    lambda2 = mu2;
    lambda1(check) = mu2(check);
    lambda2(check) = mu1(check);
end
