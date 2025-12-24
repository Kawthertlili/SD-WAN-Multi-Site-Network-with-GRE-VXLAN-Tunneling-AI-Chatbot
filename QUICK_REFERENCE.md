# SD-WAN Quick Reference Guide

## 🚀 Quick Start (One Command)

```bash
sudo ./deploy_complete.sh
```

This single command will:
- Install all prerequisites
- Deploy network topology
- Start SDN controller
- Run automated tests
- Show monitoring demo

## 📋 Common Commands

### Deployment & Management

```bash
# Deploy infrastructure only
sudo ./deploy_sdwan.sh

# Start controller manually
ryu-manager sdwan_controller.py --verbose

# Stop controller
sudo pkill -f ryu-manager

# Clean up and restart
sudo ./deploy_sdwan.sh  # Includes automatic cleanup
```

### Testing

```bash
# Run full test suite
sudo ./test_sdwan.sh

# Test single connection
sudo ip netns exec site1-host1 ping 10.2.0.11

# Bandwidth test
sudo ip netns exec site2-host1 iperf3 -s  # Server
sudo ip netns exec site1-host1 iperf3 -c 10.2.0.11 -t 30  # Client
```

### Monitoring

```bash
# Run monitoring once
sudo python3 sdwan_monitor.py

# Continuous monitoring (15 second intervals)
sudo python3 sdwan_monitor.py --continuous 15

# Real-time dashboard
sudo python3 sdwan_dashboard.py
```

### Traffic Analysis

```bash
# Monitor WAN traffic
sudo tcpdump -i br-wan -n

# Monitor specific site
sudo tcpdump -i br-site1 -n icmp

# View OpenFlow flows
sudo ovs-ofctl dump-flows br-site1 -O OpenFlow13
sudo ovs-ofctl dump-flows br-wan -O OpenFlow13
```

### Network Information

```bash
# List all bridges
sudo ovs-vsctl show

# List all namespaces
sudo ip netns list

# View namespace interfaces
sudo ip netns exec site1-host1 ip addr

# View namespace routes
sudo ip netns exec site1-host1 ip route

# Check controller connection
sudo ovs-vsctl get-controller br-site1
```

## 🧪 Testing Scenarios

### 1. Basic Connectivity Test

```bash
# From Site 1 to all other sites
sudo ip netns exec site1-host1 ping -c 5 10.2.0.11  # Site 2
sudo ip netns exec site1-host1 ping -c 5 10.3.0.11  # Site 3
```

### 2. Latency Measurement

```bash
# Extended ping for latency stats
sudo ip netns exec site1-host1 ping -c 100 -i 0.2 10.2.0.11
```

### 3. Bandwidth Testing

```bash
# TCP throughput
sudo ip netns exec site2-host1 iperf3 -s &
sudo ip netns exec site1-host1 iperf3 -c 10.2.0.11 -t 30

# UDP with specific bandwidth
sudo ip netns exec site1-host1 iperf3 -c 10.2.0.11 -u -b 50M -t 30
```

### 4. Failover Test

```bash
# Disable WAN link
sudo ip netns exec site1-router ip link set veth-site1-router-wan1 down

# Verify connectivity (should use backup path)
sudo ip netns exec site1-host1 ping -c 10 10.2.0.11

# Re-enable link
sudo ip netns exec site1-router ip link set veth-site1-router-wan1 up
```

### 5. Concurrent Traffic

```bash
# Generate multiple flows
sudo ip netns exec site1-host1 ping 10.2.0.11 -c 50 &
sudo ip netns exec site1-host1 ping 10.3.0.11 -c 50 &
sudo ip netns exec site2-host1 ping 10.3.0.11 -c 50 &
wait
```

## 🔧 Troubleshooting

### Controller Issues

```bash
# Check if controller is running
ps aux | grep ryu-manager

# View controller logs
tail -f /tmp/ryu_controller.log

# Restart controller
sudo pkill -f ryu-manager
ryu-manager sdwan_controller.py --verbose
```

### Connectivity Issues

```bash
# Verify namespace exists
sudo ip netns list | grep site1-host1

# Check interface status
sudo ip netns exec site1-host1 ip link

# Verify routing
sudo ip netns exec site1-host1 ip route

# Test gateway
sudo ip netns exec site1-host1 ping 10.1.0.1
```

### OVS Issues

```bash
# Check OVS service
sudo systemctl status openvswitch-switch

# Verify bridges
sudo ovs-vsctl list-br

# Check flow rules
sudo ovs-ofctl dump-flows br-site1 -O OpenFlow13

# Verify controller connection
sudo ovs-vsctl get-controller br-site1

# Manual flow installation (if needed)
sudo ovs-ofctl add-flow br-site1 "priority=100,actions=NORMAL" -O OpenFlow13
```

## 📊 Network Topology

```
Site 1: 10.1.0.0/24
  - site1-host1: 10.1.0.11
  - site1-host2: 10.1.0.12
  - site1-router: 10.1.0.1 (gateway)
    ├─ WAN1: 192.168.1.1
    └─ WAN2: 192.168.1.2

Site 2: 10.2.0.0/24
  - site2-host1: 10.2.0.11
  - site2-host2: 10.2.0.12
  - site2-router: 10.2.0.1 (gateway)
    ├─ WAN1: 192.168.2.1
    └─ WAN2: 192.168.2.2

Site 3: 10.3.0.0/24
  - site3-host1: 10.3.0.11
  - site3-host2: 10.3.0.12
  - site3-router: 10.3.0.1 (gateway)
    ├─ WAN1: 192.168.3.1
    └─ WAN2: 192.168.3.2
```

## 🎯 QoS Priority Ports

- **Critical (Priority 2)**: SSH (22), SIP (5060)
- **High (Priority 1)**: HTTPS (443), DNS (53)
- **Normal (Priority 0)**: HTTP (80), Other

## 📈 Performance Metrics

### Latency Targets
- Excellent: < 50ms
- Good: 50-100ms
- Fair: 100-200ms
- Poor: > 200ms

### Packet Loss Targets
- Excellent: < 0.5%
- Good: 0.5-1%
- Fair: 1-5%
- Poor: > 5%

### Health Score
- Score = (Latency_Score × 0.4) + (Loss_Score × 0.4) + (Bandwidth_Score × 0.2)
- 90-100: Excellent
- 70-89: Good
- 50-69: Fair
- <50: Poor

## 🔄 Workflow

### Initial Setup
```bash
1. sudo ./deploy_complete.sh
2. Wait for completion (~2-3 minutes)
3. Network is ready!
```

### Daily Operations
```bash
# Morning health check
sudo python3 sdwan_monitor.py

# View real-time status
sudo python3 sdwan_dashboard.py

# Run tests if needed
sudo ./test_sdwan.sh
```

### Making Changes
```bash
# Modify WAN characteristics in deploy_sdwan.sh
# Then redeploy:
sudo ./deploy_sdwan.sh
```

## 📝 Log Files

- Controller: `/tmp/ryu_controller.log`
- Tests: Console output
- Monitoring: Console output
- System: `/var/log/syslog` (for OVS issues)

## 🛑 Emergency Stop

```bash
# Stop everything
sudo pkill -f ryu-manager
sudo ovs-vsctl list-br | xargs -r -L1 sudo ovs-vsctl del-br
sudo ip -all netns delete

# Clean restart
sudo ./deploy_complete.sh
```

## 💡 Tips

1. **Always use sudo** for namespace commands
2. **Check controller first** if connectivity fails
3. **Monitor logs** during troubleshooting
4. **Use dashboard** for quick visual status
5. **Run tests** after any configuration change

## 🆘 Getting Help

```bash
# View full documentation
cat README.md

# View architecture details
cat sdwan_architecture.md

# View script help
./deploy_sdwan.sh --help  # (if implemented)
```

## ⚙️ Configuration Files

- `deploy_sdwan.sh` - Network topology and WAN links
- `sdwan_controller.py` - Path selection algorithm, QoS rules
- `sdwan_monitor.py` - Monitoring thresholds
- `test_sdwan.sh` - Test scenarios

## 🔐 Security Notes

This is a lab/demo environment. For production:
- Enable TLS for OpenFlow
- Use encrypted tunnels (IPsec)
- Implement authentication
- Add firewall rules
- Monitor for anomalies

---

**Need more help?** Check README.md for detailed documentation!
