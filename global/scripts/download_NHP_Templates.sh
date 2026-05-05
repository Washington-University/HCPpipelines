#!/bin/bash
set -eu

scriptloc="$(dirname "$0")"

cd "$scriptloc"/../templates/

wget -O NHP_NNP_Templates-20260504.zip 'https://balsa.wustl.edu/myelin/download?dirName=public&filepath=NHP_NNP_Templates-20260504.zip&dirPass='
unzip NHP_NNP_Templates-20260504.zip

