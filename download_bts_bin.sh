#!/bin/sh

VERSION=`curl https://github.com/bitshares/bitshares-core/releases/latest 2>/dev/null | cut -f2 -d'"' | cut -f8 -d'/'`
DIR=bitshares-core-${VERSION}-linux-amd64-bin
FILE=${DIR}.tar.bz2

wget -c https://github.com/bitshares/bitshares-core/releases/download/${VERSION}/${FILE}

sha256sum ${FILE}

tar xjf ${FILE}

mv ${DIR}/witness_node ./witness_node.${VERSION}
mv ${DIR}/cli_wallet ./cli_wallet.${VERSION}
rm -rf ${DIR} ${FILE}

