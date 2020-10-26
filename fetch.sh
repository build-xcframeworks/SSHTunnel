LIBRESSL=3.2.2
curl -iL --max-redirs 1 -o libressl.zip https://github.com/build-xcframeworks/libressl/releases/download/${LIBRESSL}/${LIBRESSL}.zip
unzip libressl.zip
mv ${LIBRESSL} libressl
