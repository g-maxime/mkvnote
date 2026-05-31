##  Copyright (c) MediaArea.net SARL. All Rights Reserved.
 #
 #  Use of this source code is governed by a BSD-style license that can
 #  be found in the License.html file in the root of the source tree.
 ##

#!/bin/bash

set -e # fail on any error

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
    "${release_directory}/../Project/OBS/mkvnote.spec"
    "${release_directory}/../Project/OBS/mkvnote.dsc"
    "${release_directory}/../Project/OBS/PKGBUILD"
    "${release_directory}/../mkvnote"
    "${release_directory}/../main.cpp"
    "${release_directory}/../mainwindow.cpp"
)

for file in "${files_dot[@]}"; do
   sed -i "s/${version_old//./\\.}/${version}/g" "${file}"
done

#-----------------------------------------------------------------------
# Update changelogs

date_rfc2822="$(LC_ALL=C date -u -R)"
debian_changelog="${release_directory}/../Project/OBS/debian.changelog"
cat - <<EOF > "${debian_changelog}.new"
mkvnote (${version}-1) stable; urgency=medium

  * Update to version ${version}

 -- MediaArea CI <info@mediaarea.net>  ${date_rfc2822}

EOF

sed -i "1e cat ${debian_changelog}.new" "${debian_changelog}"
rm -f "${debian_changelog}.new"

date_rpm="$(LC_ALL=C date -u '+%a %b %e %Y' | sed 's/  / /g')"
rpm_changelog="${release_directory}/../Project/OBS/mkvnote.changes"
cat - <<EOF > "${rpm_changelog}.new"
* ${date_rpm} MediaArea CI <info@mediaarea.net> - ${version}
- Version ${version}

EOF

sed -i "1e cat ${rpm_changelog}.new" "${rpm_changelog}"
rm -f "${rpm_changelog}.new"