function cleanup_read_avw_img_slice(tmpfname)
% tmpfname = CLEANUP_READ_AVW_IMG_SLICE(tmpfname)
%
%  This will delete the temporary files created by an earlier
%  call to prepare_read_avw_img_slice.
%  It is intended to be used together with read_avw_img_slice
%  routine to avoid doing the conversion once per slice.
%  The code using it would look something like
%
%  tmpfname = prepare_read_avw_img_slice(fname).
%  dims = read_avw_hdr(tmpfname);
%  for i=1:dims(3)
%    slicedata = read_avw_img_slice(tmpfname,i);
%    process the data ...
%  end
%  cleanup_read_avw_img_slice(tmpfname);
%

delete([tmpfname,'.hdr']);
delete([tmpfname,'.img']);
