#! /bin/sh

preproc() {
    local dir=${1:?}
    local file=${2:?}
    local line=0
    local idxfile=/tmp/rebuild.idx.$$
    > $idxfile
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
	    continue
	elif [ -n "$rest" ]; then
	    echo >&2 "$file:$line: extra fields"
	    continue
	else
	    local loc=$(sed -n -e "/^$camid:/s///p" $idxfile)
	    if [ -n "$loc" ]; then
		echo >&2 "$file:$line: duplicate camera ID"
		echo >&2 "$loc: initially defined here"
		continue
	    else
		echo >$idxfile "$camid:$file:$line"
	    fi
	fi

	{
	    echo "#line $line \"$file\""
	    echo "DEFSERVICE($camid,$url,$ip,$port)"
	} | m4 $m4incdir/service.m4 - > $dir/$camid.conf
    done < $file
    rm -f $idxfile
}

tempdir=/tmp/service.conf.$$
tempconfdir=$tempdir/conf.d
baddir=/tmp/service.conf.bad
pidfile=/tmp/$(basename $0).pid

cleanup() {
    dotlockfile -u $pidfile
    rm -rf $tempdir
}

trap "cleanup" 1 2 3 15

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

confdir=$pounddir/conf.d
bakdir=$pounddir/conf.bak

mkdir -p $tempconfdir
rm -rf $baddir

for spec in $filelist
do
    if ! preproc $tempconfdir $spec; then
	echo >& "$0: error while preprocessing $spec"
	mv $tempconfdir $baddir
	echo >&2 "$0: malformed configuration files left in $baddir"
	cleanup
	exit 1
     fi
done

if ! [ "$(ls -A $tempconfdir)" ]; then
    echo "# placeholder" > $tempconfdir/_dummy.conf
fi

if ! pound -c -Winclude-dir=$tempdir -f $pounddir/pound.cfg; then
    mv $tempconfdir $baddir
    echo >&2 "$0: malformed configuration files left in $baddir"
    cleanup
    exit 1
fi

rm -rf $bakdir
mv $confdir $bakdir
rsync -a --delete $tempconfdir/ $confdir
cleanup

if [ $norestart -eq 0 ]; then
    piesctl restart component pound
fi
