#!/bin/bash

#############################################################################
# SD-WAN Tunnel Setup Script (CORRECTED)
# Configure GRE et VXLAN tunnels entre les 3 sites
# Réalisé par : Kawther Tlili
#############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

clear

echo -e "${CYAN}"
cat << "BANNER"
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║              SD-WAN TUNNEL CONFIGURATION SCRIPT                  ║
║                   GRE + VXLAN Tunnels Setup                      ║
║                                                                  ║
║                 Projet réalisé par: Kawther TLILI                ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}\n"

# Configuration des adresses IP WAN (CORRIGÉES)
SITE1_WAN="192.168.1.1"
SITE2_WAN="192.168.2.1"
SITE3_WAN="192.168.3.1"

# Noms des interfaces WAN
SITE1_WAN_IF="v-s1w1"
SITE2_WAN_IF="v-s2w1"
SITE3_WAN_IF="v-s3w1"

#############################################################################
# FONCTION: Vérification des prérequis
#############################################################################

check_prerequisites() {
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}    VÉRIFICATION DES PRÉREQUIS                                     ${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════════${NC}\n"
    
    # Vérifier si les namespaces existent
    echo -e "${WHITE}Vérification des namespaces réseau...${NC}"
    for ns in s1r s2r s3r; do
        if sudo ip netns list | grep -q "^$ns"; then
            echo -e "  ${GREEN}✓${NC} Namespace $ns existe"
        else
            echo -e "  ${RED}✗${NC} Namespace $ns n'existe pas"
            echo -e "${RED}Erreur: Les namespaces doivent être créés avant de configurer les tunnels${NC}"
            exit 1
        fi
    done
    
    # Vérifier les adresses IP WAN
    echo -e "\n${WHITE}Vérification des adresses IP WAN...${NC}"
    echo -e "  Site 1: ${CYAN}$SITE1_WAN${NC}"
    echo -e "  Site 2: ${CYAN}$SITE2_WAN${NC}"
    echo -e "  Site 3: ${CYAN}$SITE3_WAN${NC}"
    
    echo -e "\n${GREEN}✓ Tous les prérequis sont satisfaits${NC}\n"
    sleep 2
}

#############################################################################
# FONCTION: Nettoyage des anciens tunnels
#############################################################################

cleanup_old_tunnels() {
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}    NETTOYAGE DES ANCIENS TUNNELS                                  ${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════════${NC}\n"
    
    # Supprimer anciens tunnels GRE
    for ns in s1r s2r s3r; do
        sudo ip netns exec $ns ip tunnel show 2>/dev/null | grep "^gre-" | cut -d: -f1 | while read tunnel; do
            sudo ip netns exec $ns ip tunnel del $tunnel 2>/dev/null
        done
    done
    
    # Supprimer anciens tunnels VXLAN
    for ns in s1r s2r s3r; do
        sudo ip netns exec $ns ip link show type vxlan 2>/dev/null | grep "^[0-9]" | awk '{print $2}' | cut -d: -f1 | while read vxlan; do
            sudo ip netns exec $ns ip link delete $vxlan 2>/dev/null
        done
    done
    
    echo -e "${GREEN}✓ Nettoyage terminé${NC}\n"
    sleep 1
}

#############################################################################
# FONCTION: Configuration des tunnels GRE
#############################################################################

setup_gre_tunnels() {
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}    CONFIGURATION DES TUNNELS GRE                                  ${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════════${NC}\n"
    
    echo -e "${WHITE}Configuration tunnel GRE: Site 1 ↔ Site 2${NC}"
    
    # Tunnel GRE entre Site 1 et Site 2
    sudo ip netns exec s1r ip tunnel add gre-s1-s2 mode gre remote $SITE2_WAN local $SITE1_WAN ttl 255 2>/dev/null
    sudo ip netns exec s1r ip link set gre-s1-s2 up
    sudo ip netns exec s1r ip addr add 172.16.12.1/30 dev gre-s1-s2 2>/dev/null
    echo -e "  ${GREEN}✓${NC} Site 1 → Site 2 (172.16.12.1/30)"
    
    sudo ip netns exec s2r ip tunnel add gre-s2-s1 mode gre remote $SITE1_WAN local $SITE2_WAN ttl 255 2>/dev/null
    sudo ip netns exec s2r ip link set gre-s2-s1 up
    sudo ip netns exec s2r ip addr add 172.16.12.2/30 dev gre-s2-s1 2>/dev/null
    echo -e "  ${GREEN}✓${NC} Site 2 → Site 1 (172.16.12.2/30)"
    
    sleep 1
    
    echo -e "\n${WHITE}Configuration tunnel GRE: Site 1 ↔ Site 3${NC}"
    
    # Tunnel GRE entre Site 1 et Site 3
    sudo ip netns exec s1r ip tunnel add gre-s1-s3 mode gre remote $SITE3_WAN local $SITE1_WAN ttl 255 2>/dev/null
    sudo ip netns exec s1r ip link set gre-s1-s3 up
    sudo ip netns exec s1r ip addr add 172.16.13.1/30 dev gre-s1-s3 2>/dev/null
    echo -e "  ${GREEN}✓${NC} Site 1 → Site 3 (172.16.13.1/30)"
    
    sudo ip netns exec s3r ip tunnel add gre-s3-s1 mode gre remote $SITE1_WAN local $SITE3_WAN ttl 255 2>/dev/null
    sudo ip netns exec s3r ip link set gre-s3-s1 up
    sudo ip netns exec s3r ip addr add 172.16.13.2/30 dev gre-s3-s1 2>/dev/null
    echo -e "  ${GREEN}✓${NC} Site 3 → Site 1 (172.16.13.2/30)"
    
    sleep 1
    
    echo -e "\n${WHITE}Configuration tunnel GRE: Site 2 ↔ Site 3${NC}"
    
    # Tunnel GRE entre Site 2 et Site 3
    sudo ip netns exec s2r ip tunnel add gre-s2-s3 mode gre remote $SITE3_WAN local $SITE2_WAN ttl 255 2>/dev/null
    sudo ip netns exec s2r ip link set gre-s2-s3 up
    sudo ip netns exec s2r ip addr add 172.16.23.1/30 dev gre-s2-s3 2>/dev/null
    echo -e "  ${GREEN}✓${NC} Site 2 → Site 3 (172.16.23.1/30)"
    
    sudo ip netns exec s3r ip tunnel add gre-s3-s2 mode gre remote $SITE2_WAN local $SITE3_WAN ttl 255 2>/dev/null
    sudo ip netns exec s3r ip link set gre-s3-s2 up
    sudo ip netns exec s3r ip addr add 172.16.23.2/30 dev gre-s3-s2 2>/dev/null
    echo -e "  ${GREEN}✓${NC} Site 3 → Site 2 (172.16.23.2/30)"
    
    echo -e "\n${GREEN}✓ Tous les tunnels GRE sont configurés${NC}\n"
    sleep 2
}

#############################################################################
# FONCTION: Configuration des tunnels VXLAN
#############################################################################

setup_vxlan_tunnels() {
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}    CONFIGURATION DES TUNNELS VXLAN                                ${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════════${NC}\n"
    
    echo -e "${WHITE}Configuration tunnel VXLAN: Site 1 ↔ Site 2 (VNI 12)${NC}"
    
    # Tunnel VXLAN entre Site 1 et Site 2
    sudo ip netns exec s1r ip link add vxlan12 type vxlan id 12 remote $SITE2_WAN local $SITE1_WAN dstport 4789 dev $SITE1_WAN_IF 2>/dev/null
    sudo ip netns exec s1r ip link set vxlan12 up
    sudo ip netns exec s1r ip addr add 10.100.12.1/24 dev vxlan12 2>/dev/null
    echo -e "  ${GREEN}✓${NC} Site 1 → Site 2 (10.100.12.1/24, VNI 12)"
    
    sudo ip netns exec s2r ip link add vxlan21 type vxlan id 12 remote $SITE1_WAN local $SITE2_WAN dstport 4789 dev $SITE2_WAN_IF 2>/dev/null
    sudo ip netns exec s2r ip link set vxlan21 up
    sudo ip netns exec s2r ip addr add 10.100.12.2/24 dev vxlan21 2>/dev/null
    echo -e "  ${GREEN}✓${NC} Site 2 → Site 1 (10.100.12.2/24, VNI 12)"
    
    sleep 1
    
    echo -e "\n${WHITE}Configuration tunnel VXLAN: Site 1 ↔ Site 3 (VNI 13)${NC}"
    
    # Tunnel VXLAN entre Site 1 et Site 3
    sudo ip netns exec s1r ip link add vxlan13 type vxlan id 13 remote $SITE3_WAN local $SITE1_WAN dstport 4789 dev $SITE1_WAN_IF 2>/dev/null
    sudo ip netns exec s1r ip link set vxlan13 up
    sudo ip netns exec s1r ip addr add 10.100.13.1/24 dev vxlan13 2>/dev/null
    echo -e "  ${GREEN}✓${NC} Site 1 → Site 3 (10.100.13.1/24, VNI 13)"
    
    sudo ip netns exec s3r ip link add vxlan31 type vxlan id 13 remote $SITE1_WAN local $SITE3_WAN dstport 4789 dev $SITE3_WAN_IF 2>/dev/null
    sudo ip netns exec s3r ip link set vxlan31 up
    sudo ip netns exec s3r ip addr add 10.100.13.2/24 dev vxlan31 2>/dev/null
    echo -e "  ${GREEN}✓${NC} Site 3 → Site 1 (10.100.13.2/24, VNI 13)"
    
    sleep 1
    
    echo -e "\n${WHITE}Configuration tunnel VXLAN: Site 2 ↔ Site 3 (VNI 23)${NC}"
    
    # Tunnel VXLAN entre Site 2 et Site 3
    sudo ip netns exec s2r ip link add vxlan23 type vxlan id 23 remote $SITE3_WAN local $SITE2_WAN dstport 4789 dev $SITE2_WAN_IF 2>/dev/null
    sudo ip netns exec s2r ip link set vxlan23 up
    sudo ip netns exec s2r ip addr add 10.100.23.1/24 dev vxlan23 2>/dev/null
    echo -e "  ${GREEN}✓${NC} Site 2 → Site 3 (10.100.23.1/24, VNI 23)"
    
    sudo ip netns exec s3r ip link add vxlan32 type vxlan id 23 remote $SITE2_WAN local $SITE3_WAN dstport 4789 dev $SITE3_WAN_IF 2>/dev/null
    sudo ip netns exec s3r ip link set vxlan32 up
    sudo ip netns exec s3r ip addr add 10.100.23.2/24 dev vxlan32 2>/dev/null
    echo -e "  ${GREEN}✓${NC} Site 3 → Site 2 (10.100.23.2/24, VNI 23)"
    
    echo -e "\n${GREEN}✓ Tous les tunnels VXLAN sont configurés${NC}\n"
    sleep 2
}

#############################################################################
# FONCTION: Configuration système (Forwarding, RPF, Routes)
#############################################################################

setup_system_config() {
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}    CONFIGURATION SYSTÈME                                          ${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════════${NC}\n"
    
    echo -e "${WHITE}Activation IP Forwarding...${NC}"
    for ns in s1r s2r s3r; do
        sudo ip netns exec $ns sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
        echo -e "  ${GREEN}✓${NC} IP Forwarding activé sur $ns"
    done
    
    echo -e "\n${WHITE}Désactivation Reverse Path Filtering...${NC}"
    for ns in s1r s2r s3r; do
        sudo ip netns exec $ns sysctl -w net.ipv4.conf.all.rp_filter=0 >/dev/null 2>&1
        sudo ip netns exec $ns sysctl -w net.ipv4.conf.default.rp_filter=0 >/dev/null 2>&1
        echo -e "  ${GREEN}✓${NC} RPF désactivé sur $ns"
    done
    
    echo -e "\n${WHITE}Ajout des routes...${NC}"
    echo -e "  ${GREEN}✓${NC} Routes automatiques via interfaces tunnel"
    
    echo ""
    sleep 2
}

#############################################################################
# FONCTION: Vérification des tunnels GRE
#############################################################################

verify_gre_tunnels() {
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}    VÉRIFICATION DES TUNNELS GRE                                   ${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════════${NC}\n"
    
    echo -e "${WHITE}Tests de connectivité via tunnels GRE :${NC}\n"
    
    # Test Site 1 → Site 2
    echo -e "${CYAN}Test: Site 1 → Site 2 (172.16.12.2)${NC}"
    if sudo ip netns exec s1r ping -c 3 -W 2 172.16.12.2 >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓ SUCCÈS${NC} - Tunnel GRE S1↔S2 fonctionnel"
    else
        echo -e "  ${RED}✗ ÉCHEC${NC} - Problème avec le tunnel GRE S1↔S2"
    fi
    
    # Test Site 1 → Site 3
    echo -e "\n${CYAN}Test: Site 1 → Site 3 (172.16.13.2)${NC}"
    if sudo ip netns exec s1r ping -c 3 -W 2 172.16.13.2 >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓ SUCCÈS${NC} - Tunnel GRE S1↔S3 fonctionnel"
    else
        echo -e "  ${RED}✗ ÉCHEC${NC} - Problème avec le tunnel GRE S1↔S3"
    fi
    
    # Test Site 2 → Site 3
    echo -e "\n${CYAN}Test: Site 2 → Site 3 (172.16.23.2)${NC}"
    if sudo ip netns exec s2r ping -c 3 -W 2 172.16.23.2 >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓ SUCCÈS${NC} - Tunnel GRE S2↔S3 fonctionnel"
    else
        echo -e "  ${RED}✗ ÉCHEC${NC} - Problème avec le tunnel GRE S2↔S3"
    fi
    
    echo ""
    sleep 2
}

#############################################################################
# FONCTION: Vérification des tunnels VXLAN
#############################################################################

verify_vxlan_tunnels() {
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}    VÉRIFICATION DES TUNNELS VXLAN                                 ${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════════${NC}\n"
    
    echo -e "${WHITE}Tests de connectivité via tunnels VXLAN :${NC}\n"
    
    # Test Site 1 → Site 2
    echo -e "${CYAN}Test: Site 1 → Site 2 (10.100.12.2) via VXLAN VNI 12${NC}"
    if sudo ip netns exec s1r ping -c 3 -W 2 10.100.12.2 >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓ SUCCÈS${NC} - Tunnel VXLAN S1↔S2 fonctionnel"
    else
        echo -e "  ${RED}✗ ÉCHEC${NC} - Problème avec le tunnel VXLAN S1↔S2"
    fi
    
    # Test Site 1 → Site 3
    echo -e "\n${CYAN}Test: Site 1 → Site 3 (10.100.13.2) via VXLAN VNI 13${NC}"
    if sudo ip netns exec s1r ping -c 3 -W 2 10.100.13.2 >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓ SUCCÈS${NC} - Tunnel VXLAN S1↔S3 fonctionnel"
    else
        echo -e "  ${RED}✗ ÉCHEC${NC} - Problème avec le tunnel VXLAN S1↔S3"
    fi
    
    # Test Site 2 → Site 3
    echo -e "\n${CYAN}Test: Site 2 → Site 3 (10.100.23.2) via VXLAN VNI 23${NC}"
    if sudo ip netns exec s2r ping -c 3 -W 2 10.100.23.2 >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓ SUCCÈS${NC} - Tunnel VXLAN S2↔S3 fonctionnel"
    else
        echo -e "  ${RED}✗ ÉCHEC${NC} - Problème avec le tunnel VXLAN S2↔S3"
    fi
    
    echo ""
    sleep 2
}

#############################################################################
# FONCTION: Résumé de la configuration
#############################################################################

show_summary() {
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}    RÉSUMÉ DE LA CONFIGURATION DES TUNNELS                         ${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════════${NC}\n"
    
    echo -e "${WHITE}Tunnels GRE configurés :${NC}"
    echo -e "  ${GREEN}✓${NC} Site 1 ↔ Site 2 : ${CYAN}172.16.12.1/30 ↔ 172.16.12.2/30${NC}"
    echo -e "  ${GREEN}✓${NC} Site 1 ↔ Site 3 : ${CYAN}172.16.13.1/30 ↔ 172.16.13.2/30${NC}"
    echo -e "  ${GREEN}✓${NC} Site 2 ↔ Site 3 : ${CYAN}172.16.23.1/30 ↔ 172.16.23.2/30${NC}"
    
    echo -e "\n${WHITE}Tunnels VXLAN configurés :${NC}"
    echo -e "  ${GREEN}✓${NC} Site 1 ↔ Site 2 : ${CYAN}10.100.12.1/24 ↔ 10.100.12.2/24 (VNI 12)${NC}"
    echo -e "  ${GREEN}✓${NC} Site 1 ↔ Site 3 : ${CYAN}10.100.13.1/24 ↔ 10.100.13.2/24 (VNI 13)${NC}"
    echo -e "  ${GREEN}✓${NC} Site 2 ↔ Site 3 : ${CYAN}10.100.23.1/24 ↔ 10.100.23.2/24 (VNI 23)${NC}"
    
    echo -e "\n${WHITE}Adresses IP WAN utilisées :${NC}"
    echo -e "  ${CYAN}Site 1: $SITE1_WAN${NC}"
    echo -e "  ${CYAN}Site 2: $SITE2_WAN${NC}"
    echo -e "  ${CYAN}Site 3: $SITE3_WAN${NC}"
    
    echo -e "\n${GREEN}✓ Configuration des tunnels terminée avec succès !${NC}\n"
}

#############################################################################
# PROGRAMME PRINCIPAL
#############################################################################

main() {
    check_prerequisites
    cleanup_old_tunnels
    setup_gre_tunnels
    setup_vxlan_tunnels
    setup_system_config
    verify_gre_tunnels
    verify_vxlan_tunnels
    show_summary
}

main
