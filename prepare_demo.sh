#!/bin/bash

#############################################################################
# Script de Préparation pour la Démo SD-WAN
# Redéploie et configure tout automatiquement
#############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear

echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║        PRÉPARATION DE LA DÉMO SD-WAN                             ║
║        Redéploiement et Configuration Automatique                ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

#############################################################################
# ÉTAPE 1 : NETTOYAGE COMPLET
#############################################################################

echo -e "${YELLOW}[1/6]${NC} 🧹 Nettoyage de l'environnement existant..."

# Arrête le contrôleur Docker
docker stop sdwan-ryu 2>/dev/null || true

# Supprime les bridges OVS
for br in $(sudo ovs-vsctl list-br 2>/dev/null); do
    sudo ovs-vsctl del-br $br 2>/dev/null
done

# Supprime les namespaces
for ns in $(sudo ip netns list 2>/dev/null | awk '{print $1}'); do
    sudo ip netns del $ns 2>/dev/null
done

# Tue les processus iperf3
sudo pkill -9 iperf3 2>/dev/null || true

echo -e "${GREEN}✓${NC} Nettoyage terminé\n"
sleep 1

#############################################################################
# ÉTAPE 2 : DÉPLOIEMENT DE L'INFRASTRUCTURE
#############################################################################

echo -e "${YELLOW}[2/6]${NC} 🚀 Déploiement de l'infrastructure réseau..."

if sudo ./deploy_sdwan.sh > /tmp/deploy.log 2>&1; then
    echo -e "${GREEN}✓${NC} Infrastructure déployée avec succès\n"
else
    echo -e "${RED}✗${NC} Erreur lors du déploiement"
    echo -e "Voir les logs : cat /tmp/deploy.log"
    exit 1
fi
sleep 1

#############################################################################
# ÉTAPE 3 : CONFIGURATION DU ROUTAGE
#############################################################################

echo -e "${YELLOW}[3/6]${NC} ⚙️  Configuration du routage inter-sites..."

# Active le forwarding IP
for router in s1r s2r s3r; do
    sudo ip netns exec $router sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
    sudo ip netns exec $router sysctl -w net.ipv4.conf.all.proxy_arp=1 >/dev/null 2>&1
done

# Routes WAN
sudo ip netns exec s1r ip route add 192.168.2.0/24 dev v-s1w1 2>/dev/null || true
sudo ip netns exec s1r ip route add 192.168.3.0/24 dev v-s1w1 2>/dev/null || true

sudo ip netns exec s2r ip route add 192.168.1.0/24 dev v-s2w1 2>/dev/null || true
sudo ip netns exec s2r ip route add 192.168.3.0/24 dev v-s2w1 2>/dev/null || true

sudo ip netns exec s3r ip route add 192.168.1.0/24 dev v-s3w1 2>/dev/null || true
sudo ip netns exec s3r ip route add 192.168.2.0/24 dev v-s3w1 2>/dev/null || true

# Routes LAN (CRUCIAL)
sudo ip netns exec s1r ip route add 10.2.0.0/24 via 192.168.2.1 dev v-s1w1 2>/dev/null || true
sudo ip netns exec s1r ip route add 10.3.0.0/24 via 192.168.3.1 dev v-s1w1 2>/dev/null || true

sudo ip netns exec s2r ip route add 10.1.0.0/24 via 192.168.1.1 dev v-s2w1 2>/dev/null || true
sudo ip netns exec s2r ip route add 10.3.0.0/24 via 192.168.3.1 dev v-s2w1 2>/dev/null || true

sudo ip netns exec s3r ip route add 10.1.0.0/24 via 192.168.1.1 dev v-s3w1 2>/dev/null || true
sudo ip netns exec s3r ip route add 10.2.0.0/24 via 192.168.2.1 dev v-s3w1 2>/dev/null || true

# NAT/SNAT
for site in 1 2 3; do
    router="s${site}r"
    lan_net="10.${site}.0.0/24"
    wan_iface="v-s${site}w1"
    sudo ip netns exec $router iptables -t nat -F 2>/dev/null || true
    sudo ip netns exec $router iptables -t nat -A POSTROUTING -s $lan_net -o $wan_iface -j MASQUERADE 2>/dev/null || true
done

echo -e "${GREEN}✓${NC} Routage configuré\n"
sleep 1

#############################################################################
# ÉTAPE 4 : CONFIGURATION OVS
#############################################################################

echo -e "${YELLOW}[4/6]${NC} 🔧 Configuration des bridges Open vSwitch..."

for bridge in br-site1 br-site2 br-site3 br-wan; do
    sudo ovs-vsctl set-fail-mode $bridge standalone 2>/dev/null
    sudo ovs-ofctl del-flows $bridge -O OpenFlow13 2>/dev/null
    sudo ovs-ofctl add-flow $bridge "priority=0,actions=NORMAL" -O OpenFlow13 2>/dev/null
done

echo -e "${GREEN}✓${NC} Bridges OVS configurés\n"
sleep 1

#############################################################################
# ÉTAPE 5 : DÉMARRAGE DU CONTRÔLEUR
#############################################################################

echo -e "${YELLOW}[5/6]${NC} 🐳 Démarrage du contrôleur SDN..."

if docker ps -a | grep -q sdwan-ryu; then
    docker start sdwan-ryu >/dev/null 2>&1
else
    docker run -d \
      --name sdwan-ryu \
      --network host \
      --restart unless-stopped \
      osrg/ryu \
      ryu-manager --verbose ryu.app.simple_switch_13 >/dev/null 2>&1
fi

sleep 3

if docker ps | grep -q sdwan-ryu; then
    echo -e "${GREEN}✓${NC} Contrôleur démarré\n"
else
    echo -e "${YELLOW}⚠${NC}  Contrôleur non actif (mode standalone)\n"
fi
sleep 1

#############################################################################
# ÉTAPE 6 : TESTS DE VALIDATION
#############################################################################

echo -e "${YELLOW}[6/6]${NC} 🧪 Tests de validation...\n"

tests_passed=0
tests_total=3

# Test 1: Site 1 → Site 2
echo -n "  Test Site 1 → Site 2 (10.1.0.11 → 10.2.0.11) ... "
if sudo ip netns exec s1h1 ping -c 2 -W 2 10.2.0.11 >/dev/null 2>&1; then
    echo -e "${GREEN}✓ OK${NC}"
    tests_passed=$((tests_passed + 1))
else
    echo -e "${RED}✗ FAIL${NC}"
fi

# Test 2: Site 1 → Site 3
echo -n "  Test Site 1 → Site 3 (10.1.0.11 → 10.3.0.11) ... "
if sudo ip netns exec s1h1 ping -c 2 -W 2 10.3.0.11 >/dev/null 2>&1; then
    echo -e "${GREEN}✓ OK${NC}"
    tests_passed=$((tests_passed + 1))
else
    echo -e "${RED}✗ FAIL${NC}"
fi

# Test 3: Site 2 → Site 3
echo -n "  Test Site 2 → Site 3 (10.2.0.11 → 10.3.0.11) ... "
if sudo ip netns exec s2h1 ping -c 2 -W 2 10.3.0.11 >/dev/null 2>&1; then
    echo -e "${GREEN}✓ OK${NC}"
    tests_passed=$((tests_passed + 1))
else
    echo -e "${RED}✗ FAIL${NC}"
fi

echo ""

#############################################################################
# RÉSUMÉ ET LANCEMENT DE LA DÉMO
#############################################################################

if [ $tests_passed -eq $tests_total ]; then
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}   ✓✓✓ TOUS LES TESTS RÉUSSIS ($tests_passed/$tests_total) ✓✓✓${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}🎉 Le réseau SD-WAN est opérationnel !${NC}"
    echo ""
    echo -e "${YELLOW}Lancement de la démo dans 3 secondes...${NC}"
    sleep 3
    
    # Lance la démo
    sudo ./demo_complete.sh
    
else
    echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}   ✗ ÉCHEC : $tests_passed/$tests_total tests réussis${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Diagnostic :${NC}"
    echo "  1. Vérifiez les routes : sudo ip netns exec s1r ip route"
    echo "  2. Testez manuellement : sudo ip netns exec s1h1 ping 10.2.0.11"
    echo "  3. Voir les logs : cat /tmp/deploy.log"
    echo ""
    exit 1
fi
