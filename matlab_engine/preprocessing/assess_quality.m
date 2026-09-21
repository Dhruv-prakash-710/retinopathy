function [qualityGrade, metrics, feedback] = assess_quality(img)
% ASSESS_QUALITY Comprehensive fundus image quality assessment.
%   Evaluates focus, illumination, field of view, artifacts, contrast, and
%   noise to produce a 3-tier quality grade with actionable recapture feedback.
%
%   [qualityGrade, metrics, feedback] = assess_quality(img)
%
%   Outputs:
%     qualityGrade - 'Gradeable', 'Borderline', or 'Ungradeable'
%     metrics      - struct with all quality sub-scores
%     feedback     - struct with 'recaptureReasons' cell array and 'suggestions'

    % Convert to grayscale if RGB
    if size(img, 3) == 3
        grayImg = im2double(rgb2gray(img));
        rgbImg = im2double(img);
    else
        grayImg = im2double(img);
        rgbImg = repmat(grayImg, [1 1 3]);
    end

    [rows, cols] = size(grayImg);
    metrics = struct();
    feedback = struct('recaptureReasons', {{}}, 'suggestions', {{}});
    issueCount = 0;
    severeIssueCount = 0;

    %% ══════════════════════════════════════════════════════════════
    %  1. FOCUS EVALUATION — Variance of Laplacian (multi-scale)
    %% ══════════════════════════════════════════════════════════════
    % Compute at two scales for robustness
    lap1 = fspecial('laplacian', 0.2);
    lap2 = fspecial('laplacian', 0.5);
    lapImg1 = imfilter(grayImg, lap1, 'replicate');
    lapImg2 = imfilter(grayImg, lap2, 'replicate');

    focusScore1 = var(lapImg1(:));
    focusScore2 = var(lapImg2(:));
    focusScore = (focusScore1 + focusScore2) / 2;

    % Tenengrad gradient-based focus measure (complementary)
    [gx, gy] = imgradientxy(grayImg, 'sobel');
    tenenbaumScore = mean(gx(:).^2 + gy(:).^2);

    % Combine into composite focus metric [0-1]
    % Empirical normalization — tuned for 1024+ pixel fundus images
    focusNorm = min(focusScore / 0.002, 1.0);
    tenenNorm = min(tenenbaumScore / 0.01, 1.0);
    compositeFocus = 0.6 * focusNorm + 0.4 * tenenNorm;

    metrics.focusScore = focusScore;
    metrics.tenenbaumScore = tenenbaumScore;
    metrics.compositeFocus = round(compositeFocus * 100, 1);

    FOCUS_GOOD = 0.5;
    FOCUS_MIN = 0.25;

    if compositeFocus < FOCUS_MIN
        severeIssueCount = severeIssueCount + 1;
        feedback.recaptureReasons{end+1} = 'SEVERE: Image is significantly out of focus';
        feedback.suggestions{end+1} = 'Clean the lens and ask the patient to fixate on the target light. Ensure the camera is properly focused before capture.';
    elseif compositeFocus < FOCUS_GOOD
        issueCount = issueCount + 1;
        feedback.recaptureReasons{end+1} = 'Focus is below optimal — major retinal vessels are not sharply resolved';
        feedback.suggestions{end+1} = 'Re-adjust focus dial until retinal vessels appear sharp.';
    end

    %% ══════════════════════════════════════════════════════════════
    %  2. ILLUMINATION ANALYSIS
    %% ══════════════════════════════════════════════════════════════
    meanIntensity = mean(grayImg(:));
    stdIntensity = std(grayImg(:));

    % Check exposure percentiles
    p5 = prctile(grayImg(:), 5);
    p95 = prctile(grayImg(:), 95);
    dynamicRange = p95 - p5;

    % Uniformity — compare quadrant means
    midR = round(rows/2); midC = round(cols/2);
    q1 = mean2(grayImg(1:midR, 1:midC));
    q2 = mean2(grayImg(1:midR, midC+1:end));
    q3 = mean2(grayImg(midR+1:end, 1:midC));
    q4 = mean2(grayImg(midR+1:end, midC+1:end));
    illuminationUniformity = 1 - (std([q1 q2 q3 q4]) / mean([q1 q2 q3 q4]));

    metrics.meanIntensity = round(meanIntensity * 255, 1);
    metrics.stdIntensity = round(stdIntensity * 255, 1);
    metrics.dynamicRange = round(dynamicRange * 255, 1);
    metrics.illuminationUniformity = round(illuminationUniformity * 100, 1);

    isUnderexposed = meanIntensity < 0.12;
    isOverexposed = meanIntensity > 0.85;
    isPoorContrast = dynamicRange < 0.15;
    isNonUniform = illuminationUniformity < 0.6;

    if isUnderexposed
        severeIssueCount = severeIssueCount + 1;
        feedback.recaptureReasons{end+1} = 'SEVERE: Image is significantly underexposed (too dark)';
        feedback.suggestions{end+1} = 'Increase flash intensity. Ensure the pupil is adequately dilated.';
    elseif isOverexposed
        severeIssueCount = severeIssueCount + 1;
        feedback.recaptureReasons{end+1} = 'SEVERE: Image is overexposed (washed out)';
        feedback.suggestions{end+1} = 'Reduce flash intensity or increase the working distance slightly.';
    end

    if isPoorContrast
        issueCount = issueCount + 1;
        feedback.recaptureReasons{end+1} = 'Low contrast — retinal structures are not well differentiated';
        feedback.suggestions{end+1} = 'Check for media opacity (cataract). Adjust exposure settings.';
    end

    if isNonUniform
        issueCount = issueCount + 1;
        feedback.recaptureReasons{end+1} = 'Non-uniform illumination across the image';
        feedback.suggestions{end+1} = 'Center the camera on the pupil. Ensure proper alignment with the optical axis.';
    end

    %% ══════════════════════════════════════════════════════════════
    %  3. FIELD OF VIEW (FOV) ASSESSMENT
    %% ══════════════════════════════════════════════════════════════
    % Detect the retinal field as the non-black circular region
    % Fundus images typically have a circular retinal field on a black bg

    % Threshold to find the retinal area (non-background)
    bwRetina = grayImg > 0.05;
    bwRetina = imfill(bwRetina, 'holes');
    bwRetina = bwareaopen(bwRetina, round(rows * cols * 0.01));

    retinalArea = sum(bwRetina(:));
    totalArea = rows * cols;
    fovRatio = retinalArea / totalArea;

    % Find the bounding circle of the retinal area
    stats = regionprops(bwRetina, 'Centroid', 'EquivDiameter', 'BoundingBox');
    if ~isempty(stats)
        [~, maxIdx] = max([stats.EquivDiameter]);
        retinaDiameter = stats(maxIdx).EquivDiameter;
        retinaCentroid = stats(maxIdx).Centroid;

        % Circularity of the retinal field
        expectedArea = pi * (retinaDiameter/2)^2;
        fovCircularity = min(retinalArea / expectedArea, 1.0);

        % Check if centered (centroid close to image center)
        centerOffset = sqrt((retinaCentroid(1) - cols/2)^2 + (retinaCentroid(2) - rows/2)^2);
        centerOffsetNorm = centerOffset / (min(rows, cols) / 2);
        isCentered = centerOffsetNorm < 0.15;
    else
        retinaDiameter = 0;
        fovCircularity = 0;
        isCentered = false;
        centerOffsetNorm = 1.0;
    end

    metrics.fovRatio = round(fovRatio * 100, 1);
    metrics.fovCircularity = round(fovCircularity * 100, 1);
    metrics.fovCentered = isCentered;
    metrics.centerOffset = round(centerOffsetNorm * 100, 1);

    FOV_MIN = 0.30;  % Minimum retinal area ratio
    FOV_GOOD = 0.50;

    if fovRatio < FOV_MIN
        severeIssueCount = severeIssueCount + 1;
        feedback.recaptureReasons{end+1} = 'SEVERE: Insufficient field of view — retina is barely visible';
        feedback.suggestions{end+1} = 'Reposition camera closer to the eye. Ensure proper alignment and pupil dilation.';
    elseif fovRatio < FOV_GOOD
        issueCount = issueCount + 1;
        feedback.recaptureReasons{end+1} = 'Partial retinal field — some peripheral regions may be cut off';
        feedback.suggestions{end+1} = 'Adjust camera position to capture a wider field. Standard 45-degree FOV recommended.';
    end

    if ~isCentered && fovRatio > FOV_MIN
        issueCount = issueCount + 1;
        feedback.recaptureReasons{end+1} = 'Retinal field is not centered — macula or optic disc may be partially outside the frame';
        feedback.suggestions{end+1} = 'Re-center the camera on the pupil. Ask the patient to look directly at the fixation target.';
    end

    %% ══════════════════════════════════════════════════════════════
    %  4. ARTIFACT DETECTION
    %% ══════════════════════════════════════════════════════════════
    hasArtifacts = false;
    artifactTypes = {};

    % 4a. Eyelash/Eyelid artifacts — dark intrusions from edges
    topStrip = grayImg(1:round(rows*0.1), :);
    bottomStrip = grayImg(round(rows*0.9):end, :);
    topDark = mean(topStrip(:)) < 0.08 && std(topStrip(:)) > 0.02;
    bottomDark = mean(bottomStrip(:)) < 0.08 && std(bottomStrip(:)) > 0.02;

    if topDark || bottomDark
        % Check for irregular dark patterns (eyelash-like)
        edgeStrip = topDark * topStrip + bottomDark * bottomStrip;
        if sum(edgeStrip(:) > 0.03 & edgeStrip(:) < 0.15) > numel(edgeStrip) * 0.1
            hasArtifacts = true;
            artifactTypes{end+1} = 'Eyelash/eyelid obstruction';
            feedback.suggestions{end+1} = 'Ask the patient to open their eye wider. Gently hold the eyelid if needed.';
        end
    end

    % 4b. Lens flare / bright spots — saturated regions outside the OD
    saturated = grayImg > 0.98;
    saturatedRatio = sum(saturated(:)) / totalArea;
    if saturatedRatio > 0.005
        hasArtifacts = true;
        artifactTypes{end+1} = 'Lens flare or specular reflection';
        feedback.suggestions{end+1} = 'Adjust the angle of the camera to eliminate reflections. Clean the lens.';
    end

    % 4c. Dust / smudge — localized low-contrast blobs
    blurred = imgaussfilt(grayImg, 20);
    diffImg = abs(grayImg - blurred);
    dustRegions = diffImg < 0.005 & grayImg > 0.1 & grayImg < 0.8;
    dustRatio = sum(dustRegions(:)) / totalArea;
    if dustRatio > 0.15
        hasArtifacts = true;
        artifactTypes{end+1} = 'Dust or smudge on lens';
        feedback.suggestions{end+1} = 'Clean the camera lens with a microfiber cloth before recapture.';
    end

    if hasArtifacts
        issueCount = issueCount + length(artifactTypes);
        for k = 1:length(artifactTypes)
            feedback.recaptureReasons{end+1} = ['Artifact detected: ' artifactTypes{k}];
        end
    end

    metrics.hasArtifacts = hasArtifacts;
    metrics.artifactTypes = artifactTypes;

    %% ══════════════════════════════════════════════════════════════
    %  5. NOISE LEVEL ESTIMATION
    %% ══════════════════════════════════════════════════════════════
    % Estimate noise using the Median Absolute Deviation of wavelet coefficients
    % (robust noise estimator)
    if exist('wdencmp', 'file')
        try
            [~, ~, ~, ~] = dwt2(grayImg, 'db1');
            [~, cH, ~, ~] = dwt2(grayImg, 'db1');
            noiseEstimate = median(abs(cH(:))) / 0.6745;
        catch
            noiseEstimate = std2(grayImg - imgaussfilt(grayImg, 2));
        end
    else
        noiseEstimate = std2(grayImg - imgaussfilt(grayImg, 2));
    end

    metrics.noiseLevel = round(noiseEstimate * 1000, 2);

    NOISE_HIGH = 0.03;
    if noiseEstimate > NOISE_HIGH
        issueCount = issueCount + 1;
        feedback.recaptureReasons{end+1} = 'High noise level in the image';
        feedback.suggestions{end+1} = 'Ensure adequate lighting. Stabilize the camera during capture.';
    end

    %% ══════════════════════════════════════════════════════════════
    %  6. SATURATION / COLOR ANALYSIS (RGB only)
    %% ══════════════════════════════════════════════════════════════
    if size(img, 3) == 3
        hsvImg = rgb2hsv(rgbImg);
        saturation = hsvImg(:,:,2);
        meanSaturation = mean(saturation(bwRetina));
        metrics.meanSaturation = round(meanSaturation * 100, 1);

        % Green channel quality (most diagnostic)
        greenChannel = rgbImg(:,:,2);
        greenContrast = std(greenChannel(bwRetina));
        metrics.greenContrast = round(greenContrast * 255, 1);

        if meanSaturation < 0.05
            issueCount = issueCount + 1;
            feedback.recaptureReasons{end+1} = 'Very low color saturation — image appears washed out or grayscale';
            feedback.suggestions{end+1} = 'Check camera color settings and white balance.';
        end
    else
        metrics.meanSaturation = 0;
        metrics.greenContrast = 0;
    end

    %% ══════════════════════════════════════════════════════════════
    %  7. COMPOSITE QUALITY GRADE
    %% ══════════════════════════════════════════════════════════════
    if severeIssueCount > 0
        qualityGrade = 'Ungradeable';
        metrics.status = 'Ungradeable';
        metrics.gradeScore = 0;
    elseif issueCount >= 3
        qualityGrade = 'Ungradeable';
        metrics.status = 'Ungradeable';
        metrics.gradeScore = 15;
    elseif issueCount >= 1
        qualityGrade = 'Borderline';
        metrics.status = 'Borderline';
        metrics.gradeScore = 50;
    else
        qualityGrade = 'Gradeable';
        metrics.status = 'Gradeable';
        metrics.gradeScore = 95;
    end

    % If no issues found, provide positive feedback
    if isempty(feedback.recaptureReasons)
        feedback.recaptureReasons{1} = 'No issues detected — image quality is adequate for analysis';
        feedback.suggestions{1} = 'Image is ready for processing.';
    end

    metrics.issueCount = issueCount;
    metrics.severeIssueCount = severeIssueCount;

end
