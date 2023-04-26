function outstruct = cifti_parse_xml(bytes, filename)
    outstruct = struct();
    %truncate at null terminator to remove extension padding
    nulls = bytes == 0;
    if any(nulls)
        bytes = bytes(1:(find(nulls, 1) - 1));
    end
    tree = xmltreemod(bytes);
    setfilename(tree, filename);%probably helps with error messages for malformed XML?
    attrs = myattrs(tree);
    for attr = attrs
        switch attr{1}.key
            case 'Version'
                switch attr{1}.val
                    case '2'
                        parse_vers = 2; %#ok<NASGU>
                    otherwise
                        error('cifti:version', ['unsupported cifti version "' attr{1}.val '"'], filename); %the 'cifti:version' is used to let cifti_read know to use wb_command to convert
                end
            otherwise
                mywarn(['unrecognized CIFTI attribute "' attr{1}.key '"'], filename);
        end
    end
    outstruct.metadata = cifti_parse_metadata(tree, find(tree, '/CIFTI/Matrix/MetaData'), filename);
    map_uids = find(tree, '/CIFTI/Matrix/MatrixIndicesMap');
    outstruct.diminfo = {};
    for map_uid = map_uids
        [map, applies] = cifti_parse_map(tree, map_uid, filename);
        appliesmod = applies;
        appliesmod(applies < 3) = 3 - applies(applies < 3); %NOTE: swap 1 and 2 to match ciftiopen cdata convention...
        outstruct.diminfo(appliesmod) = {map}; %lhs {} doesn't support multi-assignment, but () on cell does...
    end
    for i = length(outstruct.diminfo)
        if isempty(outstruct.diminfo{i})
            myerror(['missing mapping for dimension ' num2str(i - 1)], filename);
        end
    end
end

%save a small amount of repetition
function myerror(msg, filename)
    error([msg ' in cifti file ' filename]);
end

function mywarn(msg, filename)
    warning([msg ' in cifti file ' filename]);
end

function metastruct = cifti_parse_metadata(tree, uid, filename)
    %assume this was called using an unchecked find or similar
    if isempty(uid)
        metastruct = struct('key', {}, 'value', {});
    else
        if ~isscalar(uid)
            myerror('multiple MetaData children at same level', filename);
        end
        md_uids = child_match(tree, uid, 'MD');%ignores unexpected elements...
        num_mds = length(md_uids);
        metastruct = struct('key', cell(1, num_mds), 'value', cell(1, num_mds));
        for i = 1:num_mds
            name_uid = child_match(tree, md_uids(i), 'Name');
            val_uid = child_match(tree, md_uids(i), 'Value');
            if ~(isscalar(name_uid) && isscalar(val_uid))
                myerror('malformed child element of MetaData', filename);
            end
            metastruct(i).key = mygettext(tree, name_uid);
            metastruct(i).value = mygettext(tree, val_uid);
        end
    end
end

function [map, applies] = cifti_parse_map(tree, map_uid, filename)
    type = '';
    applies = [];
    attrs = myattrs(tree, map_uid);
    for attr = attrs
        switch attr{1}.key
            case 'AppliesToMatrixDimension'
                applies = str2vec(attr{1}.val) + 1; %NOTE: 1-based matlab indexing
                if isempty(applies) || any((mod(applies, 1) ~= 0) | (applies < 0))
                    myerror(['invalid AppliesToMatrixDimension value "' attr{1}.val '"'], filename);
                end
            case 'IndicesMapToDataType'
                type = attr{1}.val;
        end %only series has other attributes, we can read those in a later function
    end
    if isempty(applies)
        myerror('mapping has missing or empty AppliesToMatrixDimension attribute', filename);
    end
    if isempty(type)
        myerror('mapping has missing or empty IndicesMapToDataType attribute', filename);
    end
    switch type
        case 'CIFTI_INDEX_TYPE_BRAIN_MODELS'
            map = cifti_parse_dense(tree, map_uid, filename);
        case 'CIFTI_INDEX_TYPE_PARCELS'
            map = cifti_parse_parcels(tree, map_uid, filename);
        case 'CIFTI_INDEX_TYPE_SERIES'
            map = cifti_parse_series(tree, map_uid, filename);
        case 'CIFTI_INDEX_TYPE_SCALARS'
            map = cifti_parse_scalars(tree, map_uid, filename);
        case 'CIFTI_INDEX_TYPE_LABELS'
            map = cifti_parse_labels(tree, map_uid, filename);
        otherwise
            myerror(['unrecognized mapping type "' type '"'], filename);
    end
end

function map = cifti_parse_dense(tree, map_uid, filename)
    map = struct('type', 'dense');
    map.vol = cifti_parse_vol(tree, map_uid, filename); %volume also gets used by parcels
    model_uids = child_match(tree, map_uid, 'BrainModel');
    map.models = cell(1, length(model_uids));%the model types have different fields, so don't use struct array
    starts = zeros(1, length(model_uids));
    for i = 1:length(model_uids)
        model = struct();
        attrs = myattrs(tree, model_uids(i));
        for attr = attrs
            switch attr{1}.key
                case 'ModelType'
                    type = attr{1}.val;
                    switch type
                        case 'CIFTI_MODEL_TYPE_SURFACE'
                            model.type = 'surf';
                        case 'CIFTI_MODEL_TYPE_VOXELS'
                            model.type = 'vox';
                        otherwise
                            myerror(['unrecognized brain model type "' type '"'], filename);
                    end
                case 'IndexOffset'
                    %NOTE: cifti indices are one-based
                    model.start = str2double(attr{1}.val) + 1;
                    if mod(model.start, 1) ~= 0 || model.start < 1
                        myerror(['invalid value "' attr{1}.val '" for IndexOffset attribute'], filename);
                    end
                    starts(i) = model.start;
                case 'IndexCount'
                    model.count = str2double(attr{1}.val);
                    if mod(model.count, 1) ~= 0 || model.count < 1
                        myerror(['invalid value "' attr{1}.val '" for IndexCount attribute'], filename);
                    end
                case 'BrainStructure'
                    model.struct = cifti_structure_to_friendly(attr{1}.val, filename);
                case 'SurfaceNumberOfVertices'
                    model.numvert = str2double(attr{1}.val);
                    if mod(model.numvert, 1) ~= 0 || model.numvert < 1
                        myerror(['invalid value "' attr{1}.val '" for SurfaceNumberOfVertices attribute'], filename);
                    end
                otherwise
                    mywarn(['unrecognized BrainModel attribute "' attr{1}.key '"'], filename);
            end
        end
        if ~isfield(model, 'type')
            myerror('BrainModel with no ModelType attribute', filename);
        end
        if ~isfield(model, 'start')
            myerror('BrainModel with no IndexOffset attribute', filename);
        end
        if ~isfield(model, 'count')
            myerror('BrainModel with no IndexCount attribute', filename);
        end
        if ~isfield(model, 'struct')
            myerror('BrainModel with no BrainStructure attribute', filename);
        end
        switch model.type
            case 'surf'
                if ~isfield(model, 'numvert')
                    myerror('Surface type BrainModel with no SurfaceNumberOfVertices attribute', filename);
                end
                vert_uid = child_match(tree, model_uids(i), 'VertexIndices');
                if isempty(vert_uid)
                    myerror('VertexIndices element missing in Surface type BrainModel', filename);
                end
                if ~isscalar(vert_uid)
                    myerror('multiple VertexIndices elements in one BrainModel', filename);
                end
                %NOTE: vertices are zero-based
                model.vertlist = str2vec(mygettext(tree, vert_uid));
                if isempty(model.vertlist) || ~isreal(model.vertlist) || any(model.vertlist < 0 | model.vertlist >= model.numvert)
                    myerror('invalid VertexIndices content', filename);
                end
                if length(model.vertlist) ~= model.count
                    myerror('VertexIndices does not match IndexCount', filename);
                end
            case 'vox'
                if isfield(model, 'numvert')
                    mywarn('SurfaceNumberOfVertices attribute present in Voxel type BrainModel', filename);
                    model = rmfield(model, 'numvert');
                end
                vox_uid = child_match(tree, model_uids(i), 'VoxelIndicesIJK');
                if isempty(vox_uid)
                    myerror('VoxelIndicesIJK element missing in Voxel type BrainModel', filename);
                end
                if ~isscalar(vox_uid)
                    myerror('multiple VoxelIndicesIJK elements in one BrainModel', filename);
                end
                %NOTE: voxels are zero-based
                voxlist = str2vec(mygettext(tree, vox_uid));
                numelem = length(voxlist);
                if mod(numelem, 3) ~= 0
                    myerror('number of values in VoxelIndicesIJK not a multiple of 3', filename);
                end
                if numelem ~= 3 * model.count
                    myerror('VoxelIndicesIJK does not match IndexCount', filename);
                end
                model.voxlist = reshape(voxlist, 3, model.count); %looping is along the second dimension, so ijk should be on first dimension
                if isempty(model.voxlist) || ~isreal(model.voxlist) || any(any(model.voxlist < 0 | model.voxlist >= repmat(map.vol.dims', 1, model.count)))
                    myerror('invalid VoxelIndicesIJK content', filename);
                end
            otherwise
                error(['internal error while parsing cifti file ' filename]);
        end
        map.models{i} = model;
    end
    [~, perm] = sort(starts);
    map.models = map.models(perm);
    curindex = 1;
    for i = 1:length(map.models)
        if map.models{i}.start ~= curindex
            myerror(['BrainModel elements overlap or have a gap at cifti index ' num2str(map.models{i}.start)]);
        end
        curindex = curindex + map.models{i}.count;
    end
    map.length = map.models{end}.start + map.models{end}.count - 1; %1-based indexing fencepost
    allvox = [];
    allstructs = {};
    for model = map.models(:)'
        switch model{1}.type
            case 'vox'
                allvox = [allvox model{1}.voxlist]; %#ok<AGROW>
        end
        allstructs = [allstructs {model{1}.struct}]; %#ok<AGROW>
    end
    if length(unique(allstructs)) ~= length(allstructs)
        myerror('brain models specify a structure more than once', filename);
    end
    if size(unique(allvox, 'rows'), 1) ~= size(allvox, 1)
        myerror('brain models have repeated or overlapping voxels', filename);
    end
end

function outstr = cifti_structure_to_friendly(instr, filename)
    switch instr
        case 'CIFTI_STRUCTURE_ACCUMBENS_LEFT'; outstr = 'ACCUMBENS_LEFT';
        case 'CIFTI_STRUCTURE_ACCUMBENS_RIGHT'; outstr = 'ACCUMBENS_RIGHT';
        case 'CIFTI_STRUCTURE_ALL_WHITE_MATTER'; outstr = 'ALL_WHITE_MATTER';
        case 'CIFTI_STRUCTURE_ALL_GREY_MATTER'; outstr = 'ALL_GREY_MATTER';
        case 'CIFTI_STRUCTURE_AMYGDALA_LEFT'; outstr = 'AMYGDALA_LEFT';
        case 'CIFTI_STRUCTURE_AMYGDALA_RIGHT'; outstr = 'AMYGDALA_RIGHT';
        case 'CIFTI_STRUCTURE_BRAIN_STEM'; outstr = 'BRAIN_STEM';
        case 'CIFTI_STRUCTURE_CAUDATE_LEFT'; outstr = 'CAUDATE_LEFT';
        case 'CIFTI_STRUCTURE_CAUDATE_RIGHT'; outstr = 'CAUDATE_RIGHT';
        case 'CIFTI_STRUCTURE_CEREBELLAR_WHITE_MATTER_LEFT'; outstr = 'CEREBELLAR_WHITE_MATTER_LEFT';
        case 'CIFTI_STRUCTURE_CEREBELLAR_WHITE_MATTER_RIGHT'; outstr = 'CEREBELLAR_WHITE_MATTER_RIGHT';
        case 'CIFTI_STRUCTURE_CEREBELLUM'; outstr = 'CEREBELLUM';
        case 'CIFTI_STRUCTURE_CEREBELLUM_LEFT'; outstr = 'CEREBELLUM_LEFT';
        case 'CIFTI_STRUCTURE_CEREBELLUM_RIGHT'; outstr = 'CEREBELLUM_RIGHT';
        case 'CIFTI_STRUCTURE_CEREBRAL_WHITE_MATTER_LEFT'; outstr = 'CEREBRAL_WHITE_MATTER_LEFT';
        case 'CIFTI_STRUCTURE_CEREBRAL_WHITE_MATTER_RIGHT'; outstr = 'CEREBRAL_WHITE_MATTER_RIGHT';
        case 'CIFTI_STRUCTURE_CORTEX'; outstr = 'CORTEX';
        case 'CIFTI_STRUCTURE_CORTEX_LEFT'; outstr = 'CORTEX_LEFT';
        case 'CIFTI_STRUCTURE_CORTEX_RIGHT'; outstr = 'CORTEX_RIGHT';
        case 'CIFTI_STRUCTURE_DIENCEPHALON_VENTRAL_LEFT'; outstr = 'DIENCEPHALON_VENTRAL_LEFT';
        case 'CIFTI_STRUCTURE_DIENCEPHALON_VENTRAL_RIGHT'; outstr = 'DIENCEPHALON_VENTRAL_RIGHT';
        case 'CIFTI_STRUCTURE_HIPPOCAMPUS_LEFT'; outstr = 'HIPPOCAMPUS_LEFT';
        case 'CIFTI_STRUCTURE_HIPPOCAMPUS_RIGHT'; outstr = 'HIPPOCAMPUS_RIGHT';
        case 'CIFTI_STRUCTURE_OTHER'; outstr = 'OTHER';
        case 'CIFTI_STRUCTURE_OTHER_GREY_MATTER'; outstr = 'OTHER_GREY_MATTER';
        case 'CIFTI_STRUCTURE_OTHER_WHITE_MATTER'; outstr = 'OTHER_WHITE_MATTER';
        case 'CIFTI_STRUCTURE_PALLIDUM_LEFT'; outstr = 'PALLIDUM_LEFT';
        case 'CIFTI_STRUCTURE_PALLIDUM_RIGHT'; outstr = 'PALLIDUM_RIGHT';
        case 'CIFTI_STRUCTURE_PUTAMEN_LEFT'; outstr = 'PUTAMEN_LEFT';
        case 'CIFTI_STRUCTURE_PUTAMEN_RIGHT'; outstr = 'PUTAMEN_RIGHT';
        case 'CIFTI_STRUCTURE_THALAMUS_LEFT'; outstr = 'THALAMUS_LEFT';
        case 'CIFTI_STRUCTURE_THALAMUS_RIGHT'; outstr = 'THALAMUS_RIGHT';
        otherwise
            myerror(['unrecognized cifti structure name "' instr '"'], filename);
    end
end

function vol = cifti_parse_vol(tree, map_uid, filename)
    vol = struct();
    vol_uid = child_match(tree, map_uid, 'Volume');
    if length(vol_uid) > 1
        myerror('multiple Volume elements in one map', filename);
    end
    if ~isempty(vol_uid)
        attrs = myattrs(tree, vol_uid);
        for attr = attrs
            switch attr{1}.key
                case 'VolumeDimensions'
                    vol.dims = str2vec(attr{1}.val); %zeros(), etc require a row vector
                otherwise
                    mywarn(['unrecognized Volume attribute "' attr{1}.key '"'], filename);
            end
        end
        if ~isfield(vol, 'dims')
            myerror('Volume element with no VolumeDimensions attribute', filename);
        end
        tfm_uid = child_match(tree, vol_uid, 'TransformationMatrixVoxelIndicesIJKtoXYZ');
        if length(tfm_uid) > 1
            myerror('multiple TransformationMatrixVoxelIndicesIJKtoXYZ elements in Volume element', filename);
        end
        if isempty(tfm_uid)
            myerror('missing TransformationMatrixVoxelIndicesIJKtoXYZ element in Volume element', filename);
        end
        exponent = nan;
        attrs = myattrs(tree, tfm_uid);
        for attr = attrs
            switch attr{1}.key
                case 'MeterExponent'
                    exponent = str2double(attr{1}.val);
                    if ~isreal(exponent) || mod(exponent, 1) ~= 0
                        myerror('non-integer MeterExponent', filename);
                    end
                otherwise
                    mywarn(['unrecognized TransformationMatrixVoxelIndicesIJKtoXYZ attribute "' attr{1}.key '"'], filename);
            end
        end
        if isnan(exponent)
            myerror('missing MeterExponent attribute in TransformationMatrixVoxelIndicesIJKtoXYZ', filename);
        end
        matrix = str2vec(mygettext(tree, tfm_uid));
        if length(matrix) ~= 16 || any(matrix(13:16) ~= [0 0 0 1]) || ~isreal(matrix)
            myerror('malformed matrix in Volume element', filename);
        end
        vol.sform = reshape(matrix, 4, 4)' * 10^(exponent + 3); %convert to mm
    end
end

function map = cifti_parse_parcels(tree, map_uid, filename)
    map = struct('type', 'parcels');
    map.vol = cifti_parse_vol(tree, map_uid, filename);
    %surfaces
    surf_uids = child_match(tree, map_uid, 'Surface');
    num_surfs = length(surf_uids);
    map.surflist = struct('struct', cell(1, num_surfs), 'numvert', cell(1, num_surfs));
    for i = 1:num_surfs
        attrs = myattrs(tree, surf_uids(i));
        thissurf = struct();
        for attr = attrs
            switch attr{1}.key
                case 'BrainStructure'
                    thissurf.struct = cifti_structure_to_friendly(attr{1}.val);
                case 'SurfaceNumberOfVertices'
                    thissurf.numvert = str2double(attr{1}.val);
                    if ~isscalar(thissurf.numvert) || thissurf.numvert < 1 || mod(thissurf.numvert, 1) ~= 0
                        myerror(['invalid text "' attr{1}.val '" for number of vertices'], filename);
                    end
                otherwise
                    mywarn(['unrecognized Surface attribute "' attr{1}.key '"'], filename);
            end
        end
        if ~isfield(thissurf, 'struct') || ~isfield(thissurf, 'numvert')
            myerror('missing required attribute in Surface element', filename);
        end
        map.surflist(i) = thissurf;
    end
    allsurfstructs = {map.surflist.struct};
    if length(unique(allsurfstructs)) ~= length(allsurfstructs)
        myerror('parcel surfaces specify a structure more than once', filename);
    end
    parcel_uids = child_match(tree, map_uid, 'Parcel');
    num_parcels = length(parcel_uids);
    map.parcels = struct('name', cell(1, num_parcels), 'surfs', cell(1, num_parcels), 'voxlist', cell(1, num_parcels));
    for i = 1:num_parcels
        %attributes
        attrs = myattrs(tree, parcel_uids(i));
        thisparcel = struct();
        for attr = attrs
            switch attr{1}.key
                case 'Name'
                    thisparcel.name = attr{1}.val;
                otherwise
                    mywarn(['unrecognized Surface attribute "' attr{1}.key '"'], filename);
            end
        end
        if ~isfield(thisparcel, 'name')
            myerror('missing required attribute in Parcel element', filename);
        end
        %vertices
        vert_uids = child_match(tree, parcel_uids(i), 'Vertices');
        num_vertelem = length(vert_uids);
        thisparcel.surfs = struct('struct', cell(1, num_vertelem), 'vertlist', cell(1, num_vertelem)); %same fields, so use struct array I guess
        for j = 1:num_vertelem
            attrs = myattrs(tree, vert_uids(j));
            thissurf = struct();
            for attr = attrs
                switch attr{1}.key
                    case 'BrainStructure'
                        thissurf.struct = cifti_structure_to_friendly(attr{1}.val);
                    otherwise
                        mywarn(['unrecognized Vertices attribute "' attr{1}.key '"'], filename);
                end
            end
            if ~isfield(thissurf, 'struct')
                myerror('missing required attribute in Vertices element', filename);
            end
            whichsurf = 0;
            for k = 1:length(map.surflist)
                if strcmp(thissurf.struct, map.surflist(k).struct)
                    whichsurf = k;
                    break;
                end
            end
            if whichsurf == 0
                myerror('parcel uses surface that is not specified', filename);
            end
            %NOTE: vertices are zero-based
            vertlist = str2vec(mygettext(tree, vert_uids(j)));
            if any(vertlist < 0 | vertlist >= map.surflist(whichsurf).numvert)
                myerror(['invalid vertex in parcel "' thisparcel.name '"'], filename);
            end
            thissurf.vertlist = vertlist;
            thisparcel.surfs(j) = thissurf;
        end
        %voxels - may be nonexistant, in which case we currently make the fields, but leave them empty
        vox_uid = child_match(tree, parcel_uids(i), 'VoxelIndicesIJK');
        if length(vox_uid) > 1
            myerror('multiple VoxelIndicesIJK elements in Parcel element', filename);
        end
        %NOTE: voxels are zero-based
        voxlist = str2vec(mygettext(tree, vox_uid));
        if mod(length(voxlist), 3) ~= 0
            myerror('number of values in VoxelIndicesIJK not a multiple of 3', filename);
        end
        thisparcel.voxlist = reshape(voxlist, 3, []); %looping is along the second dimension, so ijk should be on first dimension
        if ~isempty(voxlist) %accept empty VoxelIndicesIJK without Volume element?
            if ~isfield(map.vol, 'dims')
                myerror('missing Volume element in parcels map', filename);
            end
            if ~isreal(thisparcel.voxlist) || any(any(thisparcel.voxlist < 0 | thisparcel.voxlist >= repmat(map.vol.dims', 1, size(thisparcel.voxlist, 2))))
                myerror('invalid VoxelIndicesIJK content', filename);
            end
        end
        map.parcels(i) = thisparcel;
    end
    map.length = length(map.parcels);
    allvox = horzcat(map.parcels.voxlist);
    if size(unique(allvox', 'rows'), 1) ~= size(allvox, 2)
        myerror('parcels have repeated or overlapping voxels', filename);
    end
    for surfstruct = {map.surflist.struct}
        structvert = [];
        for j = 1:length(map.parcels)
            for i = 1:length(map.parcels(j).surfs)
                if strcmp(map.parcels(j).surfs(i).struct, surfstruct)
                    structvert = [structvert map.parcels(j).surfs(i).vertlist]; %#ok<AGROW>
                end
            end
        end
        if length(unique(structvert)) ~= length(structvert)
            myerror('parcels have repeated or overlapping vertices', filename);
        end
    end
end

function map = cifti_parse_series(tree, map_uid, filename)
    map = struct('type', 'series');
    exponent = nan;
    attrs = myattrs(tree, map_uid);
    for attr = attrs
        switch attr{1}.key
            case 'NumberOfSeriesPoints'
                map.length = str2double(attr{1}.val);
                if map.length < 1 || mod(map.length, 1) ~= 0
                    myerror('nonsensical series length', filename);
                end
            case 'SeriesExponent'
                exponent = str2double(attr{1}.val);
                if ~isreal(exponent) || mod(exponent, 1) ~= 0
                    myerror('non-integer SeriesExponent', filename);
                end
            case 'SeriesStart'
                map.seriesStart = str2double(attr{1}.val);
                if ~isreal(map.seriesStart)
                    myerror('non-real SeriesStart', filename)
                end
            case 'SeriesStep'
                map.seriesStep = str2double(attr{1}.val);
                if ~isreal(map.seriesStep)
                    myerror('non-real SeriesStep', filename)
                end
            case 'SeriesUnit'
                map.seriesUnit = attr{1}.val;
                switch attr{1}.val
                    case 'SECOND'
                    case 'HERTZ'
                    case 'METER'
                    case 'RADIAN'
                    otherwise
                        myerror('invalid SeriesUnit', filename);
                end
            case 'AppliesToMatrixDimension' %since these are on the same tag, we need to not warn when we see them
            case 'IndicesMapToDataType'
            otherwise
                mywarn(['unrecognized Vertices attribute "' attr{1}.key '"'], filename);
        end
    end
    if ~isfield(map, 'length') || isnan(exponent) || ~isfield(map, 'seriesStart') || ~isfield(map, 'seriesStep') || ~isfield(map, 'seriesUnit')
        myerror('missing required attribute in series map', filename);
    end
    map.seriesStart = map.seriesStart * 10^exponent;
    map.seriesStep = map.seriesStep * 10^exponent;
end

function map = cifti_parse_scalars(tree, map_uid, filename)
    map = struct('type', 'scalars');
    mapel_uids = child_match(tree, map_uid, 'NamedMap');
    map.length = length(mapel_uids);
    if map.length == 0
        myerror('empty scalars mapping', filename);
    end
    map.maps = struct('name', cell(1, map.length), 'metadata', cell(1, map.length));
    for i = 1:map.length
        thismap = struct();
        thismap.metadata = cifti_parse_metadata(tree, child_match(tree, mapel_uids(i), 'MetaData'), filename);
        name_uid = child_match(tree, mapel_uids(i), 'MapName');
        if ~isscalar(name_uid)
            myerror('MapName element missing or repeated in a NamedMap', filename);
        end
        thismap.name = mygettext(tree, name_uid);
        map.maps(i) = thismap;
    end
end

function map = cifti_parse_labels(tree, map_uid, filename)
    map = struct('type', 'labels');
    mapel_uids = child_match(tree, map_uid, 'NamedMap');
    map.length = length(mapel_uids);
    if map.length == 0
        myerror('empty labels mapping', filename);
    end
    map.maps = struct('name', cell(1, map.length), 'metadata', cell(1, map.length), 'table', cell(1, map.length));
    for i = 1:map.length
        thismap = struct();
        thismap.metadata = cifti_parse_metadata(tree, child_match(tree, mapel_uids(i), 'MetaData'), filename);
        name_uid = child_match(tree, mapel_uids(i), 'MapName');
        if ~isscalar(name_uid)
            myerror('MapName element missing or repeated in a label-type NamedMap', filename);
        end
        thismap.name = mygettext(tree, name_uid);
        table_uid = child_match(tree, mapel_uids(i), 'LabelTable');
        if ~isscalar(table_uid)
            myerror('LabelTable element missing or repeated in a label-type NamedMap', filename);
        end
        label_uids = child_match(tree, table_uid, 'Label');
        numlabels = length(label_uids);
        temptable = struct('name', cell(1, numlabels), 'key', cell(1, numlabels), 'rgba', cell(1, numlabels));
        for j = 1:numlabels
            thislabel = struct();
            thislabel.name = mygettext(tree, label_uids(j));
            thislabel.rgba = nan(4, 1);
            attrs = myattrs(tree, label_uids(j));
            for attr = attrs
                switch attr{1}.key
                    case 'Key'
                        thislabel.key = str2double(attr{1}.val);
                        if mod(thislabel.key, 1) ~= 0
                            myerror('noninteger label key', filename);
                        end
                    case 'Red'
                        colorval = str2double(attr{1}.val);
                        if colorval < 0 || colorval > 1
                            myerror('label color value outside the range [0, 1]', filename);
                        end
                        thislabel.rgba(1) = colorval;
                    case 'Green'
                        colorval = str2double(attr{1}.val);
                        if colorval < 0 || colorval > 1
                            myerror('label color value outside the range [0, 1]', filename);
                        end
                        thislabel.rgba(2) = colorval;
                    case 'Blue'
                        colorval = str2double(attr{1}.val);
                        if colorval < 0 || colorval > 1
                            myerror('label color value outside the range [0, 1]', filename);
                        end
                        thislabel.rgba(3) = colorval;
                    case 'Alpha'
                        colorval = str2double(attr{1}.val);
                        if colorval < 0 || colorval > 1
                            myerror('label color value outside the range [0, 1]', filename);
                        end
                        thislabel.rgba(4) = colorval;
                    otherwise
                        mywarn(['unrecognized Label attribute "' attr{1}.key '"'], filename);
                end
            end
            if ~isfield(thislabel, 'key') || any(isnan(thislabel.rgba))
                myerror('missing or invalid required attribute of Label', filename);
            end
            temptable(j) = thislabel;
        end
        if length(unique([temptable.key])) ~= length(temptable)
            warning(['label table contains duplicate key value in map ' num2str(i)]);
        end
        [~, torder] = sort([temptable.key]);
        thismap.table = temptable(torder);
        map.maps(i) = thismap;
    end
end

