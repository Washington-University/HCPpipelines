function outstruct = cifti_read(filename, varargin)
    %function outstruct = cifti_read(filename, ...)
    %   Read a cifti file.
    %   If wb_command is not on your PATH and you need to read cifti-1
    %   files, include the extra arguments ", 'wbcmd', '<wb_command with full path>'".
    %
    %   >> cifti = cifti_read('91282_Greyordinates.dscalar.nii');
    %   >> cifti.cdata = outdata;
    %   >> cifti.diminfo{2} = cifti_diminfo_make_scalars(size(outdata, 2));
    %   >> cifti_write(cifti, 'ciftiout.dscalar.nii');
    options = myargparse(varargin, {'wbcmd'});
    if isempty(options.wbcmd)
        options.wbcmd = 'wb_command';
    end
    [hdr, fid, cleanupObj] = read_nifti2_hdr(filename); %#ok<ASGLU>
    if isempty(hdr.extensions)
        error(['no cifti extension found in file ' filename]);
    end
    ciftiextindex = find(hdr.extensions.ecode == 32);
    if length(ciftiextindex) ~= 1
        error(['multiple cifti extensions found in file ' filename]);
    end
    %sanity check dims
    if hdr.dim(1) < 6 || any(hdr.dim(2:5) ~= 1)
        error(['wrong nifti dimensions for cifti file ' filename]);
    end
    try
        outstruct = cifti_parse_xml(hdr.extensions(ciftiextindex).edata, filename);
    catch excinfo
        if strcmp(excinfo.identifier, 'cifti:version')
            if mod(length(varargin), 2) == 1 && strcmp(varargin{end}, 'recursed') %guard against infinite recursion
                error('internal error, cifti version conversion problem');
            end
            warning(['cifti file "' filename '" appears to not be version 2, converting using wb_command...']);
            [~, name, ext] = fileparts(filename);
            tmpfile = [tempname '.' name ext];
            cleanupObj = onCleanup(@()mydelete(tmpfile)); %make previous obj close our fid, make new cleanup obj to delete temp file
            my_system([options.wbcmd ' -file-convert -cifti-version-convert ' filename ' 2 ' tmpfile]);
            outstruct = cifti_read(tmpfile, [varargin, {'recursed'}]); %guard against infinite recursion
            return;
        end
        rethrow(excinfo);
    end
    dims_c = hdr.dim(6:(hdr.dim(1) + 1)); %extract cifti dimensions from header
    dims_m = dims_c([2 1 3:length(dims_c)]); %for ciftiopen compatibility, first dimension for matlab code is down
    dims_xml = zeros(1, length(outstruct.diminfo));
    for i = 1:length(outstruct.diminfo)
        dims_xml(i) = outstruct.diminfo{i}.length;
    end
    if any(dims_m ~= dims_xml)
        error(['xml dimensions disagree with nifti dimensions in cifti file ' filename]);
    end
    
    %find stored datatype
    switch hdr.datatype
        case 2
            intype = 'uint8';
            inbitpix = 8;
        case 4
            intype = 'int16';
            inbitpix = 16;
        case 8
            intype = 'int32';
            inbitpix = 32;
        case 16
            intype = 'float32';
            inbitpix = 32;
        case 64
            intype = 'float64';
            inbitpix = 64;
        case 256
            intype = 'int8';
            inbitpix = 8;
        case 512
            intype = 'uint16';
            inbitpix = 16;
        case 768
            intype = 'uint32';
            inbitpix = 32;
        case 1024
            intype = 'int64';
            inbitpix = 64;
        case 1280
            intype = 'uint64';
            inbitpix = 64;
        otherwise
            error(['unsupported datatype ' num2str(hdr.datatype) ' for cifti file ' filename]);
    end
    if hdr.bitpix ~= inbitpix
        warning(['mismatch between datatype (' num2str(hdr.datatype) ') and bitpix (' num2str(hdr.bitpix) ') in cifti file ' filename]);
    end
    %header reading does not seek to vox_offset
    if(fseek(fid, hdr.vox_offset, 'bof') ~= 0)
        error(['failed to seek to start of data in file ' filename]);
    end
    %always output as float32, maybe add a feature later
    %use 'cdata' to be compatible with old ciftiopen
    max_elems = 128 * 1024 * 1024 / 4; %when reading as float32, use only 128MiB extra memory when reading (or the size of a row, if that manages to be larger)
    if prod(hdr.dim(6:(hdr.dim(1) + 1))) <= max_elems
        %file is small, use the simple code to read it all in one call
        %permute to match ciftiopen: cifti "rows" matching matlab rows
        %hack: 3:2 produces empty array, 3:3 produces [3]
        outstruct.cdata = permute(do_nifti_scaling(fread_excepting(fid, hdr.dim(6:(hdr.dim(1) + 1)), [intype '=>float32'], filename), hdr), [2 1 3:(hdr.dim(1) - 4)]);
    else
        outstruct.cdata = myzeros(dims_m); %avoid inconsistent 1-dimension handling, allow column vector, default to float32
        max_rows = max(1, min(hdr.dim(7), floor(max_elems / hdr.dim(6))));
        switch hdr.dim(1) %dim[0]
            case 6
                %even out the passes to use about the same memory
                num_passes = ceil(hdr.dim(7) / max_rows);
                chunk_rows = ceil(hdr.dim(7) / num_passes);
                for i = 1:chunk_rows:hdr.dim(7)
                    outstruct.cdata(i:min(hdr.dim(7), i + chunk_rows - 1), :) = do_nifti_scaling(fread_excepting(fid, [hdr.dim(6), min(chunk_rows, hdr.dim(7) - i + 1)], [intype '=>float32']), hdr)';
                end
            case 7
                %3D - this is all untested
                if max_rows < hdr.dim(7)
                    %keep it simple, chunk each plane independently
                    num_passes = ceil(hdr.dim(7) / max_rows);
                    chunk_rows = ceil(hdr.dim(7) / num_passes);
                    for j = 1:hdr.dim(8)
                        for i = 1:chunk_rows:hdr.dim(7)
                            outstruct.cdata(i:min(hdr.dim(7), i + chunk_rows - 1), :, j) = do_nifti_scaling(fread_excepting(fid, [hdr.dim(6), min(chunk_rows, hdr.dim(7) - i + 1)], [intype '=>float32']), hdr)';
                        end
                    end
                else
                    %read multiple full planes per call
                    plane_elems = hdr.dim(7) * hdr.dim(6);
                    max_planes = max(1, min(hdr.dim(8), floor(max_elems / plane_elems)));
                    num_passes = ceil(hdr.dim(8) / max_planes);
                    chunk_planes = ceil(hdr.dim(8) / num_passes);
                    for j = 1:chunk_planes:hdr.dim(8)
                        outstruct.cdata(:, :, j:min(hdr.dim(8), j + chunk_planes - 1)) = permute(do_nifti_scaling(fread_excepting(fid, [hdr.dim(6:7), min(chunk_planes, hdr.dim(8) - j + 1)], [intype '=>float32']), hdr), [2 1 3]);
                    end
                end
            otherwise
                %4D and beyond is not in the cifti-2 standard and is treated as an error in sanity_check_cdata
                %but, if it ever is supported, warn and read it the memory-intensive way anyway
                warning('cifti reading for 4 or more dimensions currently peaks at double the memory');
                outstruct.cdata = permute(do_nifti_scaling(fread_excepting(fid, hdr.dim(6:(hdr.dim(1) + 1)), [intype '=>float32'], filename), hdr), [2 1 3:(hdr.dim(1) - 4)]);
        end
    end
end

function outdata = do_nifti_scaling(data, hdr)
    if ~(hdr.scl_slope == 0 || (hdr.scl_slope == 1 && hdr.scl_inter == 0))
        outdata = data .* hdr.scl_slope + hdr.scl_inter;
    else
        outdata = data;
    end
end

%avoid inconsistent 1-dimension handling, allow column vector, default to float32
function outzeros = myzeros(dimarray)
    if length(dimarray) == 1
        outzeros = zeros(dimarray(1), 1, 'single');
    else
        outzeros = zeros(dimarray(:)', 'single');
    end
end
