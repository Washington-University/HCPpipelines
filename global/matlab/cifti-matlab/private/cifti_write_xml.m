function outbytes = cifti_write_xml(cifti, keep_metadata)
    if ~(nargin > 1 && keep_metadata)
        prov = cifti_metadata_get(cifti.metadata, 'Provenance');
        cifti.metadata = struct('key', 'Provenance', 'value', 'cifti_write_xml.m v1.0');
        if ~isempty(prov)
            cifti.metadata = cifti_metadata_set(cifti.metadata, 'ParentProvenance', prov);
        end
    end
    tree = xmltreemod();
    root_uid = root(tree);
    tree = set(tree, root_uid, 'name', 'CIFTI');
    tree = attributes(tree, 'add', root_uid, 'Version', '2');
    [tree, matrix_uid] = add(tree, root_uid, 'element', 'Matrix');
    tree = cifti_write_metadata(cifti.metadata, tree, matrix_uid);
    tree = cifti_write_maps(cifti, tree, matrix_uid);
    outbytes = save_string(tree); %modified version of save() that doesn't add formatting whitespace in bad places
end

function tree = cifti_write_metadata(metadata, tree, matrix_uid)
    if isempty(metadata)
        return
    end
    [tree, meta_uid] = add(tree, matrix_uid, 'element', 'MetaData');
    for i = 1:length(metadata)
        [tree, md_uid] = add(tree, meta_uid, 'element', 'MD');
        [tree, name_uid] = add(tree, md_uid, 'element', 'Name');
        tree = add(tree, name_uid, 'chardata', metadata(i).key);
        [tree, val_uid] = add(tree, md_uid, 'element', 'Value');
        tree = add(tree, val_uid, 'chardata', metadata(i).value);
    end
end

function tree = cifti_write_maps(cifti, tree, matrix_uid)
    mapused = false(length(cifti.diminfo), 1);
    for i = 1:length(cifti.diminfo)
        if mapused(i)
            continue;
        end
        if i < 3 %NOTE: first and second dims are swapped compared to on disk, because of ciftiopen convention
            appliesto = sprintf('%d', 2 - i); %NOTE: no, this isn't complex, and on disk needs 0-based numbers
        else
            appliesto = sprintf('%d', i - 1);
        end
        for j = (i + 1):length(cifti.diminfo)
            %consider simplifying maps, like removing the volume space if voxels aren't used and sorting parcel member lists, to make this equality "less picky"
            if ~mapused(j) && isequaln(cifti.diminfo{i}, cifti.diminfo{j})
                if j < 3
                    appliesto = [appliesto ',' sprintf('%d', 2 - j)]; %#ok<AGROW>
                else
                    appliesto = [appliesto ',' sprintf('%d', j - 1)]; %#ok<AGROW>
                end
                mapused(j) = true;
            end
        end
        [tree, map_uid] = add(tree, matrix_uid, 'element', 'MatrixIndicesMap');
        tree = attributes(tree, 'add', map_uid, 'AppliesToMatrixDimension', appliesto); %NOTE: 1-based matlab indexing
        switch cifti.diminfo{i}.type
            case 'dense'
                tree = cifti_write_dense(cifti.diminfo{i}, tree, map_uid);
            case 'parcels'
                tree = cifti_write_parcels(cifti.diminfo{i}, tree, map_uid);
            case 'series'
                tree = cifti_write_series(cifti.diminfo{i}, tree, map_uid);
            case 'scalars'
                tree = cifti_write_scalars(cifti.diminfo{i}, tree, map_uid);
            case 'labels'
                tree = cifti_write_labels(cifti.diminfo{i}, tree, map_uid);
            otherwise
                error(['unrecognized mapping type "' cifti.diminfo{i}.type '"']);
        end
    end
end

function tree = cifti_write_dense(map, tree, map_uid)
    tree = attributes(tree, 'add', map_uid, 'IndicesMapToDataType', 'CIFTI_INDEX_TYPE_BRAIN_MODELS');
    %TODO: check if map.vol is actually needed by mapping?
    tree = cifti_write_vol(map.vol, tree, map_uid); %also used by parcels
    for model = map.models(:)'
        if model{1}.start + model{1}.count - 1 > map.length
            error('length attribute is less than dense map content'); %TODO: check for gaps and overlap?
        end
        [tree, model_uid] = add(tree, map_uid, 'element', 'BrainModel');
        tree = attributes(tree, 'add', model_uid, 'IndexOffset', num2str(model{1}.start - 1)); %NOTE: 1-based cifti indices
        tree = attributes(tree, 'add', model_uid, 'IndexCount', num2str(model{1}.count));
        tree = attributes(tree, 'add', model_uid, 'BrainStructure', friendly_to_cifti_structure(model{1}.struct));
        switch model{1}.type
            case 'surf'
                if length(model{1}.vertlist) ~= model{1}.count
                    error('model vertex list does not match count');
                end
                if any(model{1}.vertlist < 0 | model{1}.vertlist >= model{1}.numvert | mod(model{1}.vertlist, 1) ~= 0)
                    error('vertex list contains invalid vertex numbers');
                end
                tree = attributes(tree, 'add', model_uid, 'ModelType', 'CIFTI_MODEL_TYPE_SURFACE');
                tree = attributes(tree, 'add', model_uid, 'SurfaceNumberOfVertices', num2str(model{1}.numvert));
                [tree, vert_uid] = add(tree, model_uid, 'element', 'VertexIndices');
                tree = add(tree, vert_uid, 'chardata', vertlist2str(model{1}.vertlist(:)')); %NOTE: 0-based vertex indices
            case 'vox'
                if size(model{1}.voxlist, 1) == model{1}.count && size(model{1}.voxlist, 2) == 3
                    warning('model voxel list appears to be transposed');
                    model{1}.voxlist = model{1}.voxlist'; %#ok<FXSET>
                end
                if size(model{1}.voxlist, 2) ~= model{1}.count
                    error('model voxel list does not match count');
                end
                if size(model{1}.voxlist, 1) ~= 3
                    error('model voxel list does not contain 3 indices per voxel');
                end
                if any(model{1}.voxlist < 0 | model{1}.voxlist >= repmat(map.vol.dims', 1, model{1}.count))
                    error('invalid voxlist content in cifti struct');
                end
                tree = attributes(tree, 'add', model_uid, 'ModelType', 'CIFTI_MODEL_TYPE_VOXELS');
                [tree, vox_uid] = add(tree, model_uid, 'element', 'VoxelIndicesIJK');
                tree = add(tree, vox_uid, 'chardata', voxlist2str(model{1}.voxlist'));
            otherwise
                error(['unrecignized brain model type "' model{1}.type '"']);
        end
    end
end

function outstr = friendly_to_cifti_structure(instr)
    switch instr
        case 'ACCUMBENS_LEFT'; outstr = 'CIFTI_STRUCTURE_ACCUMBENS_LEFT';
        case 'ACCUMBENS_RIGHT'; outstr = 'CIFTI_STRUCTURE_ACCUMBENS_RIGHT';
        case 'ALL_WHITE_MATTER'; outstr = 'CIFTI_STRUCTURE_ALL_WHITE_MATTER';
        case 'ALL_GREY_MATTER'; outstr = 'CIFTI_STRUCTURE_ALL_GREY_MATTER';
        case 'AMYGDALA_LEFT'; outstr = 'CIFTI_STRUCTURE_AMYGDALA_LEFT';
        case 'AMYGDALA_RIGHT'; outstr = 'CIFTI_STRUCTURE_AMYGDALA_RIGHT';
        case 'BRAIN_STEM'; outstr = 'CIFTI_STRUCTURE_BRAIN_STEM';
        case 'CAUDATE_LEFT'; outstr = 'CIFTI_STRUCTURE_CAUDATE_LEFT';
        case 'CAUDATE_RIGHT'; outstr = 'CIFTI_STRUCTURE_CAUDATE_RIGHT';
        case 'CEREBELLAR_WHITE_MATTER_LEFT'; outstr = 'CIFTI_STRUCTURE_CEREBELLAR_WHITE_MATTER_LEFT';
        case 'CEREBELLAR_WHITE_MATTER_RIGHT'; outstr = 'CIFTI_STRUCTURE_CEREBELLAR_WHITE_MATTER_RIGHT';
        case 'CEREBELLUM'; outstr = 'CIFTI_STRUCTURE_CEREBELLUM';
        case 'CEREBELLUM_LEFT'; outstr = 'CIFTI_STRUCTURE_CEREBELLUM_LEFT';
        case 'CEREBELLUM_RIGHT'; outstr = 'CIFTI_STRUCTURE_CEREBELLUM_RIGHT';
        case 'CEREBRAL_WHITE_MATTER_LEFT'; outstr = 'CIFTI_STRUCTURE_CEREBRAL_WHITE_MATTER_LEFT';
        case 'CEREBRAL_WHITE_MATTER_RIGHT'; outstr = 'CIFTI_STRUCTURE_CEREBRAL_WHITE_MATTER_RIGHT';
        case 'CORTEX'; outstr = 'CIFTI_STRUCTURE_CORTEX';
        case 'CORTEX_LEFT'; outstr = 'CIFTI_STRUCTURE_CORTEX_LEFT';
        case 'CORTEX_RIGHT'; outstr = 'CIFTI_STRUCTURE_CORTEX_RIGHT';
        case 'DIENCEPHALON_VENTRAL_LEFT'; outstr = 'CIFTI_STRUCTURE_DIENCEPHALON_VENTRAL_LEFT';
        case 'DIENCEPHALON_VENTRAL_RIGHT'; outstr = 'CIFTI_STRUCTURE_DIENCEPHALON_VENTRAL_RIGHT';
        case 'HIPPOCAMPUS_LEFT'; outstr = 'CIFTI_STRUCTURE_HIPPOCAMPUS_LEFT';
        case 'HIPPOCAMPUS_RIGHT'; outstr = 'CIFTI_STRUCTURE_HIPPOCAMPUS_RIGHT';
        case 'OTHER'; outstr = 'CIFTI_STRUCTURE_OTHER';
        case 'OTHER_GREY_MATTER'; outstr = 'CIFTI_STRUCTURE_OTHER_GREY_MATTER';
        case 'OTHER_WHITE_MATTER'; outstr = 'CIFTI_STRUCTURE_OTHER_WHITE_MATTER';
        case 'PALLIDUM_LEFT'; outstr = 'CIFTI_STRUCTURE_PALLIDUM_LEFT';
        case 'PALLIDUM_RIGHT'; outstr = 'CIFTI_STRUCTURE_PALLIDUM_RIGHT';
        case 'PUTAMEN_LEFT'; outstr = 'CIFTI_STRUCTURE_PUTAMEN_LEFT';
        case 'PUTAMEN_RIGHT'; outstr = 'CIFTI_STRUCTURE_PUTAMEN_RIGHT';
        case 'THALAMUS_LEFT'; outstr = 'CIFTI_STRUCTURE_THALAMUS_LEFT';
        case 'THALAMUS_RIGHT'; outstr = 'CIFTI_STRUCTURE_THALAMUS_RIGHT';
        otherwise
            error(['invalid structure name "' instr '"in cifti struct']);
    end
end

function tree = cifti_write_vol(vol, tree, map_uid)
    %may be called on empty struct, in which case it should do nothing
    if isempty(vol) || ~isfield(vol, 'dims')
        return
    end
    [tree, vol_uid] = add(tree, map_uid, 'element', 'Volume');
    if length(vol.dims(:)) ~= 3 || any(vol.dims(:) < 1)
        error('volume dimensions must consist of 3 positive values');
    end
    tree = attributes(tree, 'add', vol_uid, 'VolumeDimensions', [num2str(vol.dims(1)) ',' num2str(vol.dims(2)) ',' num2str(vol.dims(3))]); %standard says it needs commas
    [tree, tfm_uid] = add(tree, vol_uid, 'element', 'TransformationMatrixVoxelIndicesIJKtoXYZ');
    if any(size(vol.sform) ~= [4 4]) || any(vol.sform(4, :) ~= [0 0 0 1])
        error('malformed sform in cifti structure');
    end
    max_spacing = max(max(abs(vol.sform(1:3, 1:3))));
    exponent = 3 * floor((log10(max_spacing) - log10(50)) / 3); %find exponent that is a multiple of 3 which puts abs of largest spacing number in [0.05, 50]
    if isnan(exponent) || isinf(exponent)
        warning('bad values in sform in cifti structure');
        exponent = -3; %use mm if sform is zeros or inf or nan
    end
    tree = attributes(tree, 'add', tfm_uid, 'MeterExponent', num2str(exponent));
    modsform = vol.sform / (10^(exponent + 3)); % convert from mm to given meter exponent
    tree = add(tree, tfm_uid, 'chardata', sform2str(modsform));
end

%sprintf is (much) faster, and allows "single space" formatting, but is dumb about columns vs rows and doesn't understand matrix dimensions
function outstring = voxlist2str(input)
    outstring = sprintf('%d %d %d\n', input');
end

function outstring = vertlist2str(input)
    outstring = sprintf('%d ', input);
end

function outstring = sform2str(input)
    outstring = sprintf('\n%.7f %.7f %.7f %.7f', input');
end

function tree = cifti_write_parcels(map, tree, map_uid)
    if length(map.parcels) ~= map.length
        error('number of parcels is not equal to map length in cifti struct');
    end
    tree = attributes(tree, 'add', map_uid, 'IndicesMapToDataType', 'CIFTI_INDEX_TYPE_PARCELS');
    %TODO: check if map.vol is actually needed by mapping?
    tree = cifti_write_vol(map.vol, tree, map_uid);
    %TODO: check if all surfaces are used?  valid structures?
    for i = 1:length(map.surflist)
        if (map.surflist(i).numvert < 1)
            error('invalid numvert in cifti struct');
        end
        [tree, surf_uid] = add(tree, map_uid, 'element', 'Surface');
        tree = attributes(tree, 'add', surf_uid, 'BrainStructure', friendly_to_cifti_structure(map.surflist(i).struct));
        tree = attributes(tree, 'add', surf_uid, 'SurfaceNumberOfVertices', num2str(map.surflist(i).numvert));
    end
    for i = 1:length(map.parcels)
        [tree, parcel_uid] = add(tree, map_uid, 'element', 'Parcel');
        tree = attributes(tree, 'add', parcel_uid, 'Name', map.parcels(i).name);
        if ~isempty(map.parcels(i).voxlist)
            if size(map.parcels(i).voxlist, 1) ~= 3 && size(map.parcels(i).voxlist, 2) == 3
                warning('parcel voxlist seems transposed in cifti struct');
                map.parcels(i).voxlist = map.parcels(i).voxlist';
            end
            if size(map.parcels(i).voxlist, 1) ~= 3
                error('malformed voxlist in cifti struct');
            end
            if any(map.parcels(i).voxlist < 0 | map.parcels(i).voxlist >= repmat(map.vol.dims', 1, size(map.parcels(i).voxlist, 2)))
                error('invalid voxlist content in cifti struct');
            end
            [tree, vox_uid] = add(tree, parcel_uid, 'element', 'VoxelIndicesIJK');
            tree = add(tree, vox_uid, 'chardata', voxlist2str(map.parcels(i).voxlist'));
        end
        for j = 1:length(map.parcels(i).surfs)
            numverts = -1;
            for k = 1:length(map.surflist)
                if strcmp(map.parcels(i).surfs(j).struct, map.surflist(k).struct)
                    numverts = map.surflist(k).numvert;
                    break;
                end
            end
            if (numverts == -1)
                error('parcel uses surface that is not defined in cifti struct');
            end
            if any(map.parcels(i).surfs(j).vertlist < 0 | map.parcels(i).surfs(j).vertlist >= numverts)
                error('invalid vertlist content in cifti struct');
            end
            [tree, vert_uid] = add(tree, parcel_uid, 'element', 'Vertices');
            tree = attributes(tree, 'add', vert_uid, 'BrainStructure', friendly_to_cifti_structure(map.parcels(i).surfs(j).struct));
            tree = add(tree, vert_uid, 'chardata', vertlist2str(map.parcels(i).surfs(j).vertlist));
        end
    end
end

function tree = cifti_write_series(map, tree, map_uid)
    testval = map.seriesStep;
    if map.seriesStep == 0
        warning('seriesStep is zero in cifti struct');
        testval = map.seriesStart;
    end
    exponent = 3 * floor((log10(testval) - log10(0.05)) / 3); %find good exponent - vol uses log10(50) because sform is mm, but exponent was meters
    %for spatial units in series, reported units are meters, so log10(0.05) instead
    if isnan(exponent) || isinf(exponent)
        warning('bad values for seriesStep or seriesStart in cifti struct');
        exponent = 0;
    end
    switch map.seriesUnit
        case 'SECOND'
        case 'HERTZ'
        case 'METER'
        case 'RADIAN'
        otherwise
            error('invalid seriesUnit in cifti struct');
    end
    tree = attributes(tree, 'add', map_uid, 'IndicesMapToDataType', 'CIFTI_INDEX_TYPE_SERIES');
    tree = attributes(tree, 'add', map_uid, 'SeriesExponent', num2str(exponent));
    tree = attributes(tree, 'add', map_uid, 'SeriesUnit', map.seriesUnit);
    tree = attributes(tree, 'add', map_uid, 'SeriesStart', num2str(map.seriesStart / 10^exponent, 6));
    tree = attributes(tree, 'add', map_uid, 'SeriesStep', num2str(map.seriesStep / 10^exponent, 6));
    tree = attributes(tree, 'add', map_uid, 'NumberOfSeriesPoints', num2str(map.length));
end

function tree = cifti_write_scalars(map, tree, map_uid)
    if map.length ~= length(map.maps) %error to be on the safe side - users won't call the xml writing code directly anyway
        error('number of scalar maps is not equal to map length in cifti struct');
    end
    tree = attributes(tree, 'add', map_uid, 'IndicesMapToDataType', 'CIFTI_INDEX_TYPE_SCALARS');
    for i = 1:length(map.maps)
        [tree, nm_uid] = add(tree, map_uid, 'element', 'NamedMap');
        [tree, name_uid] = add(tree, nm_uid, 'element', 'MapName');
        tree = add(tree, name_uid, 'chardata', map.maps(i).name);
        tree = cifti_write_metadata(map.maps(i).metadata, tree, nm_uid);
    end
end

function tree = cifti_write_labels(map, tree, map_uid)
    if map.length ~= length(map.maps) %error to be on the safe side - users won't call the xml writing code directly anyway
        error('number of label maps is not equal to map length in cifti struct');
    end
    tree = attributes(tree, 'add', map_uid, 'IndicesMapToDataType', 'CIFTI_INDEX_TYPE_LABELS');
    for i = 1:length(map.maps)
        [tree, nm_uid] = add(tree, map_uid, 'element', 'NamedMap');
        [tree, name_uid] = add(tree, nm_uid, 'element', 'MapName');
        tree = add(tree, name_uid, 'chardata', map.maps(i).name);
        tree = cifti_write_metadata(map.maps(i).metadata, tree, nm_uid);
        [tree, table_uid] = add(tree, nm_uid, 'element', 'LabelTable');
        if length(unique([map.maps(i).table.key])) ~= length(map.maps(i).table)
            error(['label table contains duplicate key value in map ' num2str(i)]);
        end
        [~, torder] = sort([map.maps(i).table.key]); %write the table in sorted order
        for jind = 1:length(map.maps(i).table)
            j = torder(jind);
            [tree, label_uid] = add(tree, table_uid, 'element', 'Label');
            tree = attributes(tree, 'add', label_uid, 'Key', num2str(map.maps(i).table(j).key));
            tree = attributes(tree, 'add', label_uid, 'Red', num2str(map.maps(i).table(j).rgba(1), 6));
            tree = attributes(tree, 'add', label_uid, 'Green', num2str(map.maps(i).table(j).rgba(2), 6));
            tree = attributes(tree, 'add', label_uid, 'Blue', num2str(map.maps(i).table(j).rgba(3), 6));
            tree = attributes(tree, 'add', label_uid, 'Alpha', num2str(map.maps(i).table(j).rgba(4), 6));
            tree = add(tree, label_uid, 'chardata', map.maps(i).table(j).name);
        end
    end
end
