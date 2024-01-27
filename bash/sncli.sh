#!/bin/bash

############################################
# sncli.sh
#
# ServiceNow CLI in Bash
#
# Interface for viewing ServiceNow data using
# SQL-style SELECT statements
#
# Login with hostname, username, and password to access CLI
#    
# Commands:
#
#    PRETTY - turn pretty display of XML/JSON on and off
#    LIST - list tables or users
#    PAGE - turn paging on or off
#    POP - change paging operation (more or less)
#    INFO - display current configuration of CLI
#    SELECT - query data from tables
#
# Select Usage:
#    SELECT <FIELDSPEC> FROM <TABLESPEC> [WHERE <QUERY>]
#        FIELDSPEC:  Can be * (for all fields) or a comma-separated list of fields
#        TABLESPEC:  Name of table
#        QUERY:      Selection query in the form FIELD=VALUE
#
############################################

showcommands() {
	echo "Commands:  PRETTY, SELECT, LIST, PAGE, POP, INFO, OUTPUT"
}

selectusage() {
	echo "Usage:  SELECT <FIELDSPEC> FROM <TABLESPEC> [WHERE <QUERY>]"
	echo ""
	echo "FIELDSPEC:  Can be * (for all fields) or a comma-separated list of fields"
	echo "TABLESPEC:  Name of table"
	echo "QUERY:      Selection query in the form FIELD=VALUE"
}

getargs() {
	[[ -z "$1" ]] && echo "usage: getargs <arguments>" || echo "$@" | sed 's/\(-[a-zA-Z] \)/\n\1/g' | awk '/^-/ { printf("ARG_%s=\"%s\"\n",gensub(/\n/,"","g",gensub(/^-/,"","g",$1)),length($2)==0?"EMPTY":gensub(/\n/,"","g",$2)) }'
}

xmlpretty() {
	sed 's/\(<\/[^>]+>\)/\1\n/g;s/\(>\)\(<\)/\1\n\2/g'
}

jsonpretty() {
	tr -d '\n' | sed 's/\([{}]\)/\n\1\n/g;s/\[/\[\n/g;s/\][^,]/\n\]\n/g;s/\(\],\)/\n\1\n/g;s/,/,\n/g' | grep -v '^$'
}

cryptstr() {
	echo "$1"
	#echo -n "$(openssl enc -aes-256-ecb -e -pass pass:$2 <<< "$1" | xxd -ps | tr -d '\n')"
}

decryptstr() {
	echo "$1"
	#echo -n "$(xxd -ps -r <<< "$1" | openssl enc -aes-256-ecb -pass pass:$2 -d)"
}

snselect() {
	eval $(getargs "$@")
	QUERY="$([[ -n "$ARG_q" ]] && echo -n "sysparm_query=$ARG_q" ; [[ -n "$ARG_q" && -n "ARG_f" ]] &&  echo -n "&sysparm_fields=$ARG_f" || ([[ -n "$ARG_f" ]] && echo -n "sysparm_fields=$ARG_f"))"
	URL="https://$ARG_h/api/now/table/$ARG_t?$QUERY"
	curl -sk "https://$ARG_h/api/now/table/$ARG_t?$QUERY" -H"Accept: application/$ARG_o" -H"Authorization: Basic $(decryptstr "$ARG_u" $ARG_p)"
}

sntableval() {
	eval $(getargs "$@")
	RESULT="$(snselect -h $ARG_h -t sys_db_object -q name=$ARG_v -f name -u "$ARG_u" -p "$ARG_p")"
	[[ -n "$(grep "<response></response>" <<< "$RESULT")" ]] && echo "0" || echo "1"
}

read -p "Hostname: " SNHOST
read -p "Username: " SNUSER
read -p "Password: " -s SNPASS
echo ""

AUTHENC="$(openssl dgst -sha256 <<< "$RANDOM" |  sed 's/^.*=[ \t]*//g' | tr -d '\n')"
AUTHSTR="$(cryptstr $(echo -n "$SNUSER:$SNPASS" | openssl enc -base64) $AUTHENC)"
SNPASS=""

AUTHTEST="$(snselect -h $SNHOST -t sys_user -q user_name=$SNUSER -f user_name -o xml -u $AUTHSTR -p "$AUTHENC")"
if [ -n "$(grep 'Required to provide Auth information' <<< "$AUTHTEST")" ]; then
	echo "Invalid username/password"
else
	PAGEOUT=""
	PRETTYOUT=""
	PAGEOP="more"
	DATAOUT="xml"
	echo "ServiceNow SQL Shell"
	while true; do
		read -p "${SNUSER}@${SNHOST} > " STATEMENT
		if [ -z "$STATEMENT" ]; then
			continue
		elif [ -n "$(grep -i "^help" <<< "$STATEMENT")" ]; then
			showcommands
			continue
		elif [ -n "$(grep -i "^info" <<< "$STATEMENT")" ]; then
			echo "Connected to $SNHOST as $SNUSER"
			[[ $PRETTYOUT ]] && echo "Pretty output is on" || echo "Pretty output is off"
			[[ $PAGEOUT ]] && echo "Paging is on" || echo "Paging is off"
			[[ "$PAGEOP" == "more" ]] && echo "Paging operation set to 'more'" || echo "Paging operation set to 'less'"
			[[ "$DATAOUT" == "xml" ]] && echo "Output format set to XML" || echo "Output format set to JSON"
		elif [ -n "$(grep -i "^list" <<< "$STATEMENT")" ]; then
			STATEMENT="$(sed 's/^list[ \t]*//i' <<< "$STATEMENT")"
			if [ -n "$(grep -i "^tables" <<< "$STATEMENT")" ]; then
				(
				printf "%-60s %-40s\n" "-- Label --" "-- Name --"
				snselect -h $SNHOST -t sys_db_object -f name,label -o xml -u $AUTHSTR -p "$AUTHENC" | sed 's/\(<\/result>\)\(<result>\)/\1\n\2/g' | awk '{ printf("%-60s %-40s\n",gensub(/^.*<label>(.*)<\/label>.*$/,"\\1","g",$0),gensub(/^.*<name>(.*)<\/name>.*$/,"\\1","g",$0)) }'
				) | ([[ $PAGEOUT ]] && $PAGEOP || cat -)
			elif [ -n "$(grep -i "^users" <<< "$STATEMENT")" ]; then
				(
				printf "%-30s %-20s\n" "-- Name --" "-- Username --"
				snselect -h $SNHOST -t sys_user -f name,user_name -o xml -u $AUTHSTR -p "$AUTHENC" | sed 's/\(<\/result>\)\(<result>\)/\1\n\2/g' | awk '{ printf("%-30s %-20s\n",gensub(/^.*<name>(.*)<\/name>.*$/,"\\1","g",$0),gensub(/^.*<user_name>(.*)<\/user_name>.*$/,"\\1","g",$0)) }'
				) | ([[ $PAGEOUT ]] && $PAGEOP || cat -)
			else
				echo "usage: LIST <TABLES | USERS>"
				continue
			fi
		elif [ -n "$(grep -i "^output" <<< "$STATEMENT")" ]; then
			STATEMENT="$(sed 's/^output[ \t]*//i' <<< "$STATEMENT")"
			if [ -n "$(grep -i "^xml" <<< "$STATEMENT")" ]; then
				DATAOUT="xml"
				echo "Output format set to XML"
			elif [ -n "$(grep -i "^json" <<< "$STATEMENT")" ]; then
				DATAOUT="json"
				echo "Output format set to JSON"
			else
				echo "usage: output: <xml|json>"
				[[ "$DATAOUT" == "xml" ]] && echo "Output format set to XML" || echo "Output format set to JSON"
			fi
		elif [ -n "$(grep -i "^pretty" <<< "$STATEMENT")" ]; then
			STATEMENT="$(sed 's/^pretty[ \t]*//i' <<< "$STATEMENT")"
			if [ -n "$(grep -i "^on" <<< "$STATEMENT")" ]; then
				PRETTYOUT="1"
				echo "Pretty output on"
			elif [ -n "$(grep -i "^off" <<< "$STATEMENT")" ]; then
				PRETTYOUT=""
				echo "Pretty output off"
			else
				echo "usage:  PRETTY <on|off>"
				[[ $PRETTYOUT ]] && echo "Pretty output is on" || echo "Pretty output is off"
				continue
			fi
		elif [ -n "$(grep -i "^page" <<< "$STATEMENT")" ]; then
			STATEMENT="$(sed 's/^page[ \t]*//i' <<< "$STATEMENT")"
			if [ -n "$(grep -i "^on" <<< "$STATEMENT")" ]; then
				PAGEOUT="1"
				echo "Paging on"
			elif [ -n "$(grep -i "^off" <<< "$STATEMENT")" ]; then
				PAGEOUT=""
				echo "Paging off"
			else
				echo "usage:  PAGE <on|off>"
				[[ $PAGEOUT ]] && echo "Paging is on" || echo "Paging is off"
				continue
			fi
		elif [ -n "$(grep -i "^pop" <<< "$STATEMENT")" ]; then
			STATEMENT="$(sed 's/^pop[ \t]*//i' <<< "$STATEMENT")"
			if [ -n "$(grep -i "^more" <<< "$STATEMENT")" ]; then
				PAGEOP="more"
				echo "Paging operation set to 'more'"
			elif [ -n "$(grep -i "^less" <<< "$STATEMENT")" ]; then
				PAGEOP="less"
				echo "Paging operation set to 'less'"
			else
				echo "usage:  POP <more|less>"
				[[ "$PAGEOP" == "more" ]] && echo "Paging operation set to 'more'" || echo "Paging operation set to 'less'"
				continue
			fi
		elif [ -n "$(grep -i "^exit" <<< "$STATEMENT")" ]; then
			break
		elif [ -n "$(grep -i "^select" <<< "$STATEMENT")" ]; then
			STATEMENT="$(sed 's/^select[ \t]*//i' <<< "$STATEMENT")"
			if [ -n "$(grep "^*" <<< "$STATEMENT")" ]; then
				FIELDS=""
			else
				FIELDS="$(sed 's/^\([^ \t]\+\)[  \t]*.*$/\1/g' <<< "$STATEMENT")"
			fi

			STATEMENT="$(sed 's/^[^ \t]\+[ \t]*//g' <<< "$STATEMENT")"
			if [ -z "$(grep -i "^from" <<< "$STATEMENT")" ]; then
				selectusage
				continue
			fi

			STATEMENT="$(sed 's/^from[ \t]*//i' <<< "$STATEMENT")"

			TABLE="$(sed 's/^\([^ \t]\+\)[ \t]*.*$/\1/g' <<< "$STATEMENT")"
			if [ "$(sntableval -h $SNHOST -v $TABLE -u $AUTHSTR -p "$AUTHENC")" == "0" ]; then
				selectusage
				continue
			fi

			STATEMENT="$(sed 's/^[^ \t]\+[ \t]*//g' <<< "$STATEMENT")"

			if [ -n "$(grep -i "^where" <<< "$STATEMENT")" ]; then
				STATEMENT="$(sed 's/^where[ \t]*//i' <<< "$STATEMENT")"
				QUERY="$STATEMENT"
			fi

			snselect -h $SNHOST -t $TABLE $([[ -n "$QUERY" ]] && echo "-q $QUERY") $([[ -n "$FIELDS" ]] && echo "-f $FIELDS") -o $DATAOUT -u $AUTHSTR -p "$AUTHENC" | ([[ $PRETTYOUT && "$DATAOUT" == "xml" ]] && xmlpretty || cat -) | ([[ $PRETTYOUT && "$DATAOUT" == "json" ]] && jsonpretty || cat -) | ([[ $PAGEOUT ]] && $PAGEOP || cat -)
			echo ""
		else
			echo "Invalid command"
			continue
		fi
	done
fi
