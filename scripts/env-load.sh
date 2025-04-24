#!/usr/bin/env sh

[ "$#" -eq 0 ] && echo "No profile provided!" && exit 128
profile=$1

eval $(aws configure export-credentials --profile ${profile} --format env)
