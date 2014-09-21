#!/bin/bash
# -*-mode: Shell-script; indent-tabs-mode: nil; sh-basic-offset: 2 -*-

# Find the base directory while avoiding subtle variations in $0:
dollar0=`which $0`; PACKAGE_DIR=$(cd $(dirname $dollar0); pwd) # NEVER export PACKAGE_DIR

# Set defaults for BUILD_DIR and INSTALL_DIR environment variables and
# utility functions such as BuildDependentPackage:
. $PACKAGE_DIR/../../../support-files/build_platform_util.bash
# Define perl utility functions:
. $PACKAGE_DIR/../../../support-files/perl_util.bash

usage () {
  cat <<EOF
USAGE: $0 ... options ...

Options are:

[ -builddir BUILD_DIR ]

  Override the BUILD_DIR default, which is $BUILD_DIR.

[ -installdir INSTALL_DIR ]

  Override the INSTALL_DIR default, which is $INSTALL_DIR.

EOF
}

while [ $# -gt 0 ]
do
  if [ "$1" = "-builddir" ]
  then
    BUILDDIR="$2"
    shift
  elif [ "$1" = "-installdir" ]
  then
    INSTALLDIR="$2"
    shift
  elif [ "$1" = "-h" ]
  then
    usage
    exit 0
  else
    echo "Undefined parameter $1"
    exit 1
  fi
  shift
done

# --------------------------------------------------------------------------------
# Dependent packages will be installed into $INSTALL_DIR/bin so add
# that directory to the PATH:
# --------------------------------------------------------------------------------
SetupBasicEnvironment

# --------------------------------------------------------------------------------
# Build required dependent packages:
# --------------------------------------------------------------------------------
BuildDependentPackage autoconf bin/autoconf
BuildDependentPackage automake bin/automake
BuildDependentPackage libtool bin/libtool
BuildDependentPackage pkg-config bin/pkg-config

# --------------------------------------------------------------------------------
# Dependent packages will be installed into $INSTALL_DIR/bin so add
# that directory to the PATH:
# --------------------------------------------------------------------------------
SetupBasicEnvironment

# --------------------------------------------------------------------------------
# Create build directory structure:
# --------------------------------------------------------------------------------
CreateAndChdirIntoBuildDir patchelf

# --------------------------------------------------------------------------------
# Check out the source for emacs into the build directory:
# --------------------------------------------------------------------------------
packageSubDir=patchelf
# https://github.com/NixOS/patchelf.git
DownloadPackageFromGitRepo https://github.com/NixOS/patchelf.git $packageSubDir

PrintRun cd $packageSubDir

# --------------------------------------------------------------------------------
# Configure
# --------------------------------------------------------------------------------
echo "Configuring ..."
# There is no autogen.sh for this package so guesswork commences:
ACLOCAL="aclocal $ACLOCAL_FLAGS" autoreconf --force --install || exit $?
PrintRun ./configure --prefix="$INSTALL_DIR"

# --------------------------------------------------------------------------------
# Build:
# --------------------------------------------------------------------------------
echo "Building ..."
PrintRun make

# --------------------------------------------------------------------------------
# Install:
# --------------------------------------------------------------------------------
echo "Installing ..."
PrintRun make install

# --------------------------------------------------------------------------------
# Testing:
# --------------------------------------------------------------------------------
echo "Testing ..."

# Determine the expected version from the ./configure file:
expected_version=$(sed -n "s%^ *PACKAGE_VERSION='\\([^']*\\)'.*\$%\\1%gp" < configure);
if [ -z "$expected_version" ]
then
  echo "ASSERTION FAILED: Could not determine expected glib version."
  exit 1
fi

# Verify a file we should have installed:
exeFile="$INSTALL_DIR/bin/patchelf"
if [ ! -f "$exeFile" ]
then
  echo "ERROR: Failed to install file: $exeFile"
  exit 1
fi
echo "Note: All installation tests passed. patchelf version $expected_version was built and installed."
exit 0
