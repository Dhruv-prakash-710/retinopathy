function [dmeMask, dmeDetails] = detect_dme(hardExudateMask, hemorrhageMask, foveaCenter, odRadius, maculaMask)
% DETECT_DME Diabetic Macular Edema (DME) detection and severity grading.
%   Analyzes the spatial distribution of hard exudates and hemorrhages
%   relative to the fovea to determine DME presence and severity.
%   DME is the #1 cause of vision loss in diabetic retinopathy patients
%   and is an independent referral criterion regardless of DR grade.
%
%   [dmeMask, dmeDetails] = detect_dme(hardExudateMask, hemorrhageMask, foveaCenter, odRadius, maculaMask)
%
%   Inputs:
%     hardExudateMask - Binary mask of hard exudates
%     hemorrhageMask  - Binary mask of hemorrhages
%     foveaCenter     - [row, col] center of the fovea
%     odRadius        - Optic disc radius (used for distance calibration)
%     maculaMask      - (optional) Binary mask of the macular region
%
%   Outputs:
%     dmeMask    - Binary mask of the DME-affected region
%     dmeDetails - Struct with severity, CSME status, distances, thickness proxy
%
%   DME Severity Classification (ETDRS-based):
%     None     - No macular edema
%     Mild     - Some retinal thickening/exudates in posterior pole but not center
%     Moderate - Retinal thickening/exudates approaching the center but not involving it
%     Severe   - Retinal thickening/exudates involving the center of the macula
%
%   CSME (Clinically Significant Macular Edema — ETDRS criteria):
%     1. Retinal thickening at or within 500 μm of the foveal center
%     2. Hard exudates at or within 500 μm of foveal center with adjacent thickening
%     3. Retinal thickening ≥ 1 disc area, any part within 1 disc diameter of center

    if nargin < 5 || isempty(maculaMask)
        maculaMask = [];
    end

    [rows, cols] = size(hardExudateMask);

    dmeDetails = struct();
    dmeDetails.detected = false;
    dmeDetails.severity = 'None';
    dmeDetails.csme = false;
    dmeDetails.centralInvolvement = false;
    dmeDetails.nearestExudateToFovea_px = Inf;
    dmeDetails.nearestHemorrhageToFovea_px = Inf;
    dmeDetails.exudatesInMacula = 0;
    dmeDetails.exudateAreaInMacula = 0;
    dmeDetails.hemorrhagesInMacula = 0;
    dmeDetails.centralThicknessProxy = 200;  % Normal baseline (μm equivalent)
    dmeDetails.csmeReason = '';
    dmeDetails.referralRequired = false;

    %% ══════════════════════════════════════════════════════════════
    %  DISTANCE CALIBRATION
    %  Use OD radius as anatomical ruler:
    %    OD diameter ≈ 1.5 mm → OD radius ≈ 0.75 mm
    %    500 μm ≈ 0.67 × OD radius
    %    1 disc diameter ≈ 2 × OD radius
    %    1 disc area ≈ π × OD radius²
    %% ══════════════════════════════════════════════════════════════
    pixelsPerMM = odRadius / 0.75;  % Approximate pixels per mm

    % ETDRS distance thresholds in pixels
    dist_500um = round(0.5 * pixelsPerMM);      % 500 μm from fovea center
    dist_1dd = round(1.5 * pixelsPerMM);         % 1 disc diameter (1.5 mm)
    dist_macula = round(3.0 * pixelsPerMM);      % Macular region (~3 mm radius)
    disc_area_px = round(pi * odRadius^2);        % 1 disc area in pixels

    fovR = foveaCenter(1);
    fovC = foveaCenter(2);

    %% ══════════════════════════════════════════════════════════════
    %  1. CREATE DISTANCE MAP FROM FOVEA
    %% ══════════════════════════════════════════════════════════════
    [X, Y] = meshgrid(1:cols, 1:rows);
    distFromFovea = sqrt((X - fovC).^2 + (Y - fovR).^2);

    %% ══════════════════════════════════════════════════════════════
    %  2. DEFINE MACULAR ZONES (concentric rings)
    %% ══════════════════════════════════════════════════════════════
    % Zone 1: Central (within 500 μm — critical CSME zone)
    centralZone = distFromFovea <= dist_500um;

    % Zone 2: Inner ring (500 μm to 1 DD)
    innerRing = distFromFovea > dist_500um & distFromFovea <= dist_1dd;

    % Zone 3: Outer macular ring (1 DD to full macula)
    outerRing = distFromFovea > dist_1dd & distFromFovea <= dist_macula;

    % Full macular mask
    if isempty(maculaMask)
        maculaRegion = distFromFovea <= dist_macula;
    else
        maculaRegion = maculaMask;
    end

    %% ══════════════════════════════════════════════════════════════
    %  3. ANALYZE HARD EXUDATES IN MACULAR ZONES
    %% ══════════════════════════════════════════════════════════════
    % Exudates in each zone
    heInCentral = hardExudateMask & centralZone;
    heInInner = hardExudateMask & innerRing;
    heInOuter = hardExudateMask & outerRing;
    heInMacula = hardExudateMask & maculaRegion;

    centralHEArea = sum(heInCentral(:));
    innerHEArea = sum(heInInner(:));
    outerHEArea = sum(heInOuter(:));
    macularHEArea = sum(heInMacula(:));

    % Count distinct exudate clusters in macula
    cc_he = bwconncomp(heInMacula);
    dmeDetails.exudatesInMacula = cc_he.NumObjects;
    dmeDetails.exudateAreaInMacula = macularHEArea;

    % Find nearest exudate to fovea
    if macularHEArea > 0
        heDistances = distFromFovea(hardExudateMask & maculaRegion);
        dmeDetails.nearestExudateToFovea_px = min(heDistances);
    end

    %% ══════════════════════════════════════════════════════════════
    %  4. ANALYZE HEMORRHAGES IN MACULAR ZONES
    %% ══════════════════════════════════════════════════════════════
    hemInMacula = hemorrhageMask & maculaRegion;
    hemInCentral = hemorrhageMask & centralZone;

    cc_hem = bwconncomp(hemInMacula);
    dmeDetails.hemorrhagesInMacula = cc_hem.NumObjects;

    if sum(hemInMacula(:)) > 0
        hemDistances = distFromFovea(hemorrhageMask & maculaRegion);
        dmeDetails.nearestHemorrhageToFovea_px = min(hemDistances);
    end

    %% ══════════════════════════════════════════════════════════════
    %  5. ESTIMATE CENTRAL SUBFIELD THICKNESS PROXY
    %  Real OCT measures thickness; we approximate from lesion density
    %% ══════════════════════════════════════════════════════════════
    % Normal central subfield thickness: ~200-260 μm
    % Edematous: 300-600+ μm
    % Proxy: base thickness + contribution from nearby lesions

    baseThickness = 230;  % Normal baseline

    % Exudates near center increase thickness estimate
    centralLesionDensity = (centralHEArea + sum(hemInCentral(:))) / max(sum(centralZone(:)), 1);
    innerLesionDensity = (innerHEArea + sum(hemInMacula(:) & innerRing(:))) / max(sum(innerRing(:)), 1);

    thicknessContribution = 0;
    if centralLesionDensity > 0
        thicknessContribution = thicknessContribution + min(centralLesionDensity * 5000, 250);
    end
    if innerLesionDensity > 0
        thicknessContribution = thicknessContribution + min(innerLesionDensity * 2000, 100);
    end

    dmeDetails.centralThicknessProxy = round(baseThickness + thicknessContribution);

    %% ══════════════════════════════════════════════════════════════
    %  6. CSME CLASSIFICATION (ETDRS Criteria)
    %% ══════════════════════════════════════════════════════════════
    csme = false;
    csmeReason = '';

    % Criterion 1: Hard exudates within 500 μm of foveal center
    if centralHEArea > 0
        csme = true;
        csmeReason = 'Hard exudates within 500 μm of foveal center';
    end

    % Criterion 2: Hemorrhages/thickening within 500 μm
    if sum(hemInCentral(:)) > 0 && ~csme
        csme = true;
        csmeReason = 'Hemorrhages within 500 μm of foveal center (thickening indicator)';
    end

    % Criterion 3: Exudate area >= 1 disc area, any part within 1 DD of center
    if macularHEArea >= disc_area_px && dmeDetails.nearestExudateToFovea_px <= dist_1dd && ~csme
        csme = true;
        csmeReason = sprintf('Exudate area (%.0f px²) >= 1 disc area (%.0f px²) within 1 DD of center', ...
            macularHEArea, disc_area_px);
    end

    dmeDetails.csme = csme;
    dmeDetails.csmeReason = csmeReason;

    %% ══════════════════════════════════════════════════════════════
    %  7. DME SEVERITY GRADING
    %% ══════════════════════════════════════════════════════════════
    if centralHEArea > 0 || sum(hemInCentral(:)) > 0
        % Center-involving DME
        dmeDetails.severity = 'Severe';
        dmeDetails.centralInvolvement = true;
        dmeDetails.detected = true;
    elseif innerHEArea > 0 || (dmeDetails.nearestExudateToFovea_px <= dist_1dd)
        % Approaching center
        dmeDetails.severity = 'Moderate';
        dmeDetails.detected = true;
    elseif outerHEArea > 0 || dmeDetails.exudatesInMacula > 0
        % Peripheral macular involvement
        dmeDetails.severity = 'Mild';
        dmeDetails.detected = true;
    else
        dmeDetails.severity = 'None';
        dmeDetails.detected = false;
    end

    %% ══════════════════════════════════════════════════════════════
    %  8. REFERRAL DECISION
    %  DME is an independent referral criterion
    %% ══════════════════════════════════════════════════════════════
    if csme || strcmp(dmeDetails.severity, 'Severe') || strcmp(dmeDetails.severity, 'Moderate')
        dmeDetails.referralRequired = true;
        dmeDetails.referralUrgency = 'Refer to ophthalmologist within 4 weeks for macular assessment';
    elseif strcmp(dmeDetails.severity, 'Mild')
        dmeDetails.referralRequired = false;
        dmeDetails.referralUrgency = 'Monitor — rescreen in 3-6 months';
    else
        dmeDetails.referralRequired = false;
        dmeDetails.referralUrgency = 'No macular edema — routine follow-up';
    end

    %% ══════════════════════════════════════════════════════════════
    %  9. GENERATE DME MASK
    %  Highlight the affected macular region
    %% ══════════════════════════════════════════════════════════════
    dmeMask = false(rows, cols);

    if dmeDetails.detected
        % DME-affected region: union of lesions within the macular zone
        dmeMask = (heInMacula | hemInMacula);

        % Dilate slightly to show the affected area more clearly
        se = strel('disk', round(dist_500um * 0.3));
        dmeMask = imdilate(dmeMask, se);
        dmeMask = dmeMask & maculaRegion;  % Constrain to macula
    end

    %% ══════════════════════════════════════════════════════════════
    %  10. ZONE STATISTICS (for detailed reporting)
    %% ══════════════════════════════════════════════════════════════
    dmeDetails.zoneAnalysis = struct();
    dmeDetails.zoneAnalysis.centralZone = struct( ...
        'exudateArea', centralHEArea, ...
        'hemorrhageArea', sum(hemInCentral(:)), ...
        'radiusPx', dist_500um);
    dmeDetails.zoneAnalysis.innerRing = struct( ...
        'exudateArea', innerHEArea, ...
        'hemorrhageArea', sum(hemorrhageMask(:) & innerRing(:)), ...
        'radiusPx', dist_1dd);
    dmeDetails.zoneAnalysis.outerRing = struct( ...
        'exudateArea', outerHEArea, ...
        'hemorrhageArea', sum(hemorrhageMask(:) & outerRing(:)), ...
        'radiusPx', dist_macula);

end
