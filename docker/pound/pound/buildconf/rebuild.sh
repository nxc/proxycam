#! /bin/sh

preproc() {
    local dir=${1:?}
    local file=${2:?}
    local line=0
    while read camid url ip port
    do
	line=$(($line + 1))
	case $camid in
	    \#*) continue
	esac
	{
	    echo "#line $line \"$file\""
	    echo "DEFSERVICE($camid,$url,$ip,$port)"
	} | m4 $m4incdir/service.m4 - > $dir/$camid.conf
    done < $file
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
#
while getopts "C:I:nt:" OPTION
do
    case $OPTION in
	I) m4incdir=$OPTARG;;
	C) pounddir=$OPTARG;;
	n) norestart=1;;
	t) timeout=$OPTARG;;
	*) exit 1
    esac
done

shift $(($OPTIND - 1))

if [ $# -eq 0 ]; then
    if [ -n "$DIREVENT_FILE" ]; then
	if dotlockfile -p -r 0 $pidfile; then
	    sleep $timeout
	    filelist=*.spec
	else
	    echo >&2 "$0: another process already running"
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

mkdir $tempdir
cp -r $confdir $tempdir
rm -f $tempdir/_dummy.conf
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

[ $norestart -eq 0 ] && piesctl restart component pound
