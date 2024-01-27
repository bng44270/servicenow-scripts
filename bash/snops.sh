#!/bin/bash

###########################
# snops.sh
#
# Query/Update data in ServiceNow
#
# Usage:
#    snops.sh -o <operation> -h <host> -t <table> -d <json|xml> [-q <query>] [-r <record-sys_id>] [-f <field-name>] [-v <value>]
#        <operation> => query or update
#        query => requires host and table arguments.  query and field are optional
#        update => requires host, table, record-sys_id, field name, and value arguments
#
###########################

getargs() {
	echo "$@" | sed 's/\(-[a-zA-Z] \)/\n\1/g' | awk '/^-/ { printf("ARG_%s=\"%s\"\n",gensub(/\n/,"","g",gensub(/^-/,"","g",$1)),length($2)==0?"EMPTY":gensub(/\n/,"","g",$2)) }'
}

formatval() {
	[[ "$1" == "json" || "$1" == "xml" ]] && echo $1
}

urlencode() {
	[[ -z "$1" ]] && echo "usage: urlencode <string>" || xxd -u -p <<< "$1" | tr -d '\n' | sed 's/\(..\)/%\1/g'
}

usage() {
	echo "usage: snops.sh -o <operation> -h <host> -t <table> -d <json|xml> [-q <query>] [-r <record-sys_id>] [-f <field>] [-v <value>]"
	echo "       <operation> => query or update"
	echo "       query => requires host and table arguments.  query and field are optional"
	echo "       update => requires host, table, record-sys_id, field, and value arguments"
}

[[ -n "$@" ]] && eval $(getargs $@)

if [ -z "$ARG_o" ] || [ -z "$ARG_h" ] || [ -z "$ARG_t" ] || [ -z "$ARG_d" ]; then
	usage
else
	if [ "$ARG_o" == "query" ] && [ -n "$ARG_h" ] && [ -n "$ARG_t" ] && [ -n "$(formatval $ARG_d)" ]; then
		QUERY="$([[ -n "$ARG_q" ]] && echo -n "sysparm_query=$ARG_q" ; [[ -n "$ARG_q" && -n "ARG_f" ]] &&  echo -n "&sysparm_fields=$ARG_f" || ([[ -n "$ARG_f" ]] && echo -n "sysparm_fields=$ARG_f"))"
		echo "https://$ARG_h/api/now/table/$ARG_t?$QUERY"
		curl -sk -H"Accept: application/$ARG_d" \
			-u "$(read -p "Username: " usern; echo $usern):$(read -s -p "Password: "  passwd; echo $passwd)" \
			"https://$ARG_h/api/now/table/$ARG_t?$QUERY"
	elif [ "$ARG_o" == "update" ] && [ -n "$ARG_f" ] && [ -n "$ARG_v" ] && [ -n "$ARG_h" ] && [ -n "$ARG_t" ] && [ -n "$ARG_r" ] && [ -n "$(formatval $ARG_d)" ]; then
		curl -sk "https://$ARG_h/api/now/table/$ARG_t/$ARG_r" -X PUT -H"Accept: application/json" -H"Content-Type: application/$ARG_d" -d"{\"$ARG_f\":\"$ARG_v\"}" -u "$(read -p "Username: " usern; echo $usern):$(read -s -p "Password: "  passwd; echo $passwd)"
	else
		echo "Error: invalid arguments"
		usage
	fi
fi
