#!/bin/bash
set -e

KEY_FORMAT=$1 # APT, RPM or TARGZ

if [ -z $KEY_FORMAT ];then
  echo -e "${RED} usage ./generate_key.sh [APT|RPM|TAGGZ] .${NC}"
      exit 1
    fi

# params: KEY_FORMAT
PASSPHRASE_LENGTH=24
KEY_LIFE_TIME="10y"
EMAIL="caos-team@newrelic.com"
OUTPUT_DIR="$HOME/caos_key_generator"
LOG_FILE="$OUTPUT_DIR/key_generation.log"
RED='\033[0;31m'
NC='\033[0m' # No Color

#check dependencies
DEP="gpg openssl docker"
for dep in $DEP;do
  if [ ! $( which "$dep" ) ];then
    echo -e "${RED}$dep is mandatory. Install it and restart the process.${NC}"
    exit 1
  fi
done

echo "Existing keys sanity check..."
#sanity check
KEYS_COUNT=$(gpg --list-secret-keys --keyid-format=long 2>$LOG_FILE | grep "${EMAIL}" | wc -l | grep -oE "[0-9]*")
if [ "${KEYS_COUNT}" != "0" ]
then
  echo -e "${RED}You already have a key for ${EMAIL}. Clean manually and retry.${NC}"
  cat <<EOF
You can execute this commands to find a key and remove it:
gpg --list-secret-keys --with-fingerprint --keyid-format=long "${EMAIL}" | grep "Key fingerprint" | grep -E -o "= ([A-Z0-9 ]*)" | sed 's/ //g' | grep -o "[0-9A-Z]*"
gpg --batch --delete-secret-key --yes KEY_ID_HERE
EOF
  exit 1
fi

# prepare env to work with
mkdir -p "${OUTPUT_DIR}"
WORKDIR=$(mktemp -d)
cd "${WORKDIR}"

echo "Generating passphrase..."
# generate passphrase
PASSPHRASE=$(openssl rand -base64 $PASSPHRASE_LENGTH)
if [ "$PASSPHRASE" == "" ];then
  echo -e "${RED}PASSPHRASE was not generated properly${NC}"
  exit 1
fi

echo "Generating key..."
# generate key
# generate setting file for key gen
cat >key_config <<EOF
     %echo Generating GPG Signing key for $KEY_FORMAT
     Key-Type: RSA
     Key-Length: 4096
     Key-Usage: sign
     Name-Real: Infrastructure
     Name-Comment: NewRelic
     Name-Email: $EMAIL
     Expire-Date: $KEY_LIFE_TIME
     Passphrase: $PASSPHRASE
     # Do a commit here, so that we can later print "done" :-)
     %commit
     %echo done
EOF
gpg --batch --generate-key key_config >> "$LOG_FILE" 2>&1

#sanity check
KEYS_COUNT=$(gpg --list-secret-keys --keyid-format=long $EMAIL 2>>$LOG_FILE | grep rsa4096 | wc -l | grep -Eo "[0-9]*")
if [ "$KEYS_COUNT" -eq 0 ];then
  echo -e "${RED}Key was not generated${NC}"
  exit 1
fi

echo "Exporting key..."
KEY_ID=$(gpg --list-secret-keys --keyid-format=long $EMAIL | grep rsa4096 | grep -E -o "\/([A-Z0-9]*)\ " | grep -o "[0-9A-Z]*")

KEY_UID="${KEY_ID}_${KEY_FORMAT}"

# export keys from keyring
gpg --batch --pinentry-mode=loopback --passphrase $PASSPHRASE --output "${KEY_UID}_private.gpg" --armor --export-secret-key $KEY_ID
gpg --batch --pinentry-mode=loopback --passphrase $PASSPHRASE --output "${KEY_UID}_public.gpg" --armor --export $KEY_ID

# private key as base64
openssl base64 -in "${KEY_UID}_private.gpg" -out "${KEY_UID}_private.gpg.base64"
echo "$PASSPHRASE" > "${KEY_UID}_passphrase.txt"
if [ $( grep "$PASSPHRASE" "${KEY_UID}_passphrase.txt" ) != "$PASSPHRASE" ];then
  echo -e "${RED}passphrase file was not created properly${NC}"
  exit 1
fi

# zip
zip "${KEY_UID}_public.gpg.zip" "${KEY_UID}_public.gpg" >> "$LOG_FILE" 2>&1
zip "${KEY_UID}_private.gpg.base64.zip" "${KEY_UID}_private.gpg.base64" >> "$LOG_FILE" 2>&1
zip "${KEY_UID}_passphrase.txt.zip" "${KEY_UID}_passphrase.txt" >> "$LOG_FILE" 2>&1

# copy what needed to home directory
cp ${KEY_UID}*zip "$OUTPUT_DIR"
echo "Keys successfully generated!"

echo "Starting tests..."
# tests
# create test dir
TESTDIR=$(mktemp -d)
echo "test directory: ${TESTDIR}" >> $LOG_FILE
cd $TESTDIR

cp $OUTPUT_DIR/${KEY_UID}*zip .

# test
TEST_FILE="test_original.txt"
echo -e "test for $KEY_FORMAT $EMAIL" > $TEST_FILE

# run docker which installs base64 key in the system and generates signature for a test file
GNUPGHOME="/root/.gnupg"
cat > test_sign.sh <<EOF
#!/usr/bin/env sh
set -e

apt-get -qq update
apt-get -qq install -y gpg zip unzip

mkdir -p "${GNUPGHOME}"
chmod -R 600 "${GNUPGHOME}"

cd /srv/test_dir

unzip "${KEY_UID}_private.gpg.base64.zip"
unzip "${KEY_UID}_passphrase.txt.zip"

ls -la .

cat ${KEY_UID}_passphrase.txt > "${GNUPGHOME}/gpg-passphrase"
echo "passphrase-file ${GNUPGHOME}/gpg-passphrase" >> "$GNUPGHOME/gpg.conf"
echo 'allow-loopback-pinentry' >> "${GNUPGHOME}/gpg-agent.conf"
echo 'pinentry-mode loopback' >> "${GNUPGHOME}/gpg.conf"
echo 'use-agent' >> "${GNUPGHOME}/gpg.conf"
echo RELOADAGENT | gpg-connect-agent

cat ${KEY_UID}_private.gpg.base64 | base64 -d | gpg --batch --import -

echo "===> Signing $TEST_FILE"
gpg --sign --armor --detach-sig $TEST_FILE

ls -la .
EOF
chmod +x test_sign.sh
docker run --rm -t -v $TESTDIR:/srv/test_dir ubuntu /srv/test_dir/test_sign.sh >> "$LOG_FILE"
# run docker which imports public key and verify signature of a file

cat > test_verify.sh <<EOF
#!/usr/bin/bash
set -e

apt-get -qq update
apt-get -qq install -y gpg zip unzip

cd /srv/test_dir

unzip "${KEY_UID}_public.gpg.zip"

ls -la .

gpg --import "${KEY_UID}_public.gpg"

# trust public key
for fpr in \$(gpg --list-keys --with-colons  | awk -F: '/fpr:/ {print \$10}' | sort -u); do  echo -e "5\ny\n" |  gpg --command-fd 0 --expert --edit-key \$fpr trust; done

echo "===> Verifying $TEST_FILE"
gpg --verify "$TEST_FILE.asc" "$TEST_FILE"

# todo check exit code
EOF

chmod +x test_verify.sh
set +e
docker run --rm -t -v $TESTDIR:/srv/test_dir ubuntu bash -c "./srv/test_dir/test_verify.sh" >> "$LOG_FILE"
if [ $? -ne 0 ];then
  echo -e "${RED}Tests failed. Check $LOG_FILE and restart the process${NC}"
  exit 1
fi
set -e
echo "Tests successfully passed!"

echo "Cleaning temporary folders..."
# cleanup
KEY_FINGERPRINT=$(gpg --list-secret-keys --with-fingerprint --keyid-format=long "${EMAIL}" | grep "Key fingerprint" | grep -E -o "= ([A-Z0-9 ]*)" | sed 's/ //g' | grep -o "[0-9A-Z]*")
gpg --batch --delete-secret-key --yes $KEY_FINGERPRINT >> "$LOG_FILE" 2>&1

PUBLIC_KEY_FINGERPRINT=$(gpg --list-keys --with-fingerprint --keyid-format=long "${EMAIL}" | grep "Key fingerprint" | grep -E -o "= ([A-Z0-9 ]*)" | sed 's/ //g' | grep -o "[0-9A-Z]*")
gpg --batch --delete-key --yes $PUBLIC_KEY_FINGERPRINT >> "$LOG_FILE" 2>&1

cd ~
rm -r $WORKDIR
rm -r $TESTDIR
echo "Done! Your keys are located in $OUTPUT_DIR. Save them and delete this folder."
echo "run 'ls -la $OUTPUT_DIR/${KEY_UID}*' to find your keys"
echo "Have a nice day!"