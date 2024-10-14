function mixtureModel(inFile,outFile,wbcmd,melocmd)
% mixtureModel(inFile,outFile,wbcmd,melocmd)
% Performs Gaussian mixture modeling on precomputed ICs
% Wrapper arround melodic.Accepts nifti or cifti inputs. 
% Require Input:
%   inFile  : file path to IC z-scores, file path including extension as string (accepts nifti or cifti files)
%   outFile : file path to IC z-scores with Gaussian mixture modeling
%              Can output nifti, nifit-gz, or cifti, depending on extension: .nii, .nii.gz, .dscalar.nii,
%              Output format does not have to match input format, unless output is cifti.
% Optional Inputs
%   wbcmd   : worbench command, defaults to 'wb_command' 
%   melocmd : melodic command, defaults to 'melodic'
%
% See also: 
% https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=fsl;6e85d498.1607
% https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/MELODIC#Using_melodic_for_just_doing_mixture-modelling
% https://www.fmrib.ox.ac.uk/datasets/techrep/tr02cb1/tr02cb1.pdf

% Created by Burke Rosen
% 2024-07-08
% Dependencies:workbench, FSL
% Written with workbench 2.0 and FSL 6.0.7.1
%
% ToDo: 
% Feed arbitrary melodic arguments. 

%% handle inputs 
if nargin < 2 || isempty(inFile) || isempty(outFile)
  error('inFile and outFile arguments are required!'); 
end 
if nargin < 3 || isempty(wbcmd); wbcmd = 'wb_command'; end 
if nargin < 4 || isempty(melocmd); melocmd = 'melodic'; end 
[wbStat,~] = system(wbcmd);
[meloStat,~] = system(['which ' melocmd]);
if wbStat; error('workbench_command binary %s not on path',wbcmd);end
if meloStat; error('melodic command binary %s not on path',melocmd);end
inFile0 = inFile;
outFile0 = outFile;
tDir = tempname;
FSLOUTPUTTYPE0 = getenv('FSLOUTPUTTYPE');
stat = zeros(9,1);
if endsWith(inFile0,'dscalar.nii')
  % convert to input cifti to nifti
  inFile = [tempname '.nii'];
  [stat(1),~] = system(sprintf('%s -cifti-convert -to-nifti %s %s -smaller-dims',wbcmd,inFile0,inFile),'-echo');
  [stat(2),out] = system(sprintf('%s -file-information %s | grep Dimensions',wbcmd,inFile),'-echo');% more elegant to use niftiinfo, but that adds dependency
  dims = str2num(out(12:end));
  if any(dims == 1) && find( dims == 1,1) < 4
    warning('singleton dimension in converted nifti, melodic may not interpret correctly!');
  end
  inFile = strrep(inFile,'.nii','');
elseif endsWith(inFile0,'.nii') 
  inFile = strrep(inFile0,'.nii','');
elseif endsWith(inFile0,'.nii.gz') 
  inFile = strrep(inFile0,'.nii.gz','');
else
  error('inFile is not a nifti or dscalar cifti?')
end
if endsWith(outFile0,'dscalar.nii')
  if ~endsWith(inFile0,'dscalar.nii')
    error('cifti output only supported for cifti input.')
  end
  outFile = strrep(outFile0,'.dscalar.nii','');
  FSLOUTPUTTYPE = 'NIFTI_GZ';
elseif endsWith(outFile0,'.nii') 
  outFile = strrep(outFile0,'.nii','');
  FSLOUTPUTTYPE = 'NIFTI';
elseif endsWith(outFile0,'.nii.gz') 
  FSLOUTPUTTYPE = 'NIFTI_GZ';
  outFile = strrep(outFile0,'.nii.gz','');
else
  error('outFile is not a nifti or dscalar cifti?')
end

%% run gaussian mixture modeling with melodic
[stat(3),~] = system(sprintf('mkdir -p %s;echo "1" > %s/grot', tDir, tDir),'-echo');
[stat(4),~] = system(sprintf(...
  '%s -i %s --ICs=%s --mix=%s/grot -o %s --Oall --report -v --mmthresh=0',... 
  melocmd,inFile, inFile, tDir, tDir),'-echo');
[stat(5),~] = system(sprintf(...
    'FSLOUTPUTTYPE=%s;fslmerge -t %s $(ls %s/stats/thresh_zstat* | sort -V);FSLOUTPUTTYPE=%s;',...
    FSLOUTPUTTYPE, outFile, tDir ,FSLOUTPUTTYPE0),'-echo');
[stat(6),~] = system(['rm -r ' tDir],'-echo');% clean up temporary files

%% convert output to cifti, if needed
if endsWith(outFile0,'dscalar.nii')
  [stat(7),~] = system(sprintf('%s -cifti-convert -from-nifti %s.nii.gz %s %s',wbcmd,outFile,inFile0,outFile0),'-echo');
  [stat(8),~] = system(sprintf('imrm %s %s',inFile,outFile),'-echo');% clean up intermediate niftis
elseif endsWith(inFile0,'dscalar.nii')
  [stat(9),~] = system(sprintf('imrm %s',inFile),'-echo');
end
if any(stat);error('system commands failed, see console output!');end
end % EOF