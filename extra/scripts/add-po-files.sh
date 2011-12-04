#!/bin/bash

# Script to add po files for a single ebox module
# It is required a package name
# Usage: add-po-files.sh packageName
# Kopyleft (K) 2007 by Warp Networks
# All rights reversed

usage() {

    echo "Usage: $0 [-h] package-name"
    echo "Where package-name : the package to add the po files, i.e. ebox-services"
    echo "      -h           : Show this message"

}

# Getting optional options
while getopts "h" opt
  do
  case $opt in
      h)
	  usage
	  exit 0
	  ;;
      *)
	  usage
	  exit 1
	  ;;
  esac
done

shift $(($OPTIND - 1))

if [ $# -ne 1 ]; then
    echo "package-name is required"
    usage
    exit 1
fi

packageName=$1

IFS=" "
for locale in $(cat LINGUAS) #  | sed -s 's: :\n:g')
  do
  echo $locale
  msginit --input=${packageName}.pot \
      --locale=$locale --output="$locale.po" \
      --no-translator

  # Get version from configure.ac
  version=$(perl -ne 'if (m/^AC_INIT.*, *\[(.*)\]\)/ ) { print $1; }' ../configure.ac)
  # Put version and package name in po file
  # And charset to UTF-8
  sed -i -e "s/^\"Project-Id-Version:.*$/\"Project-Id-Version: $packageName $version\"/" \
      -e 's/charset=.*\\/charset=UTF-8\\/' -e "s/PACKAGE/$packageName/" $locale.po

done


