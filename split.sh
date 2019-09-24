#!/bin/sh

set -e

DEFAULT_BUILDDIR="build";
DEFAULT_FRAMEWORK_URL="https://github.com/korowai/framework";
DEFAULT_COMPONENT_URL_BASE="git@github.com:korowai"

PUSH=false;

print_help() {
  echo "Usage: `basename $0` [-f framework-url] [-c component-url-base] [-b build-dir] [-p]";
  echo "";
  echo "Options:"
  echo "  -f framework-url"
  echo "     An URL of korowai/framework repository to be cloned and split into components.";
  echo "     Defaults to '$DEFAULT_FRAMEWORK_URL'";
  echo "  -c component-url-base"
  echo "     A base URL of the remote repositories for generated components.";
  echo "     Defaults to '$DEFAULT_COMPONENT_URL_BASE'";
  echo "  -b build-dir";
  echo "     A temporary directory, where all the component repositories will be created."
  echo "     Defaults to '$DEFAULT_BUILDDIR'";
  echo "  -p";
  echo "     Push components to their remote repositories. By default, components are not pushed.";
}

while getopts ":r:c:b:ph" OPT; do
  case $OPT in
    f)
      if [ ! -z "$FRAMEWORK_URL" ]; then
        echo "Error: repeated option -$OPT" >&2;
        exit 1;
      fi
      FRAMEWORK_URL="$OPTARG";
      ;;
    c)
      if [ ! -z "$COMPONENT_URL_BASE" ]; then
        echo "Error: repeated option -$OPT" >&2;
        exit 1;
      fi
      COMPONENT_URL_BASE="$OPTARG";
      ;;
    b)
      if [ ! -z "$BUILDDIR" ]; then
        echo "Error: repeated option -$OPT" >&2;
        exit 1;
      fi
      BUILDDIR="$OPTARG";
      ;;
    p)
      PUSH=true;
      ;;
    h)
      print_help;
      exit 0;
      ;;
    \?)
      echo "Error: invalid option: -$OPTARG" >&2;
      exit 1;
      ;;
    :)
      echo "Error: option -$OPTARG requires an argument" >&2;
      exit 1;
      ;;
  esac
done

if [ -z "$BUILDDIR" ]; then
  BUILDDIR="$DEFAULT_BUILDDIR";
fi

if [ -z "$FRAMEWORK_URL" ]; then
  FRAMEWORK_URL=$DEFAULT_FRAMEWORK_URL;
fi

if [ -z "$FRAMEWORK_REPO" ]; then
  FRAMEWORK_REPO="$BUILDDIR/framework"
fi

if [ -z "$COMPONENT_URL_BASE" ]; then
  COMPONENT_URL_BASE="$DEFAULT_COMPONENT_URL_BASE";
fi


if [ ! -e $FRAMEWORK_REPO ]; then
  git clone "$FRAMEWORK_URL" "$FRAMEWORK_REPO";
fi

COMPONENT_REPOS=""
for COMPOSER_JSON in `find "$FRAMEWORK_REPO/src" "$FRAMEWORK_REPO/packages" -name composer.json`; do
  COMPOSER_JSON_DIR=`dirname $COMPOSER_JSON`;
  COMPONENT_SUBDIR=`realpath --relative-to="$FRAMEWORK_REPO" "$COMPOSER_JSON_DIR"`;
  COMPONENT_FULLNAME=`cat "$COMPOSER_JSON" | jq -r .name`;
  COMPONENT_BASE=`echo "$COMPONENT_FULLNAME" | awk -F '/' '{print $1}'`
  COMPONENT_NAME=`echo "$COMPONENT_FULLNAME" | awk -F '/' '{print $2}'`;
  COMPONENT_REPO="$BUILDDIR/$COMPONENT_NAME";
  if [ -d "$COMPONENT_REPO" ]; then
    echo "removing '$COMPONENT_REPO'";
    rm -rf "$COMPONENT_REPO";
  fi
  COMPONENT_URL="$COMPONENT_URL_BASE/$COMPONENT_NAME";
  git clone "$FRAMEWORK_REPO" "$COMPONENT_REPO";
  ( cd "$COMPONENT_REPO" && \
    git filter-branch --prune-empty --subdirectory-filter $COMPONENT_SUBDIR --tag-name-filter cat -- --all && \
    git remote set-url origin $COMPONENT_URL )
  if [ -z "$COMPONENT_REPOS" ]; then
    COMPONENT_REPOS="$COMPONENT_REPO";
  else
    COMPONENT_REPOS="$COMPONENT_REPOS $COMPONENT_REPO";
  fi
done

if $PUSH; then
  for COMPONENT_REPO in $COMPONENT_REPOS; do
    echo '( cd '"$COMPONENT_REPO"' && git push --all && git push --tags )';
  done
fi
