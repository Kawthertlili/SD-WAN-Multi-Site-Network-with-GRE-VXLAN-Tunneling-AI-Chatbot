#!/bin/bash

#############################################################################
# SD-WAN Multi-Site Network Deployment Script - FIXED VERSION
# Production-grade setup with automatic configuration
#############################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

#############################################################################
# Configuration Variables
#############################################################################

CONTROLLER_IP="127.0.0.1"
CONTROLLER_PORT="6653"

# Site configurations
declare -A SITES=(
    ["site1"]="10.1.0.0/24"
    ["site2"]="10.2.0.0/24"
    ["site3"]="10.3.0.0/24"
)

# WAN link configurations (simulating different quality links)
declare -A WAN_LINKS=(
    ["link1_latency"]="10ms"
    ["link1_loss"]="0.1%"
    ["link1_bandwidth"]="100mbit"
    ["link2_latency"]="50ms"
    ["link2_loss"]="1%"
    ["link2_bandwidth"]="50mbit"
    ["link3_latency"]="100ms"
    ["link3_loss"]="2%"
    ["link3_bandwidth"]="20mbit"
)

#############################################################################
# Prerequisites Check and Installation
#############################################################################

check_and_install_prerequisites() {
    log_info "Checking prerequisites..."
    
    if [ "$EUID" -ne 0 ]; then 
        log_error "Please run as root (use sudo)"
        exit 1
    fi
    
    log_info "Updating package lists..."
    apt-get update -qq
    
    PACKAGES=(
        "openvswitch-switch"
        "openvswitch-common"
        "python3"
        "python3-pip"
        "python3-venv"
        "iproute2"
        "net-tools"
        "tcpdump"
        "iperf3"
        "curl"
        "jq"
    )
    
    for pkg in "${PACKAGES[@]}"; do
        if ! dpkg -l | grep -q "^ii  $pkg"; then
            log_info "Installing $pkg..."
            apt-get install -y "$pkg" > /dev/null 2>&1
        fi
    done
    
    log_info "Installing Ryu SDN Framework..."
    pip3 install ryu eventlet==0.30.2 --break-system-packages > /dev/null 2>&1 || true
    
    log_success "Prerequisites installed successfully"
}

#############################################################################
# Cleanup existing configuration
#############################################################################

cleanup_existing() {
    log_info "Cleaning up existing configuration..."
    
    pkill -f ryu-manager || true
    
    for br in $(ovs-vsctl list-br 2>/dev/null); do
        log_info "Deleting bridge: $br"
        ovs-vsctl del-br "$br" 2>/dev/null || true
    done
    
    for ns in $(ip netns list 2>/dev/null | awk '{print $1}'); do
        log_info "Deleting namespace: $ns"
        ip netns del "$ns" 2>/dev/null || true
    done
    
    for iface in $(ip link show | grep -E "v-s[0-9]|veth" | awk '{print $2}' | cut -d: -f1 | cut -d@ -f1); do
        ip link del "$iface" 2>/dev/null || true
    done
    
    log_success "Cleanup completed"
}

#############################################################################
# Create Network Topology
#############################################################################

create_topology() {
    log_info "Creating SD-WAN network topology..."
    
    for site in "${!SITES[@]}"; do
        log_info "Creating bridge: br-$site"
        ovs-vsctl add-br "br-$site"
        ovs-vsctl set bridge "br-$site" protocols=OpenFlow13
        ovs-vsctl set-controller "br-$site" tcp:${CONTROLLER_IP}:${CONTROLLER_PORT}
        ip link set "br-$site" up
    done
    
    log_info "Creating WAN bridge: br-wan"
    ovs-vsctl add-br br-wan
    ovs-vsctl set bridge br-wan protocols=OpenFlow13
    ovs-vsctl set-controller br-wan tcp:${CONTROLLER_IP}:${CONTROLLER_PORT}
    ip link set br-wan up
    
    log_success "Bridges created successfully"
}

#############################################################################
# Create Host Namespaces - FIXED WITH SHORT NAMES
#############################################################################

create_hosts() {
    log_info "Creating host namespaces..."
    
    # Map site names to short codes
    declare -A SITE_CODES=(["site1"]="s1" ["site2"]="s2" ["site3"]="s3")
    
    for site in "${!SITES[@]}"; do
        local subnet="${SITES[$site]}"
        local network=$(echo $subnet | cut -d/ -f1 | cut -d. -f1-3)
        local scode="${SITE_CODES[$site]}"
        
        # Create 2 hosts per site
        for host_num in 1 2; do
            local ns_name="${scode}h${host_num}"  # Exemple: s1h1, s1h2
            local veth_ns="v-${ns_name}"          # Exemple: v-s1h1
            local veth_br="${veth_ns}b"           # Exemple: v-s1h1b (9 chars max)
            local ip="${network}.$((10 + host_num))/24"
            local gw="${network}.1"
            
            log_info "Creating namespace: $ns_name with IP: $ip"
            
            # Create namespace
            ip netns add "$ns_name"
            
            # Create veth pair with SHORT names
            ip link add "$veth_ns" type veth peer name "$veth_br"
            
            # Move one end to namespace
            ip link set "$veth_ns" netns "$ns_name"
            
            # Configure namespace interface
            ip netns exec "$ns_name" ip addr add "$ip" dev "$veth_ns"
            ip netns exec "$ns_name" ip link set "$veth_ns" up
            ip netns exec "$ns_name" ip link set lo up
            ip netns exec "$ns_name" ip route add default via "$gw"
            
            # Attach bridge end to OVS
            ip link set "$veth_br" up
            ovs-vsctl add-port "br-$site" "$veth_br"
        done
    done
    
    log_success "Host namespaces created"
}

#############################################################################
# Create Edge Router Namespaces - FIXED WITH SHORT NAMES
#############################################################################

create_edge_routers() {
    log_info "Creating edge router namespaces..."
    
    declare -A SITE_CODES=(["site1"]="s1" ["site2"]="s2" ["site3"]="s3")
    local site_num=1
    
    for site in "${!SITES[@]}"; do
        local subnet="${SITES[$site]}"
        local network=$(echo $subnet | cut -d/ -f1 | cut -d. -f1-3)
        local scode="${SITE_CODES[$site]}"
        local router_ns="${scode}r"  # Exemple: s1r, s2r, s3r
        
        log_info "Creating edge router: $router_ns"
        
        # Create router namespace
        ip netns add "$router_ns"
        
        # Create LAN-side interface (to site bridge)
        local lan_ns="v-${router_ns}l"    # Exemple: v-s1rl (7 chars)
        local lan_br="${lan_ns}b"          # Exemple: v-s1rlb (8 chars)
        
        ip link add "$lan_ns" type veth peer name "$lan_br"
        ip link set "$lan_ns" netns "$router_ns"
        
        # Configure LAN interface (gateway for hosts)
        ip netns exec "$router_ns" ip addr add "${network}.1/24" dev "$lan_ns"
        ip netns exec "$router_ns" ip link set "$lan_ns" up
        ip netns exec "$router_ns" ip link set lo up
        
        # Attach to site bridge
        ip link set "$lan_br" up
        ovs-vsctl add-port "br-$site" "$lan_br"
        
        # Create WAN-side interfaces (multiple paths to WAN)
        for path_num in 1 2; do
            local wan_ns="v-${scode}w${path_num}"   # Exemple: v-s1w1 (7 chars)
            local wan_br="${wan_ns}b"                # Exemple: v-s1w1b (8 chars)
            local wan_ip="192.168.${site_num}.${path_num}/24"
            
            # Create WAN interface
            ip link add "$wan_ns" type veth peer name "$wan_br"
            ip link set "$wan_ns" netns "$router_ns"
            
            # Configure WAN interface
            ip netns exec "$router_ns" ip addr add "$wan_ip" dev "$wan_ns"
            ip netns exec "$router_ns" ip link set "$wan_ns" up
            
            # Attach to WAN bridge
            ip link set "$wan_br" up
            ovs-vsctl add-port br-wan "$wan_br"
            
            # Apply WAN characteristics
            local link_key="link${path_num}_latency"
            tc qdisc add dev "$wan_br" root netem \
                delay ${WAN_LINKS[$link_key]} \
                loss ${WAN_LINKS["link${path_num}_loss"]} \
                rate ${WAN_LINKS["link${path_num}_bandwidth"]}
        done
        
        # Enable IP forwarding in router
        ip netns exec "$router_ns" sysctl -w net.ipv4.ip_forward=1 > /dev/null
        
        site_num=$((site_num + 1))
    done
    
    log_success "Edge routers created with multiple WAN paths"
}

#############################################################################
# Configure OpenFlow Rules
#############################################################################

configure_initial_flows() {
    log_info "Configuring initial OpenFlow flows..."
    
    for site in "${!SITES[@]}"; do
        ovs-ofctl add-flow "br-$site" "priority=0,actions=CONTROLLER:65535" -O OpenFlow13
    done
    
    ovs-ofctl add-flow br-wan "priority=0,actions=CONTROLLER:65535" -O OpenFlow13
    
    log_success "Initial flows configured"
}

#############################################################################
# Display Network Information
#############################################################################

display_info() {
    log_success "====== SD-WAN Network Deployment Complete ======"
    echo ""
    log_info "Network Topology:"
    echo "  - Sites: ${!SITES[@]}"
    echo "  - Controller: ${CONTROLLER_IP}:${CONTROLLER_PORT}"
    echo ""
    
    log_info "Network Namespaces (SHORT NAMES):"
    ip netns list
    echo ""
    
    log_info "Testing Instructions:"
    echo "  Test connectivity:"
    echo "    sudo ip netns exec s1h1 ping 10.2.0.11"
    echo ""
    echo "  Bandwidth test:"
    echo "    sudo ip netns exec s2h1 iperf3 -s &"
    echo "    sudo ip netns exec s1h1 iperf3 -c 10.2.0.11 -t 30"
    echo ""
    
    log_warning "NOTE: Namespace names are shortened:"
    echo "  site1-host1 → s1h1"
    echo "  site1-host2 → s1h2"
    echo "  site1-router → s1r"
    echo "  (same pattern for site2 and site3)"
}

#############################################################################
# Main Execution
#############################################################################

main() {
    log_info "Starting SD-WAN deployment..."
    echo ""
    
    check_and_install_prerequisites
    cleanup_existing
    create_topology
    create_hosts
    create_edge_routers
    configure_initial_flows
    display_info
    
    log_success "Deployment script completed successfully!"
}

main "$@"
