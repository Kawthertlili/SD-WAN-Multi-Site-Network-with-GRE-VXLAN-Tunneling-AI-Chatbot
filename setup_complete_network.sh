#!/bin/bash

echo "Configuration complète du réseau SD-WAN..."

# Active le forwarding IP sur tous les routeurs
echo "⚙️  Activation du forwarding IP..."
for router in s1r s2r s3r; do
    sudo ip netns exec $router sysctl -w net.ipv4.ip_forward=1 >/dev/null
    sudo ip netns exec $router sysctl -w net.ipv4.conf.all.proxy_arp=1 >/dev/null
    sudo ip netns exec $router sysctl -w net.ipv4.conf.all.arp_announce=2 >/dev/null
done

# Configure les routes WAN directes entre routeurs
echo "🌐 Configuration des routes WAN..."

# Site 1 Router
sudo ip netns exec s1r ip route add 192.168.2.0/24 dev v-s1w1 2>/dev/null || true
sudo ip netns exec s1r ip route add 192.168.3.0/24 dev v-s1w1 2>/dev/null || true

# Site 2 Router  
sudo ip netns exec s2r ip route add 192.168.1.0/24 dev v-s2w1 2>/dev/null || true
sudo ip netns exec s2r ip route add 192.168.3.0/24 dev v-s2w1 2>/dev/null || true

# Site 3 Router
sudo ip netns exec s3r ip route add 192.168.1.0/24 dev v-s3w1 2>/dev/null || true
sudo ip netns exec s3r ip route add 192.168.2.0/24 dev v-s3w1 2>/dev/null || true

# Configure les routes LAN vers les réseaux distants
echo "📍 Configuration des routes LAN..."

# Site 1 Router → vers LANs Site 2 et Site 3
sudo ip netns exec s1r ip route add 10.2.0.0/24 via 192.168.2.1 dev v-s1w1 2>/dev/null || true
sudo ip netns exec s1r ip route add 10.3.0.0/24 via 192.168.3.1 dev v-s1w1 2>/dev/null || true

# Site 2 Router → vers LANs Site 1 et Site 3
sudo ip netns exec s2r ip route add 10.1.0.0/24 via 192.168.1.1 dev v-s2w1 2>/dev/null || true
sudo ip netns exec s2r ip route add 10.3.0.0/24 via 192.168.3.1 dev v-s2w1 2>/dev/null || true

# Site 3 Router → vers LANs Site 1 et Site 2
sudo ip netns exec s3r ip route add 10.1.0.0/24 via 192.168.1.1 dev v-s3w1 2>/dev/null || true
sudo ip netns exec s3r ip route add 10.2.0.0/24 via 192.168.2.1 dev v-s3w1 2>/dev/null || true

# Routes LAN de BACKUP (via WAN2 avec metric plus élevé)
echo "🔄 Configuration des routes de backup..."

# Site 1 Router → routes backup via v-s1w2
sudo ip netns exec s1r ip route add 10.2.0.0/24 via 192.168.2.2 dev v-s1w2 metric 100 2>/dev/null || true
sudo ip netns exec s1r ip route add 10.3.0.0/24 via 192.168.3.2 dev v-s1w2 metric 100 2>/dev/null || true

# Site 2 Router → routes backup via v-s2w2
sudo ip netns exec s2r ip route add 10.1.0.0/24 via 192.168.1.2 dev v-s2w2 metric 100 2>/dev/null || true
sudo ip netns exec s2r ip route add 10.3.0.0/24 via 192.168.3.2 dev v-s2w2 metric 100 2>/dev/null || true

# Site 3 Router → routes backup via v-s3w2
sudo ip netns exec s3r ip route add 10.1.0.0/24 via 192.168.1.2 dev v-s3w2 metric 100 2>/dev/null || true
sudo ip netns exec s3r ip route add 10.2.0.0/24 via 192.168.2.2 dev v-s3w2 metric 100 2>/dev/null || true

# Configure le SNAT pour que les paquets passent
echo "🔒 Configuration du NAT/SNAT..."
for site in 1 2 3; do
    router="s${site}r"
    lan_net="10.${site}.0.0/24"
    wan_iface="v-s${site}w1"
    
    # Nettoie les règles NAT existantes
    sudo ip netns exec $router iptables -t nat -F 2>/dev/null || true
    
    # Active le SNAT
    sudo ip netns exec $router iptables -t nat -A POSTROUTING -s $lan_net -o $wan_iface -j MASQUERADE 2>/dev/null || true
done

echo ""
echo "✓ Configuration terminée!"
echo ""

# Tests de connectivité
echo "🧪 Tests de connectivité..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test Gateway
if sudo ip netns exec s1h1 ping -c 3 -W 2 10.1.0.1 >/dev/null 2>&1; then
    echo "✓ Gateway Site 1 OK"
else
    echo "✗ Gateway Site 1 FAIL"
fi

# Test Site 1 → Site 2
if sudo ip netns exec s1h1 ping -c 3 -W 2 10.2.0.11 >/dev/null 2>&1; then
    echo "✓ Site 1 → Site 2 OK"
else
    echo "✗ Site 1 → Site 2 FAIL"
fi

# Test Site 1 → Site 3
if sudo ip netns exec s1h1 ping -c 3 -W 2 10.3.0.11 >/dev/null 2>&1; then
    echo "✓ Site 1 → Site 3 OK"
else
    echo "✗ Site 1 → Site 3 FAIL"
fi

# Test Site 2 → Site 3
if sudo ip netns exec s2h1 ping -c 3 -W 2 10.3.0.11 >/dev/null 2>&1; then
    echo "✓ Site 2 → Site 3 OK"
else
    echo "✗ Site 2 → Site 3 FAIL"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🎉 Configuration du réseau SD-WAN terminée avec succès!"
echo ""
echo "Commandes utiles :"
echo "  • Voir les routes : sudo ip netns exec s1r ip route"
echo "  • Tests manuels  : sudo ip netns exec s1h1 ping 10.2.0.11"
echo "  • Lancer la démo : sudo ./prepare_demo.sh"
echo ""
