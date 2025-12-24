#!/bin/bash

echo "🔄 Configuration du Failover Multi-Path..."

# Configuration Site 1
echo "Site 1: Configuration des routes multi-path..."

# Supprime les anciennes routes
sudo ip netns exec s1r ip route del 10.2.0.0/24 2>/dev/null || true
sudo ip netns exec s1r ip route del 10.3.0.0/24 2>/dev/null || true

# Ajoute les routes avec ECMP (Equal-Cost Multi-Path)
# Route principale (metric 10) + route backup (metric 20)
sudo ip netns exec s1r ip route add 10.2.0.0/24 via 192.168.2.1 dev v-s1w1 metric 10
sudo ip netns exec s1r ip route add 10.2.0.0/24 via 192.168.2.1 dev v-s1w2 metric 20

sudo ip netns exec s1r ip route add 10.3.0.0/24 via 192.168.3.1 dev v-s1w1 metric 10
sudo ip netns exec s1r ip route add 10.3.0.0/24 via 192.168.3.1 dev v-s1w2 metric 20

# Configuration Site 2
echo "Site 2: Configuration des routes multi-path..."

sudo ip netns exec s2r ip route del 10.1.0.0/24 2>/dev/null || true
sudo ip netns exec s2r ip route del 10.3.0.0/24 2>/dev/null || true

sudo ip netns exec s2r ip route add 10.1.0.0/24 via 192.168.1.1 dev v-s2w1 metric 10
sudo ip netns exec s2r ip route add 10.1.0.0/24 via 192.168.1.1 dev v-s2w2 metric 20

sudo ip netns exec s2r ip route add 10.3.0.0/24 via 192.168.3.1 dev v-s2w1 metric 10
sudo ip netns exec s2r ip route add 10.3.0.0/24 via 192.168.3.1 dev v-s2w2 metric 20

# Configuration Site 3
echo "Site 3: Configuration des routes multi-path..."

sudo ip netns exec s3r ip route del 10.1.0.0/24 2>/dev/null || true
sudo ip netns exec s3r ip route del 10.2.0.0/24 2>/dev/null || true

sudo ip netns exec s3r ip route add 10.1.0.0/24 via 192.168.1.1 dev v-s3w1 metric 10
sudo ip netns exec s3r ip route add 10.1.0.0/24 via 192.168.1.1 dev v-s3w2 metric 20

sudo ip netns exec s3r ip route add 10.2.0.0/24 via 192.168.2.1 dev v-s3w1 metric 10
sudo ip netns exec s3r ip route add 10.2.0.0/24 via 192.168.2.1 dev v-s3w2 metric 20

echo "✅ Routes multi-path configurées"
echo ""
echo "📊 Vérification des routes Site 1:"
sudo ip netns exec s1r ip route | grep "10\."

echo ""
echo "🧪 Test de failover..."

# Test initial
echo "1. Connectivité normale:"
sudo ip netns exec s1h1 ping -c 2 10.2.0.11 | tail -2

# Désactive le lien principal
echo ""
echo "2. Désactivation v-s1w1..."
sudo ip netns exec s1r ip link set v-s1w1 down
sleep 2

# Teste avec backup
echo "3. Test avec backup (attendez 3 secondes):"
sudo ip netns exec s1h1 ping -c 3 10.2.0.11 | tail -2

# Réactive
echo ""
echo "4. Réactivation v-s1w1..."
sudo ip netns exec s1r ip link set v-s1w1 up

echo ""
echo "✅ Configuration terminée!"
