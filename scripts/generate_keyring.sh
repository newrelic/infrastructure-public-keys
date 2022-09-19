#!/bin/bash

# Exit if any commants has a non-zero exit code
set -e

if [ -z "$1" ]; then
	echo "Usage: generate_keyring key1 key2 ..." >&2
	echo "A list of key paths must be provided as arguments" >&2
	exit 1
fi

# default values
KEYRING="gpg/keyrings/newrelic-infra-keyring.gpg"

# avoid gnupg touching ~/.gnupg
GNUPGHOME=$(mktemp -d -t nrring.XXXXXXXX)
export GNUPGHOME
trap cleanup exit
cleanup () {
	rm -rf "$GNUPGHOME"
}


echo "Creating newrelic-infra-keyring.gpg keyring with keys: $@"

# array to store keyids (to prevent adding duplicated keys)
keyids=()

for keyfile in "$@"
do
	if [ -f $keyfile ]; then
		keyid=$(gpg --with-colons --keyid long --options /dev/null --no-auto-check-trustdb < $keyfile | grep '^pub' | cut -d : -f 5)
		if [[ ! " ${keyids[*]} " =~ " ${keyid} " ]]; then
			keyids+=($keyid)	
			gpg --quiet --import $keyfile
		else
			echo "Skipping $keyfile as already exists in keyring"
			continue
		fi
	else
		echo "Key file $key does not exists, exiting..."
	fi
done

# empty keyring file
true > $KEYRING

# append keys to keyring
for keyid in "${keyids[@]}"
do
	gpg --no-auto-check-trustdb --options /dev/null \
		--export-options export-clean,no-export-attributes \
		--export $keyid >> $KEYRING
	echo "Key with ID $keyid added into the keyring"
done

echo "Keyring successfully generated with ${#keyids[@]}, available in: $KEYRING"
