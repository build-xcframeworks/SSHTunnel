export LIBRESSL=3.2.2
curl -iL --max-redirs 1 -o libressl.zip https://github.com/build-xcframeworks/libressl/releases/download/${LIBRESSL}/${LIBRESSL}.zip
unzip libressl.zip
mv ${LIBRESSL} frameworks
rm -R frameworks/libssl.xcframework/*/Headers # don't have double set headers

git clone https://github.com/build-xcframeworks/libssh2
cd libssh2
bash libssh2.sh
mv output/libssh2.xcframework ../frameworks
cd ..
