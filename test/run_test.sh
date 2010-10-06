#!/bin/bash
EXPECTED_ARGS=1
if [ $# -ne $EXPECTED_ARGS ]
then
	echo "Usage: `basename $0` [manifest.pp]"
        exit
fi

PWD=`pwd`
MODULEPATH="$PWD/../..:$PWD/../../../site:$PWD/../../../base"

LIBDIR=""

if [ -d $PWD/lib ]
then
	LIBDIR="--libdir $PWD/lib"
fi

echo "MODULEPATH: $MODULEPATH LIBDIR: $LIBDIR"

puppet $NOOP -d --modulepath=$MODULEPATH $LIBDIR $1
