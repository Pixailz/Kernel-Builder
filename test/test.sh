#!/bin/bash

function usage() {
    echo "${0} : ${0} <config_name>"
}

if [[ -z "${1}" ]]; then
    usage
fi
