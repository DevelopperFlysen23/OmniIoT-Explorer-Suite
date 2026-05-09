% SETUP_IOT_EXPLORER Adds project folders to the MATLAB path.
% Run this script before using IoTDataExplorer or OmniIoTAnalyst.

% Get the current folder
rootFolder = pwd;

% Add toolbox folders to the path
addpath(fullfile(rootFolder, 'OmniIoT-Analytics', 'toolbox'));
addpath(fullfile(rootFolder, 'IoT-Data-Explorer-master', 'toolbox'));

% Verify path
if exist('OmniIoTAnalyst', 'class') == 8
    fprintf('OmniIoTAnalyst is ready.\n');
else
    warning('OmniIoTAnalyst NOT found on path. Please check folder structure.');
end

if exist('IoTDataExplorer', 'file') == 2
    fprintf('IoTDataExplorer is ready.\n');
else
    warning('IoTDataExplorer NOT found on path.');
end

fprintf('Setup complete.\n');
