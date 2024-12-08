function HippUnfoldMatlabHack(File,Left,Right)
cii=ciftiopen(File,'wb_command');
cii.diminfo{1,1}.models{1,1}.struct=Left;
cii.diminfo{1,1}.models{1,2}.struct=Right;
ciftisave(cii,File,'wb_command');
end

