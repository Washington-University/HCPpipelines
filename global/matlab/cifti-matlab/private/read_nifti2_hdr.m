function [hdr, fid, cleanupObj] = read_nifti2_hdr(filename)
    % READ_NIFTI2_HDR
    %
    % Use as
    %   [hdr, fid, cleanupObj] = read_nifti2_hdr(filename)
    % where
    %   filename   = string
    %
    % cleanupObj MUST be kept around until you are done reading from fid,
    %   as it will close fid when it is destroyed.
    %   
    % This implements the format as described at
    %   http://www.nitrc.org/forum/forum.php?thread_id=2148&forum_id=1941
    %
    % Please note that it is different from the suggested format described here
    %   http://www.nitrc.org/forum/forum.php?thread_id=2070&forum_id=1941
    % and
    %   https://mail.nmr.mgh.harvard.edu/pipermail//freesurfer/2011-February/017482.html
    % Notably, the unused fields have been removed and the size has been
    % reduced from 560 to 540 bytes.
    %
    % See also WRITE_NIFTI_HDR, CIFTI_READ, CIFTI_WRITE

    % Copyright (C) 2013, Robert Oostenveld
    %
    % The fieldtrip-derived version of this file has been dual licensed by its author,
    % Robert Oostenveld, under BSD 2-clause or GPL v3+ as follows:
    %
    % Redistribution and use in source and binary forms, with or without modification,
    % are permitted provided that the following conditions are met:
    %
    % 1. Redistributions of source code must retain the above copyright notice,
    % this list of conditions and the following disclaimer.
    %
    % 2. Redistributions in binary form must reproduce the above copyright notice,
    % this list of conditions and the following disclaimer in the documentation and/or
    % other materials provided with the distribution.
    %
    % THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
    % EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
    % MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
    % IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
    % INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
    % PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
    % BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
    % STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
    % THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
    %
    % See the review of PR #8 here: https://github.com/Washington-University/cifti-matlab/pull/8
    %
    % At your option, you may instead use this file under the terms of GPL v3 or later:
    %
    % This file is part of FieldTrip, see http://www.fieldtriptoolbox.org
    % for the documentation and details.
    %
    %    FieldTrip is free software: you can redistribute it and/or modify
    %    it under the terms of the GNU General Public License as published by
    %    the Free Software Foundation, either version 3 of the License, or
    %    (at your option) any later version.
    %
    %    FieldTrip is distributed in the hope that it will be useful,
    %    but WITHOUT ANY WARRANTY; without even the implied warranty of
    %    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    %    GNU General Public License for more details.
    %
    %    You should have received a copy of the GNU General Public License
    %    along with FieldTrip. If not, see <http://www.gnu.org/licenses/>.
    %
    % $Id$

    % Edited by Tim Coalson
    % Copyright (c) 2020 Washington University School of Medicine
    % BSD 2-clause, see LICENSE in the top level of the repository

    hdr.endian = 'l';
    fid = fopen(filename, 'rb', hdr.endian);
    if fid == -1
        error(['file does not exist or cannot be read: ' filename]);
    end
    hdr.sizeof_hdr = fread_excepting(fid, [1 1 ], 'int32=>int32', filename); % 0

    if hdr.sizeof_hdr~=348 && hdr.sizeof_hdr~=540
        % try opening as big endian
        badsize = hdr.sizeof_hdr; %save incorrect size for error message
        fclose(fid);
        hdr.endian = 'b';
        fid = fopen(filename, 'rb', hdr.endian);
        hdr.sizeof_hdr = fread_excepting(fid, [1 1 ], 'int32=>int32', filename); % 0
    end
    
    cleanupObj = onCleanup(@()cleanup(fid));

    if hdr.sizeof_hdr~=348 && hdr.sizeof_hdr~=540
        error('cannot open %s as nifti file, hdr size = %d, should be 348 or 540\n', filename, min(badsize, hdr.sizeof_hdr));
    end

    if hdr.sizeof_hdr==348
        % the remainder of the code is for nifti-2 files
        error('%s seems to be a nifti-1 file', filename)
    end

    hdr.magic           = fread_excepting(fid, [1 8 ], 'uint8=>char', filename     ); % 4       `n', '+', `2', `\0','\r','\n','\032','\n' or (0x6E,0x2B,0x32,0x00,0x0D,0x0A,0x1A,0x0A)
    hdr.datatype        = fread_excepting(fid, [1 1 ], 'int16=>int16', filename   ); % 12      See file formats
    hdr.bitpix          = fread_excepting(fid, [1 1 ], 'int16=>int16', filename   ); % 14      See file formats
    hdr.dim             = fread_excepting(fid, [1 8 ], 'int64=>int64', filename   ); % 16      See file formats

    if hdr.dim(1)<1 || hdr.dim(1)>7
        % see http://nifti.nimh.nih.gov/nifti-1/documentation/nifti1fields/nifti1fields_pages/dim.html
        error('inconsistent endianness in the header');
    end

    if ~strcmp(hdr.magic, ['n+2' char([0 13 10 26 10])])
        % see https://www.nitrc.org/forum/forum.php?thread_id=2148&forum_id=1941
        % support only single-file
        error('wrong magic string in the header');
    end

    hdr.intent_p1       = fread_excepting(fid, [1 1 ], 'double=>double', filename ); % 80      0
    hdr.intent_p2       = fread_excepting(fid, [1 1 ], 'double=>double', filename ); % 88      0
    hdr.intent_p3       = fread_excepting(fid, [1 1 ], 'double=>double', filename ); % 96      0
    hdr.pixdim          = fread_excepting(fid, [1 8 ], 'double=>double', filename ); % 104     0,1,1,1,1,1,1,1
    hdr.vox_offset      = fread_excepting(fid, [1 1 ], 'int64=>int64', filename   ); % 168     Offset of data, minimum=544
    hdr.scl_slope       = fread_excepting(fid, [1 1 ], 'double=>double', filename ); % 176     1
    hdr.scl_inter       = fread_excepting(fid, [1 1 ], 'double=>double', filename ); % 184     0
    hdr.cal_max         = fread_excepting(fid, [1 1 ], 'double=>double', filename ); % 192     0
    hdr.cal_min         = fread_excepting(fid, [1 1 ], 'double=>double', filename ); % 200     0
    hdr.slice_duration  = fread_excepting(fid, [1 1 ], 'double=>double', filename ); % 208     0
    hdr.toffset         = fread_excepting(fid, [1 1 ], 'double=>double', filename ); % 216     0
    hdr.slice_start     = fread_excepting(fid, [1 1 ], 'int64=>int64', filename   ); % 224     0
    hdr.slice_end       = fread_excepting(fid, [1 1 ], 'int64=>int64', filename   ); % 232     0
    hdr.descrip         = fread_excepting(fid, [1 80], 'uint8=>char', filename     ); % 240     All zeros
    hdr.aux_file        = fread_excepting(fid, [1 24], 'uint8=>char', filename     ); % 320     All zeros
    hdr.qform_code      = fread_excepting(fid, [1 1 ], 'int32=>int32', filename   ); % 344     NIFTI_XFORM_UNKNOWN (0)
    hdr.sform_code      = fread_excepting(fid, [1 1 ], 'int32=>int32', filename   ); % 348     NIFTI_XFORM_UNKNOWN (0)
    hdr.quatern_b       = fread_excepting(fid, [1 1 ], 'double=>double', filename ); % 352     0
    hdr.quatern_c       = fread_excepting(fid, [1 1 ], 'double=>double', filename ); % 360     0
    hdr.quatern_d       = fread_excepting(fid, [1 1 ], 'double=>double', filename ); % 368     0
    hdr.qoffset_x       = fread_excepting(fid, [1 1 ], 'double=>double', filename ); % 376     0
    hdr.qoffset_y       = fread_excepting(fid, [1 1 ], 'double=>double', filename ); % 384     0
    hdr.qOffset_z       = fread_excepting(fid, [1 1 ], 'double=>double', filename ); % 392     0
    hdr.srow_x          = fread_excepting(fid, [1 4 ], 'double=>double', filename ); % 400     0,0,0,0
    hdr.srow_y          = fread_excepting(fid, [1 4 ], 'double=>double', filename ); % 432     0,0,0,0
    hdr.srow_z          = fread_excepting(fid, [1 4 ], 'double=>double', filename ); % 464     0,0,0,0
    hdr.slice_code      = fread_excepting(fid, [1 1 ], 'int32=>int32', filename   ); % 496     0
    hdr.xyzt_units      = fread_excepting(fid, [1 1 ], 'int32=>int32', filename   ); % 500     0xC (seconds, millimeters)
    hdr.intent_code     = fread_excepting(fid, [1 1 ], 'int32=>int32'   ); % 504     See file formats
    hdr.intent_name     = fread_excepting(fid, [1 16], 'uint8=>char'     ); % 508     See file formats
    hdr.dim_info        = fread_excepting(fid, [1 1 ], 'uint8=>uint8'     ); % 524     0
    hdr.unused_str      = fread_excepting(fid, [1 15], 'uint8'     ); % 525     All zeros
    % disp(ftell(fid));                                          % 540     End of the header

    if feof(fid)
        error('nifti-2 file %s is too short to contain the entire header', filename);
    end

    if hdr.vox_offset < 544
        error('vox_offset must not be less than 544 in nifti-2, but is %d in %s', hdr.vox_offset, filename);
    end

    hdr.extensions = struct([]);
    extender = fread_excepting(fid, [1 4], 'uint8=>uint8'); % 540, extender bytes
    % 0 0 0 0 means no extensions
    if any(extender ~= [0 0 0 0])
        %"extentions match those of NIfTI-1.1 when the extender bytes are 1 0 0 0", https://nifti.nimh.nih.gov/nifti-2/
        if all(extender == [1 0 0 0])
            while ftell(fid) + 8 < hdr.vox_offset && ~feof(fid)
                extension = struct();
                esize = fread_excepting(fid, [1 1], 'int32=>int32'); % includes the size and code int32s
                if esize < 8 || ftell(fid) - 4 + esize > hdr.vox_offset
                    break;
                end
                extension.ecode = fread_excepting(fid, [1 1], 'int32=>int32');
                extension.edata = fread_excepting(fid, [1 esize - 8], 'uint8');
                hdr.extensions = [hdr.extensions extension];
            end
        end
    end
end

function cleanup(fid)
    fclose(fid);
end

