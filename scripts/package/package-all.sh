#!/bin/bash

set -e

echoerr() { echo "$@" 1>&2; }

function get_platform() {
    # Will return "linux" for GNU/Linux
    #   I'd just like to interject for a moment...
    #   https://wiki.installgentoo.com/index.php/Interjection
    # Will return "macos" for macOS/OS X
    # Will return "windows" for Windows/MinGW/msys

    _platform=$(uname | tr '[:upper:]' '[:lower:]')
    if [[ $_platform == "darwin" ]]; then
        _platform="macos";
    elif [[ $_platform == "msys"* ]]; then
        _platform="windows";
    elif [[ $_platform == "mingw"* ]]; then
        _platform="windows";
    elif [[ $_platform == "linux" ]]; then
        # Nothing to do
        true;
    else
        echoerr "ERROR: $_platform is not a valid platform";
        exit 1;
    fi

    echo $_platform;
}

function get_version() {
    $(dirname "$0")/getversion.sh;
}

function get_arch() {
    _arch="$(uname -m)"
    echo $_arch;
}

platform=$(get_platform)
version=$(get_version)
arch=$(get_arch)
echo "Platform: $platform, arch: $arch, version: $version"

SIGN_THUMBPRINT="866d1fe067993331d92fcf7c624fbdad211a794a"
TIMESTAMP_URL="http://timestamp.digicert.com"

function sign_payload() {
    local file
    echo "Signing binaries in dist/activitywatch..."
    while IFS= read -r -d '' file; do

        echo "Signing $file"
        # Git Bash rewrites arguments that start with / into paths.
        MSYS2_ARG_CONV_EXCL='*' signtool sign /sha1 "$SIGN_THUMBPRINT" /fd SHA256 /td SHA256 /a /tr "$TIMESTAMP_URL" "$file"

    done < <(find dist/activitywatch -type f \( -iname '*.exe' -o -iname '*.dll' -o -iname '*.pyd' \) -print0)
}

function build_zip() {
    echo "Zipping executables..."
    pushd dist;
    filename="activitywatch-${version}-${platform}-${arch}.zip"
    echo "Name of package will be: $filename"

    if [[ $platform == "windows"* ]]; then
        7z a $filename activitywatch;
    else
        zip -r $filename activitywatch;
    fi
    popd;
    echo "Zip built!"
}

function build_setup() {
    filename="activitywatch-${version}-${platform}-${arch}-setup.exe"
    echo "Name of package will be: $filename"

    innosetupdir="/c/Program Files (x86)/Inno Setup 6"
    if [ ! -d "$innosetupdir" ]; then
        echo "ERROR: Couldn't find innosetup which is needed to build the installer. We suggest you install it using chocolatey. Exiting."
        exit 1
    fi

    # Windows installer version should not include 'v' prefix, see: https://github.com/microsoft/winget-pkgs/pull/17564
    version_no_prefix="$(echo $version | sed -e 's/^v//')"
    # $f is filled in by Inno Setup. Git Bash rewrites arguments that start with / into paths.
    env MSYS2_ARG_CONV_EXCL='*' AW_VERSION=$version_no_prefix \
        "$innosetupdir/iscc.exe" \
        "/Ssigntool=signtool sign /sha1 ${SIGN_THUMBPRINT} /fd SHA256 /td SHA256 /a /tr ${TIMESTAMP_URL} \$f" \
        scripts/package/activitywatch-setup.iss
    mv dist/activitywatch-setup.exe dist/$filename
    echo "Setup built!"
}

if [[ $platform == "windows"* ]]; then
    sign_payload
fi
build_zip
if [[ $platform == "windows"* ]]; then
    build_setup
fi

echo
echo "-------------------------------------"
echo "Contents of ./dist"
ls -l dist
echo "-------------------------------------"

