% Script to compute similarity between individual PET scans and a reference tremor network map.
% Outputs: Spearman correlation and voxelwise dot product (sum of multiplications).

% -------------------- File Selection --------------------
% Select the tremor treatment network map (NIfTI)
[tremor_map_file, tremor_map_path] = uigetfile('*.nii', 'Select the tremor map');
tremor_map_pathfile = fullfile(tremor_map_path, tremor_map_file);
tremor_map_img = spm_vol(tremor_map_pathfile);

% Select PET scans (NIfTI files)
[pet_files, pet_path] = uigetfile('*.nii', 'Select PET scans', 'MultiSelect', 'on');
if ischar(pet_files)
    pet_files = {pet_files};  % Convert to cell array if only one file selected
end

% Initialize results table
similarity_table = cell(length(pet_files), 3);

% ---------------------------------------
for i = 1:length(pet_files)
    pet_file = fullfile(pet_path, pet_files{i});
    pet_img = spm_vol(pet_file);
    pet_data = spm_read_vols(pet_img);

    % Check for dimension mismatch
    if isequal(tremor_map_img.dim, pet_img.dim)
        resliced_data = spm_read_vols(tremor_map_img);
    else
        % Reslice tremor map into PET image space if necessary
        warning('Dimension mismatch detected with %s. Reslicing tremor map.', pet_files{i});
        flags = struct('interp', 4, 'mask', false, 'mean', false, ...
                       'which', 1, 'wrap', [0 0 0], 'prefix', 'r_');
        spm_reslice({pet_file, tremor_map_pathfile}, flags);

        % Load resliced tremor map
        resliced_file = fullfile(tremor_map_path, ['r_', tremor_map_file]);
        if ~isfile(resliced_file)
            warning('Reslicing failed for %s. Skipping.', pet_files{i});
            similarity_table(i, :) = {pet_files{i}, NaN, NaN};
            continue;
        end
        resliced_data = spm_read_vols(spm_vol(resliced_file));
    end

    % Flatten and mask valid voxels
    map_vector = resliced_data(:);
    pet_vector = pet_data(:);
    valid_voxels = ~isnan(map_vector) & ~isnan(pet_vector) & map_vector ~= 0;

    % Compute similarity metrics
    similarity_table{i, 1} = pet_files{i};
    similarity_table{i, 2} = corr(map_vector(valid_voxels), pet_vector(valid_voxels), 'Type', 'Spearman');
    similarity_table{i, 3} = sum(map_vector(valid_voxels) .* pet_vector(valid_voxels));

    disp(['Processed: ', pet_files{i}]);
end

% -------------------- Save Results --------------------
similarity_results = cell2table(similarity_table, ...
    'VariableNames', {'Patient', 'SpearmanCorrelation', 'Voxelwise_Mult_Sum'});

output_file = fullfile(pet_path, 'ET_diffPET_FDGchange_Similarity.xlsx');
writetable(similarity_results, output_file, 'FileType', 'spreadsheet');

% Clean up resliced file
resliced_file = fullfile(tremor_map_path, ['r_', tremor_map_file]);
if isfile(resliced_file)
    delete(resliced_file);
end

disp(['Results saved to: ', output_file]);
