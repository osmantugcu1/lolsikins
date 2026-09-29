#!/bin/bash
# Builds the LolSikins release folder from a build directory. The workflow adds the patcher folder afterwards.

copy2folder() {
    mkdir -p "$2/tools" "$2/licenses"

    cp "./dist/"*.bat "$2/tools"
    cp "./dist/"*.reg "$2/tools"
    cp "./dist/README.txt" "$2"
    cp "./dist/licenses/"* "$2/licenses"
    cp "./LICENSE" "$2/licenses/GPL-3.0.txt"
    # GPL-3.0: whoever receives the program also receives the source of this exact version.
    git archive --format=zip --prefix=lolsikins-source/ -o "$2/licenses/LolSikins-source.zip" HEAD

    cp "$1/cslol-tools/"*.exe "$2/tools"
    cp "$1/LolSikins.exe" "$2"
    echo "windeployqt is only necessary for non-static builds"
    windeployqt --qmldir "src/qml" "$2/LolSikins.exe"
    curl -N -R -L -o "$2/tools/hashes.game.txt" "https://raw.communitydragon.org/data/hashes/lol/hashes.game.txt"
}

VERSION=$(git log --date=short --format="%ad-%h" -1)
echo "Version: $VERSION"

if [ "$#" -gt 0 ] && [ -d "$1" ]; then
    copy2folder "$1" "lolsikins"
    echo "Version: $VERSION" > "lolsikins/version.txt"
else
    echo "Error: Provide at least one valid path."
    exit
fi;
