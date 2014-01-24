#!/usr/bin/bash
#
# Put this DC in maintenance mode:
# - put cloudapi in readonly mode
# - wait for a while for the wf queue to drain
#

export PS4='[\D{%FT%TZ}] ${BASH_SOURCE}:${LINENO}: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -o xtrace
set -o errexit
set -o pipefail

TOP=$(cd $(dirname $0)/; pwd)

source $TOP/libupgrade.sh


#---- support routines

function fatal
{
    echo "$0: fatal error: $*" >&2
    exit 1
}


#---- mainline

[[ $(hostname) == "headnode" ]] || fatal "not running on the headnode"
cloudapi_readonly_mode true
wait_for_wf_drain

