#!/bin/bash

xmlpretty() {
        sed 's/\(<\/[^>]+>\)/\1\n/g;s/\(>\)\(<\)/\1\n\2/g'
}

getargs() {
	echo "$@" | sed 's/[ \t]\+\(-[a-zA-Z][ \t]\+\)/\n\1/g' | awk '/^-/ { printf("ARG_%s=\"%s\"\n",gensub(/^-([a-zA-Z]).*$/,"\\1","g",$0),gensub(/^-[a-zA-Z][ \t]+(.*)[ \t]*$/,"\\1","g",$0)) }'
}

usage() {
	echo "usage: usanalyze.sh -s <source-file/folder> -t <file|repo> -o <list|view> [-i <sys_id>]"
	echo ""
	echo "    -s    Source from which to pull data.  This may be an Update Set XML file or"
	echo "          the repository where an Application has been stored"
	echo ""
	echo "    -t    Type of source from which data should be pulled.  May be file or repo"
	echo ""
	echo "    -o    Operation to perform on data source"
	echo "          'list' => list individual updates in set/repo"
	echo "          'view' => view specific update identified by sys_id (requires -i)"
	echo ""
	echo "    -i    Specifies the sys_id to be viewed (required by '-o view')"
}

[[ -n "$@" ]] && eval "$(getargs "$@")"

# Check for xmllint
which xmllint 2>&1 > /dev/null
if [ $? -ne 0 ]; then
	echo "ERROR:  xmllint not found"
	exit
fi

if ([ -z "$ARG_s" ] && [ -z "$ARG_r" ])|| [ -z "$ARG_o" ]; then
	usage
else
	if [ "$ARG_t" == "file" ] && [ -f $ARG_s ]; then
		if [ "$ARG_o" == "list" ]; then
			xmllint --xpath "/unload/sys_update_xml/*[self::name or self::sys_id]" $ARG_s | xmlpretty | \
			awk 'BEGIN {
				name=""; sysid="" 
			} /<name>/ { 
				name = gensub(/_[0-9a-f]{32}/,"","g",gensub(/^.*>(.*)<.*$/,"\\1","g",$0))
			} /<sys_id>/ { 
				sysid = gensub(/^.*>(.*)<.*$/,"\\1","g",$0) 
			} { 
				if (length(sysid) > 0) {
					printf("%s (sys_id = %s)\n",name,sysid);
				}
			}' | sort
		elif [ "$ARG_o" == "view" ]; then
			if [ -n "$ARG_i" ]; then
					xmllint --xpath "/unload/sys_update_xml[sys_id='$ARG_i']/payload" $ARG_s | \
					sed 's/<[\/]*payload>//g;s/<!\[CDATA\[//g;s/\]\]>//g' | xmlpretty | \
					awk '/^[ \t]*$/ { getline } /^<\?/ { printf("\n") } { print gensub(/&gt;/,">","g",gensub(/&lt;/,"<","g",$0)) }' | \
					xmlpretty
			else
				echo "sys_id not specified"
				usage
			fi
		else
			echo "Invalid operation ($ARG_o)"
			usage
		fi
	elif [ "$ARG_t" == "repo" ] && [ -d $ARG_s ]; then
		if [ "$ARG_o" == "list" ]; then
			awk '/<sys_id>/ { 
				printf("%s (sys_id = %s)\n",gensub(/\.xml/,"","g",gensub(/_[a-f0-9]{32}/,"","g",gensub(/^.*\//,"","g",FILENAME))),gensub(/^.*>(.*)<.*$/,"\\1","g",$0))
			}' $ARG_s/update/*xml | sort
		elif [ "$ARG_o" == "view" ]; then
			if [ -n "$ARG_i" ]; then
				grep "<sys_id>$ARG_i</sys_id>" $ARG_s/update/*xml | \
				awk 'BEGIN { FS=":" } { print $1 }' | sed 's/&gt;/>/g;s/&lt;/</g' | \
				xmlpretty
			else
				echo "sys_id not specified"
				usage
			fi
		else
			echo "Invalid operation ($ARG_o)"
			usage
		fi
	else
		echo "Invalid type and/or file/folder not found"
		usage	
	fi
fi
