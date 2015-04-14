#!/bin/bash

get_fsl_version()
{
	local fsl_version_file
	local fsl_version
	local __functionResultVar=${1}

	fsl_version_file="${FSLDIR}/etc/fslversion"
	
	if [ -f ${fsl_version_file} ]
	then
		fsl_version=`cat ${fsl_version_file}`
		echo "INFO: Determined that the FSL version in use is: ${fsl_version}"
	else
		echo "ERROR: Cannot tell which version of FSL you are using."
		exit 1
	fi

	eval $__functionResultVar="'${fsl_version}'"
}

# get_fsl_version_based_on_fslmaths()
# {
# 	local which_fslmaths
# 	local fsl_bin_directory
# 	local fsl_version_file
# 	local fsl_version
# 	local __functionResultVar=${1}

# 	# Try to locate the fslversion file based on where fslmaths is found
# 	which_fslmaths=`which fslmaths`
# 	fsl_bin_directory=`dirname ${which_fslmaths}`
# 	fsl_version_file="${fsl_bin_directory}/../etc/fslversion"
	
# 	if [ -f ${fsl_version_file} ]
# 	then
# 		# We've found the file containing fsl version information based on the location of fslmaths
# 		fsl_version=`cat ${fsl_version_file}`
# 		echo "INFO: I've determined that the FSL version in use is: ${fsl_version}"
# 	else
# 		# We couldn't file the fslversion file based on the location of fslmaths.
# 		# Let's try looking in a "standard" location
# 		if [ -d /usr/share ]
# 		then 
# 			fsl_version_file=`find /usr/share -name 'fslversion'`
# 			if [[ "${fsl_version_file}" == *" "* ]]
# 			then
# 				echo "ERROR: There is a possibility that there are multiple versions of FSL installed"
# 				echo "ERROR: and I cannot tell which one you are using."
# 				exit
# 			fi
# 			fsl_version=`cat ${fsl_version_file}`
# 			echo "WARNING: I've determined that the FSL version in use is: ${fsl_version}"
# 			echo "WARNING: But I had to do some \"guessing\". So you need to verify that I've determined correctly."
# 		else
# 			echo "ERROR: I cannot tell which version of FSL you are using."
# 			exit
# 		fi
# 	fi

# 	eval $__functionResultVar="'${fsl_version}'"
# }

determine_old_or_new_fslmaths()
{
	local fsl_version=${1}
	local old_or_new
	local fsl_version_array
	local fsl_primary_version
	local fsl_secondary_version
	local fsl_tertiary_version

	echo "Working with fsl_version: ${fsl_version}"

	# parse the FSL version information into primary, secondary, and tertiary parts
	fsl_version_array=(${fsl_version//./ })

	fsl_primary_version="${fsl_version_array[0]}"
	fsl_primary_version=${fsl_primary_version//[!0-9]/}
	echo "fsl_primary_version: ${fsl_primary_version}"
	
	fsl_secondary_version="${fsl_version_array[1]}"
	fsl_secondary_version=${fsl_secondary_version//[!0-9]/}
	echo "fsl_secondary_version: ${fsl_secondary_version}"
	
	fsl_tertiary_version="${fsl_version_array[2]}"
	fsl_tertiary_version=${fsl_tertiary_version//[!0-9]/}
	echo "fsl_tertiary_version: ${fsl_tertiary_version}"
	
	if [[ $(( ${fsl_primary_version} )) -lt 5 ]]
	then
		echo "We are working with a version prior to 5.0.0"
		old_or_new="OLD"
	elif [[ $(( ${fsl_primary_version} )) -gt 5 ]]
	then
		echo "We are working with version 6.0.0 or above"
		old_or_new="NEW"
	else
		echo "We are working with version 5.x.x"
		if [[ $(( ${fsl_secondary_version} )) -gt 0 ]]
		then
			echo "We are working with version 5.1.x"
			old_or_new="NEW"
		else
			echo "We are working with version 5.0.x"
			fsl_tertiary_version_number=$(( ${fsl_tertiary_version} ))
			if [[ $(( ${fsl_tertiary_version} )) -le 6 ]]
			then
				echo "We are working with version 5.0.0 - 5.0.6"
				old_or_new="OLD"
			else
				echo "We are working with version 5.0.7 or above"
				old_or_new="NEW"
			fi
		fi
	fi
	
	echo ${old_or_new}
}


#get_fsl_version_based_on_fslmaths fsl_ver
#echo "fsl_ver: ${fsl_ver}"

get_fsl_version fsl_ver
echo "fsl_ver: ${fsl_ver}"

OLD_OR_NEW_FSLMATHS=$(determine_old_or_new_fslmaths ${fsl_ver})
echo "OLD_OR_NEW_FSLMATHS: ${OLD_OR_NEW_FSLMATHS}"




