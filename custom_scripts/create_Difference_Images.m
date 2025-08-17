%% create_Difference_Images.m
% Create difference images from paired NIfTI files (Fixed – Subtract).
%
% Features:
% - Pairs Fixed and Subtract NIfTI files in a folder (matching by name stems).
% - Optional: apply binary mask to output.
% - Optional: center each difference image by subtracting the mean inside a mask.
% - Saves new NIfTI difference images in a chosen output folder.
%
% Dependencies: NIfTI toolbox

%% -------------------- User Warning ----------------------
disp('Ensure all images are in the same spatial coordinate system.');
disp('This function reslices the Mask to match the selected Images if necessary.');

%% -------------------- Select Input Files ----------------
% Select folder containing Fixed and Subtract images
folder_path = uigetdir(pwd, 'Select the folder containing Fixed and Subtract NIfTI files');
if folder_path == 0
    disp('No folder selected. Exiting...');
    return;
end

% Ask user for naming stems (identifiers in filenames)
stems = inputdlg({'Enter the identifier for Fixed files:', ...
                  'Enter the identifier for Subtract files:'}, ...
                  'File Identifiers', [1 50], {'Fixed', 'Subtract'});
if isempty(stems)
    disp('User canceled stem input. Exiting...');
    return;
end
[fixed_stem, subtract_stem] = deal(stems{:});

% Select output folder
output_folder = uigetdir(pwd, 'Select Output Directory for Difference Images');
if output_folder == 0
    disp('No output folder selected. Exiting...');
    return;
end

% Collect Fixed and Subtract files (ignore hidden/._ files)
all_fixed_files    = dir(fullfile(folder_path, ['*' fixed_stem '*.nii']));
fixed_files        = all_fixed_files(~startsWith({all_fixed_files.name}, '._'));
all_subtract_files = dir(fullfile(folder_path, ['*' subtract_stem '*.nii']));
subtract_files     = all_subtract_files(~startsWith({all_subtract_files.name}, '._'));

%% -------------------- Pair Matching ---------------------
pairs = containers.Map;
for i = 1:length(fixed_files)
    fixed_file = fixed_files(i).name;
    expected_subtract_file = strrep(fixed_file, fixed_stem, subtract_stem);

    if any(strcmp({subtract_files.name}, expected_subtract_file))
        pairs(fixed_file) = expected_subtract_file;
    else
        warning('No matching Subtract file found for %s. Skipping...', fixed_file);
    end
end

if isempty(keys(pairs))
    error('No matching pairs of NIfTI files found. Ensure files differ only by defined stems.');
end

%% -------------------- Mask Option -----------------------
apply_mask = strcmp(questdlg('Do you want to apply a mask to the difference images?', ...
                              'Mask Application', 'Yes', 'No', 'No'), 'Yes');
if apply_mask
    [maskFile, maskPath] = uigetfile({'*.nii;*.nii.gz', 'NIfTI files'}, 'Select the Binary Mask');
    if isequal(maskFile, 0)
        disp('User canceled mask selection. Exiting...');
        return;
    end
    mask_nii  = load_nii(fullfile(maskPath, maskFile));
    mask_data = mask_nii.img > 0; % Ensure binary
end

%% -------------------- Centering Option ------------------
center_images = strcmp(questdlg('Do you want to center the difference images? Recommended if using parametric tests afterwards.', ...
                                'Centering Option', 'Yes', 'No', 'Yes'), 'Yes');
if center_images
    [centeringMaskFile, centeringMaskPath] = uigetfile({'*.nii;*.nii.gz', 'NIfTI files'}, ...
                                                      'Select the Binary Mask for Mean Calculation');
    if isequal(centeringMaskFile, 0)
        disp('User canceled centering mask selection. Exiting...');
        return;
    end
    centering_mask_nii  = load_nii(fullfile(centeringMaskPath, centeringMaskFile));
    centering_mask_data = centering_mask_nii.img > 0;
end

%% -------------------- Process Each Pair -----------------
keys_list = keys(pairs);
for i = 1:length(keys_list)
    fixed_file    = keys_list{i};
    subtract_file = pairs(fixed_file);

    % Paths
    fixed_pathfile    = fullfile(folder_path, fixed_file);
    subtract_pathfile = fullfile(folder_path, subtract_file);

    % Load Fixed and Subtract images
    fixed_img    = load_nii(fixed_pathfile);
    subtract_img = load_nii(subtract_pathfile);

    % Compute difference (Fixed – Subtract)
    fixed_data     = fixed_img.img;
    subtract_data  = subtract_img.img;
    difference_data = fixed_data - subtract_data;

    % ---- Centering (optional)
    if center_images
        if ~isequal(size(centering_mask_data), size(difference_data))
            warning('Centering mask dimensions mismatch (%s). Reslicing...', fixed_file);
            centering_mask_resized = imresize3(centering_mask_data, size(difference_data), 'nearest');
        else
            centering_mask_resized = centering_mask_data;
        end
        mean_value      = mean(difference_data(centering_mask_resized > 0));
        difference_data = difference_data - mean_value;
        disp(['Centered difference image with mean value: ', num2str(mean_value)]);
    end

    % ---- Apply mask (optional)
    if apply_mask
        if ~isequal(size(mask_data), size(difference_data))
            warning('Mask dimensions mismatch (%s). Reslicing...', fixed_file);
            mask_resized = imresize3(mask_data, size(difference_data), 'nearest');
            mask_resized = mask_resized > 0;
        else
            mask_resized = mask_data;
        end
        difference_data(mask_resized == 0) = 0;
    end

    % ---- Save output NIfTI
    difference_img         = fixed_img; % copy metadata
    difference_img.img     = difference_data;
    [~, fixed_name, ~]     = fileparts(fixed_file);
    [~, subtract_name, ~]  = fileparts(subtract_file);
    difference_img.fileprefix = fullfile(output_folder, ...
        sprintf('%s_minus_%s_difference', fixed_name, subtract_name));
    save_nii(difference_img, [difference_img.fileprefix '.nii']);

    disp(['Processed and saved: ', fixed_name, ' minus ', subtract_name]);
end

disp('All files processed successfully.');
