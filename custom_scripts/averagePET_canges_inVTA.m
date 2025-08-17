%% extract average ROI values
% either from individual VTAs or average group stimulation areas

% Extract mean values from connectivity/PET maps using ROI masks.
% - Lets you pick one or more NIfTI images and one or more NIfTI masks.
% - Shows a GUI preview of pairings before computing.
% - Outputs an Excel file with mean values per (image, mask) pair for
% furhter statisitcs
%
% Requires: SPM

clear; clc;

%% -------------------- Select Images --------------------
[imageFiles, imagePath] = uigetfile('*.nii', 'Select Connectivity/PET Images', 'MultiSelect', 'on');
if isequal(imageFiles, 0)
    disp('No image files selected. Exiting.');
    return;
end
if ischar(imageFiles), imageFiles = {imageFiles}; end
imageFiles = fullfile(imagePath, imageFiles);

%% -------------------- Select Masks ---------------------
[maskFiles, maskPath] = uigetfile('*.nii', 'Select Mask(s)/VTAs', 'MultiSelect', 'on');
if isequal(maskFiles, 0)
    disp('No mask files selected. Exiting.');
    return;
end
if ischar(maskFiles), maskFiles = {maskFiles}; end
maskFiles = fullfile(maskPath, maskFiles);

%% ---- Handle single/global mask vs. per-image masks ----
if numel(maskFiles) == 1 && numel(imageFiles) > 1
    % Single mask applied to all images
    maskFiles = repmat(maskFiles, 1, numel(imageFiles));

elseif numel(maskFiles) ~= numel(imageFiles)
    % Offer to run all combinations if counts differ
    choice = questdlg( ...
        sprintf(['Number of masks (%d) does not match number of images (%d).\n' ...
                 'Do you want to run each mask against all images?'], ...
                 numel(maskFiles), numel(imageFiles)), ...
        'Confirm Mismatch', 'Yes','No','No');

    if ~strcmp(choice, 'Yes')
        disp('Operation cancelled by user.');
        return;
    end

    % Expand all combinations of mask × image
    [imgIdx, maskIdx] = ndgrid(1:numel(imageFiles), 1:numel(maskFiles));
    imageFiles = imageFiles(imgIdx(:));
    maskFiles  = maskFiles(maskIdx(:));
end

%% ---------------- Preview Pairings (GUI) ----------------
% Build short names (last folder + filename) for display
shortImageNames = strings(size(imageFiles));
shortMaskNames  = strings(size(maskFiles));
for i = 1:numel(imageFiles)
    [imgFolder, imgName, imgExt] = fileparts(imageFiles{i});
    [~, lastImgFolder]  = fileparts(imgFolder);
    shortImageNames(i)   = fullfile(lastImgFolder,  [imgName imgExt]);

    [maskFolder, maskName, maskExt] = fileparts(maskFiles{i});
    [~, lastMaskFolder]  = fileparts(maskFolder);
    shortMaskNames(i)    = fullfile(lastMaskFolder, [maskName maskExt]);
end
shortImageNames = cellstr(shortImageNames);
shortMaskNames  = cellstr(shortMaskNames);

% Simple table-style preview window
f = figure('Name', 'Check File Pairings', 'Position', [300 300 800 400], 'NumberTitle', 'off');

uitable(f, 'Data', [shortImageNames(:), shortMaskNames(:)], ...
    'ColumnName', {'Image File', 'Mask File'}, ...
    'ColumnWidth', {350, 350}, ...
    'Position', [25 75 750 300]);

uicontrol(f, 'Style', 'text', 'String', 'Review pairings below:', ...
    'FontSize', 12, 'Position', [25 370 300 20], 'HorizontalAlignment', 'left');

uicontrol(f, 'Style', 'pushbutton', 'String', 'Continue', ...
    'Position', [600 20 80 30], 'Callback', @(~,~) uiresume(f));

uicontrol(f, 'Style', 'pushbutton', 'String', 'Abort', ...
    'Position', [700 20 80 30], 'Callback', @(~,~) close(f));

uiwait(f);
if ~isvalid(f)
    disp('Aborted by user.');
    return;
end
close(f);

%% ---------------- Prepare Output Table ------------------
results = table('Size', [numel(imageFiles), 3], ...
    'VariableTypes', {'string', 'string', 'double'}, ...
    'VariableNames', {'ImageFile', 'MaskFile', 'MeanValue'});

%% ----------------- Compute Mean Values ------------------
for i = 1:numel(imageFiles)
    imgVol  = spm_vol(imageFiles{i});
    imgData = spm_read_vols(imgVol);

    maskVol  = spm_vol(maskFiles{i});
    maskData = spm_read_vols(maskVol) > 0;

    if ~isequal(size(imgData), size(maskData))
        error('Dimension mismatch between image and mask: %s', imageFiles{i});
    end

    maskedValues = imgData(maskData);
    meanVal = mean(maskedValues(:), 'omitnan');

    results.ImageFile(i) = string(imageFiles{i});
    results.MaskFile(i)  = string(maskFiles{i});
    results.MeanValue(i) = meanVal;
end

%% --------------------- Save Results ---------------------
[saveFile, savePath] = uiputfile('*.xlsx', 'Save Results As');
if saveFile ~= 0
    writetable(results, fullfile(savePath, saveFile));
    disp('Results saved.');
else
    disp('Save canceled.');
end
