function brain_masks(StudyFolder, GroupAverageName, Resolution, MaskSavePath, ConfigFilePath, Dilate)
%Generate cifti masks for spatial tICA features. There are two categories of masks, 1. specific brain region masks, including CSF, WM, GM and
%subcortical area, 2. brain boundary masks
%   Detailed explanation goes here
switch nargin
  case 0
    error('Must feed arguments!!!') 
  case 1
    error('Must specify group-average name!!!') 
  case 2
    error('Must specify resolution!!!') 
  case 3
    MaskSavePath = [];
    ConfigFilePath = [];
    Dilate=[];
  case 4
    ConfigFilePath = [];
    Dilate=[];
  case 5
    Dilate=[];
    case 6
  otherwise
    error('<=6 inputs are accepted.')
end

if isempty(ConfigFilePath)
  ConfigFilePath = '/media/2TBB/Connectome_Project/Pipelines/global/config';
end
if isempty(MaskSavePath)
  MaskSavePath = [StudyFolder '/' GroupAverageName '/MNINonLinear/ROIs'];
end
if isempty(Dilate)
  Dilate = '5.0';
end

resolution=str2double(Resolution);
erode_mm=cell(1,5);
for i=1:5
    erode_mm{i}=num2str(resolution*i);
end
% if strcmp(Resolution, '2')
%     erode_mm = {'2', '4', '6', '8', '10'};
% elseif strcmp(Resolution, '1.60')
%     erode_mm = {'1.60', '3.20', '4.80', '6.40', '8'};
% else
%     error('Please specify resolution as 2 or 1.60')
% end

EssentialFileNames={[MaskSavePath '/' GroupAverageName '_AverageWM_Mask.' Resolution '.dscalar.nii'], ...
                    [MaskSavePath '/' GroupAverageName '_AverageGM_Mask.' Resolution '.dscalar.nii'], ...
                    [MaskSavePath '/' GroupAverageName '_AverageCSF_Mask.' Resolution '.dscalar.nii'], ...
                    [MaskSavePath '/' GroupAverageName '_AverageSubcortical_Mask.' Resolution '.dscalar.nii'], ...
                    [MaskSavePath '/' GroupAverageName '_AverageRightCerebellar_Mask.' Resolution '.dscalar.nii'], ...
                    [MaskSavePath '/' GroupAverageName '_AverageLeftCerebellar_Mask.' Resolution '.dscalar.nii'], ...
                    [MaskSavePath '/' GroupAverageName '_AverageLeftGM_NoCerebellar_Mask.' Resolution '.dscalar.nii'], ...
                    [MaskSavePath '/' GroupAverageName '_AverageRightGM_NoCerebellar_Mask.' Resolution '.dscalar.nii'], ...
                    [MaskSavePath '/' GroupAverageName '_brainboundary_' erode_mm{1} 'mm.' Resolution '.dscalar.nii'], ...
                    [MaskSavePath '/' GroupAverageName '_brainboundary_' erode_mm{2} 'mm.' Resolution '.dscalar.nii'], ...
                    [MaskSavePath '/' GroupAverageName '_brainboundary_' erode_mm{3} 'mm.' Resolution '.dscalar.nii'], ...
                    [MaskSavePath '/' GroupAverageName '_brainboundary_' erode_mm{4} 'mm.' Resolution '.dscalar.nii'], ...
                    [MaskSavePath '/' GroupAverageName '_brainboundary_' erode_mm{5} 'mm.' Resolution '.dscalar.nii']};

% check if mask files are already there
ToRun=0;
for i=1:length(EssentialFileNames)
    if ~isfile(EssentialFileNames{i})
        ToRun=1;
    end
end

% only generate mask files when there's missing file
if ToRun==1
    MNIPath=[StudyFolder '/' GroupAverageName '/MNINonLinear'];

    if ~exist(MaskSavePath, 'dir')
        mkdir(MaskSavePath);
    end

    % specific brain region masks
    unix(['wb_command -volume-label-import ' MNIPath '/' GroupAverageName '_Averagewmparc.nii.gz ' ConfigFilePath '/FreeSurferAllLut.txt ' MaskSavePath '/' GroupAverageName '_Averagewmparc_for_mask.nii.gz -drop-unused-labels']);
    % transform into nifti volume space
    unix(['wb_command -volume-resample ' MaskSavePath '/' GroupAverageName '_Averagewmparc_for_mask.nii.gz ' MNIPath '/brainmask_fs_max.' Resolution '.nii.gz ENCLOSING_VOXEL ' MaskSavePath '/' GroupAverageName '_Averagewmparc.' Resolution '.nii.gz']);

    unix(['wb_command -volume-label-import ' MaskSavePath '/' GroupAverageName '_Averagewmparc.' Resolution '.nii.gz ' ConfigFilePath '/FreeSurferCSFRegLut.txt ' MaskSavePath '/' GroupAverageName '_AverageCSF.' Resolution '.nii.gz -discard-others -drop-unused-labels']);
    unix(['wb_command -volume-label-import ' MaskSavePath '/' GroupAverageName '_Averagewmparc.' Resolution '.nii.gz ' ConfigFilePath '/FreeSurferWMRegLut.txt ' MaskSavePath '/' GroupAverageName '_AverageWM.' Resolution '.nii.gz -discard-others -drop-unused-labels']);
    unix(['wb_command -volume-label-import ' MaskSavePath '/' GroupAverageName '_Averagewmparc.' Resolution '.nii.gz ' ConfigFilePath '/FreeSurferAllGM.txt ' MaskSavePath '/' GroupAverageName '_AverageGM.' Resolution '.nii.gz -discard-others -drop-unused-labels']);
    unix(['wb_command -volume-label-import ' MaskSavePath '/' GroupAverageName '_Averagewmparc.' Resolution '.nii.gz ' ConfigFilePath '/FreeSurferSubcorticalLabelTableLut.txt ' MaskSavePath '/' GroupAverageName '_AverageSubcortical.' Resolution '.nii.gz -discard-others -drop-unused-labels']);	
    
    unix(['wb_command -volume-label-import ' MaskSavePath '/' GroupAverageName '_Averagewmparc.' Resolution '.nii.gz ' ConfigFilePath '/FreeSurferCerebellarLabelTableLut.txt ' MaskSavePath '/' GroupAverageName '_AverageCerebellar.' Resolution '.nii.gz -discard-others -drop-unused-labels']);
    unix(['wb_command -volume-label-import ' MaskSavePath '/' GroupAverageName '_Averagewmparc.' Resolution '.nii.gz ' ConfigFilePath '/LeftSubcorticalFreeSurferTrajectoryLabelTableLut.txt ' MaskSavePath '/' GroupAverageName '_AverageLeftSubcortical.' Resolution '.nii.gz -discard-others -drop-unused-labels']);
    unix(['wb_command -volume-label-import ' MaskSavePath '/' GroupAverageName '_Averagewmparc.' Resolution '.nii.gz ' ConfigFilePath '/RightSubcorticalFreeSurferTrajectoryLabelTableLut.txt ' MaskSavePath '/' GroupAverageName '_AverageRightSubcortical.' Resolution '.nii.gz -discard-others -drop-unused-labels']);	
    unix(['wb_command -volume-label-import ' MaskSavePath '/' GroupAverageName '_Averagewmparc.' Resolution '.nii.gz ' ConfigFilePath '/FreeSurferAllGMWMLeft.txt ' MaskSavePath '/' GroupAverageName '_AverageLeftGMWM.' Resolution '.nii.gz -discard-others -drop-unused-labels']);	
    unix(['wb_command -volume-label-import ' MaskSavePath '/' GroupAverageName '_Averagewmparc.' Resolution '.nii.gz ' ConfigFilePath '/FreeSurferAllGMWMRight.txt ' MaskSavePath '/' GroupAverageName '_AverageRightGMWM.' Resolution '.nii.gz -discard-others -drop-unused-labels']);	

    % avoid mask		
    unix(['wb_command -volume-math ''wm > 0'' ' MaskSavePath '/' GroupAverageName '_AverageWM_AvoidMask.' Resolution '.nii.gz -var wm ' MaskSavePath '/' GroupAverageName '_AverageWM.' Resolution '.nii.gz']);
    unix(['wb_command -volume-math ''csf > 0'' ' MaskSavePath '/' GroupAverageName '_AverageCSF_AvoidMask.' Resolution '.nii.gz -var csf ' MaskSavePath '/' GroupAverageName '_AverageCSF.' Resolution '.nii.gz']);
    unix(['wb_command -volume-math ''gm > 0'' ' MaskSavePath '/' GroupAverageName '_AverageGM_AvoidMask.' Resolution '.nii.gz -var gm ' MaskSavePath '/' GroupAverageName '_AverageGM.' Resolution '.nii.gz']);

    % dilate
    unix(['wb_command -volume-dilate ' MaskSavePath '/' GroupAverageName '_AverageWM_AvoidMask.' Resolution '.nii.gz ' Dilate ' NEAREST ' MaskSavePath '/' GroupAverageName '_AverageWM_AvoidMask.' Resolution '.nii.gz']);
    unix(['wb_command -volume-dilate ' MaskSavePath '/' GroupAverageName '_AverageCSF_AvoidMask.' Resolution '.nii.gz ' Dilate ' NEAREST ' MaskSavePath '/' GroupAverageName '_AverageCSF_AvoidMask.' Resolution '.nii.gz']);
    unix(['wb_command -volume-dilate ' MaskSavePath '/' GroupAverageName '_AverageGM_AvoidMask.' Resolution '.nii.gz ' Dilate ' NEAREST ' MaskSavePath '/' GroupAverageName '_AverageGM_AvoidMask.' Resolution '.nii.gz']);

    % nifti mask files
    %unix(['wb_command -volume-math ''(wm > 0) && (! gmavoid)'' ' MaskSavePath '/' GroupAverageName '_AverageWM_Mask.' Resolution '.nii.gz -var wm ' MaskSavePath '/' GroupAverageName '_AverageWM.' Resolution '.nii.gz -var gmavoid ' MaskSavePath '/' GroupAverageName '_AverageGM_AvoidMask.' Resolution '.nii.gz']);
    unix(['wb_command -volume-math ''(wm > 0)'' ' MaskSavePath '/' GroupAverageName '_AverageWM_Mask.' Resolution '.nii.gz -var wm ' MaskSavePath '/' GroupAverageName '_AverageWM.' Resolution '.nii.gz']);

    %unix(['wb_command -volume-math ''(csf > 0) && (! gmavoid)'' ' MaskSavePath '/' GroupAverageName '_AverageCSF_Mask.' Resolution '.nii.gz -var csf ' MaskSavePath '/' GroupAverageName '_AverageCSF.' Resolution '.nii.gz -var gmavoid ' MaskSavePath '/' GroupAverageName '_AverageGM_AvoidMask.' Resolution '.nii.gz']);
    unix(['wb_command -volume-math ''(csf > 0)'' ' MaskSavePath '/' GroupAverageName '_AverageCSF_Mask.' Resolution '.nii.gz -var csf ' MaskSavePath '/' GroupAverageName '_AverageCSF.' Resolution '.nii.gz']);

    %unix(['wb_command -volume-math ''(gm > 0) && (! wmavoid)'' ' MaskSavePath '/' GroupAverageName '_AverageGM_Mask.' Resolution '.nii.gz -var gm ' MaskSavePath '/' GroupAverageName '_AverageGM.' Resolution '.nii.gz -var wmavoid ' MaskSavePath '/' GroupAverageName '_AverageWM_AvoidMask.' Resolution '.nii.gz']);
    %unix(['wb_command -volume-math ''(gm > 0) && (! csfavoid)'' ' MaskSavePath '/' GroupAverageName '_AverageGM_Mask.' Resolution '.nii.gz -var gm ' MaskSavePath '/' GroupAverageName '_AverageGM_Mask.' Resolution '.nii.gz -var csfavoid ' MaskSavePath '/' GroupAverageName '_AverageCSF_AvoidMask.' Resolution '.nii.gz']);
    unix(['wb_command -volume-math ''(gm > 0)'' ' MaskSavePath '/' GroupAverageName '_AverageGM_Mask.' Resolution '.nii.gz -var gm ' MaskSavePath '/' GroupAverageName '_AverageGM.' Resolution '.nii.gz']);

    unix(['wb_command -volume-math ''(subcortical > 0)'' ' MaskSavePath '/' GroupAverageName '_AverageSubcortical_Mask.' Resolution '.nii.gz -var subcortical ' MaskSavePath '/' GroupAverageName '_AverageSubcortical.' Resolution '.nii.gz']);
    
    unix(['wb_command -volume-math ''(cerebellar > 0)'' ' MaskSavePath '/' GroupAverageName '_AverageCerebellar_Mask.' Resolution '.nii.gz -var cerebellar ' MaskSavePath '/' GroupAverageName '_AverageCerebellar.' Resolution '.nii.gz']);

    unix(['wb_command -volume-math ''(leftgmwm > 0)'' ' MaskSavePath '/' GroupAverageName '_AverageLeftGMWM_Mask.' Resolution '.nii.gz -var leftgmwm ' MaskSavePath '/' GroupAverageName '_AverageLeftGMWM.' Resolution '.nii.gz']);
    unix(['wb_command -volume-math ''(rightgmwm > 0)'' ' MaskSavePath '/' GroupAverageName '_AverageRightGMWM_Mask.' Resolution '.nii.gz -var rightgmwm ' MaskSavePath '/' GroupAverageName '_AverageRightGMWM.' Resolution '.nii.gz']);
    unix(['wb_command -volume-math ''((leftgmwm > 0) && (! cerebellar)) && (gm > 0)'' ' MaskSavePath '/' GroupAverageName '_AverageLeftGM_NoCerebellar_Mask.' Resolution '.nii.gz -var leftgmwm ' MaskSavePath '/' GroupAverageName '_AverageLeftGMWM_Mask.' Resolution '.nii.gz -var cerebellar ' MaskSavePath '/' GroupAverageName '_AverageCerebellar_Mask.' Resolution '.nii.gz -var gm ' MaskSavePath '/' GroupAverageName '_AverageGM_Mask.' Resolution '.nii.gz']);
    unix(['wb_command -volume-math ''((rightgmwm > 0) && (! cerebellar)) && (gm > 0)'' ' MaskSavePath '/' GroupAverageName '_AverageRightGM_NoCerebellar_Mask.' Resolution '.nii.gz -var rightgmwm ' MaskSavePath '/' GroupAverageName '_AverageRightGMWM_Mask.' Resolution '.nii.gz -var cerebellar ' MaskSavePath '/' GroupAverageName '_AverageCerebellar_Mask.' Resolution '.nii.gz -var gm ' MaskSavePath '/' GroupAverageName '_AverageGM_Mask.' Resolution '.nii.gz']);
    unix(['wb_command -volume-math ''(cerebellar > 0) && (! rightgmwm)'' ' MaskSavePath '/' GroupAverageName '_AverageLeftCerebellar_Mask.' Resolution '.nii.gz -var rightgmwm ' MaskSavePath '/' GroupAverageName '_AverageRightGMWM_Mask.' Resolution '.nii.gz -var cerebellar ' MaskSavePath '/' GroupAverageName '_AverageCerebellar_Mask.' Resolution '.nii.gz']);
    unix(['wb_command -volume-math ''(cerebellar > 0) && (! leftgmwm)'' ' MaskSavePath '/' GroupAverageName '_AverageRightCerebellar_Mask.' Resolution '.nii.gz -var leftgmwm ' MaskSavePath '/' GroupAverageName '_AverageLeftGMWM_Mask.' Resolution '.nii.gz -var cerebellar ' MaskSavePath '/' GroupAverageName '_AverageCerebellar_Mask.' Resolution '.nii.gz']);

    % dense from template
    unix(['wb_command -cifti-create-dense-from-template ' MNIPath '/' GroupAverageName '_CIFTIVolumeTemplate.' Resolution '.dscalar.nii ' MaskSavePath '/' GroupAverageName '_AverageWM_Mask.' Resolution '.dscalar.nii -volume-all ' MaskSavePath '/' GroupAverageName '_AverageWM_Mask.' Resolution '.nii.gz']);
    unix(['wb_command -cifti-create-dense-from-template ' MNIPath '/' GroupAverageName '_CIFTIVolumeTemplate.' Resolution '.dscalar.nii ' MaskSavePath '/' GroupAverageName '_AverageCSF_Mask.' Resolution '.dscalar.nii -volume-all ' MaskSavePath '/' GroupAverageName '_AverageCSF_Mask.' Resolution '.nii.gz']);
    unix(['wb_command -cifti-create-dense-from-template ' MNIPath '/' GroupAverageName '_CIFTIVolumeTemplate.' Resolution '.dscalar.nii ' MaskSavePath '/' GroupAverageName '_AverageGM_Mask.' Resolution '.dscalar.nii -volume-all ' MaskSavePath '/' GroupAverageName '_AverageGM_Mask.' Resolution '.nii.gz']);
    unix(['wb_command -cifti-create-dense-from-template ' MNIPath '/' GroupAverageName '_CIFTIVolumeTemplate.' Resolution '.dscalar.nii ' MaskSavePath '/' GroupAverageName '_AverageSubcortical_Mask.' Resolution '.dscalar.nii -volume-all ' MaskSavePath '/' GroupAverageName '_AverageSubcortical_Mask.' Resolution '.nii.gz']);

    unix(['wb_command -cifti-create-dense-from-template ' MNIPath '/' GroupAverageName '_CIFTIVolumeTemplate.' Resolution '.dscalar.nii ' MaskSavePath '/' GroupAverageName '_AverageRightCerebellar_Mask.' Resolution '.dscalar.nii -volume-all ' MaskSavePath '/' GroupAverageName '_AverageRightCerebellar_Mask.' Resolution '.nii.gz']);
    unix(['wb_command -cifti-create-dense-from-template ' MNIPath '/' GroupAverageName '_CIFTIVolumeTemplate.' Resolution '.dscalar.nii ' MaskSavePath '/' GroupAverageName '_AverageLeftCerebellar_Mask.' Resolution '.dscalar.nii -volume-all ' MaskSavePath '/' GroupAverageName '_AverageLeftCerebellar_Mask.' Resolution '.nii.gz']);
    unix(['wb_command -cifti-create-dense-from-template ' MNIPath '/' GroupAverageName '_CIFTIVolumeTemplate.' Resolution '.dscalar.nii ' MaskSavePath '/' GroupAverageName '_AverageLeftGM_NoCerebellar_Mask.' Resolution '.dscalar.nii -volume-all ' MaskSavePath '/' GroupAverageName '_AverageLeftGM_NoCerebellar_Mask.' Resolution '.nii.gz']);
    unix(['wb_command -cifti-create-dense-from-template ' MNIPath '/' GroupAverageName '_CIFTIVolumeTemplate.' Resolution '.dscalar.nii ' MaskSavePath '/' GroupAverageName '_AverageRightGM_NoCerebellar_Mask.' Resolution '.dscalar.nii -volume-all ' MaskSavePath '/' GroupAverageName '_AverageRightGM_NoCerebellar_Mask.' Resolution '.nii.gz']);

    % brain boundary mask
    for i=1:length(erode_mm)
        erode=erode_mm{i};
        unix(['wb_command -volume-erode ' MNIPath '/brainmask_fs_max.' Resolution '.nii.gz ' erode ' ' MaskSavePath '/' GroupAverageName '_CIFTIVolumeTemplateErode_' erode '.nii.gz']);
        unix(['wb_command -cifti-create-dense-from-template ' MNIPath '/' GroupAverageName '_CIFTIVolumeTemplate.' Resolution '.dscalar.nii ' MaskSavePath '/' GroupAverageName '_CIFTIVolumeTemplateErode_' erode '.dscalar.nii -volume-all ' MaskSavePath '/' GroupAverageName '_CIFTIVolumeTemplateErode_' erode '.nii.gz']);
        unix(['wb_command -cifti-math ''(original > 0) && (!eroded)'' ' MaskSavePath '/' GroupAverageName '_brainboundary_' erode 'mm.' Resolution '.dscalar.nii -var original ' MNIPath '/' GroupAverageName '_CIFTIVolumeTemplate.' Resolution '.dscalar.nii -var eroded ' MaskSavePath '/' GroupAverageName '_CIFTIVolumeTemplateErode_' erode '.dscalar.nii']);
        unix(['rm ' MaskSavePath '/' GroupAverageName '_CIFTIVolumeTemplateErode_' erode '.dscalar.nii ' MaskSavePath '/' GroupAverageName '_CIFTIVolumeTemplateErode_' erode '.nii.gz']);
    end
end
end
