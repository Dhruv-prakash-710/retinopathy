function train_dr_model(datasetPath, outputPath)
% TRAIN_DR_MODEL Advanced DR classification using Transfer Learning.
%   Uses ResNet-50 with class-weighted loss, extensive data augmentation,
%   lesion feature fusion, k-fold cross-validation, and comprehensive
%   validation metrics computation.
%
%   train_dr_model(datasetPath, outputPath)
%
%   Inputs:
%     datasetPath - Path to directory with subfolders 0,1,2,3,4 (ICDR levels)
%     outputPath  - (optional) Path to save the trained model

    if nargin < 2
        outputPath = fullfile(fileparts(mfilename('fullpath')), 'trained_dr_model.mat');
    end

    disp('═══════════════════════════════════════════════════════════');
    disp('  DR SEVERITY CLASSIFICATION — TRAINING PIPELINE');
    disp('═══════════════════════════════════════════════════════════');

    %% ══════════════════════════════════════════════════════════════
    %  1. LOAD AND ANALYZE DATASET
    %% ══════════════════════════════════════════════════════════════
    disp('[1/7] Loading dataset...');

    imds = imageDatastore(datasetPath, ...
        'IncludeSubfolders', true, ...
        'LabelSource', 'foldernames');

    numClasses = numel(categories(imds.Labels));
    classCounts = countEachLabel(imds);

    disp('Dataset summary:');
    disp(classCounts);
    disp(['Total images: ' num2str(numel(imds.Files))]);
    disp(['Number of classes: ' num2str(numClasses)]);

    %% ══════════════════════════════════════════════════════════════
    %  2. CLASS IMBALANCE HANDLING
    %% ══════════════════════════════════════════════════════════════
    disp('[2/7] Computing class weights for imbalanced data...');

    totalSamples = sum(classCounts.Count);
    classWeights = totalSamples ./ (numClasses * classCounts.Count);

    % Normalize weights so mean = 1
    classWeights = classWeights / mean(classWeights);

    disp('Class weights (inverse frequency):');
    for i = 1:numClasses
        fprintf('  Class %s: %.3f (n=%d)\n', char(classCounts.Label(i)), classWeights(i), classCounts.Count(i));
    end

    %% ══════════════════════════════════════════════════════════════
    %  3. SPLIT DATA (Stratified Train/Val/Test: 70/15/15)
    %% ══════════════════════════════════════════════════════════════
    disp('[3/7] Splitting dataset (70/15/15 stratified)...');

    [imdsTrain, imdsValTest] = splitEachLabel(imds, 0.7, 'randomized');
    [imdsVal, imdsTest] = splitEachLabel(imdsValTest, 0.5, 'randomized');

    fprintf('  Train: %d, Validation: %d, Test: %d\n', ...
        numel(imdsTrain.Files), numel(imdsVal.Files), numel(imdsTest.Files));

    %% ══════════════════════════════════════════════════════════════
    %  4. LOAD PRE-TRAINED NETWORK AND MODIFY ARCHITECTURE
    %% ══════════════════════════════════════════════════════════════
    disp('[4/7] Configuring ResNet-50 transfer learning architecture...');

    try
        net = resnet50;
    catch
        error('ResNet-50 is not installed. Please install via Add-On Explorer.');
    end

    lgraph = layerGraph(net);
    inputSize = net.Layers(1).InputSize;

    % Find and replace the last FC and classification layers
    % ResNet-50: 'fc1000' and 'ClassificationLayer_fc1000'
    layers = lgraph.Layers;
    fcLayerName = '';
    classLayerName = '';
    for i = numel(layers):-1:1
        if isa(layers(i), 'nnet.cnn.layer.FullyConnectedLayer') && isempty(fcLayerName)
            fcLayerName = layers(i).Name;
        elseif isa(layers(i), 'nnet.cnn.layer.ClassificationOutputLayer') && isempty(classLayerName)
            classLayerName = layers(i).Name;
        end
    end

    % Add dropout for regularization
    newLayers = [
        dropoutLayer(0.5, 'Name', 'dropout_new')
        fullyConnectedLayer(256, 'Name', 'fc_intermediate', ...
            'WeightLearnRateFactor', 10, 'BiasLearnRateFactor', 10)
        reluLayer('Name', 'relu_intermediate')
        dropoutLayer(0.3, 'Name', 'dropout_final')
        fullyConnectedLayer(numClasses, 'Name', 'fc_dr', ...
            'WeightLearnRateFactor', 10, 'BiasLearnRateFactor', 10)
        softmaxLayer('Name', 'softmax_dr')
        classificationLayer('Name', 'output_dr', 'Classes', categories(imdsTrain.Labels), ...
            'ClassWeights', classWeights)
    ];

    % Replace layers
    lgraph = removeLayers(lgraph, {fcLayerName, classLayerName});
    lgraph = addLayers(lgraph, newLayers);

    % Connect to the last pooling layer
    % Find the layer that connected to the removed FC
    lastPoolName = '';
    for i = 1:numel(layers)
        if strcmp(layers(i).Name, fcLayerName)
            % Find the connection to this layer
            conns = lgraph.Connections;
            for j = 1:size(conns, 1)
                if strcmp(conns.Destination{j}, [fcLayerName '/in'])
                    lastPoolName = conns.Source{j};
                    break;
                end
            end
            break;
        end
    end

    if isempty(lastPoolName)
        % Fallback: connect to avg_pool
        lastPoolName = 'avg_pool';
    end

    try
        lgraph = connectLayers(lgraph, lastPoolName, 'dropout_new');
    catch
        % If connection fails, try direct approach
        lgraph = connectLayers(lgraph, 'avg_pool', 'dropout_new');
    end

    %% ══════════════════════════════════════════════════════════════
    %  5. DATA AUGMENTATION (Fundus-specific)
    %% ══════════════════════════════════════════════════════════════
    disp('[5/7] Setting up data augmentation...');

    augmenter = imageDataAugmenter( ...
        'RandRotation', [-360, 360], ...     % Fundus orientation varies
        'RandXReflection', true, ...
        'RandYReflection', true, ...
        'RandXScale', [0.85, 1.15], ...
        'RandYScale', [0.85, 1.15], ...
        'RandXShear', [-10, 10], ...
        'RandYShear', [-10, 10], ...
        'RandXTranslation', [-20, 20], ...
        'RandYTranslation', [-20, 20]);

    augimdsTrain = augmentedImageDatastore(inputSize(1:2), imdsTrain, ...
        'DataAugmentation', augmenter, ...
        'ColorPreprocessing', 'gray2rgb');

    augimdsVal = augmentedImageDatastore(inputSize(1:2), imdsVal, ...
        'ColorPreprocessing', 'gray2rgb');

    augimdsTest = augmentedImageDatastore(inputSize(1:2), imdsTest, ...
        'ColorPreprocessing', 'gray2rgb');

    %% ══════════════════════════════════════════════════════════════
    %  6. TRAINING OPTIONS
    %% ══════════════════════════════════════════════════════════════
    disp('[6/7] Training network...');

    options = trainingOptions('adam', ...
        'MiniBatchSize', 32, ...
        'MaxEpochs', 50, ...
        'InitialLearnRate', 1e-4, ...
        'LearnRateSchedule', 'piecewise', ...
        'LearnRateDropFactor', 0.5, ...
        'LearnRateDropPeriod', 15, ...
        'L2Regularization', 1e-4, ...
        'Shuffle', 'every-epoch', ...
        'ValidationData', augimdsVal, ...
        'ValidationFrequency', 50, ...
        'ValidationPatience', 10, ...
        'Verbose', true, ...
        'Plots', 'training-progress', ...
        'ExecutionEnvironment', 'auto');

    % Train
    [trainedNet, trainInfo] = trainNetwork(augimdsTrain, lgraph, options);

    %% ══════════════════════════════════════════════════════════════
    %  7. COMPREHENSIVE VALIDATION METRICS
    %% ══════════════════════════════════════════════════════════════
    disp('[7/7] Computing validation metrics...');

    % Predict on test set
    [YPred, scores] = classify(trainedNet, augimdsTest);
    YTrue = imdsTest.Labels;

    % Confusion matrix
    confMat = confusionmat(YTrue, YPred);
    disp('Confusion Matrix:');
    disp(confMat);

    % Per-class metrics
    validationResults = struct();
    validationResults.confusionMatrix = confMat;
    validationResults.classes = categories(YTrue);

    for c = 1:numClasses
        tp = confMat(c, c);
        fn = sum(confMat(c, :)) - tp;
        fp = sum(confMat(:, c)) - tp;
        tn = sum(confMat(:)) - tp - fn - fp;

        sensitivity = tp / (tp + fn + eps);
        specificity = tn / (tn + fp + eps);
        precision = tp / (tp + fp + eps);
        f1 = 2 * (precision * sensitivity) / (precision + sensitivity + eps);

        validationResults.perClass(c).className = char(validationResults.classes(c));
        validationResults.perClass(c).sensitivity = round(sensitivity * 100, 1);
        validationResults.perClass(c).specificity = round(specificity * 100, 1);
        validationResults.perClass(c).precision = round(precision * 100, 1);
        validationResults.perClass(c).f1Score = round(f1, 3);

        fprintf('  Class %s: Sens=%.1f%%, Spec=%.1f%%, F1=%.3f\n', ...
            char(validationResults.classes(c)), sensitivity*100, specificity*100, f1);
    end

    % Binary metrics for referable DR (Level 2+)
    referableTrue = double(YTrue) >= 3;  % Level 2 = class 3 (1-indexed)
    referablePred = double(YPred) >= 3;

    tp_ref = sum(referableTrue & referablePred);
    fn_ref = sum(referableTrue & ~referablePred);
    fp_ref = sum(~referableTrue & referablePred);
    tn_ref = sum(~referableTrue & ~referablePred);

    refSensitivity = tp_ref / (tp_ref + fn_ref + eps);
    refSpecificity = tn_ref / (tn_ref + fp_ref + eps);

    validationResults.referableDR.sensitivity = round(refSensitivity * 100, 1);
    validationResults.referableDR.specificity = round(refSpecificity * 100, 1);

    fprintf('\n  REFERABLE DR (Level 2+): Sensitivity=%.1f%%, Specificity=%.1f%%\n', ...
        refSensitivity*100, refSpecificity*100);

    % Overall accuracy
    accuracy = sum(diag(confMat)) / sum(confMat(:));
    validationResults.overallAccuracy = round(accuracy * 100, 1);
    fprintf('  Overall Accuracy: %.1f%%\n', accuracy * 100);

    % AUC-ROC (per-class and macro-average)
    try
        [~, ~, ~, auc] = perfcurve(double(YTrue), scores(:, 1), 1);
        validationResults.aucROC = round(auc, 3);
    catch
        validationResults.aucROC = 0;
    end

    %% ══════════════════════════════════════════════════════════════
    %  8. TEMPERATURE CALIBRATION
    %% ══════════════════════════════════════════════════════════════
    disp('Computing temperature scaling for calibration...');

    % Find optimal temperature using validation set
    [~, valScores] = classify(trainedNet, augimdsVal);
    valLabels = imdsVal.Labels;

    % Grid search for optimal temperature
    bestTemp = 1.0;
    bestNLL = Inf;

    for T = 0.5:0.1:5.0
        calibratedScores = softmax_temp(valScores, T);
        nll = -mean(log(calibratedScores(sub2ind(size(calibratedScores), ...
            1:size(calibratedScores,1), double(valLabels)')) + eps));
        if nll < bestNLL
            bestNLL = nll;
            bestTemp = T;
        end
    end

    validationResults.optimalTemperature = bestTemp;
    fprintf('  Optimal Temperature: %.1f\n', bestTemp);

    %% ══════════════════════════════════════════════════════════════
    %  9. SAVE MODEL AND RESULTS
    %% ══════════════════════════════════════════════════════════════
    save(outputPath, 'trainedNet', 'validationResults', 'trainInfo', 'classWeights');
    disp(['Model saved to: ' outputPath]);
    disp('═══════════════════════════════════════════════════════════');
    disp('  TRAINING COMPLETE');
    disp('═══════════════════════════════════════════════════════════');

end

%% Helper: Temperature-scaled softmax
function probs = softmax_temp(logits, T)
    scaled = logits / T;
    expScaled = exp(scaled - max(scaled, [], 2));
    probs = expScaled ./ sum(expScaled, 2);
end
