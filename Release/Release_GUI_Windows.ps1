##  Copyright (c) MediaArea.net SARL. All Rights Reserved.
##
##  Use of this source code is governed by a BSD-style license that can
##  be found in the License.html file in the root of the source tree.
##

$ErrorActionPreference = "Stop"

#-----------------------------------------------------------------------
# Setup
$release_directory = $PSScriptRoot
$version = (Get-Content "${release_directory}\..\Project\version.txt" -Raw).Trim()
$arch = "x64"

#-----------------------------------------------------------------------
# Cleanup
$artifact = "${release_directory}\mkvnote_GUI_${version}_Windows_${arch}"
if (Test-Path "${artifact}") {
    Remove-Item -Force -Recurse "${artifact}"
}

$artifact = "${release_directory}\mkvnote_GUI_${version}_Windows_${arch}_WithoutInstaller.zip"
if (Test-Path "${artifact}") {
    Remove-Item -Force "${artifact}"
}

#-----------------------------------------------------------------------
# Package GUI
Push-Location "${release_directory}"
    New-Item -Force -ItemType Directory -Path "mkvnote_GUI_${version}_Windows_${arch}"
    Push-Location "mkvnote_GUI_${version}_Windows_${arch}"
        ### Copying: Exe ###
        Copy-Item -Force "..\mkvnote_ROOT\bin\mkvnote-gui.exe" .
        Copy-Item -Force "..\mkvnote_ROOT\bin\mediainfo.exe" .
        Copy-Item -Force "..\mkvnote_ROOT\bin\mkvextract.exe" .
        Copy-Item -Force "..\mkvnote_ROOT\bin\mkvinfo.exe" .
        Copy-Item -Force "..\mkvnote_ROOT\bin\mkvmerge.exe" .
        Copy-Item -Force "..\mkvnote_ROOT\bin\mkvpropedit.exe" .
        ### Deploying Qt ###
        windeployqt.exe --release mkvnote-gui.exe
        ### Archive
        7za.exe a -r -tzip -mx9 "..\mkvnote_GUI_${version}_Windows_${arch}_WithoutInstaller.zip" *
    Pop-Location
Pop-Location