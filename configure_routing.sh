#!/bin/bash

echo "Configuration du routage entre les sites..."

# Site 1 Router - Routes vers les autres sites
sudo ip netns exec s1r ip route add 10.2.0.0/24 via 192.168.1.1 dev v-s1w1 || true
sudo ip netns exec s1r ip route add 10.3.0.0/24 via 192.168.1.1 dev v-s1w1 || true

# Site 2 Router - Routes vers les autres sites
sudo ip netns exec s2r ip route add 10.1.0.0/24 via 192.168.2.1 dev v-s2w1 || true
sudo ip netns exec s2r ip route add 10.3.0.0/24 via 192.168.2.1 dev v-s2w1 || true

# Site 3 Router - Routes vers les autres sites
sudo ip netns exec s3r ip route add 10.1.0.0/24 via 192.168.3.1 dev v-s3w1 || true
sudo ip netns exec s3r ip route add 10.2.0.0/24 via 192.168.3.1 dev v-s3w1 || true

# Configuration du NAT/forwarding sur le WAN bridge
# Ajoute des routes statiques sur tous les routeurs pour se trouver mutuellement

# Alternative : Routage direct via le WAN
sudo ip netns exec s1r ip route del 10.2.0.0/24 2>/dev/null || true
sudo ip netns exec s1r ip route del 10.3.0.0/24 2>/dev/null || true
sudo ip netns exec s1r ip route add 10.2.0.0/24 dev v-s1w1 scope link || true
sudo ip netns exec s1r ip route add 10.3.0.0/24 dev v-s1w1 scope link || true

sudo ip netns exec s2r ip route del 10.1.0.0/24 2>/dev/null || true
sudo ip netns exec s2r ip route del 10.3.0.0/24 2>/dev/null || true  
sudo ip netns exec s2r ip route add 10.1.0.0/24 dev v-s2w1 scope link || true
sudo ip netns exec s2r ip route add 10.3.0.0/24 dev v-s2w1 scope link || true

sudo ip netns exec s3r ip route del 10.1.0.0/24 2>/dev/null || true
sudo ip netns exec s3r ip route del 10.2.0.0/24 2>/dev/null || true
sudo ip netns exec s3r ip route add 10.1.0.0/24 dev v-s3w1 scope link || true
sudo ip netns exec s3r ip route add 10.2.0.0/24 dev v-s3w1 scope link || true

echo "✓ Routage configuré!"

# Vérifie les routes
echo ""
echo "Routes du router Site 1:"
sudo ip netns exec s1r ip route

echo ""
echo "Routes du router Site 2:"
sudo ip netns exec s2r ip route
