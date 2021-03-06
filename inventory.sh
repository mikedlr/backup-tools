#!/bin/bash

    # inventory - record an inventory with checksums of the files in a directory
    # Copyright (C) 2016 Michael De La Rue

    # This program is free software: you can redistribute it and/or modify
    # it under the terms of the GNU Affero General Public License as
    # published by the Free Software Foundation, either version 3 of the
    # License, or (at your option) any later version.

    # This program is distributed in the hope that it will be useful,
    # but WITHOUT ANY WARRANTY; without even the implied warranty of
    # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    # GNU Affero General Public License for more details.

    # You should have received a copy of the GNU Affero General Public License
    # along with this program.  If not, see <http://www.gnu.org/licenses/>.

#security - according to GNU find this is the "insecure" version because
#underlying directories could change
#the implication is that if we run this on someone else's directory
#we could checksum a file that wasn't there at the beginning
#e.g.
#  start find, see a file called "this"
#  hacker changes file to be symlink to sekretstuff/sekret-file
#  we checksum  sekretstuff/sekret-file
#  hacker with read access to our checksum file now verifies
#  that sekret-file matches another file he already knows
# thus, you should normally keep your checksum files private.

#N.B. I don't see the above as vulnerabiliy; just an expected feature

# Note that we use `"$@"' to let each command-line parameter expand to a
# separate word. The quotes around `$@' are essential!
# We need TEMP as the `eval set --' would nuke the return value of getopt.
TEMP=$(getopt -o ho:i:x:cv --long help,output:,input:,check,verbose -n 'inventory.sh' -- "$@" )

if [ $? != 0 ] ; then echo "Argument parsing fail; terminating..." >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

usage() { 
  cat <<EOF 
inventory - create or verify an inventory of a directory, typically for backup verification
 -h --help  - output usage information
 -c --check - read inventory file and verify directory
 -v --verbose - verbose output
 -o --output <file> - output to <file>
 -x --exclude <file> - exclude filenames matching expressions in <file>
 -i --input <file> - use <file> for input (as an inventory file), together with -c
EOF
}

OFILE=""
IFILE=""
XFILE=""
CHECK="false"
VERBOSE="false"
while true ; do
	case "$1" in
	        -h|--help) usage; exit 0;;
		-c|--check) CHECK="true" ; shift ;;
		-v|--verbose) VERBOSE="true" ; shift ;;
		-o|--output)
		    if [ "" != "$OFILE" ]
		    then
			echo "Only one output file allowed.  Terminating" >&2
			exit 1
		    fi
		    OFILE=$2; shift 2 ;;
		-i|--input)
		    if [ "" != "$IFILE" ]
		    then
			echo "Only one input file allowed.  Terminating" >&2
			exit 1
		    fi
		    IFILE=$2; shift 2 ;;
		-x|--exclude)
		    if [ "" != "$XFILE" ]
		    then
			echo "Only one exclude file currently allowed.  Terminating" >&2
			exit 1
		    fi
		    XFILE=$2; shift 2 ;;
		--) shift ; break ;;
		*) echo "Internal error!" ; exit 1 ;;
	esac
done

if [ "" = "$1" ]
then
    echo "must have at least one directory argument to run inventory on" >&2
    exit 1
fi

if [ "false" = "$CHECK" ]
then
    if [ "" != "$IFILE" ]
    then
	echo "cannot give input file when generating inventory" >&2
	exit 1
    fi
fi


check_inventory ()
{
    local check_dir="$1"
    if [ "false" = "$VERBOSE" ]
    then
	SHAOPTS="--check --quiet"
    else
	SHAOPTS="--check"
    fi

    if [ "" != "$OFILE" ]
    then
	echo "cannot give output file when checking inventory" >&2
	exit 1
    fi
    ( if [ "" = "$IFILE" ]
    then
	head -n-2
    else
	head -n-2 "$IFILE"
    fi )| tail -n+2 | (cd "$check_dir"; sha384sum $SHAOPTS - )
    SHASUMRES=$?
    exit $SHASUMRES
}

create_inventory ()
{
    local record_dir="$1"
    set -e
    local TEMPFILE
    TEMPFILE=$(mktemp)
    ( echo inventoryfile-0 at "$(date --rfc-3339=seconds --utc)" directory: "$(readlink -f "$1")" ) > "$TEMPFILE"
    ( cd "$record_dir"
	{   find . -type f "${FINDFILTER[@]}" -exec sha384sum {} + | sort -k 2
	    echo -----------------------------------------------
	} >> "$TEMPFILE"
	#split to two lines to avoid reading and writing at the same time
	FOOT="inventory checksum $(sha384sum "$TEMPFILE" | sed 's/ .*//')"
	echo "$FOOT" >>  "$TEMPFILE"
    )
    if [ "" = "$OFILE" ]
    then
       cat "$TEMPFILE"
    else
       mv "$TEMPFILE" "$OFILE"
    fi
}

if [  "true" = "$CHECK" ]
then
    check_inventory "$1"
fi

FINDFILTER=()

if [ "" != "$XFILE" ]
then
    if [ ! -r "$XFILE" ] 
    then
	echo "$XFILE no such file or directory" >&2
	exit 5
    fi
    while read line           
    do           
	#TODO: comments
	if [ "" != "$line" ]
	then
	   FINDFILTER=("${FINDFILTER[@]}" -not -path "$line")
	fi
    done <"$XFILE"
fi

create_inventory "$1" 
