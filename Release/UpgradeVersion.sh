##  Copyright (c) MediaArea.net SARL. All Rights Reserved.
 #
 #  Use of this source code is governed by a BSD-style license that can
 #  be found in the License.html file in the root of the source tree.
 ##

#!/bin/bash

set -e # fail on any error
set -x
if [ "${#}" -ne 1 ]; then
    echo "Usage: ${0} version"
    exit 1
fi

#-----------------------------------------------------------------------
# Setup
release_directory="$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")")"
version="${1}"
version_old="$(<"${release_directory}/../Project/version.txt")"

#-----------------------------------------------------------------------
# Processing versions with dots

files_dot=(
    "${release_directory}/../Project/version.txt"
    "${release_directory}/../mkvnote"
    "${release_directory}/../main.cpp"
    "${release_directory}/../mainwindow.cpp"
)

for file in "${files_dot[@]}"; do
   sed -i.bak "s/${version_old//./\\.}/${version}/g" "${file}"
   rm -f "${file}.bak"
done
