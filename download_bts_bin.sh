#!/bin/sh

if [ -n "$1" ]; then
   VERSION=$1
else
   VERSION=`curl -w %{redirect_url} https://github.com/bitshares/bitshares-core/releases/latest 2>/dev/null | cut -f8 -d'/'`
fi
DIR=bitshares-core-${VERSION}-linux-amd64-bin
FILE=${DIR}.tar.bz2

wget -c https://github.com/bitshares/bitshares-core/releases/download/${VERSION}/${FILE}

sha256sum ${FILE}

tar xjf ${FILE}

mv ${DIR}/witness_node ./witness_node.${VERSION}
mv ${DIR}/cli_wallet ./cli_wallet.${VERSION}
rm -rf ${DIR} ${FILE}
