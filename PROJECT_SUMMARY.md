# 🌐 SD-WAN Multi-Site Network - Complete Project

## 📦 Project Overview

This is a **production-grade SD-WAN implementation** that demonstrates advanced networking concepts using Ubuntu, Open vSwitch, and Ryu SDN controller. The system provides intelligent traffic routing, automatic failover, QoS, and real-time monitoring.

## ✨ Key Features

| Feature | Description | Status |
|---------|-------------|--------|
| **Dynamic Path Selection** | Automatically routes traffic based on latency, loss, and bandwidth | ✅ Implemented |
| **Automatic Failover** | Instant rerouting when links fail (<2s) | ✅ Implemented |
| **Quality of Service** | Priority traffic (SSH, VoIP) gets preferred treatment | ✅ Implemented |
| **Real-time Monitoring** | Continuous health checks with anomaly detection | ✅ Implemented |
| **Complete Automation** | One-command deployment and testing | ✅ Implemented |
| **Visual Dashboard** | Real-time status monitoring | ✅ Implemented |

## 📂 Project Files

```
sdwan-project/
├── 📄 README.md                    # Complete documentation
├── 📄 QUICK_REFERENCE.md           # Command cheat sheet
├── 📄 sdwan_architecture.md        # Architecture details
│
├── 🚀 deploy_complete.sh           # ONE-COMMAND DEPLOYMENT ⭐
├── 🔧 deploy_sdwan.sh              # Network infrastructure setup
│
├── 🤖 sdwan_controller.py          # Ryu SDN controller (core logic)
├── 📊 sdwan_monitor.py             # Network monitoring & health checks
├── 📺 sdwan_dashboard.py           # Real-time visual dashboard
│
└── 🧪 test_sdwan.sh                # Automated test suite (10 tests)
```

## 🎯 Quick Start - 3 Simple Steps

### Step 1: Get the Files
```bash
# You already have them! You're in: /home/claude/
cd /home/claude
ls -l *.sh *.py *.md
```

### Step 2: Run One Command
```bash
sudo ./deploy_complete.sh
```

### Step 3: Enjoy! 🎉
The script will:
- ✅ Install prerequisites (OVS, Ryu, Python packages)
- ✅ Create 3 sites with hosts and routers
- ✅ Configure WAN links with realistic characteristics
- ✅ Start SDN controller
- ✅ Run automated tests
- ✅ Show monitoring demo

**Total time:** 2-3 minutes

## 🎓 What Gets Created

### Network Topology
```
┌─────────────┐
│   Ryu SDN   │  ← Intelligence & Path Selection
│  Controller │
└──────┬──────┘
       │ OpenFlow 1.3
   ┌───┴───┬───────┬────────┐
   │       │       │        │
┌──▼──┐ ┌──▼──┐ ┌──▼──┐  ┌─▼─┐
│Site1│ │Site2│ │Site3│  │WAN│
│ OVS │ │ OVS │ │ OVS │  │OVS│
└──┬──┘ └──┬──┘ └──┬──┘  └───┘
   │       │       │       │
 Hosts   Hosts   Hosts     │
 Router  Router  Router────┘
10.1.0/24 10.2.0/24 10.3.0/24
```

### Components Created
- **4 OVS Bridges**: br-site1, br-site2, br-site3, br-wan
- **9 Network Namespaces**: 6 hosts + 3 routers
- **Multiple WAN Paths**: Each site has 2 WAN connections
- **SDN Controller**: Running Ryu with custom intelligence
- **Automated Tests**: 10 comprehensive test scenarios

## 💻 Usage Examples

### Verify Deployment
```bash
# Check controller is running
ps aux | grep ryu-manager

# Check network namespaces
sudo ip netns list

# Check OVS bridges
sudo ovs-vsctl show
```

### Test Connectivity
```bash
# Ping between sites
sudo ip netns exec site1-host1 ping 10.2.0.11

# All at once
for site in 10.2.0.11 10.3.0.11; do
  echo "Testing $site..."
  sudo ip netns exec site1-host1 ping -c 3 $site
done
```

### Performance Testing
```bash
# Bandwidth test
sudo ip netns exec site2-host1 iperf3 -s &
sudo ip netns exec site1-host1 iperf3 -c 10.2.0.11 -t 30

# Concurrent connections
sudo ./test_sdwan.sh  # Runs all tests
```

### Monitoring
```bash
# One-time health check
sudo python3 sdwan_monitor.py

# Continuous monitoring
sudo python3 sdwan_monitor.py --continuous 15

# Visual dashboard
sudo python3 sdwan_dashboard.py
```

## 🧪 Testing Capabilities

The automated test suite (`test_sdwan.sh`) validates:

1. ✅ **Basic Connectivity** - Inter-site communication
2. ✅ **Latency Measurements** - Network performance
3. ✅ **Bandwidth Tests** - Throughput validation
4. ✅ **Concurrent Flows** - Multi-stream handling
5. ✅ **Link Failover** - Automatic rerouting
6. ✅ **QoS Verification** - Priority traffic handling
7. ✅ **OVS Status** - Switch health
8. ✅ **Namespace Config** - Proper setup
9. ✅ **Path Selection** - Dynamic routing
10. ✅ **System Resources** - Resource usage

## 🔍 Monitoring Features

The monitoring system provides:

- **Latency tracking** (min/avg/max)
- **Packet loss percentage**
- **Link health scores** (0-100)
- **Anomaly detection** (statistical analysis)
- **Historical trends**
- **Real-time alerts**

## 🎮 Interactive Commands

### Quick Health Check
```bash
sudo python3 sdwan_monitor.py
```

### Watch Traffic Live
```bash
sudo tcpdump -i br-wan -n
```

### View Real-time Dashboard
```bash
sudo python3 sdwan_dashboard.py
# Press 'q' to quit
```

### Run Full Test Suite
```bash
sudo ./test_sdwan.sh
```

## 📊 Expected Results

After successful deployment:

### Test Results
```
═══════════════════════════════════════════════════════════════
TEST SUMMARY
═══════════════════════════════════════════════════════════════
Total Tests:  10
Passed:       10
Failed:       0
Success Rate: 100.00%
═══════════════════════════════════════════════════════════════
✓ ALL TESTS PASSED!
```

### Network Status
```
● Controller: RUNNING (PID: xxxx)
● Bridges: 4 (br-site1, br-site2, br-site3, br-wan)
● Namespaces: 9 (6 hosts + 3 routers)
● Flows: Active and routing intelligently
```

### Connectivity
```
● Site1 → Site2: Latency: 12.45ms, Loss: 0.5%  🟢 Excellent
● Site1 → Site3: Latency: 15.20ms, Loss: 0.8%  🟢 Excellent
● Site2 → Site3: Latency: 10.80ms, Loss: 0.3%  🟢 Excellent
```

## 🎯 Learning Objectives Achieved

Through this project, you'll understand:

✅ **SDN Architecture** - Controller-based networking
✅ **OpenFlow Protocol** - Switch-controller communication
✅ **Network Namespaces** - Linux network isolation
✅ **Open vSwitch** - Software-defined switching
✅ **Traffic Engineering** - Path selection algorithms
✅ **QoS Implementation** - Priority queuing
✅ **Failover Mechanisms** - High availability
✅ **Network Monitoring** - Health tracking
✅ **Automation** - Infrastructure as code

## 🔧 Customization

### Change WAN Link Characteristics
Edit `deploy_sdwan.sh`:
```bash
declare -A WAN_LINKS=(
    ["link1_latency"]="20ms"     # Adjust as needed
    ["link1_loss"]="0.5%"
    ["link1_bandwidth"]="200mbit"
)
```

### Modify QoS Priorities
Edit `sdwan_controller.py`:
```python
self.priority_ports = {
    22: 2,    # SSH - critical
    443: 1,   # HTTPS - high
    8080: 0,  # Your app - normal
}
```

### Add More Sites
Edit `deploy_sdwan.sh`:
```bash
declare -A SITES=(
    ["site1"]="10.1.0.0/24"
    ["site2"]="10.2.0.0/24"
    ["site3"]="10.3.0.0/24"
    ["site4"]="10.4.0.0/24"  # Add new site
)
```

## 🛠️ Troubleshooting

### Problem: Controller won't start
```bash
# Solution: Check Python dependencies
pip3 install ryu eventlet==0.30.2 --break-system-packages

# Verify installation
python3 -c "import ryu; print('Ryu installed OK')"
```

### Problem: No connectivity between sites
```bash
# Solution: Check namespace and routing
sudo ip netns exec site1-host1 ip route
sudo ip netns exec site1-host1 ping 10.1.0.1  # Test gateway
```

### Problem: OVS issues
```bash
# Solution: Restart OVS service
sudo systemctl restart openvswitch-switch
sudo ovs-vsctl show
```

## 📚 Documentation Files

- **README.md** - Complete comprehensive guide
- **QUICK_REFERENCE.md** - Command cheat sheet
- **sdwan_architecture.md** - Technical architecture
- **Controller logs** - `/tmp/ryu_controller.log`

## 🎉 Success Indicators

You'll know everything works when:

1. ✅ Controller starts with "SD-WAN Controller initialized"
2. ✅ Test suite shows 10/10 passed
3. ✅ Pings between sites work
4. ✅ Dashboard shows all links green
5. ✅ iperf3 tests complete successfully

## 🚀 Next Steps

After deployment:

1. **Explore**: Run monitoring and dashboard
2. **Test**: Try bandwidth tests and failover scenarios
3. **Customize**: Modify WAN characteristics and QoS rules
4. **Learn**: Study the controller code and path selection logic
5. **Extend**: Add more sites, implement new features

## 💡 Pro Tips

1. Always run with `sudo` for network operations
2. Check controller logs first when troubleshooting
3. Use dashboard for quick visual status
4. Run tests after any configuration change
5. Monitor during tests to see live path selection

## 🎓 Educational Value

This project teaches:
- **Networking**: SD-WAN, routing, QoS, failover
- **Linux**: Namespaces, veth pairs, tc, iptables
- **SDN**: OpenFlow, Ryu, path algorithms
- **Python**: Event-driven programming, network APIs
- **DevOps**: Automation, testing, monitoring

## ✅ Checklist

Before running:
- [ ] Ubuntu 20.04+ or compatible Linux
- [ ] Root/sudo access
- [ ] 4GB+ RAM
- [ ] All files in /home/claude/

To deploy:
- [ ] Run: `sudo ./deploy_complete.sh`
- [ ] Wait 2-3 minutes
- [ ] Verify tests pass
- [ ] Try monitoring commands
- [ ] Enjoy your SD-WAN! 🎉

## 📞 Support

Having issues? Check:
1. README.md for detailed docs
2. QUICK_REFERENCE.md for commands
3. Controller logs: `tail -f /tmp/ryu_controller.log`
4. System logs: `journalctl -xe`

---

**Ready to start?**

```bash
cd /home/claude
sudo ./deploy_complete.sh
```

**Let's build an SD-WAN! 🚀**
