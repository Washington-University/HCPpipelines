MATLAB code for reading and writing CIFTI files, v2
==================================================================

This library is compatible with the CIFTI-2 format, without
externally installed dependencies (except that CIFTI-1 files require
wb_command for conversion), returning a structure that exposes the
information contained in the CIFTI-2 XML with minimal translation, as well
as the data matrix with no added padding.  The cifti_read function is
the intended starting point, ciftiopen and similar are compatibility
wrappers so that the library can be used in older code.

Additionally, the library provides numerous helper functions to make many
common operations (such as extracting the data for one structure) into a
single line of intuitive code.

The previous code that was derived from FieldTrip is in the "ft_cifti"
folder.

The cifti structure returned by this library uses 0-based
indices for vertex and voxel indices, 1-based for cifti indices, and
the helper functions return 1-based indices for everything.

# Usage
All exposed functions have usage information available through the `help` command:

```
>> help cifti_read
 function outstruct = cifti_read(filename, ...)
    Read a cifti file.
...
```

The simplest practical usage is to load a cifti file with `cifti_read`, take
its data from the `.cdata` field, modify it, store it back into the `.cdata` field,
and write it back out to a new file with `cifti_write`:

```octave
mycifti = cifti_read('something.dscalar.nii');
mycifti.cdata = sqrt(mycifti.cdata);
cifti_write(mycifti, 'sqrt.dscalar.nii');
```

The `ciftiopen`, `ciftisave`, and `ciftisavereset` functions provide backward
compatibility with a previous cifti library (option II of
[HCP FAQ 2](https://wiki.humanconnectome.org/display/PublicData/HCP+Users+FAQ#HCPUsersFAQ-2.HowdoyougetCIFTIfilesintoMATLAB?)),
and you can also use this `ciftisavereset` function even if you use `cifti_read`.
An alternative way to do the equivalent of `ciftisavereset` is to use the
`cifti_write_from_template` helper function (which also has options to set
the names of the maps for dscalar, and similar for other cifti file types):

```octave
mycifti = cifti_read('something.dscalar.nii');
cifti_write_from_template(mycifti, mycifti.cdata(:, 1), 'firstmap.dscalar.nii', 'namelist', {'map #1'});

%ciftisavereset equivalent (keeping 'mycifti' unmodified):
mycifti = cifti_read('something.dscalar.nii');
newcifti = mycifti;
newcifti.cdata = mycifti.cdata(:, 1);
ciftisavereset(newcifti, 'firstmap.dscalar.nii');
clear newcifti;
```

The `cifti_struct_create_from_template` function can create a cifti struct without writing
it to a file, with the same options as `cifti_write_from_template` to control the other
diminfo.  The `cifti_write...` or `cifti_struct...` functions should handle most cases of
working with common cifti files, including extracting the data for one cortical surface,
doing some computation on it, and replacing the surface data with the new values:

```octave
mycifti = cifti_read('something.dscalar.nii');
leftdata = cifti_struct_dense_extract_surface_data(mycifti, 'CORTEX_LEFT');
newleftdata = 1 - leftdata;
newcifti = cifti_struct_dense_replace_surface_data(mycifti, newleftdata, 'CORTEX_LEFT');
...
```

The `dense` part of some function names refers to only being applicable to "dense" files
or diminfo (in cifti xml terms, a "brain models" mapping), such as dtseries, dscalar,
dlabel, or dconn.  There are more `dense` helpers mainly because there is a more common
need to make use of the information in a dense diminfo than most other diminfo types.

The `cifti_diminfo_*` helpers are lower-level and require more understanding of the
details of the cifti format, and often require writing more code to use them, so you
should generally look at the `cifti_write...` and `cifti_struct...` functions first.

# Function reference
## Main functions
### read/write and compatibility
```
outstruct = cifti_read(filename, ...)
cifti_write(cifti, filename, ...)

cifti = ciftiopen(filename, ...)     %note: these 3 do not use option pairs,
ciftisave(cifti, filename, ...)      %  the varargin here is to make passing 'wb_command' optional
ciftisavereset(cifti, filename, ...)
```
### struct create helpers and write convenience functions
```
cifti = cifti_struct_create_from_template(ciftitemplate, data, type, ...)
cifti_write_from_template(ciftitemplate, data, filename, ...)

cifti = cifti_struct_create_sdseries(data, ...)
cifti_write_sdseries(data, filename, ...)
```
### dense struct extract/replace helpers
```
[outdata, outroi] = cifti_struct_dense_extract_surface_data(cifti, structure[, dimension])
cifti = cifti_struct_dense_replace_surface_data(cifti, data, structure[, dimension])

[outdata, outsform1, outroi] = cifti_struct_dense_extract_volume_all_data(cifti[, cropped, dimension])
cifti = cifti_struct_dense_replace_volume_all_data(cifti, data[, cropped, dimension])

[outdata, outsform1, outroi] = cifti_struct_dense_extract_volume_structure_data(cifti, structure[, cropped, dimension])
cifti = cifti_struct_dense_replace_volume_structure_data(cifti, data, structure[, cropped, dimension])
```
### misc
```
[surflist, vollist] = cifti_diminfo_dense_get_structures(diminfo)     %returns the names of structures that exist in this diminfo

outstring = cifti_metadata_get(metadata, key)           %returns empty string for nonexistent key
metadata = cifti_metadata_remove(metadata, key)         %returns unmodified metadata struct for nonexistent key
metadata = cifti_metadata_set(metadata, key, value)     %overwrites key if it exists
```
## Special usage
### advanced diminfo helpers
```
outinfo = cifti_diminfo_dense_get_surface_info(diminfo, structure)
outinfo = cifti_diminfo_dense_get_volume_all_info(diminfo[, cropped])
outinfo = cifti_diminfo_dense_get_volume_structure_info(diminfo, structure[, cropped])

outmap = cifti_diminfo_make_scalars(nummaps[, namelist, metadatalist])
outmap = cifti_diminfo_make_series(nummaps[, start, step, unit])
```
### advanced misc
```
indices = cifti_vox2ind(dims, voxlist1)         %helper to act like sub2ind for voxel ijk lists
```
