#!/bin/bash

for dir in \
	"/usr/src/kernels/$(uname -r)-$(arch)" \
	"/usr/src/kernels/$(uname -r)" \
	"/usr/src/linux-headers-$(uname -r)"; do
	if [ -d $dir ]; then
		echo $dir
		exit 0
	fi
done

exit 1

