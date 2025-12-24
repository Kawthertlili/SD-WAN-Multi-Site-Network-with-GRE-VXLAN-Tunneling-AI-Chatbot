# SD-WAN Multi-Site Network Architecture

## Topology Translation

### Original Architecture (Cisco SD-WAN)
- vManager: 20.3.1.2 (Control plane)
- vSmart: 20.3.1.1 (Policy engine)
- SW1, SW2: Site routers
- Border Router: WAN edge
- vEdgeCloud sites: Remote branches

### Ubuntu Implementation
```
┌─────────────────────────────────────────────────────────┐
│                  RYU SDN CONTROLLER                      │
│              (Central Intelligence)                      │
│         - Path Selection Algorithm                       │
│         - QoS Policy Engine                             │
│         - Health Monitoring                             │
└─────────────────────────────────────────────────────────┘
                          │
                   OpenFlow Protocol
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
   ┌────▼────┐      ┌────▼────┐      ┌────▼────┐
   │ SITE-1  │      │ SITE-2  │      │ SITE-3  │
   │  OVS    │      │  OVS    │      │  OVS    │
   └────┬────┘      └────┬────┘      └────┬────┘
        │                │                 │
   ┌────▼────┐      ┌────▼────┐      ┌────▼────┐
   │ Hosts   │      │ Hosts   │      │ Hosts   │
   │ (ns)    │      │ (ns)    │      │ (ns)    │
   └─────────┘      └─────────┘      └─────────┘
```

## Components
1. Network Namespaces: Isolated network environments
2. Open vSwitch: Software switches with OpenFlow
3. Ryu Controller: SDN intelligence
4. veth pairs: Virtual ethernet connections
5. Linux tc: Traffic shaping & QoS
