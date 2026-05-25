##  Copyright (c) MediaArea.net SARL. All Rights Reserved.
 #
 #  Use of this source code is governed by a BSD-style license that can
 #  be found in the License.html file in the root of the source tree.
 ##

#!/bin/bash

# This has the followind dependencies:
# - cmake
# - ninja
# - Qt6 static build (<QtPrefix>/lib/cmake must be in the CMAKE_MODULE_PATH environment variable and <QtPrefix>/bin must be in the PATH).

# This script uses the following environment variables:
# - MACOS_CODESIGN_IDENTITY: The subject and ID part of the Apple development certificate (optional).

set -e

#-----------------------------------------------------------------------
# Setup
release_directory="$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")")"
version="$(<"${release_directory}/../Project/version.txt")"

#-----------------------------------------------------------------------
# Cleanup
rm -fr "${release_directory}/mediainfo_ROOT"
rm -f "${release_directory}/MediaInfo.dmg"
rm -f "${release_directory}/mediainfo.pkg"

rm -f "${release_directory}/MKVToolNix-42.0.0.dmg"

rm -fr "${release_directory}/mkvnote_BUILD"
rm -fr "${release_directory}/mkvnote_ROOT"

rm -f "${release_directory}/mkvnote.entitlements"
rm -f "${release_directory}/mkvnote.pkg" 
rm -f "${release_directory}/mkvnote-unsigned.pkg" 
rm -f "${release_directory}/mkvnote_${version}_Mac.dmg" 

mkdir -p "${release_directory}"/mkvnote_ROOT/usr/local/{bin,lib/mkvnote/bin}


#-----------------------------------------------------------------------
# Get MediaInfo CLI
pushd "${release_directory}/"
    mi_version=$(curl -Ls https://mediaarea.net/download/binary/mediainfo | grep -Eo 'href="[0-9.]+/"' | head -n1 | grep -Eo '[0-9.]+')
    curl -L "https://mediaarea.net/download/binary/mediainfo/${mi_version}/MediaInfo_CLI_${mi_version}_Mac.dmg" -o MediaInfo.dmg

    hdiutil attach -noverify MediaInfo.dmg
    cp "/Volumes/MediaInfo/mediainfo.pkg" .
    hdiutil detach "/Volumes/MediaInfo"

    pkgutil --expand-full mediainfo.pkg mediainfo_ROOT
    cp -a mediainfo_ROOT/Payload/usr/local/bin/mediainfo mkvnote_ROOT/usr/local/lib/mkvnote/bin
popd

#-----------------------------------------------------------------------
# Get MKVToolNix
pushd "${release_directory}/"
    curl -L https://mkvtoolnix.download/macos/MKVToolNix-42.0.0.dmg -o MKVToolNix-42.0.0.dmg

    hdiutil attach -noverify MKVToolNix-42.0.0.dmg
    cp -a "/Volumes/MKVToolNix-42.0.0/MKVToolNix-42.0.0.app/Contents/MacOS/mkvextract" mkvnote_ROOT/usr/local/lib/mkvnote/bin
    cp -a "/Volumes/MKVToolNix-42.0.0/MKVToolNix-42.0.0.app/Contents/MacOS/mkvinfo" mkvnote_ROOT/usr/local/lib/mkvnote/bin
    cp -a "/Volumes/MKVToolNix-42.0.0/MKVToolNix-42.0.0.app/Contents/MacOS/mkvmerge" mkvnote_ROOT/usr/local/lib/mkvnote/bin
    cp -a "/Volumes/MKVToolNix-42.0.0/MKVToolNix-42.0.0.app/Contents/MacOS/mkvpropedit" mkvnote_ROOT/usr/local/lib/mkvnote/bin
    hdiutil detach "/Volumes/MKVToolNix-42.0.0"
popd

#-----------------------------------------------------------------------
# Build mkvnote-qt
pushd "${release_directory}/"
    mkdir mkvnote_BUILD
    pushd mkvnote_BUILD
        cmake -GNinja -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 -DCMAKE_INSTALL_PREFIX="${release_directory}/mkvnote_ROOT/usr/local" ../..
        ninja install
    popd
popd

#-----------------------------------------------------------------------
# Sign binaries

cat - > "${release_directory}/mkvnote.entitlements" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
EOF

pushd "${release_directory}/"
    if [ -n "${MACOS_CODESIGN_IDENTITY}" ] ; then
        find  mkvnote_ROOT/usr/local -type f -print0 | while IFS= read -r -d '' f ; do
            if file "${f}" | grep -q 'Mach-O.*\(executable\|dynamically linked shared library\)' ; then
                codesign --force --options runtime --timestamp --entitlements mkvnote.entitlements --sign "Developer ID Application: ${MACOS_CODESIGN_IDENTITY}" "${f}"
            fi
        done
    fi
popd

#-----------------------------------------------------------------------
# Package .pkg
pushd "${release_directory}/"
    pkgbuild --root mkvnote_ROOT --identifier "com.github.amiaopensource.mkvnote" --version "${version}" "mkvnote.unsigned.pkg"
popd

#-----------------------------------------------------------------------
# Sign .pkg
pushd "${release_directory}/"
    if [ -n "${MACOS_CODESIGN_IDENTITY}" ] ; then
        productsign --sign "Developer ID Installer: ${MACOS_CODESIGN_IDENTITY}" "mkvnote.unsigned.pkg" "mkvnote.pkg"
    else
        mv -f "mkvnote.unsigned.pkg" "mkvnote.pkg"
    fi
popd

#-----------------------------------------------------------------------
# Package .dmg
pushd "${release_directory}/"
    tmp_path="$(mktemp -d)"
    trap "rm -rf ${tmp_path}" EXIT

    tmp_files="tmp-mkvnote"
    tmp_dmg="tmp-mkvnote.dmg"

    mkdir -p "${tmp_path}/${tmp_files}"
    cp -a "mkvnote.pkg" "${tmp_path}/${tmp_files}/"

    hdiutil create "${tmp_path}/${tmp_dmg}" -ov -fs HFS+ -format UDRW -volname "mkvnote" -srcfolder "${tmp_path}/${tmp_files}"
    hdiutil attach -readwrite -noverify "${tmp_path}/${tmp_dmg}"

    sleep 1

    echo '
        tell application "Finder"
            tell disk "mkvnote"
                open
                set current view of container window to icon view
                set toolbar visible of container window to false
                set the bounds of container window to {400, 100, 950, 600}
                set viewOptions to the icon view options of container window
                set arrangement of viewOptions to not arranged
                set icon size of viewOptions to 72
                set position of item "mkvnote.pkg" of container window to {125, 175}
                close
            end tell
        end tell
    ' | osascript

    hdiutil detach "/Volumes/mkvnote"
    hdiutil convert "${tmp_path}/${tmp_dmg}" -format UDBZ -o "mkvnote_${version}_Mac.dmg"
popd

#-----------------------------------------------------------------------
# Sign .dmg
pushd "${release_directory}/"
    if [ -n "${MACOS_CODESIGN_IDENTITY}" ] ; then
        codesign --force --options runtime --timestamp --sign "Developer ID Application: ${MACOS_CODESIGN_IDENTITY}" --identifier "com.github.amiaopensource.mkvnote" "mkvnote_${version}_Mac.dmg"
    fi
popd
