#!/usr/bin/env bash

set -e

# ----------------------------
# Path settings
# ----------------------------
SOLUTION="Lampac.sln"
MAIN_PROJECT="Lampac/Lampac.csproj"
PUBLISH_DIR="./publish"
MODULE_DIR="./module"
RUNTIME_REFERENCES="$PUBLISH_DIR/runtimes/references"
MODULE_REFERENCES="$PUBLISH_DIR/module/references"
MODULE_DLLS=("DLNA" "JacRed" "Merchant" "Online" "Catalog" "SISI" "TorrServer" "Tracks")
LANGS=("cs" "de" "es" "fr" "it" "ja" "ko" "pl" "pt-BR" "ru" "tr" "zh-Hans" "zh-Hant")

echo "=============================="
echo "Building Lampac project with all modules..."
echo "=============================="

# ----------------------------
# Verify .NET version
# ----------------------------
echo "Using .NET version: $(dotnet --version)"

# ----------------------------
# Clean previous builds
# ----------------------------
echo "Cleaning previous builds..."
rm -rf "$PUBLISH_DIR" ./bin ./obj

# ----------------------------
# Restore dependencies
# ----------------------------
echo "Restoring NuGet packages..."
dotnet restore "$SOLUTION"

# ----------------------------
# Build core solution
# ----------------------------
echo "Building core solution..."
dotnet build "$SOLUTION" --configuration Release --no-restore

# ----------------------------
# Publish main application
# ----------------------------
echo "Publishing main application..."
dotnet publish "$MAIN_PROJECT" --configuration Release --output "$PUBLISH_DIR" --no-build

# ----------------------------
# Setup directories
# ----------------------------
echo "Setting up module and runtime references..."
mkdir -p "$MODULE_REFERENCES"
mkdir -p "$RUNTIME_REFERENCES"

# ----------------------------
# Move all DLL and PDB files from publish root (except Lampac.dll) to runtimes/references
# ----------------------------
echo "Moving DLL and PDB files to $RUNTIME_REFERENCES..."
find "$PUBLISH_DIR" -maxdepth 1 -type f \( -name "*.dll" -o -name "*.pdb" \) ! -name "Lampac.dll" | while read file; do
    mv "$file" "$RUNTIME_REFERENCES/"
done

# ----------------------------
# Copy BaseModule controllers
# ----------------------------
if [ -d "BaseModule/Controllers" ]; then
    echo "Copying BaseModule controllers..."
    mkdir -p publish/basemod/Controllers
    cp -r BaseModule/Controllers/* publish/basemod/Controllers/
else
    echo "Warning: BaseModule/Controllers not found, skipping copy."
fi

# ----------------------------
# Move language folders to runtimes/references
# ----------------------------
echo "Organizing language folders..."
for lang in "${LANGS[@]}"; do
    if [ -d "$PUBLISH_DIR/$lang" ]; then
        mv "$PUBLISH_DIR/$lang" "$RUNTIME_REFERENCES/"
    fi
done

# ----------------------------
# Copy module source files if they exist
# ----------------------------
if [ -d "$MODULE_DIR" ]; then
    echo "Copying module files..."
    cp -r "$MODULE_DIR" "$PUBLISH_DIR/"

    if [ -f "$MODULE_DIR/manifest.json" ]; then
        echo "Compiling dynamic modules..."
        cd "$PUBLISH_DIR"
        dotnet build --configuration Release --no-restore || echo "Module compilation completed with warnings"
        cd ..
    fi
fi

# ----------------------------
# Create manifest.json in publish/module/
# ----------------------------
cat > publish/module/manifest.json <<EOF
[{"enable":true,"dll":"Online.dll"},
 {"enable":true,"dll":"SISI.dll"},
 {"enable":true,"initspace":"Jackett.ModInit","dll":"JacRed.dll"},
 {"enable":true,"dll":"DLNA.dll"},
 {"enable":true,"initspace":"Tracks.ModInit","dll":"Tracks.dll"},
 {"enable":true,"initspace":"TorrServer.ModInit","dll":"TorrServer.dll"},
 {"enable":true,"initspace":"Catalog.ModInit","dll":"Catalog.dll"}]
EOF

echo "manifest.json created in publish/module/"

# ----------------------------
# Copy prebuilt module DLLs
# ----------------------------
echo "Copying prebuilt module DLLs..."
for module in "${MODULE_DLLS[@]}"; do
    cp "$module/bin/Release/net9.0/$module.dll" "$PUBLISH_DIR/module/"
done

# ----------------------------
# Copy configuration files
# ----------------------------
echo "Copying configuration files..."
cp init.conf "$PUBLISH_DIR/" 2>/dev/null || echo "init.conf not found, will use defaults"
cp init.yaml "$PUBLISH_DIR/" 2>/dev/null || echo "init.yaml not found, will use defaults"

# ----------------------------
# Finish
# ----------------------------
echo ""
echo "=============================="
echo "Build completed successfully!"
echo "Full application with modules available in $PUBLISH_DIR directory"
echo ""
echo "To run the application:"
echo "  cd $PUBLISH_DIR"
echo "  dotnet Lampac.dll"
echo "=============================="