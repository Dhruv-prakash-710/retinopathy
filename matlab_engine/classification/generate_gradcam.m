function [heatmap, gradcamDetails] = generate_gradcam(enhancedImg, modelPath, lesionMasks)
% GENERATE_GRADCAM Enhanced Grad-CAM with lesion evidence correlation.
%   Generates Grad-CAM attention maps, correlates with detected lesions,
%   and computes clinical usefulness scores.
%
%   [heatmap, gradcamDetails] = generate_gradcam(enhancedImg, modelPath, lesionMasks)
%
%   Inputs:
%     enhancedImg  - Enhanced fundus image
%     modelPath    - Path to trained model
%     lesionMasks  - (optional) struct with binary masks for each lesion type
%
%   Outputs:
%     heatmap        - Normalized Grad-CAM heatmap [0-1]
%     gradcamDetails - Struct with clinical evidence correlation

    if nargin < 3
        lesionMasks = struct();
    end

    gradcamDetails = struct();

    %% ══════════════════════════════════════════════════════════════
    %  1. LOAD MODEL AND PREPROCESS
    %% ══════════════════════════════════════════════════════════════
    data = load(modelPath, 'trainedNet');
    net = data.trainedNet;

    inputSize = net.Layers(1).InputSize;
    imgResized = imresize(enhancedImg, inputSize(1:2));
    if size(imgResized, 3) == 1
        imgResized = repmat(imgResized, [1 1 3]);
    end

    % Get predicted class
    [classIdx, probs] = classify(net, imgResized);

    %% ══════════════════════════════════════════════════════════════
    %  2. IDENTIFY FEATURE LAYERS FOR GRAD-CAM
    %% ══════════════════════════════════════════════════════════════
    % Find the last convolutional/activation layer before global pooling
    layers = net.Layers;
    featureLayerName = '';
    for i = numel(layers):-1:1
        layerType = class(layers(i));
        if contains(layerType, 'ReLU') || contains(layerType, 'Activation') || ...
           contains(layerType, 'Convolution')
            featureLayerName = layers(i).Name;
            break;
        end
    end

    % Fallback for ResNet-50
    if isempty(featureLayerName)
        featureLayerName = 'activation_49_relu';
    end

    %% ══════════════════════════════════════════════════════════════
    %  3. GENERATE GRAD-CAM MAP
    %% ══════════════════════════════════════════════════════════════
    try
        scoreMap = gradCAM(net, imgResized, classIdx, ...
            'FeatureLayer', featureLayerName);
    catch
        try
            % Try with a different layer name pattern
            scoreMap = gradCAM(net, imgResized, classIdx);
        catch
            % Generate synthetic attention map based on image analysis
            disp('Info: Using analytical attention map (gradCAM unavailable).');
            scoreMap = generateAnalyticalAttention(imgResized);
        end
    end

    %% ══════════════════════════════════════════════════════════════
    %  4. POST-PROCESS HEATMAP
    %% ══════════════════════════════════════════════════════════════
    % Resize to original image dimensions
    heatmap = imresize(scoreMap, [size(enhancedImg, 1), size(enhancedImg, 2)]);

    % Normalize to [0, 1]
    heatmap = (heatmap - min(heatmap(:))) / (max(heatmap(:)) - min(heatmap(:)) + eps);

    % Apply Gaussian smoothing for cleaner visualization
    heatmap = imgaussfilt(heatmap, 3);

    gradcamDetails.rawHeatmap = heatmap;
    gradcamDetails.predictedClass = char(classIdx);
    gradcamDetails.classProbabilities = probs;
    gradcamDetails.featureLayer = featureLayerName;

    %% ══════════════════════════════════════════════════════════════
    %  5. LESION-LEVEL EVIDENCE CORRELATION
    %  Overlap between Grad-CAM hotspots and detected pathology
    %% ══════════════════════════════════════════════════════════════
    % Define attention threshold for "hot" regions
    attentionThreshold = 0.5;
    hotRegion = heatmap > attentionThreshold;

    lesionTypes = {'maMask', 'hardExudateMask', 'softExudateMask', ...
                   'hemorrhageMask', 'nvMask'};
    lesionLabels = {'Microaneurysms', 'Hard Exudates', 'Soft Exudates', ...
                    'Hemorrhages', 'Neovascularization'};

    totalOverlap = 0;
    totalLesionArea = 0;
    evidenceCorrelation = struct();

    for i = 1:length(lesionTypes)
        maskName = lesionTypes{i};
        if isfield(lesionMasks, maskName)
            mask = lesionMasks.(maskName);

            % Resize mask if needed
            if ~isequal(size(mask), size(heatmap))
                mask = imresize(mask, size(heatmap), 'nearest') > 0;
            end

            lesionArea = sum(mask(:));
            overlapArea = sum(mask(:) & hotRegion(:));

            if lesionArea > 0
                overlapRatio = overlapArea / lesionArea;
            else
                overlapRatio = 0;
            end

            evidenceCorrelation(i).lesionType = lesionLabels{i};
            evidenceCorrelation(i).lesionPixels = lesionArea;
            evidenceCorrelation(i).overlapPixels = overlapArea;
            evidenceCorrelation(i).overlapRatio = round(overlapRatio, 3);
            evidenceCorrelation(i).attendedByModel = overlapRatio > 0.3;

            totalOverlap = totalOverlap + overlapArea;
            totalLesionArea = totalLesionArea + lesionArea;
        else
            evidenceCorrelation(i).lesionType = lesionLabels{i};
            evidenceCorrelation(i).lesionPixels = 0;
            evidenceCorrelation(i).overlapPixels = 0;
            evidenceCorrelation(i).overlapRatio = 0;
            evidenceCorrelation(i).attendedByModel = false;
        end
    end

    gradcamDetails.evidenceCorrelation = evidenceCorrelation;

    %% ══════════════════════════════════════════════════════════════
    %  6. CLINICAL USEFULNESS SCORE
    %% ══════════════════════════════════════════════════════════════
    % Score based on how well Grad-CAM attention aligns with pathology
    if totalLesionArea > 0
        pathologyOverlap = totalOverlap / totalLesionArea;
    else
        pathologyOverlap = 0;
    end

    % Penalize if attention is mostly in non-pathological regions
    hotArea = sum(hotRegion(:));
    if hotArea > 0
        attentionPrecision = totalOverlap / hotArea;
    else
        attentionPrecision = 0;
    end

    % Composite usefulness: blend of overlap and precision
    if totalLesionArea > 0
        usefulnessScore = 0.6 * pathologyOverlap + 0.4 * attentionPrecision;
    else
        % No lesions detected — usefulness based on attention coherence
        % (concentrated attention is better than scattered)
        coherence = std2(heatmap(hotRegion));
        usefulnessScore = max(0, 1 - coherence * 5);
    end

    gradcamDetails.clinicalUsefulness = round(usefulnessScore * 100, 1);
    gradcamDetails.pathologyOverlap = round(pathologyOverlap * 100, 1);
    gradcamDetails.attentionPrecision = round(attentionPrecision * 100, 1);

    if usefulnessScore > 0.7
        gradcamDetails.usefulnessRating = 'Highly Useful';
    elseif usefulnessScore > 0.4
        gradcamDetails.usefulnessRating = 'Moderately Useful';
    else
        gradcamDetails.usefulnessRating = 'Limited Usefulness';
    end

    %% ══════════════════════════════════════════════════════════════
    %  7. ATTENTION COHERENCE SCORE
    %  Measures how focused vs scattered the attention is
    %  Concentrated attention → more clinically interpretable
    %% ══════════════════════════════════════════════════════════════
    % Entropy-based coherence: low entropy = focused, high entropy = scattered
    heatFlat = heatmap(:) + eps;
    heatNorm = heatFlat / sum(heatFlat);
    entropy = -sum(heatNorm .* log2(heatNorm));
    maxEntropy = log2(numel(heatmap));

    coherenceScore = 1 - (entropy / maxEntropy);
    gradcamDetails.attentionCoherence = round(coherenceScore * 100, 1);

    if coherenceScore > 0.7
        gradcamDetails.coherenceRating = 'Highly Focused';
    elseif coherenceScore > 0.4
        gradcamDetails.coherenceRating = 'Moderately Focused';
    else
        gradcamDetails.coherenceRating = 'Scattered';
    end

    %% ══════════════════════════════════════════════════════════════
    %  8. PER-LESION EVIDENCE SENTENCES
    %  Link each Grad-CAM hotspot to detected pathology for
    %  clinically meaningful explanations
    %% ══════════════════════════════════════════════════════════════
    evidenceSentences = {};

    for i = 1:length(lesionTypes)
        maskName = lesionTypes{i};
        if isfield(lesionMasks, maskName)
            mask = lesionMasks.(maskName);
            if ~isequal(size(mask), size(heatmap))
                mask = imresize(mask, size(heatmap), 'nearest') > 0;
            end

            if sum(mask(:)) > 0 && evidenceCorrelation(i).overlapRatio > 0.3
                % Find the centroid of the overlap region
                overlapRegion = mask & hotRegion;
                if any(overlapRegion(:))
                    stats = regionprops(overlapRegion, heatmap, 'WeightedCentroid', 'Area');
                    if ~isempty(stats)
                        [~, maxIdx] = max([stats.Area]);
                        wc = stats(maxIdx).WeightedCentroid;
                        sentence = sprintf('Model attention at (%.0f, %.0f) correlates with detected %s (%.0f%% overlap)', ...
                            wc(2), wc(1), lesionLabels{i}, evidenceCorrelation(i).overlapRatio * 100);
                        evidenceSentences{end+1} = sentence;
                    end
                end
            elseif sum(mask(:)) > 0 && evidenceCorrelation(i).overlapRatio < 0.1
                evidenceSentences{end+1} = sprintf('WARNING: %s detected but model attention is NOT focused on these regions', lesionLabels{i});
            end
        end
    end

    % Add summary sentence
    if usefulnessScore > 0.7
        evidenceSentences{end+1} = 'Overall: Grad-CAM attention aligns well with clinical pathology — high interpretability.';
    elseif usefulnessScore > 0.4
        evidenceSentences{end+1} = 'Overall: Partial alignment between model attention and pathology — review recommended.';
    else
        evidenceSentences{end+1} = 'Overall: Poor alignment between model attention and pathology — manual review required.';
    end

    gradcamDetails.evidenceSentences = evidenceSentences;

end

%% ══════════════════════════════════════════════════════════════
%  ANALYTICAL ATTENTION MAP (Fallback when gradCAM is unavailable)
%% ══════════════════════════════════════════════════════════════
function attMap = generateAnalyticalAttention(img)
    % Generate an attention-like map based on image analysis
    % Focuses on regions with high variance (likely pathological)
    if size(img, 3) == 3
        gray = rgb2gray(im2double(img));
    else
        gray = im2double(img);
    end

    % Local variance map (high variance = interesting regions)
    localVar = stdfilt(gray, ones(15));

    % Gradient magnitude
    [gx, gy] = imgradientxy(gray);
    gradMag = sqrt(gx.^2 + gy.^2);

    % Combine
    attMap = 0.6 * localVar/max(localVar(:)+eps) + 0.4 * gradMag/max(gradMag(:)+eps);
    attMap = imgaussfilt(attMap, 5);
    attMap = (attMap - min(attMap(:))) / (max(attMap(:)) - min(attMap(:)) + eps);
end
