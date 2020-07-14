#~/bin/bash
versionText="$(head -1 version.txt)"
echo "Packing ver: " $versionText
tar -zcvf agaw-server_${versionText}_headless_linux.tar.gz agaw-server README.md server-settings.ini
#tar -zcvf agawServer.tar.gz server_guiless.debug server-settings.ini
