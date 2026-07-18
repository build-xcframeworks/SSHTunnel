#!/bin/bash

set -e

LIBRESSL_REF=${LIBRESSL_REF:-master}
LIBSSH2_REF=${LIBSSH2_REF:-master}

if [ -z "$LIBRESSL_OUTPUT_DIR" ]
then
  git clone --depth 1 --branch "$LIBRESSL_REF" https://github.com/build-xcframeworks/libressl.git libressl-source
  (
    cd libressl-source
    bash libressl.sh
  )
  LIBRESSL_OUTPUT_DIR=$(pwd)/libressl-source/output
fi

if [ -z "$LIBSSH2_OUTPUT_DIR" ]
then
  git clone --depth 1 --branch "$LIBSSH2_REF" https://github.com/build-xcframeworks/libssh2.git libssh2-source
  (
    cd libssh2-source
    LIBRESSL_OUTPUT_DIR="$LIBRESSL_OUTPUT_DIR" bash libssh2.sh
  )
  LIBSSH2_OUTPUT_DIR=$(pwd)/libssh2-source/output
fi

mkdir -p frameworks
cp -R "$LIBRESSL_OUTPUT_DIR/libssl.xcframework" frameworks/
cp -R "$LIBRESSL_OUTPUT_DIR/libcrypto.xcframework" frameworks/
cp -R "$LIBSSH2_OUTPUT_DIR/libssh2.xcframework" frameworks/

# libssl and libcrypto carry the same OpenSSL headers. Keep one copy to avoid
# duplicate ProcessXCFramework outputs in Xcode.
for headers in frameworks/libssl.xcframework/*/Headers
do
  /bin/rm -R "$headers"
  mkdir -p "$headers"
done
