#!/bin/bash
# On FreeBSD change the above line to #!/usr/local/bin/bash
#
# /usr/local/bin/dhcp-dyndns.sh
#
# This script is for secure DDNS updates on Samba,
# it can also add the 'macAddress' to the Computers object.
#
# Version: 0.9.6
#
# Copyright (C) Rowland Penny 2020-2022
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# You may need to ensure that you have a useful path
# If you have 'path' problems, Uncomment the next line and adjust for
# your setup e.g. self-compiled Samba
#export PATH=/usr/local/samba/bin:/usr/local/samba/sbin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

##########################################################################
#                                                                        #
#    You can optionally add the 'macAddress' to the Computers object.    #
#    Add 'dhcpduser' to the 'Domain Admins' group if used                #
#    Change the next line to 'yes' to make this happen                   #
Add_macAddress='no'
#                                                                        #
##########################################################################

# On FreeBSD change this to /usr/local/etc/dhcpduser.keytab
# keytab=/etc/dhcpduser.keytab
# Zentyal keytab path
keytab=/etc/dhcp/samba-keys/dhcpduser.keytab

usage()
{
	cat <<-EOF
	USAGE:
	  $(basename "$0") add ip-address dhcid|mac-address hostname
	  $(basename "$0") delete ip-address dhcid|mac-address
	EOF
}

_KERBEROS()
{
	# get current time as a number
	test=$(date +%d'-'%m'-'%y' '%H':'%M':'%S)
	# Note: there have been problems with this
	# check that 'date' returns something like

	# Check for valid kerberos ticket
	#logger "${test} [dyndns] : Running check for valid kerberos ticket"
	klist -c "${KRB5CCNAME}" -s
	ret="$?"
	if [ $ret -ne 0 ]
	then
		logger "${test} [dyndns] : Getting new ticket, old one has expired"
		# On FreeBSD change the -F to --no-forwardable
		kinit -F -k -t $keytab "${SETPRINCIPAL}"
		ret="$?"
		if [ $ret -ne 0 ]
		then
			logger "${test} [dyndns] : dhcpd kinit for dynamic DNS failed"
			exit 1
		fi
	fi
}

rev_zone_info()
{
	local RevZone="$1"
	local IP="$2"
	local rzoneip
	rzoneip="${RevZone%.in-addr.arpa}"
	local rzonenum
	rzonenum=$(echo "$rzoneip" |  tr '.' '\n')
	declare -a words
	for n in $rzonenum
	do
		words+=("$n")
	done
	local numwords="${#words[@]}"

	unset ZoneIP
	unset RZIP
	unset IP2add

	case "$numwords" in
		1)
			# single ip rev zone '192'
			ZoneIP=$(echo "${IP}" | awk -F '.' '{print $1}')
			RZIP="${rzoneip}"
			IP2add=$(echo "${IP}" | awk -F '.' '{print $4"."$3"."$2}')
			;;
		2)
			# double ip rev zone '168.192'
			ZoneIP=$(echo "${IP}" | awk -F '.' '{print $1"."$2}')
			RZIP=$(echo "${rzoneip}" | awk -F '.' '{print $2"."$1}')
			IP2add=$(echo "${IP}" | awk -F '.' '{print $4"."$3}')
			;;
		3)
			# triple ip rev zone '0.168.192'
			ZoneIP=$(echo "${IP}" | awk -F '.' '{print $1"."$2"."$3}')
			RZIP=$(echo "${rzoneip}" | awk -F '.' '{print $3"."$2"."$1}')
			IP2add=$(echo "${IP}" | awk -F '.' '{print $4}')
			;;
		*)
			# should never happen
			exit 1
			;;
	esac
}

BINDIR=$(samba -b | grep 'BINDIR' | grep -v 'SBINDIR' | awk '{print $NF}')
[[ -z $BINDIR ]] && printf "Cannot find the 'samba' binary, is it installed ?\\nOr is your path set correctly ?\\n"
WBINFO="$BINDIR/wbinfo"

SAMBATOOL=$(command -v samba-tool)
[[ -z $SAMBATOOL ]] && printf "Cannot find the 'samba-tool' binary, is it installed ?\\nOr is your path set correctly ?\\n"

MINVER=$($SAMBATOOL -V | grep -o '[0-9]*' | tr '\n' ' ' | awk '{print $2}')
if [ "$MINVER" -gt '14' ]
then
	KTYPE="--use-kerberos=required"
else
	KTYPE="-k yes"
fi

# DHCP Server hostname
Server=$(hostname -s)

# DNS domain
domain=$(hostname -d)
if [ -z "${domain}" ]
then
	logger "Cannot obtain domain name, is DNS set up correctly?"
	logger "Cannot continue... Exiting."
	exit 1
fi

# Samba realm
REALM="${domain^^}"

# krbcc ticket cache
export KRB5CCNAME="/tmp/dhcp-dyndns.cc"

# Kerberos principal
SETPRINCIPAL="dhcpduser@${REALM}"
# Kerberos keytab as above
# krbcc ticket cache : /tmp/dhcp-dyndns.cc
TESTUSER="$($WBINFO -u | grep 'dhcpduser')"
if [ -z "${TESTUSER}" ]
then
	logger "No AD dhcp user exists, need to create it first.. exiting."
	logger "you can do this by typing the following commands"
	logger "kinit Administrator@${REALM}"
	logger "$SAMBATOOL user create dhcpduser --random-password --description='Unprivileged user for DNS updates via ISC DHCP server'"
	logger "$SAMBATOOL user setexpiry dhcpduser --noexpiry"
	logger "$SAMBATOOL group addmembers DnsAdmins dhcpduser"
	exit 1
fi

# Check for Kerberos keytab
if [ ! -f "$keytab" ]
then
	logger "Required keytab $keytab not found, it needs to be created."
	logger "Use the following commands as root"
	logger "$SAMBATOOL domain exportkeytab --principal=${SETPRINCIPAL} $keytab"
	logger "chown XXXX:XXXX $keytab"
	logger "Replace 'XXXX:XXXX' with the user & group that dhcpd runs as on your distro"
	logger "chmod 400 $keytab"
	exit 1
fi

# Variables supplied by dhcpd.conf
action="$1"
ip="$2"
DHCID="$3"
name="${4%%.*}"

# Exit if no ip address
if [ -z "${ip}" ]
then
	usage
	exit 1
fi

# Exit if no computer name supplied, unless the action is 'delete'
if [ -z "${name}" ]
then
	if [ "${action}" = "delete" ]
	then
		name=$(host -t PTR "${ip}" | awk '{print $NF}' | awk -F '.' '{print $1}')
	else
		usage
		exit 1
	fi
fi

# exit if name contains a space
case ${name} in
	*\ * )
		logger "Invalid hostname '${name}' ...Exiting"
		exit
		;;
esac

# if you want computers with a hostname that starts with 'dhcp' in AD
# comment the following block of code.
if [[ $name == dhcp* ]]
then
	logger "not updating DNS record in AD, invalid name"
	exit 0
fi

## update ##
case "${action}" in
	add)
		_KERBEROS
		count=0
		# does host have an existing 'A' record ?
		mapfile -t A_REC < <($SAMBATOOL dns query "${Server}" "${domain}" "${name}" A "$KTYPE" 2>/dev/null | grep 'A:' | awk '{print $2}')
		if [ "${#A_REC[@]}" -eq 0 ]
		then
			# no A record to delete
			result1=0
			$SAMBATOOL dns add "${Server}" "${domain}" "${name}" A "${ip}" "$KTYPE"
			result2="$?"
		elif [ "${#A_REC[@]}" -gt 1 ]
		then
			for i in "${A_REC[@]}"
			do
				$SAMBATOOL dns delete "${Server}" "${domain}" "${name}" A "${i}" "$KTYPE"
			done
			# all A records deleted
			result1=0
			$SAMBATOOL dns add "${Server}" "${domain}" "${name}" A "${ip}" "$KTYPE"
			result2="$?"
		elif [ "${#A_REC[@]}" -eq 1 ]
		then
			# turn array into a variable
			VAR_A_REC="${A_REC[*]}"
			if [ "$VAR_A_REC" = "${ip}" ]
			then
				# Correct A record exists, do nothing
				logger "Correct 'A' record exists, not updating."
				result1=0
				result2=0
				count=$((count+1))
			elif [ "$VAR_A_REC" != "${ip}" ]
			then
				# Wrong A record exists
				logger "'A' record changed, updating record."
				$SAMBATOOL dns delete "${Server}" "${domain}" "${name}" A "${VAR_A_REC}" "$KTYPE"
				result1="$?"
				$SAMBATOOL dns add "${Server}" "${domain}" "${name}" A "${ip}" "$KTYPE"
				result2="$?"
			fi
		fi

		# get existing reverse zones (if any)
		ReverseZones=$($SAMBATOOL dns zonelist "${Server}" "$KTYPE" --reverse | grep 'pszZoneName' | awk '{print $NF}')
		if [ -z "$ReverseZones" ]; then
			logger "No reverse zone found, not updating"
			result3='0'
			result4='0'
			count=$((count+1))
		else
			for revzone in $ReverseZones
			do
				rev_zone_info "$revzone" "${ip}"
				if [[ ${ip} = $ZoneIP* ]] && [ "$ZoneIP" = "$RZIP" ]
				then
					# does host have an existing 'PTR' record ?
					PTR_REC=$($SAMBATOOL dns query "${Server}" "${revzone}" "${IP2add}" PTR "$KTYPE" 2>/dev/null | grep 'PTR:' | awk '{print $2}' | awk -F '.' '{print $1}')
					if [[ -z $PTR_REC ]]
					then
						# no PTR record to delete
						result3=0
						$SAMBATOOL dns add "${Server}" "${revzone}" "${IP2add}" PTR "${name}"."${domain}" "$KTYPE"
						result4="$?"
						break
					elif [ "$PTR_REC" = "${name}" ]
					then
						# Correct PTR record exists, do nothing
						logger "Correct 'PTR' record exists, not updating."
						result3=0
						result4=0
						count=$((count+1))
						break
					elif [ "$PTR_REC" != "${name}" ]
					then
						# Wrong PTR record exists
						# points to wrong host
						logger "'PTR' record changed, updating record."
						$SAMBATOOL dns delete "${Server}" "${revzone}" "${IP2add}" PTR "${PTR_REC}"."${domain}" "$KTYPE"
						result3="$?"
						$SAMBATOOL dns add "${Server}" "${revzone}" "${IP2add}" PTR "${name}"."${domain}" "$KTYPE"
						result4="$?"
						break
					fi
				else
					continue
				fi
			done
	        fi
		;;
	delete)
		_KERBEROS

		count=0
		$SAMBATOOL dns delete "${Server}" "${domain}" "${name}" A "${ip}" "$KTYPE"
		result1="$?"
		# get existing reverse zones (if any)
		ReverseZones=$($SAMBATOOL dns zonelist "${Server}" --reverse "$KTYPE" | grep 'pszZoneName' | awk '{print $NF}')
		if [ -z "$ReverseZones" ]
		then
			logger "No reverse zone found, not updating"
			result2='0'
			count=$((count+1))
		else
			for revzone in $ReverseZones
			do
				rev_zone_info "$revzone" "${ip}"
				if [[ ${ip} = $ZoneIP* ]] && [ "$ZoneIP" = "$RZIP" ]
				then
					host -t PTR "${ip}" > /dev/null 2>&1
					ret="$?"
					if [ $ret -eq 0 ]
					then
						$SAMBATOOL dns delete "${Server}" "${revzone}" "${IP2add}" PTR "${name}"."${domain}" "$KTYPE"
						result2="$?"
					else
						result2='0'
						count=$((count+1))
					fi
					break
				else
					continue
				fi
			done
		fi
		result3='0'
		result4='0'
		;;
	*)
		logger "Invalid action specified"
		exit 103
	;;
esac

result="${result1}:${result2}:${result3}:${result4}"

if [ "$count" -eq 0 ]
then
	if [ "${result}" != "0:0:0:0" ]
	then
		logger "DHCP-DNS $action failed: ${result}"
		exit 1
	else
		logger "DHCP-DNS $action succeeded"
	fi
fi

if [ "$Add_macAddress" != 'no' ]
then
	if [ -n "$DHCID" ]
	then
		Computer_Object=$(ldbsearch "$KTYPE" -H ldap://"$Server" "(&(objectclass=computer)(objectclass=ieee802Device)(cn=$name))" | grep -v '#' | grep -v 'ref:')
		if [ -z "$Computer_Object" ]
		then
			# Computer object not found with the 'ieee802Device' objectclass, does the computer actually exist, it should.
			Computer_Object=$(ldbsearch "$KTYPE" -H ldap://"$Server" "(&(objectclass=computer)(cn=$name))" | grep -v '#' | grep -v 'ref:')
			if [ -z "$Computer_Object" ]
			then
				logger "Computer '$name' not found. Exiting."
				exit 68
			else
				DN=$(echo "$Computer_Object" | grep 'dn:')
				objldif="$DN
changetype: modify
add: objectclass
objectclass: ieee802Device"

				attrldif="$DN
changetype: modify
add: macAddress
macAddress: $DHCID"

				# add the ldif
				echo "$objldif" | ldbmodify "$KTYPE" -H ldap://"$Server"
				ret="$?"
				if [ $ret -ne 0 ]
				then
					logger "Error modifying Computer objectclass $name in AD."
					exit "${ret}"
				fi
				sleep 2
				echo "$attrldif" | ldbmodify "$KTYPE" -H ldap://"$Server"
				ret="$?"
				if [ "$ret" -ne 0 ]; then
					logger "Error modifying Computer attribute $name in AD."
					exit "${ret}"
				fi
				unset objldif
				unset attrldif
				logger "Successfully modified Computer $name in AD"
			fi
	else
		DN=$(echo "$Computer_Object" | grep 'dn:')
		attrldif="$DN
changetype: modify
replace: macAddress
macAddress: $DHCID"

		echo "$attrldif" | ldbmodify "$KTYPE" -H ldap://"$Server"
		ret="$?"
		if [ "$ret" -ne 0 ]
		then
			logger "Error modifying Computer attribute $name in AD."
			exit "${ret}"
		fi
			unset attrldif
			logger "Successfully modified Computer $name in AD"
		fi
	fi
fi

exit 0