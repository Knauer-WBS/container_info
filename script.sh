#!/bin/bash
#it works on my system

_IDS=$(ls /etc/pve/lxc | sed 's/.conf//' )
_VMS=$(ls /etc/pve/qemu-server | sed 's/.conf//' )
_OUT=container_info.log
_FLAG=false

_HEAD="\e[36;4;1m"
_SUBH="\e[95;1m"
_LINE="\e[3m"
_SUCC="\e[92;1m"
_FAIL="\e[91;1m"
_WARN="\e[93;1m"
_END="\e[0m"
_LIGHT="\e[2m"

get_hypervisor () {
        local _HOSTNAME="$(hostname -s)"
        local _DOMAIN="$(hostname -d)"
        local _FQDN="${_LIGHT}${_HOSTNAME}.${_END}${_DOMAIN}"

        local _NAME_VERSION="$(cat /etc/*-release | grep -w 'NAME\|VERSION')"
        local _NAME="$(echo "$_NAME_VERSION" | grep NAME | awk 'BEGIN { FS = "=" } ; { print $2 }' | awk '{print $1}')"
        local _VERSION="$(echo "$_NAME_VERSION" | grep VERSION | awk 'BEGIN { FS = "=" } ; { print $2 }' | awk '{print $1}')"
        local _PVEVERSION="$(echo "$(pveversion)" | awk '{print $1}' | awk 'BEGIN { FS = "/" } ; { print $2 }')"

        local _IP="$(ip a | grep -E inet[^6] | grep global | awk '{print $2}')"

        echo -e "${_HEAD}> System information for hypervisor ${_SUCC}${_HOSTNAME}${_END}"
        echo ""
        echo -e "${_LINE}FQDN\t\t${_END}: ${_FQDN}"
        echo -e "${_LINE}OS\t\t${_END}: ${_NAME//\"} ${_VERSION//\"}"
        echo -e "${_LINE}PVE\t\t${_END}: ${_PVEVERSION}"

        if [ ! ${#_IDS} -eq 0 ]; then
                _FLAG=true
                echo
                _COUNT=$(echo $_IDS | sed 's/$//g' | sed 's/\n/ /' | wc -w)
                echo -e "${_LINE}LXC\t\t${_END}: ${_COUNT}"
        fi

        if [ ! ${#_VMS} -eq 0 ]; then
                test $_FLAG == true || echo
                _COUNT=$(echo $_VMS | sed 's/$//g' | sed 's/\n/ /' | wc -w)
                echo -e "${_LINE}VMs\t\t${_END}: ${_COUNT}"
        fi

        if [ ! ${#_IP} -eq 0 ]; then
                echo
                echo -e "${_SUBH}IP Adresses ${_END}"
                echo
        fi

        i=0
        for element in $_IP; do
                if [ $(echo $element | awk 'BEGIN { FS = "." } ; { print $1 }') -gt 10 ]; then echo -e "${_LINE}External\t${_END}: $element"
                elif [ $(echo $element | awk 'BEGIN { FS = "." } ; { print $1 }') -eq 10 ]; then echo -e "${_LINE}Internal\t${_END}: $element"
                else echo -e "${_LINE}Additional\t${_END}: $element"
                fi
                i=$(($i + 1))
    done
        echo
}

get_status () {
        local _STATUS=$(pct status "$_ID" | awk '{print $2}')

        test "$_STATUS" == "running" \
                && return 0
        test "$_STATUS" == "stopped" \
                        && return 1 \
                        || return -1
}

get_os () {
        local _NAME_VERSION=$(echo "cat /etc/*-release | grep -w 'NAME\|VERSION'" | pct enter "$_ID")
        local _NAME=$(echo "$_NAME_VERSION" | grep NAME | awk 'BEGIN { FS = "=" } ; { print $2 }' | awk '{print $1}')
        local _VERSION=$(echo "$_NAME_VERSION" | grep VERSION | awk 'BEGIN { FS = "=" } ; { print $2 }' | awk '{print $1}')

        echo -e "${_LINE}OS\t\t${_END}: ${_NAME//\"} ${_VERSION//\"}"
}

get_hostname () {
        local _HOSTNAME="$(pct exec "${_ID}" -- bash -c "hostname -s")"
        local _DOMAIN="$(pct exec "${_ID}" -- bash -c "hostname -d")"
        local _FQDN="${_LIGHT}${_HOSTNAME}.${_END}${_DOMAIN}"

        echo -e "${_LINE}FQDN\t\t${_END}: $_FQDN"
}

get_network () {
        local _IP="$(echo 'ip a | grep -E inet[^6] | grep global' | pct enter $_ID | awk '{print $2}')"
        local i=0

        if [ ! ${#_IP} -eq 0 ]; then
                echo
                echo -e "${_SUBH}IP Adresses${_END}"
                echo
        fi

        for element in $_IP; do
                if [ $element == ${#_IP} ]; then break; fi
                if [ $(echo $element | awk 'BEGIN { FS = "." } ; { print $1 }') -gt 10 ]; then echo -e "${_LINE}External\t${_END}: $element"
                elif [ $(echo $element | awk 'BEGIN { FS = "." } ; { print $1 }') -eq 10 ]; then echo -e "${_LINE}Internal\t${_END}: $element"
                else echo -e "${_LINE}Additional\t${_END}: $element"
                fi
		i=$(($i + 1))
	done 
}

clear

get_hypervisor

for _ID in ${_IDS[@]}; do
get_status 2&> /dev/null
        if [ $? -eq 0 ]; then echo -e "${_HEAD}> Container ${_SUCC}${_ID}${_END}"
                echo
                get_hostname
                get_os
                get_network
                echo
        elif [ $? -eq 1 ]; then
                if [ ! -z "$(cat /etc/pve/lxc/${_ID}.conf | grep arch)" ]; then
                        echo -e "${_HEAD}> Container ${_WARN}${_ID}${_END}"
                        echo
                        echo -e -n "${_WARN}Warning:${_END} Container ${_WARN}${_ID}${_END} has an issue: "
                        pct start "${_ID}"
                        echo
                else
                        echo -e "${_HEAD}> Container ${_FAIL}${_ID}${_END}"
                        echo
                        echo -e -n "${_FAIL}Error:${_END} Container ${_FAIL}${_ID}${_END} is invalid: "
                        pct start "${_ID}"
                        echo
                fi
        else
                echo -e "${_HEAD}> Container ${_FAIL}${_ID}${_END}"
                echo
                echo -e "${_FAIL}Error:${_END} Container ${_FAIL}${_ID}${_END} not found!"
                echo
        fi
done
