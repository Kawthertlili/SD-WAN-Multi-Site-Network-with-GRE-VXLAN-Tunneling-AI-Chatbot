#!/bin/bash
# Correction rapide des noms d'interfaces

cd ~/sdwan-project

echo "Correction du fichier deploy_sdwan.sh..."

# Sauvegarde
cp deploy_sdwan.sh deploy_sdwan.sh.bak

# Remplace tous les noms longs
sed -i 's/ip link add "veth-${ns_name}"/ip link add "v-${ns_name}"/g' deploy_sdwan.sh
sed -i 's/"veth-${ns_name}"/"v-${ns_name}"/g' deploy_sdwan.sh
sed -i 's/ip link add "veth-${router_ns}-lan"/ip link add "v-${router_ns}-lan"/g' deploy_sdwan.sh
sed -i 's/"veth-${router_ns}-lan"/"v-${router_ns}-lan"/g' deploy_sdwan.sh
sed -i 's/ip link add "${wan_iface}"/ip link add "v-r${site_num}-w${path_num}"/g' deploy_sdwan.sh
sed -i 's/"${wan_iface}"/"v-r${site_num}-w${path_num}"/g' deploy_sdwan.sh
sed -i 's/"${wan_iface}-br"/"v-r${site_num}-w${path_num}b"/g' deploy_sdwan.sh

echo "✓ Correction terminée!"
echo "Fichier original sauvegardé dans: deploy_sdwan.sh.bak"
