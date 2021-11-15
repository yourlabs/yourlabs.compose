#!/bin/bash -eu
for home in /root /home/*; do
    [ -d $home/.yourlabs.compose ] || continue
    pushd $home/.yourlabs.compose &> /dev/null
    for project in *; do
        [ -f $project/removeat ] || continue
        if [[ $(date +%s) -gt $(<$project/removeat) ]]; then
            pushd $project
            docker compose down --rmi all --volumes --remove-orphans
            popd &> /dev/null
            rm -rf $project
        fi
    done
    popd &> /dev/null
done
