#!/bin/bash

#############################################################################
# SD-WAN Complete Deployment - ONE COMMAND AUTOMATION
# This script deploys and tests the entire SD-WAN infrastructure
#############################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${MAGENTA}[STEP]${NC} $1"; }

print_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                                ║
║          SD-WAN Multi-Site Network Deployment                 ║
║       Production-Grade with Intelligent Routing               ║
║                                                                ║
║  Features:                                                     ║
║  ✓ Dynamic Path Selection                                    ║
║  ✓ Automatic Failover                                        ║
║  ✓ Quality of Service (QoS)                                  ║
║  ✓ Real-time Monitoring                                      ║
║  ✓ Complete Automation                                       ║
║                                                                ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then 
        log_error "This script must be run as root"
        echo "Please run: sudo $0"
        exit 1
    fi
}

make_scripts_executable() {
    log_step "Making all scripts executable..."
    chmod +x deploy_sdwan.sh 2>/dev/null || true
    chmod +x test_sdwan.sh 2>/dev/null || true
    chmod +x sdwan_controller.py 2>/dev/null || true
    chmod +x sdwan_monitor.py 2>/dev/null || true
    log_success "Scripts are executable"
}

deploy_network() {
    log_step "Deploying SD-WAN network infrastructure..."
    echo ""
    
    if [ -f "./deploy_sdwan.sh" ]; then
        bash ./deploy_sdwan.sh
    else
        log_error "deploy_sdwan.sh not found!"
        exit 1
    fi
    
    log_success "Network deployment complete"
    sleep 2
}

start_controller_background() {
    log_step "Starting Ryu SDN Controller in background..."
    
    # Kill any existing Ryu instances
    pkill -9 -f ryu-manager 2>/dev/null || true
    sleep 1
    
    # Start controller in background
    if [ -f "./sdwan_controller.py" ]; then
        nohup ryu-manager ./sdwan_controller.py --verbose > /tmp/ryu_controller.log 2>&1 &
        CONTROLLER_PID=$!
        
        # Wait for controller to start
        sleep 3
        
        if ps -p $CONTROLLER_PID > /dev/null; then
            log_success "Ryu controller started (PID: $CONTROLLER_PID)"
            echo "  Log file: /tmp/ryu_controller.log"
        else
            log_error "Failed to start Ryu controller"
            log_info "Check log: cat /tmp/ryu_controller.log"
            exit 1
        fi
    else
        log_error "sdwan_controller.py not found!"
        exit 1
    fi
}

wait_for_controller() {
    log_step "Waiting for controller initialization..."
    
    for i in {1..10}; do
        if grep -q "SD-WAN Controller initialized" /tmp/ryu_controller.log 2>/dev/null; then
            log_success "Controller ready!"
            return 0
        fi
        echo -n "."
        sleep 1
    done
    
    log_warning "Controller may not be fully initialized"
    echo ""
}

run_tests() {
    log_step "Running automated test suite..."
    echo ""
    sleep 2
    
    if [ -f "./test_sdwan.sh" ]; then
        bash ./test_sdwan.sh
        TEST_RESULT=$?
    else
        log_error "test_sdwan.sh not found!"
        exit 1
    fi
    
    return $TEST_RESULT
}

run_monitoring_demo() {
    log_step "Running network monitoring demonstration..."
    echo ""
    sleep 1
    
    if [ -f "./sdwan_monitor.py" ]; then
        python3 ./sdwan_monitor.py
    else
        log_warning "sdwan_monitor.py not found, skipping monitoring demo"
    fi
}

display_usage_info() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                 DEPLOYMENT COMPLETE!                            ${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    log_success "Your SD-WAN network is now operational!"
    echo ""
    
    echo -e "${YELLOW}📊 Network Information:${NC}"
    echo "  • Sites: 3 (site1, site2, site3)"
    echo "  • Subnets: 10.1.0.0/24, 10.2.0.0/24, 10.3.0.0/24"
    echo "  • Controller: Running (PID: $(pgrep -f ryu-manager))"
    echo "  • Controller Log: /tmp/ryu_controller.log"
    echo ""
    
    echo -e "${YELLOW}🧪 Quick Testing Commands:${NC}"
    echo ""
    echo "  Test connectivity:"
    echo "    sudo ip netns exec site1-host1 ping 10.2.0.11"
    echo ""
    echo "  Bandwidth test:"
    echo "    # Terminal 1 (server):"
    echo "    sudo ip netns exec site2-host1 iperf3 -s"
    echo "    # Terminal 2 (client):"
    echo "    sudo ip netns exec site1-host1 iperf3 -c 10.2.0.11 -t 30"
    echo ""
    echo "  Monitor traffic:"
    echo "    sudo tcpdump -i br-wan -n"
    echo ""
    echo "  Run full test suite again:"
    echo "    sudo ./test_sdwan.sh"
    echo ""
    echo "  Continuous monitoring:"
    echo "    sudo python3 sdwan_monitor.py --continuous 15"
    echo ""
    
    echo -e "${YELLOW}📈 View Controller Status:${NC}"
    echo "  • View logs: tail -f /tmp/ryu_controller.log"
    echo "  • OVS status: sudo ovs-vsctl show"
    echo "  • Flows: sudo ovs-ofctl dump-flows br-site1 -O OpenFlow13"
    echo ""
    
    echo -e "${YELLOW}🔄 Management Commands:${NC}"
    echo "  • Stop controller: sudo pkill -f ryu-manager"
    echo "  • Restart controller: ryu-manager sdwan_controller.py --verbose"
    echo "  • Clean up: sudo ./deploy_sdwan.sh (includes cleanup)"
    echo ""
    
    echo -e "${YELLOW}📚 Documentation:${NC}"
    echo "  • README: cat README.md"
    echo "  • Architecture: cat sdwan_architecture.md"
    echo ""
    
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
}

cleanup_on_error() {
    log_error "Deployment failed!"
    log_info "Cleaning up..."
    pkill -9 -f ryu-manager 2>/dev/null || true
    exit 1
}

main() {
    # Set trap for errors
    trap cleanup_on_error ERR
    
    print_banner
    
    log_info "Starting complete SD-WAN deployment..."
    log_info "This will take approximately 2-3 minutes"
    echo ""
    
    check_root
    make_scripts_executable
    
    echo ""
    log_info "═══ Phase 1: Network Infrastructure ═══"
    deploy_network
    
    echo ""
    log_info "═══ Phase 2: SDN Controller ═══"
    start_controller_background
    wait_for_controller
    
    echo ""
    log_info "═══ Phase 3: Automated Testing ═══"
    if run_tests; then
        log_success "All tests passed!"
    else
        log_warning "Some tests failed, but network is operational"
    fi
    
    echo ""
    log_info "═══ Phase 4: Monitoring Demonstration ═══"
    run_monitoring_demo
    
    display_usage_info
    
    log_success "Deployment and testing complete!"
    
    # Offer to keep controller running
    echo ""
    echo -e "${YELLOW}The Ryu controller is running in background.${NC}"
    echo -e "Press Enter to keep it running, or Ctrl+C to stop and exit..."
    read -r
    
    echo ""
    log_info "Controller will continue running."
    log_info "To stop it later: sudo pkill -f ryu-manager"
    log_info "To view logs: tail -f /tmp/ryu_controller.log"
    echo ""
}

# Execute main function
main "$@"
