function mixtureModel(inFile,outFile,wbcmd,melocmd)
% mixtureModel(inFile,outFile,wbcmd,melocmd)
% Performs Gaussian mixture modeling on precomputed ICs
% Wrapper arround melodic.Accepts nifti or cifti inputs. 
% Require Input:
%   inFile  : file path to IC z-scores, file path including extension as string (accepts nifti or cifti files)
% Optional Inputs
%   outFile :  file path to IC z-scores with Gaussian mixture modeling, defaults to inFile 
%              (can output nifti, nifit-gz, or cifti, depending on extension: .nii, .nii,gz, .dtseries.nii)
%   wbcmd   : worbench command, defaults to 'wb_command' 
%   melocmd : melodic command, defaults to 'melodic'
%
% See also: 
% https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=fsl;6e85d498.1607
% https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/MELODIC#Using_melodic_for_just_doing_mixture-modelling
% https://www.fmrib.ox.ac.uk/datasets/techrep/tr02cb1/tr02cb1.pdf

% Created by Burke Rosen
% 2024-07-08
%
% ToDo: 
% Feed arbitrary melodic arguments. 

%% handle inputs 
if nargin < 2 || isempty(outFile); outFile = inFile; end 
if nargin < 3 || isempty(wbcmd); wbcmd = 'wb_command'; end 
if nargin < 4 || isempty(melocmd); melocmd = 'melodic'; end 
[wbStat,~] = unix(wbcmd);
[meloStat,~] = unix(['which ' melocmd]);
if wbStat; error('workbench_command binary %s not on path',wbcmd);end
if meloStat; error('melodic command binary %s not on path',melocmd);end
inFile0 = inFile;
outFile0 = outFile;
tDir = tempname;
FSLOUTPUTTYPE0 = getenv('FSLOUTPUTTYPE');
if endsWith(inFile0,'dtseries.nii')
  % convert to input cifti to nifti
  inFile = strrep(inFile0,'dtseries.nii','');
[~,~] = unix(sprintf('wb_command -cifti-convert -to nifti %s %s',inFile0,inFile));
elseif endsWith(inFile0,'.nii') 
  inFile = strrep(inFile0,'.nii','');
elseif endsWith(inFile0,'.nii.gz') 
  inFile = strrep(inFile0,'.nii.gz','');
else
  error('inFile is not a nifti or dtseries cifti?')
end
if endsWith(outFile0,'dtseries.nii')
  if ~endsWith(inFile0,'dtseries.nii')
    error('cifti output only supported for cifti input.')
  end
  outFile = strrep(outFile0,'dtseries.nii','');
  FSLOUTPUTTYPE = 'NIFTI2_GZ';
elseif endsWith(outFile0,'.nii') 
  outFile = strrep(outFile0,'.nii','');
  FSLOUTPUTTYPE = 'NIFTI2';
elseif endsWith(outFile0,'.nii.gz') 
  FSLOUTPUTTYPE = 'NIFTI2_GZ';
  outFile = strrep(outFile0,'.nii.gz','');
else
  error('outFile is not a nifti or dtseries cifti?')
end

%% run gaussian mixture modeling with melodic
[~,~] = unix(sprintf('mkdir -p %s;echo "1" > %s/grot', tDir, tDir));
[~,~] = unix(sprintf(...
  'melodic -i %s --ICs=%s --mix=%s/grot -o %s --Oall --report -v --mmthresh=0',... 
  inFile, inFile, tDir, tDir));
[~,~] = unix(sprintf(...
  'FSLOUTPUTTYPE=%s;fslmerge -t %s $(ls %s/stats/thresh_zstat* | sort -V);FSLOUTPUTTYPE=%s;',...
  FSLOUTPUTTYPE, outFile, tDir ,FSLOUTPUTTYPE0));
[~,~] = unix(['rm -r ' tDir]);% clean up temporary files

%% convert output to cifti, if called for
if endsWith(outFile0,'dtseries.nii')
  [~,~] = unix(sprintf('wb_command -cifti-convert -from-nifti %s.nii.gz %s %s',outFile,inFile0,outFile0));
  delete([outFile '.nii.gz']);
end

end % EOF
