#!/usr/bin/env bash

set -e

# Transfom artifacts from platform builds into the structure
# required for the final bundle/jar.

# Copy native artifacts into Maven resources location
resources_location=java-combined/src/main/resources

mkdir -pv ${resources_location}/lib/linux-aarch64
mkdir -pv ${resources_location}/lib/linux-x86_64
mkdir -pv ${resources_location}/lib/macosx-aarch64
mkdir -pv ${resources_location}/lib/macosx-x86_64
mkdir -pv ${resources_location}/lib/win32-x86_64

cp -a hdf5-build-linux/*/linux/aarch64/* ${resources_location}/lib/linux-aarch64
cp -a hdf5-build-linux/*/linux/x86_64/* ${resources_location}/lib/linux-x86_64
cp -a hdf5-build-macos/*/macos/arm64/* ${resources_location}/lib/macosx-aarch64
cp -a hdf5-build-macos/*/macos/x86_64/* ${resources_location}/lib/macosx-x86_64
cp -a hdf5-build-win32/*/win32/x86_64/* ${resources_location}/lib/win32-x86_64

# Delete original jars
find ${resources_location}/lib -name *.jar -exec rm -v {} \;

# Delete unrequired files from java souce
rm java-combined/src/main/java/CMakeLists.txt
rm java-combined/src/main/java/hdf/CMakeLists.txt
rm java-combined/src/main/java/hdf/hdf5lib/CMakeLists.txt
rm java-combined/src/main/java/Makefile.am
rm java-combined/src/main/java/Makefile.in
rm -r java-combined/src/main/java/jni
