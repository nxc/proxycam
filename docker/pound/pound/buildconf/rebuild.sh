#! /bin/sh

preproc() {
    local outfile=${1:?}
    shift
    local idxfile=/tmp/rebuild.idx.$$
    > $idxfile
    local errfile=/tmp/rebuild.err
    rm -f $errfile
    for file
    do
	local line=0
	while read camid url ip port rest
	do
	    line=$(($line + 1))
	    case $camid in
		\#*) continue
	    esac
            if [ -z "$camid" ]; then
		# skip empty lines
		continue
	    elif [ -z "$url" ]; then
		echo >&2 "$file:$line: required fields missing"
		touch $errfile
		continue
	    elif [ -n "$rest" ]; then
		echo >&2 "$file:$line: extra fields"
		touch $errfile
		continue
	    else
		local loc=$(sed -n -e "/^$camid:/s///p" $idxfile)
		if [ -n "$loc" ]; then
		    echo >&2 "$file:$line: duplicate camera ID"
		    echo >&2 "$loc: initially defined here"
	    	    touch $errfile
		    continue
		else
		    echo >$idxfile "$camid:$file:$line"
		fi
	    fi

            echo "#line $line \"$file\""
	    echo "DEFSERVICE($camid,$url,$ip,$port)"
	done < $file
    done > $outfile
    rm -f $idxfile
    test ! -f $errfile
}

pounddir=/etc/pound
m4incdir=$pounddir/buildconf
timeout=5
norestart=0
verbose=0
#
while getopts "C:I:nt:v" OPTION
do
    case $OPTION in
	I) m4incdir=$OPTARG;;
	C) pounddir=$OPTARG;;
	n) norestart=1;;
	t) timeout=$OPTARG;;
	v) verbose=$(($verbose + 1));;
	*) exit 1
    esac
done

shift $(($OPTIND - 1))

confdir=$pounddir/inc
conffile=$confdir/cameras.inc
tempfile=$confdir/cameras.tmp
badfile=$confdir/cameras.bad
pidfile=/tmp/$(basename $0).pid

cleanup() {
    dotlockfile -u $pidfile
}

trap "cleanup" 1 2 3 15

if [ $# -eq 0 ]; then
    if [ -n "$DIREVENT_FILE" ]; then
	if dotlockfile -p -r 0 $pidfile; then
	    sleep $timeout
	    filelist=$(find . -mindepth 1 -maxdepth 1 -type f -name '*.spec')
	else
	    [ $verbose -gt 0 ] && echo >&2 "$0: another process already running"
	    exit 0
	fi

    else
	echo >&2 "$0: no input files; use \`$0 -h' to obtain help"
	exit 1
    fi
else
    filelist="$@"
fi

if ! preproc $tempfile $filelist; then
    echo >& "$0: errors while preprocessing specifications"
    mv $tempfile $badfile
    echo >&2 "$0: malformed configuration left in $badfile"
    cleanup
    exit 1
fi


if ! CAMERAS=$tempfile pound -c -f /etc/pound.cfg; then
    mv $tempfile $badfile
    echo >&2 "$0: malformed configuration left in $badfile"
    cleanup
    exit 1
fi

mv $tempfile $conffile
cleanup

if [ $norestart -eq 0 ]; then
    piesctl restart component pound
fi
