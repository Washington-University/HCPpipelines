function [ output_args ] = ciftisave(cifti,filename,caret7command)
%Save a CIFTI file as a GIFTI external binary and then convert it to CIFTI

tic
save(cifti,[filename '.gii'],'ExternalFileBinary')
toc

%unix(['/media/1TB/matlabsharedcode/ciftiunclean.sh ' filename '.gii ' filename '_.gii']);

%unix(['mv ' filename '_.gii ' filename '.gii']);

tic
unix([caret7command ' -cifti-convert -from-gifti-ext ' filename '.gii ' filename]);
toc

unix([' /bin/rm ' filename '.gii ' filename '.dat ']);

end

