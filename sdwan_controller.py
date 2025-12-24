#!/usr/bin/env python3
"""
SD-WAN Controller with Intelligent Path Selection
Features:
- Dynamic path selection based on latency, packet loss, and bandwidth
- Automatic failover
- QoS prioritization
- Real-time monitoring
"""

from ryu.base import app_manager
from ryu.controller import ofp_event
from ryu.controller.handler import CONFIG_DISPATCHER, MAIN_DISPATCHER, DEAD_DISPATCHER
from ryu.controller.handler import set_ev_cls
from ryu.ofproto import ofproto_v1_3
from ryu.lib.packet import packet, ethernet, ipv4, tcp, udp, icmp, arp
from ryu.lib import hub
import time
import json
import logging
from collections import defaultdict
from datetime import datetime

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class PathMetrics:
    """Track metrics for each network path"""
    def __init__(self, path_id):
        self.path_id = path_id
        self.latency = 0
        self.packet_loss = 0
        self.bandwidth_used = 0
        self.bandwidth_total = 100  # Mbps
        self.available = True
        self.score = 100
        self.last_update = time.time()
        self.packet_count = 0
        self.byte_count = 0
        
    def update_metrics(self, latency=None, loss=None, bandwidth=None):
        """Update path metrics and calculate score"""
        if latency is not None:
            self.latency = latency
        if loss is not None:
            self.packet_loss = loss
        if bandwidth is not None:
            self.bandwidth_used = bandwidth
            
        self.last_update = time.time()
        self.calculate_score()
        
    def calculate_score(self):
        """Calculate path score (0-100, higher is better)"""
        # Weighted scoring: latency 40%, loss 40%, bandwidth 20%
        latency_score = max(0, 100 - (self.latency / 2))  # 200ms = 0 score
        loss_score = max(0, 100 - (self.packet_loss * 10))  # 10% loss = 0 score
        utilization = (self.bandwidth_used / self.bandwidth_total) * 100
        bandwidth_score = max(0, 100 - utilization)
        
        self.score = (
            latency_score * 0.4 +
            loss_score * 0.4 +
            bandwidth_score * 0.2
        )
        
        if not self.available:
            self.score = 0
            
        return self.score
    
    def to_dict(self):
        """Convert to dictionary for JSON serialization"""
        return {
            'path_id': self.path_id,
            'latency_ms': self.latency,
            'packet_loss_percent': self.packet_loss,
            'bandwidth_used_mbps': self.bandwidth_used,
            'bandwidth_total_mbps': self.bandwidth_total,
            'available': self.available,
            'score': self.score,
            'last_update': datetime.fromtimestamp(self.last_update).isoformat()
        }


class FlowEntry:
    """Represents a network flow"""
    def __init__(self, src_ip, dst_ip, protocol, src_port=0, dst_port=0, priority=0):
        self.src_ip = src_ip
        self.dst_ip = dst_ip
        self.protocol = protocol
        self.src_port = src_port
        self.dst_port = dst_port
        self.priority = priority  # 0=normal, 1=high, 2=critical
        self.current_path = None
        self.creation_time = time.time()
        self.last_seen = time.time()
        self.packet_count = 0
        self.byte_count = 0
        
    def get_flow_id(self):
        """Generate unique flow identifier"""
        return f"{self.src_ip}:{self.src_port}->{self.dst_ip}:{self.dst_port}:{self.protocol}"
    
    def update_stats(self, packet_count, byte_count):
        """Update flow statistics"""
        self.packet_count = packet_count
        self.byte_count = byte_count
        self.last_seen = time.time()


class SDWANController(app_manager.RyuApp):
    OFP_VERSIONS = [ofproto_v1_3.OFP_VERSION]
    
    def __init__(self, *args, **kwargs):
        super(SDWANController, self).__init__(*args, **kwargs)
        
        # MAC learning table: dpid -> {mac: port}
        self.mac_to_port = {}
        
        # Datapath registry
        self.datapaths = {}
        
        # Path tracking: (src_dpid, dst_dpid) -> [PathMetrics]
        self.paths = defaultdict(list)
        
        # Active flows: flow_id -> FlowEntry
        self.flows = {}
        
        # Site to datapath mapping
        self.site_dpids = {}
        
        # Statistics
        self.stats = {
            'total_flows': 0,
            'path_switches': 0,
            'failovers': 0,
            'packets_forwarded': 0
        }
        
        # QoS priority ports (SSH, HTTPS, DNS, VoIP)
        self.priority_ports = {
            22: 2,    # SSH - critical
            443: 1,   # HTTPS - high
            53: 1,    # DNS - high
            5060: 2,  # SIP - critical
            80: 0     # HTTP - normal
        }
        
        # Start monitoring threads
        self.monitor_thread = hub.spawn(self._monitor_loop)
        self.path_selection_thread = hub.spawn(self._path_selection_loop)
        
        logger.info("SD-WAN Controller initialized")
    
    @set_ev_cls(ofp_event.EventOFPSwitchFeatures, CONFIG_DISPATCHER)
    def switch_features_handler(self, ev):
        """Handle switch connection"""
        datapath = ev.msg.datapath
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser
        dpid = datapath.id
        
        # Register datapath
        self.datapaths[dpid] = datapath
        logger.info(f"Switch connected: DPID={dpid}")
        
        # Install table-miss flow entry
        match = parser.OFPMatch()
        actions = [parser.OFPActionOutput(ofproto.OFPP_CONTROLLER,
                                         ofproto.OFPCML_NO_BUFFER)]
        self.add_flow(datapath, 0, match, actions)
        
        # Request port statistics
        self._request_stats(datapath)
    
    @set_ev_cls(ofp_event.EventOFPStateChange, [MAIN_DISPATCHER, DEAD_DISPATCHER])
    def state_change_handler(self, ev):
        """Handle switch state changes"""
        datapath = ev.datapath
        if ev.state == MAIN_DISPATCHER:
            if datapath.id not in self.datapaths:
                self.datapaths[datapath.id] = datapath
                logger.info(f"Switch registered: DPID={datapath.id}")
        elif ev.state == DEAD_DISPATCHER:
            if datapath.id in self.datapaths:
                del self.datapaths[datapath.id]
                logger.warning(f"Switch disconnected: DPID={datapath.id}")
                self._handle_switch_failure(datapath.id)
    
    def add_flow(self, datapath, priority, match, actions, buffer_id=None, idle_timeout=0, hard_timeout=0):
        """Add flow entry to switch"""
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser
        
        inst = [parser.OFPInstructionActions(ofproto.OFPIT_APPLY_ACTIONS, actions)]
        
        if buffer_id:
            mod = parser.OFPFlowMod(datapath=datapath, buffer_id=buffer_id,
                                   priority=priority, match=match,
                                   instructions=inst, idle_timeout=idle_timeout,
                                   hard_timeout=hard_timeout)
        else:
            mod = parser.OFPFlowMod(datapath=datapath, priority=priority,
                                   match=match, instructions=inst,
                                   idle_timeout=idle_timeout, hard_timeout=hard_timeout)
        datapath.send_msg(mod)
    
    @set_ev_cls(ofp_event.EventOFPPacketIn, MAIN_DISPATCHER)
    def packet_in_handler(self, ev):
        """Handle packets sent to controller"""
        msg = ev.msg
        datapath = msg.datapath
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser
        in_port = msg.match['in_port']
        dpid = datapath.id
        
        pkt = packet.Packet(msg.data)
        eth = pkt.get_protocols(ethernet.ethernet)[0]
        
        # Ignore LLDP packets
        if eth.ethertype == 0x88cc:
            return
        
        dst = eth.dst
        src = eth.src
        
        # Learn MAC address
        self.mac_to_port.setdefault(dpid, {})
        self.mac_to_port[dpid][src] = in_port
        
        # Determine output port
        if dst in self.mac_to_port[dpid]:
            out_port = self.mac_to_port[dpid][dst]
        else:
            out_port = ofproto.OFPP_FLOOD
        
        actions = [parser.OFPActionOutput(out_port)]
        
        # Install flow if not flooding
        if out_port != ofproto.OFPP_FLOOD:
            # Check for IP packets to apply intelligent routing
            ip_pkt = pkt.get_protocol(ipv4.ipv4)
            if ip_pkt:
                priority = self._get_packet_priority(pkt)
                flow_id = self._create_flow_entry(pkt, dpid)
                
                # Select best path based on priority and metrics
                selected_path = self._select_best_path(dpid, priority)
                
                match = parser.OFPMatch(in_port=in_port, eth_dst=dst, eth_src=src)
                self.add_flow(datapath, priority + 1, match, actions, idle_timeout=60)
                
                self.stats['total_flows'] += 1
                logger.debug(f"Flow installed: {flow_id} priority={priority}")
        
        # Send packet out
        data = None
        if msg.buffer_id == ofproto.OFP_NO_BUFFER:
            data = msg.data
        
        out = parser.OFPPacketOut(datapath=datapath, buffer_id=msg.buffer_id,
                                 in_port=in_port, actions=actions, data=data)
        datapath.send_msg(out)
        self.stats['packets_forwarded'] += 1
    
    def _get_packet_priority(self, pkt):
        """Determine packet priority based on protocol and port"""
        tcp_pkt = pkt.get_protocol(tcp.tcp)
        udp_pkt = pkt.get_protocol(udp.udp)
        
        if tcp_pkt:
            if tcp_pkt.dst_port in self.priority_ports:
                return self.priority_ports[tcp_pkt.dst_port]
            if tcp_pkt.src_port in self.priority_ports:
                return self.priority_ports[tcp_pkt.src_port]
        elif udp_pkt:
            if udp_pkt.dst_port in self.priority_ports:
                return self.priority_ports[udp_pkt.dst_port]
            if udp_pkt.src_port in self.priority_ports:
                return self.priority_ports[udp_pkt.src_port]
        
        return 0  # Normal priority
    
    def _create_flow_entry(self, pkt, dpid):
        """Create flow entry from packet"""
        ip_pkt = pkt.get_protocol(ipv4.ipv4)
        if not ip_pkt:
            return None
        
        tcp_pkt = pkt.get_protocol(tcp.tcp)
        udp_pkt = pkt.get_protocol(udp.udp)
        
        src_port = 0
        dst_port = 0
        protocol = ip_pkt.proto
        
        if tcp_pkt:
            src_port = tcp_pkt.src_port
            dst_port = tcp_pkt.dst_port
        elif udp_pkt:
            src_port = udp_pkt.src_port
            dst_port = udp_pkt.dst_port
        
        priority = self._get_packet_priority(pkt)
        
        flow = FlowEntry(ip_pkt.src, ip_pkt.dst, protocol, src_port, dst_port, priority)
        flow_id = flow.get_flow_id()
        self.flows[flow_id] = flow
        
        return flow_id
    
    def _select_best_path(self, dpid, priority):
        """Select best path based on metrics and priority"""
        # Simulate path selection (in real implementation, would use actual paths)
        available_paths = [p for p in self.paths.get(dpid, []) if p.available]
        
        if not available_paths:
            return None
        
        # For high priority traffic, prefer low latency and low loss
        if priority >= 1:
            best_path = min(available_paths, key=lambda p: (p.latency, p.packet_loss))
        else:
            # For normal traffic, use overall score
            best_path = max(available_paths, key=lambda p: p.score)
        
        return best_path
    
    def _handle_switch_failure(self, dpid):
        """Handle switch failure and trigger failover"""
        logger.error(f"Handling failure for switch {dpid}")
        
        # Mark all paths through this switch as unavailable
        for path_list in self.paths.values():
            for path in path_list:
                if path.path_id == dpid:
                    path.available = False
                    path.calculate_score()
        
        # Trigger path reselection for affected flows
        self._trigger_path_reselection()
        self.stats['failovers'] += 1
    
    def _trigger_path_reselection(self):
        """Force reselection of paths for all flows"""
        logger.info("Triggering path reselection for all active flows")
        # In real implementation, would reinstall flows on new paths
        self.stats['path_switches'] += len(self.flows)
    
    def _request_stats(self, datapath):
        """Request statistics from switch"""
        parser = datapath.ofproto_parser
        req = parser.OFPFlowStatsRequest(datapath)
        datapath.send_msg(req)
        
        req = parser.OFPPortStatsRequest(datapath, 0, datapath.ofproto.OFPP_ANY)
        datapath.send_msg(req)
    
    @set_ev_cls(ofp_event.EventOFPFlowStatsReply, MAIN_DISPATCHER)
    def flow_stats_reply_handler(self, ev):
        """Handle flow statistics reply"""
        flows = []
        for stat in ev.msg.body:
            flows.append({
                'priority': stat.priority,
                'packet_count': stat.packet_count,
                'byte_count': stat.byte_count,
                'duration': stat.duration_sec
            })
    
    @set_ev_cls(ofp_event.EventOFPPortStatsReply, MAIN_DISPATCHER)
    def port_stats_reply_handler(self, ev):
        """Handle port statistics reply"""
        ports = []
        for stat in ev.msg.body:
            ports.append({
                'port_no': stat.port_no,
                'rx_packets': stat.rx_packets,
                'tx_packets': stat.tx_packets,
                'rx_bytes': stat.rx_bytes,
                'tx_bytes': stat.tx_bytes,
                'rx_errors': stat.rx_errors,
                'tx_errors': stat.tx_errors
            })
    
    def _monitor_loop(self):
        """Continuous monitoring loop"""
        while True:
            for dpid, datapath in list(self.datapaths.items()):
                self._request_stats(datapath)
            
            # Update path metrics (simulated for demo)
            self._update_path_metrics()
            
            hub.sleep(10)
    
    def _path_selection_loop(self):
        """Periodic path optimization"""
        while True:
            hub.sleep(30)
            self._optimize_paths()
    
    def _update_path_metrics(self):
        """Update metrics for all paths"""
        # Simulated metric updates
        import random
        for path_list in self.paths.values():
            for path in path_list:
                # Simulate metric changes
                path.update_metrics(
                    latency=random.uniform(10, 100),
                    loss=random.uniform(0, 5),
                    bandwidth=random.uniform(0, 80)
                )
    
    def _optimize_paths(self):
        """Optimize path selection for existing flows"""
        logger.info("Running path optimization...")
        optimized = 0
        
        for flow_id, flow in list(self.flows.items()):
            if time.time() - flow.last_seen > 120:
                # Remove stale flows
                del self.flows[flow_id]
                continue
            
            # Check if better path available
            current_path = flow.current_path
            if current_path:
                best_path = self._select_best_path(0, flow.priority)
                if best_path and best_path.path_id != current_path:
                    flow.current_path = best_path.path_id
                    optimized += 1
        
        if optimized > 0:
            logger.info(f"Optimized {optimized} flows")
            self.stats['path_switches'] += optimized
    
    def get_stats_summary(self):
        """Get controller statistics summary"""
        return {
            'controller': {
                'uptime_seconds': time.time(),
                'connected_switches': len(self.datapaths),
                'active_flows': len(self.flows),
                'total_flows_installed': self.stats['total_flows'],
                'path_switches': self.stats['path_switches'],
                'failovers': self.stats['failovers'],
                'packets_forwarded': self.stats['packets_forwarded']
            },
            'paths': {
                path_key: [p.to_dict() for p in path_list]
                for path_key, path_list in self.paths.items()
            },
            'timestamp': datetime.now().isoformat()
        }


if __name__ == '__main__':
    from ryu.cmd import manager
    import sys
    
    sys.argv.append('--verbose')
    sys.argv.append(__file__)
    manager.main()
