function [level, confidence, referable, gradeDetails] = grade_dr_severity(enhancedImg, modelPath, lesionCounts)
% GRADE_DR_SEVERITY DR severity grading with calibrated confidence and ICDR rule verification.
%
%   [level, confidence, referable, gradeDetails] = grade_dr_severity(enhancedImg, modelPath, lesionCounts)
%
%   Inputs:
%     enhancedImg  - Enhanced fundus image (green channel or RGB)
%     modelPath    - Path to trained_dr_model.mat
%     lesionCounts - (optional) struct with fields: ma, hardExudates, softExudates,
%                    dotHemorrhages, blotHemorrhages, flameHemorrhages, nv
%
%   Outputs:
%     level        - ICDR severity level (0-4)
%     confidence   - Calibrated confidence percentage
%     referable    - Boolean: true if level >= 2
%     gradeDetails - Comprehensive grading details struct

    if nargin < 3
        lesionCounts = struct();
    end

    %% ══════════════════════════════════════════════════════════════
    %  1. LOAD MODEL
    %% ══════════════════════════════════════════════════════════════
    if ~isfile(modelPath)
        error('Trained model not found at %s. Please train first.', modelPath);
    end

    data = load(modelPath);
    net = data.trainedNet;

    % Load calibration temperature if available
    if isfield(data, 'validationResults') && isfield(data.validationResults, 'optimalTemperature')
        temperature = data.validationResults.optimalTemperature;
    else
        temperature = 1.0;
    end

    %% ══════════════════════════════════════════════════════════════
    %  2. PREPROCESS IMAGE
    %% ══════════════════════════════════════════════════════════════
    inputSize = net.Layers(1).InputSize;
    imgResized = imresize(enhancedImg, inputSize(1:2));

    if size(imgResized, 3) == 1
        imgResized = repmat(imgResized, [1 1 3]);
    end

    %% ══════════════════════════════════════════════════════════════
    %  3. CNN INFERENCE
    %% ══════════════════════════════════════════════════════════════
    [YPred, rawProbs] = classify(net, imgResized);

    % Apply temperature scaling for calibrated probabilities
    logits = log(rawProbs + eps);
    calibratedProbs = exp(logits / temperature) / sum(exp(logits / temperature));

    cnnLevel = str2double(char(YPred));
    cnnConfidence = max(calibratedProbs) * 100;

    %% ══════════════════════════════════════════════════════════════
    %  4. ICDR RULE-BASED VERIFICATION
    %  Cross-check CNN prediction against clinical criteria
    %% ══════════════════════════════════════════════════════════════
    % ICDR Criteria:
    %   Level 0 - No DR: No abnormalities
    %   Level 1 - Mild NPDR: Microaneurysms only
    %   Level 2 - Moderate NPDR: More than just MAs (HE, DH, or venous beading in 1 quadrant)
    %   Level 3 - Severe NPDR: 4-2-1 rule (any of: 20+ hemorrhages in each of 4 quadrants,
    %             venous beading in 2+ quadrants, IRMA in 1+ quadrant)
    %   Level 4 - PDR: Neovascularization and/or vitreous/preretinal hemorrhage

    ruleLevel = 0;
    ruleExplanation = {};

    % Extract lesion counts
    maCount = getFieldOr(lesionCounts, 'ma', 0);
    heCount = getFieldOr(lesionCounts, 'hardExudates', 0);
    seCount = getFieldOr(lesionCounts, 'softExudates', 0);
    dotHem = getFieldOr(lesionCounts, 'dotHemorrhages', 0);
    blotHem = getFieldOr(lesionCounts, 'blotHemorrhages', 0);
    flameHem = getFieldOr(lesionCounts, 'flameHemorrhages', 0);
    nvScore = getFieldOr(lesionCounts, 'nvScore', 0);
    totalHem = dotHem + blotHem + flameHem;

    if nvScore > 0.3
        ruleLevel = 4;
        ruleExplanation{end+1} = 'Neovascularization detected — consistent with Proliferative DR';
    elseif totalHem >= 20 || (seCount >= 2 && totalHem >= 10)
        ruleLevel = 3;
        ruleExplanation{end+1} = sprintf('Extensive hemorrhages (%d) and/or cotton-wool spots (%d) — Severe NPDR criteria', totalHem, seCount);
    elseif (maCount > 0 && (heCount > 0 || totalHem > 0 || seCount > 0))
        ruleLevel = 2;
        ruleExplanation{end+1} = sprintf('MAs (%d) with additional lesions (HE:%d, Hem:%d, CWS:%d) — Moderate NPDR', maCount, heCount, totalHem, seCount);
    elseif maCount > 0
        ruleLevel = 1;
        ruleExplanation{end+1} = sprintf('Microaneurysms only (%d) — Mild NPDR', maCount);
    else
        ruleLevel = 0;
        ruleExplanation{end+1} = 'No significant lesions detected — No apparent DR';
    end

    %% ══════════════════════════════════════════════════════════════
    %  5. FUSE CNN AND RULE-BASED RESULTS
    %% ══════════════════════════════════════════════════════════════
    % If CNN and rules agree, high confidence
    % If they disagree, take the higher severity (safety-first approach)

    if cnnLevel == ruleLevel
        level = cnnLevel;
        confidence = cnnConfidence;
        fusionNote = 'CNN and ICDR rule-based assessment agree';
    elseif abs(cnnLevel - ruleLevel) == 1
        % Adjacent levels — take higher severity, slightly lower confidence
        level = max(cnnLevel, ruleLevel);
        confidence = cnnConfidence * 0.85;
        fusionNote = sprintf('CNN predicts Level %d, rules suggest Level %d — using higher severity (safety-first)', cnnLevel, ruleLevel);
    else
        % Significant disagreement — flag for review
        level = max(cnnLevel, ruleLevel);
        confidence = cnnConfidence * 0.7;
        fusionNote = sprintf('SIGNIFICANT DISAGREEMENT: CNN=%d, Rules=%d — requires manual review', cnnLevel, ruleLevel);
    end

    % Referable DR: Level 2 or higher
    referable = level >= 2;

    %% ══════════════════════════════════════════════════════════════
    %  6. POPULATE DETAILED RESULTS
    %% ══════════════════════════════════════════════════════════════
    drDescriptions = {'No DR', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'Proliferative DR'};
    drActions = {
        'Routine screening in 12 months'
        'Repeat screening in 6-12 months'
        'Refer to ophthalmologist within 4-8 weeks'
        'URGENT: Refer to ophthalmologist within 1-2 weeks'
        'URGENT: Immediate referral to retina specialist'
    };

    gradeDetails = struct();
    gradeDetails.level = level;
    gradeDetails.label = drDescriptions{level + 1};
    gradeDetails.description = drDescriptions{level + 1};
    gradeDetails.confidence = round(confidence, 1);
    gradeDetails.referable = referable;
    gradeDetails.recommendedAction = drActions{level + 1};

    % Per-class probabilities
    gradeDetails.perClassProbs = struct();
    for i = 1:length(calibratedProbs)
        gradeDetails.perClassProbs(i).level = i - 1;
        gradeDetails.perClassProbs(i).label = drDescriptions{i};
        gradeDetails.perClassProbs(i).probability = round(calibratedProbs(i) * 100, 1);
    end

    % CNN vs Rules comparison
    gradeDetails.cnnLevel = cnnLevel;
    gradeDetails.ruleLevel = ruleLevel;
    gradeDetails.fusionNote = fusionNote;
    gradeDetails.ruleExplanation = ruleExplanation;

    % Calibration info
    gradeDetails.temperature = temperature;
    gradeDetails.calibrationStatus = 'Temperature-scaled';

    % ICDR criteria checklist
    gradeDetails.icdrCriteria = struct();
    gradeDetails.icdrCriteria.microaneurysmsPresent = maCount > 0;
    gradeDetails.icdrCriteria.hardExudatesPresent = heCount > 0;
    gradeDetails.icdrCriteria.softExudatesPresent = seCount > 0;
    gradeDetails.icdrCriteria.hemorrhagesPresent = totalHem > 0;
    gradeDetails.icdrCriteria.neovascularizationPresent = nvScore > 0.3;
    gradeDetails.icdrCriteria.maCount = maCount;
    gradeDetails.icdrCriteria.hemorrhageCount = totalHem;

end

%% Helper function to safely get struct field or default
function val = getFieldOr(s, fieldName, default)
    if isfield(s, fieldName)
        val = s.(fieldName);
    else
        val = default;
    end
end
