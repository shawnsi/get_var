#!/bin/bash
EXPECTED_ARGS=1
if [ $# -ne $EXPECTED_ARGS ]
then
	echo "Usage: `basename $0` [noop|reallyrun]"
        exit
fi

NOOP="--noop"
if [ "$1" = "reallyrun" ]
then
	NOOP=""
fi

PWD=`pwd`
MODULEPATH="$PWD/..:$PWD/../.."

echo "MODULEPATH: $MODULEPATH"

puppet $NOOP $DEBUG --modulepath=$MODULEPATH test/init.pp
exit 0
