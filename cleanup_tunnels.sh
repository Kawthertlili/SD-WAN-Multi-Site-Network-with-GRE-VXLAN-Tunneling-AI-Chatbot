#!/bin/bash

#############################################################################
# SD-WAN Tunnel Cleanup Script
# Suppression des tunnels GRE et VXLAN
# Réalisé par : Kawther Tlili
#############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

clear

echo -e "${CYAN}"
cat << "BANNER"
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║              SD-WAN TUNNEL CLEANUP SCRIPT                        ║
║           Suppression des tunnels GRE et VXLAN                   ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}\n"

echo -e "${YELLOW}⚠️  Ce script va supprimer TOUS les tunnels GRE et VXLAN${NC}"
echo -e "${YELLOW}⚠️  Cette action est irréversible${NC}\n"

read -p "Continuer ? (o/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Oo]$ ]]; then
    echo -e "${RED}Opération annulée${NC}"
    exit 0
fi

echo ""

#############################################################################
# SUPPRESSION DES TUNNELS GRE
#############################################################################

echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${MAGENTA}    SUPPRESSION DES TUNNELS GRE                                     ${NC}"
echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════════${NC}\n"

# Site 1
echo -e "${WHITE}Suppression des tunnels GRE sur Site 1...${NC}"
sudo ip netns exec s1r ip tunnel del gre-s1-s2 2>/dev/null && echo -e "  ${GREEN}✓${NC} gre-s1-s2 supprimé"
sudo ip netns exec s1r ip tunnel del gre-s1-s3 2>/dev/null && echo -e "  ${GREEN}✓${NC} gre-s1-s3 supprimé"

# Site 2
echo -e "\n${WHITE}Suppression des tunnels GRE sur Site 2...${NC}"
sudo ip netns exec s2r ip tunnel del gre-s2-s1 2>/dev/null && echo -e "  ${GREEN}✓${NC} gre-s2-s1 supprimé"
sudo ip netns exec s2r ip tunnel del gre-s2-s3 2>/dev/null && echo -e "  ${GREEN}✓${NC} gre-s2-s3 supprimé"

# Site 3
echo -e "\n${WHITE}Suppression des tunnels GRE sur Site 3...${NC}"
sudo ip netns exec s3r ip tunnel del gre-s3-s1 2>/dev/null && echo -e "  ${GREEN}✓${NC} gre-s3-s1 supprimé"
sudo ip netns exec s3r ip tunnel del gre-s3-s2 2>/dev/null && echo -e "  ${GREEN}✓${NC} gre-s3-s2 supprimé"

echo -e "\n${GREEN}✓ Tous les tunnels GRE ont été supprimés${NC}\n"
sleep 1

#############################################################################
# SUPPRESSION DES TUNNELS VXLAN
#############################################################################

echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${MAGENTA}    SUPPRESSION DES TUNNELS VXLAN                                   ${NC}"
echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════════${NC}\n"

# Site 1
echo -e "${WHITE}Suppression des tunnels VXLAN sur Site 1...${NC}"
sudo ip netns exec s1r ip link delete vxlan12 2>/dev/null && echo -e "  ${GREEN}✓${NC} vxlan12 supprimé"
sudo ip netns exec s1r ip link delete vxlan13 2>/dev/null && echo -e "  ${GREEN}✓${NC} vxlan13 supprimé"

# Site 2
echo -e "\n${WHITE}Suppression des tunnels VXLAN sur Site 2...${NC}"
sudo ip netns exec s2r ip link delete vxlan21 2>/dev/null && echo -e "  ${GREEN}✓${NC} vxlan21 supprimé"
sudo ip netns exec s2r ip link delete vxlan23 2>/dev/null && echo -e "  ${GREEN}✓${NC} vxlan23 supprimé"

# Site 3
echo -e "\n${WHITE}Suppression des tunnels VXLAN sur Site 3...${NC}"
sudo ip netns exec s3r ip link delete vxlan31 2>/dev/null && echo -e "  ${GREEN}✓${NC} vxlan31 supprimé"
sudo ip netns exec s3r ip link delete vxlan32 2>/dev/null && echo -e "  ${GREEN}✓${NC} vxlan32 supprimé"

echo -e "\n${GREEN}✓ Tous les tunnels VXLAN ont été supprimés${NC}\n"
sleep 1

#############################################################################
# VÉRIFICATION
#############################################################################

echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${MAGENTA}    VÉRIFICATION                                                    ${NC}"
echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════════${NC}\n"

echo -e "${WHITE}Vérification des tunnels restants...${NC}\n"

# Vérifier GRE
GRE_COUNT=0
for ns in s1r s2r s3r; do
    COUNT=$(sudo ip netns exec $ns ip tunnel show 2>/dev/null | grep -c "^gre-")
    GRE_COUNT=$((GRE_COUNT + COUNT))
done

if [ $GRE_COUNT -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} Aucun tunnel GRE restant"
else
    echo -e "  ${YELLOW}⚠${NC} $GRE_COUNT tunnel(s) GRE encore présent(s)"
fi

# Vérifier VXLAN
VXLAN_COUNT=0
for ns in s1r s2r s3r; do
    COUNT=$(sudo ip netns exec $ns ip link show type vxlan 2>/dev/null | grep -c "^[0-9]")
    VXLAN_COUNT=$((VXLAN_COUNT + COUNT))
done

if [ $VXLAN_COUNT -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} Aucun tunnel VXLAN restant"
else
    echo -e "  ${YELLOW}⚠${NC} $VXLAN_COUNT tunnel(s) VXLAN encore présent(s)"
fi

echo -e "\n${GREEN}✓ Nettoyage terminé !${NC}\n"
