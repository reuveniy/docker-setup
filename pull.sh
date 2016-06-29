#!/bin/bash -eu

cat docker.images | shuf | while read i; do
   if [ -z "$i" ]; then continue; fi;
   if [ $i == "#*" ]; then continue; fi;
   echo $i; docker pull $i;
done

