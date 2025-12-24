#!/bin/bash

echo "Correction des noms d'interfaces pour respecter la limite de 15 caractères..."

# Sauvegarde
cp deploy_sdwan.sh deploy_sdwan.sh.original

# Stratégie : s1h1, s1h2, s2h1, s2h2, s3h1, s3h2 pour les hosts
#             s1r, s2r, s3r pour les routers

# Remplace les noms de sites et hosts
sed -i '
    s/site1-host1/s1h1/g
    s/site1-host2/s1h2/g
    s/site2-host1/s2h1/g
    s/site2-host2/s2h2/g
    s/site3-host1/s3h1/g
    s/site3-host2/s3h2/g
    s/site1-router/s1r/g
    s/site2-router/s2r/g
    s/site3-router/s3r/g
' deploy_sdwan.sh

echo "✓ Noms raccourcis appliqués!"
echo ""
echo "Nouveaux noms:"
echo "  site1-host1 → s1h1"
echo "  site1-host2 → s1h2"
echo "  site1-router → s1r"
echo "  etc."
echo ""

# Vérifie les noms générés
echo "Vérification des longueurs de noms d'interfaces:"
grep "ip link add" deploy_sdwan.sh | while read -r line; do
    # Extrait les noms entre guillemets
    names=$(echo "$line" | grep -o '"[^"]*"' | tr -d '"')
    for name in $names; do
        len=${#name}
        if [ $len -gt 15 ]; then
            echo "  ⚠️  TROP LONG ($len): $name"
        elif [ $len -gt 12 ]; then
            echo "  ⚡ Limite ($len): $name"
        fi
    done
done | sort -u

echo ""
echo "Exemples de commandes avec nouveaux noms:"
grep "ip link add" deploy_sdwan.sh | head -3
