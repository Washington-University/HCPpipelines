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
    ciftiextindex = find([hdr.extensions.ecode] == 32);
    if length(ciftiextindex) > 1
        error(['multiple cifti extensions found in file ' filename]);
    end
    if isempty(ciftiextindex)
        error(['no cifti extension found in file ' filename]);
    end
    %sanity check dims
    if hdr.dim(1) < 6 || any(hdr.dim(2:5) ~= 1)
        error(['wrong nifti dimensions for cifti file ' filename]);
    end
    try
        outstruct = cifti_parse_xml(native2unicode(hdr.extensions(ciftiextindex).edata, 'UTF-8'), filename);
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
    outstruct.otherexts = struct([]);
    for i = 1:length(hdr.extensions)
        if hdr.extensions(i).ecode ~= 32
            outstruct.otherexts = [outstruct.otherexts hdr.extensions(i)];
        end
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
    %always convert to float32, maybe add a feature later
    outstruct.cdata = myzeros(dims_m);
    %use 'cdata' to be compatible with old ciftiopen
    max_elems = 128 * 1024 * 1024 / 4; %when reading as float32, use only 128MiB extra memory when reading (or the size of a row, if that manages to be larger)
    if prod(dims_c) <= max_elems
        %file is small, use the simple code to read it all in one call
        %permute to match ciftiopen: cifti "rows" matching matlab rows
        %note: 3:2 produces empty array, 3:3 produces [3]
        outstruct.cdata(:) = permute(do_nifti_scaling(fread_excepting(fid, hdr.dim(6:(hdr.dim(1) + 1)), [intype '=>float32'], filename), hdr), [2 1 3:(hdr.dim(1) - 4)]);
    else
        %matlab indexing modes can't handle swapping first two dims while doing "some full planes plus a partial plane" per fread()
        %reshape at the end would hit double the memory usage, and we want to avoid that
        %so to avoid slow row-at-a-time loops, two cases: less than a plane, and multiple full planes
        %with implicit third index and implicit flattening on final specified dimension, we can do these generically in a way that should work even for 4D+ (if it is ever supported)
        max_rows = max(1, floor(max_elems / dims_c(1)));
        if max_rows < dims_c(2) %less than a plane at a time, don't read cross-plane
            num_passes = ceil(dims_c(2) / max_rows); %even out the passes
            chunk_rows = ceil(prod(dims_c(2:end)) / num_passes);
            total_planes = prod(dims_c(3:end));
            for plane = 1:total_planes
                for chunkstart = 1:chunk_rows:dims_c(2)
                    outstruct.cdata(chunkstart:min(dims_c(2), chunkstart + chunk_rows - 1), :, plane) = do_nifti_scaling(fread_excepting(fid, [dims_c(1), min(chunk_rows, dims_c(2) - chunkstart + 1)], [intype '=>float32']), hdr)';
                end
            end
        else
            max_planes = max(1, floor(max_rows / dims_c(2))); %just in case the division does something dumb
            total_planes = prod(dims_c(3:end));
            num_passes = ceil(total_planes / max_planes);
            chunk_planes = ceil(total_planes / num_passes);
            for chunkstart = 1:chunk_planes:total_planes
                outstruct.cdata(:, :, chunkstart:min(total_planes, chunkstart + chunk_planes - 1)) = permute(do_nifti_scaling(fread_excepting(fid, [dims_c(1:2), min(chunk_planes, total_planes - chunkstart + 1)], [intype '=>float32']), hdr), [2 1 3]);
            end
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

