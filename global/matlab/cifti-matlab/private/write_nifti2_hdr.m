function [fid, hdr, cleanupObj] = write_nifti2_hdr(hdr, filename)
    mydelete(filename); %avoid permission issues, and replace links with files instead of overwriting the pointed-to file
    fid = fopen(filename, 'Wb'); %always write native-endian - capital W means fwrite() doesn't flush every call
    if fid == -1
        error(['unable to open file "' filename '" for writing']);
    end
    cleanupObj = onCleanup(@()cleanup(fid, filename));
    %vox_offset needs to start on a multiple of 16
    %first extension starts on byte 544 = 16 * 34
    %so, pad all extensions to align their data to 16 bytes, too, in case they are binary and something cares about their alignment
    vox_offset = 544; %first possible value of vox_offset
    for i = 1:length(hdr.extensions)
        %esize and ecode are 32bit each, for a total of 8 bytes extra
        datasize = length(hdr.extensions(i).edata);
        overflow = mod(datasize + 8, 16);
        if overflow ~= 0
            padding = 16 - overflow;
            hdr.extensions(i).edata = bytes_force_size(hdr.extensions(i).edata, datasize + padding);
        end
        vox_offset = vox_offset + length(hdr.extensions(i).edata) + 8;
    end
    hdr.vox_offset = vox_offset;
    fwrite_excepting(fid, int32(540), 'int32', filename); %this must never be another number, so ignore what hdr says
    fwrite_excepting(fid, ['n+2' char([0 13 10 26 10])], 'uint8', filename); %ditto
    fwrite_excepting(fid, hdr.datatype(1), 'int16', filename); %force scalar by taking first element
    fwrite_excepting(fid, hdr.bitpix(1), 'int16', filename);
    fwrite_excepting(fid, hdr.dim(1:8), 'int64', filename); %force vector sizes by indexing
    fwrite_excepting(fid, hdr.intent_p1(1), 'float64', filename);
    fwrite_excepting(fid, hdr.intent_p2(1), 'float64', filename);
    fwrite_excepting(fid, hdr.intent_p3(1), 'float64', filename);
    fwrite_excepting(fid, hdr.pixdim(1:8), 'float64', filename);
    fwrite_excepting(fid, hdr.vox_offset(1), 'int64', filename);
    fwrite_excepting(fid, hdr.scl_slope(1), 'float64', filename);
    fwrite_excepting(fid, hdr.scl_inter(1), 'float64', filename);
    fwrite_excepting(fid, hdr.cal_max(1), 'float64', filename);
    fwrite_excepting(fid, hdr.cal_min(1), 'float64', filename);
    fwrite_excepting(fid, hdr.slice_duration(1), 'float64', filename);
    fwrite_excepting(fid, hdr.toffset(1), 'float64', filename);
    fwrite_excepting(fid, hdr.slice_start(1), 'int64', filename);
    fwrite_excepting(fid, hdr.slice_end(1), 'int64', filename);
    fwrite_excepting(fid, bytes_force_size(unicode2native(hdr.descrip(:)', 'UTF-8'), 80), 'uint8', filename); %force strings to be vectors of the right length
    fwrite_excepting(fid, bytes_force_size(unicode2native(hdr.aux_file(:)', 'UTF-8'), 24), 'uint8', filename);
    fwrite_excepting(fid, hdr.qform_code(1), 'int32', filename);
    fwrite_excepting(fid, hdr.sform_code(1), 'int32', filename);
    fwrite_excepting(fid, hdr.quatern_b(1), 'float64', filename);
    fwrite_excepting(fid, hdr.quatern_c(1), 'float64', filename);
    fwrite_excepting(fid, hdr.quatern_d(1), 'float64', filename);
    fwrite_excepting(fid, hdr.qoffset_x(1), 'float64', filename);
    fwrite_excepting(fid, hdr.qoffset_y(1), 'float64', filename);
    fwrite_excepting(fid, hdr.qoffset_z(1), 'float64', filename);
    fwrite_excepting(fid, hdr.srow_x(1:4), 'float64', filename);
    fwrite_excepting(fid, hdr.srow_y(1:4), 'float64', filename);
    fwrite_excepting(fid, hdr.srow_z(1:4), 'float64', filename);
    fwrite_excepting(fid, hdr.slice_code(1), 'int32', filename);
    fwrite_excepting(fid, hdr.xyzt_units(1), 'int32', filename);
    fwrite_excepting(fid, hdr.intent_code(1), 'int32', filename);
    fwrite_excepting(fid, bytes_force_size(unicode2native(hdr.intent_name(:)', 'UTF-8'), 16), 'uint8', filename);
    fwrite_excepting(fid, hdr.dim_info(1), 'uint8', filename);
    fwrite_excepting(fid, bytes_force_size(hdr.unused_str(:)', 15), 'uint8', filename);
    if ftell(fid) ~= 540 %sanity check how many bytes we wrote
        error('internal error in write_nifti2_hdr()');
    end
    if isempty(hdr.extensions)
        fwrite_excepting(fid, char([0 0 0 0]), 'uint8', filename);
    else
        fwrite_excepting(fid, char([1 0 0 0]), 'uint8', filename);
        for i = 1:length(hdr.extensions) %these are already properly padded, just write them
            fwrite_excepting(fid, length(hdr.extensions(i).edata) + 8, 'int32', filename);
            fwrite_excepting(fid, hdr.extensions(i).ecode, 'int32', filename);
            fwrite_excepting(fid, hdr.extensions(i).edata, 'uint8', filename);
        end
    end
    if ftell(fid) > hdr.vox_offset %another sanity check
        error('internal error in write_nifti2_hdr()');
    end
end

function outbytes = bytes_force_size(inbytes, newsize)
    if length(inbytes) > newsize
        outbytes = inbytes(1:newsize);
    else
        if length(inbytes) < newsize
            outbytes = inbytes;
            outbytes(end+1:newsize) = 0;
        else
            outbytes = inbytes;
        end
    end
end

function cleanup(fid, filename)
    status = fclose(fid);
    if status ~= 0
        error(['failed to close file ' filename]);
    end
end
