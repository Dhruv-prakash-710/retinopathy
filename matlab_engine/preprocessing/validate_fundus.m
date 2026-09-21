function [isValid, reason] = validate_fundus(img)
% VALIDATE_FUNDUS Fast heuristic to check if the input image is a retinal fundus scan.
%   [isValid, reason] = validate_fundus(img) checks structural (circular FOV)
%   and chromatic (red-dominant) properties to reject non-eye images early.

    isValid = true;
    reason = '';
    
    [rows, cols, channels] = size(img);
    totalArea = rows * cols;
    
    % Convert to double for calculations
    imgD = im2double(img);
    
    %% 1. STRUCTURAL CHECK: Circular Field of View
    % Fundus images are typically circular masks on a dark background.
    % General photos (dogs, cars, landscapes) will fill the entire rectangular frame.
    
    if channels == 3
        grayImg = rgb2gray(imgD);
    else
        grayImg = imgD;
    end
    
    % Threshold to find non-background area
    bw = grayImg > 0.05;
    bw = imfill(bw, 'holes');
    
    % Find the largest connected component
    cc = bwconncomp(bw);
    if cc.NumObjects == 0
        isValid = false;
        reason = 'Image is completely dark or blank.';
        return;
    end
    
    numPixels = cellfun(@numel, cc.PixelIdxList);
    [maxArea, ~] = max(numPixels);
    
    % Ratio of the largest object to the total image area
    fillRatio = maxArea / totalArea;
    
    % If the non-black area occupies > 98% of the image, it's likely a standard rectangular photo,
    % not a fundus image (which typically has black borders/corners).
    % Note: Some ultra-widefield or cropped images might be rectangular. 
    % We will allow it if the chromatic check passes strongly, but flag it for now.
    isRectangularPhoto = fillRatio > 0.98;
    
    %% 2. CHROMATIC CHECK: Red Dominance (for RGB images)
    if channels == 3
        meanR = mean2(imgD(:,:,1));
        meanG = mean2(imgD(:,:,2));
        meanB = mean2(imgD(:,:,3));
        
        % Fundus images are heavily red-dominant, with very little blue.
        % Typical healthy fundus: R is high, G is medium, B is very low.
        isRedDominant = (meanR > meanG) && (meanR > meanB * 1.5);
        
        % Check for grayscale images saved as RGB (R=G=B)
        isGrayscale = abs(meanR - meanG) < 0.01 && abs(meanG - meanB) < 0.01;
        
        if isRectangularPhoto && ~isRedDominant && ~isGrayscale
            isValid = false;
            reason = 'Does not match structural or chromatic properties of a retinal scan (detected as a standard color photograph).';
            return;
        end
        
        if meanB > meanR
            isValid = false;
            reason = 'Atypical color profile (blue-dominant). Not a standard fundus image.';
            return;
        end
    else
        % For truly grayscale images, we rely only on the structural check
        if isRectangularPhoto
             % Very likely just a normal B&W photo, but we can be lenient or strict.
             % We will be strict to prevent random objects.
             isValid = false;
             reason = 'Does not match the circular structural properties of a retinal scan.';
             return;
        end
    end
    
    %% 3. ADDITIONAL EDGE ARTIFACT CHECK
    % Check corners: if all 4 corners are bright, it's definitively rectangular
    % Fundus images should be dark in the corners.
    cornerSize = round(min(rows, cols) * 0.05);
    if cornerSize > 0
        tl = mean2(grayImg(1:cornerSize, 1:cornerSize));
        tr = mean2(grayImg(1:cornerSize, end-cornerSize+1:end));
        bl = mean2(grayImg(end-cornerSize+1:end, 1:cornerSize));
        br = mean2(grayImg(end-cornerSize+1:end, end-cornerSize+1:end));
        
        if (tl > 0.2 && tr > 0.2 && bl > 0.2 && br > 0.2) && isRectangularPhoto
            isValid = false;
            reason = 'Rectangular framing with no dark boundaries detected. Not a fundus image.';
            return;
        end
    end

end
