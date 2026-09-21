function [enhanced_rgb, enhanced_green] = enhance_fundus(img, qualityGrade)
% ENHANCE_FUNDUS Comprehensive adaptive enhancement of fundus images.
%   Applies illumination normalization, CLAHE, bilateral filtering, and
%   color normalization. Enhancement intensity adapts based on quality grade.
%
%   [enhanced_rgb, enhanced_green] = enhance_fundus(img, qualityGrade)
%
%   Inputs:
%     img          - RGB fundus image
%     qualityGrade - (optional) 'Gradeable', 'Borderline', or 'Ungradeable'
%
%   Outputs:
%     enhanced_rgb   - Full RGB enhanced image
%     enhanced_green - Enhanced green channel (best for vessel/lesion analysis)

    if nargin < 2
        qualityGrade = 'Gradeable';
    end

    % Ensure image is RGB
    if size(img, 3) ~= 3
        error('Input must be an RGB image.');
    end

    imgDouble = im2double(img);

    % Set enhancement intensity based on quality
    switch qualityGrade
        case 'Borderline'
            claheClipLimit = 0.015;    % More aggressive
            bilateralDegree = 0.08;
            denoiseStrength = 'strong';
        case 'Ungradeable'
            claheClipLimit = 0.02;     % Maximum enhancement
            bilateralDegree = 0.1;
            denoiseStrength = 'maximum';
        otherwise  % Gradeable
            claheClipLimit = 0.01;     % Conservative
            bilateralDegree = 0.05;
            denoiseStrength = 'light';
    end

    %% ══════════════════════════════════════════════════════════════
    %  Step 1: ILLUMINATION NORMALIZATION
    %  Estimate and subtract the background illumination field
    %% ══════════════════════════════════════════════════════════════
    % Process each channel separately
    normalized = zeros(size(imgDouble));
    for ch = 1:3
        channel = imgDouble(:,:,ch);

        % Estimate background illumination using large Gaussian
        bgEstimate = imgaussfilt(channel, 50);

        % Subtract background and rescale
        corrected = channel - bgEstimate + mean(bgEstimate(:));

        % Clip to valid range
        normalized(:,:,ch) = max(min(corrected, 1), 0);
    end

    %% ══════════════════════════════════════════════════════════════
    %  Step 2: COLOR NORMALIZATION
    %  Histogram specification to standardize color distribution
    %% ══════════════════════════════════════════════════════════════
    % Normalize to a reference mean and std per channel
    % Reference values from typical good-quality fundus images
    refMeans = [0.45, 0.28, 0.15];  % R, G, B typical fundus
    refStds = [0.14, 0.10, 0.07];

    colorNorm = zeros(size(normalized));
    for ch = 1:3
        channel = normalized(:,:,ch);
        mask = channel > 0.02;  % Only normalize retinal area

        if sum(mask(:)) > 100
            chMean = mean(channel(mask));
            chStd = std(channel(mask));

            if chStd > 0.001
                adjusted = (channel - chMean) * (refStds(ch) / chStd) + refMeans(ch);
            else
                adjusted = channel;
            end
            colorNorm(:,:,ch) = max(min(adjusted, 1), 0);
        else
            colorNorm(:,:,ch) = channel;
        end
    end

    %% ══════════════════════════════════════════════════════════════
    %  Step 3: DENOISING — Edge-preserving bilateral filtering
    %% ══════════════════════════════════════════════════════════════
    switch denoiseStrength
        case 'light'
            smoothDegree = bilateralDegree * 0.5;
        case 'strong'
            smoothDegree = bilateralDegree;
        case 'maximum'
            smoothDegree = bilateralDegree * 1.5;
        otherwise
            smoothDegree = bilateralDegree;
    end

    denoised = zeros(size(colorNorm));
    for ch = 1:3
        % Use bilateral-like filtering via edge-preserving smoothing
        % imbilatfilt requires Image Processing Toolbox R2018a+
        try
            denoised(:,:,ch) = imbilatfilt(colorNorm(:,:,ch), smoothDegree);
        catch
            % Fallback: guided filter (available in more versions)
            try
                denoised(:,:,ch) = imguidedfilter(colorNorm(:,:,ch));
            catch
                % Last resort: Gaussian + median hybrid
                temp = imgaussfilt(colorNorm(:,:,ch), 0.8);
                denoised(:,:,ch) = medfilt2(temp, [3 3]);
            end
        end
    end

    %% ══════════════════════════════════════════════════════════════
    %  Step 4: CLAHE on GREEN CHANNEL
    %  Green channel has the best contrast for retinal structures
    %% ══════════════════════════════════════════════════════════════
    greenChannel = im2uint8(denoised(:,:,2));

    % Apply CLAHE with adaptive clip limit
    enhancedGreen = adapthisteq(greenChannel, ...
        'NumTiles', [8 8], ...
        'ClipLimit', claheClipLimit, ...
        'Distribution', 'rayleigh', ...
        'Alpha', 0.4);

    % Also apply CLAHE to the luminance in LAB space for full RGB
    labImg = rgb2lab(denoised);
    L = labImg(:,:,1) / 100;  % Normalize L to [0,1]
    L_uint8 = im2uint8(L);
    L_enhanced = adapthisteq(L_uint8, ...
        'NumTiles', [8 8], ...
        'ClipLimit', claheClipLimit * 0.8, ...
        'Distribution', 'rayleigh', ...
        'Alpha', 0.4);
    labImg(:,:,1) = im2double(L_enhanced) * 100;
    enhancedRGB = lab2rgb(labImg);
    enhancedRGB = max(min(enhancedRGB, 1), 0);

    %% ══════════════════════════════════════════════════════════════
    %  Step 5: FINAL POST-PROCESSING
    %% ══════════════════════════════════════════════════════════════
    % Mild sharpening on the green channel for lesion visibility
    sharpenKernel = [0 -0.5 0; -0.5 3 -0.5; 0 -0.5 0];
    enhancedGreenFinal = imfilter(double(enhancedGreen), sharpenKernel, 'replicate');
    enhancedGreenFinal = uint8(max(min(enhancedGreenFinal, 255), 0));

    % Apply median filter for salt-and-pepper noise cleanup
    enhancedGreenFinal = medfilt2(enhancedGreenFinal, [3 3]);

    %% ══════════════════════════════════════════════════════════════
    %  OUTPUT
    %% ══════════════════════════════════════════════════════════════
    enhanced_rgb = im2uint8(enhancedRGB);
    enhanced_green = enhancedGreenFinal;

end
