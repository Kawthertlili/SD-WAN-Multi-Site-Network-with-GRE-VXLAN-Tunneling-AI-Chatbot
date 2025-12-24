#!/usr/bin/env python3
"""
SD-WAN Controller - Version FINALE qui fonctionne !
"""

import sys
import types
import eventlet
eventlet.monkey_patch()  # Fix le warning RLock

# Crée un module wsgi factice COMPLET
fake_wsgi = types.ModuleType('ryu.app.wsgi')
fake_wsgi._AlreadyHandledResponse = object
fake_wsgi.start_service = lambda app_mgr: None
fake_wsgi.WSGIApplication = object
sys.modules['ryu.app.wsgi'] = fake_wsgi

from ryu.base import app_manager
from ryu.controller import ofp_event
from ryu.controller.handler import CONFIG_DISPATCHER, MAIN_DISPATCHER
from ryu.controller.handler import set_ev_cls
from ryu.ofproto import ofproto_v1_3
from ryu.lib.packet import packet, ethernet
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(message)s'  # Format simplifié
)
logger = logging.getLogger(__name__)


class FinalSDWANController(app_manager.RyuApp):
    OFP_VERSIONS = [ofproto_v1_3.OFP_VERSION]
    
    def __init__(self, *args, **kwargs):
        super(FinalSDWANController, self).__init__(*args, **kwargs)
        self.mac_to_port = {}
        self.flow_count = 0
        self.switches_connected = 0
        
        print("\n" + "="*70)
        print("  ✓✓✓ SD-WAN Controller Successfully Started! ✓✓✓")
        print("  ✓ OpenFlow 1.3 Ready")
        print("  ✓ Listening on port 6653...")
        print("="*70 + "\n")
    
    @set_ev_cls(ofp_event.EventOFPSwitchFeatures, CONFIG_DISPATCHER)
    def switch_features_handler(self, ev):
        datapath = ev.msg.datapath
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser
        dpid = datapath.id
        
        self.switches_connected += 1
        
        print(f"✓ SWITCH {self.switches_connected} CONNECTED: DPID={dpid}")
        
        # Installe la règle par défaut
        match = parser.OFPMatch()
        actions = [parser.OFPActionOutput(ofproto.OFPP_CONTROLLER,
                                         ofproto.OFPCML_NO_BUFFER)]
        self.add_flow(datapath, 0, match, actions, idle_timeout=0)
        
        print(f"  → Default flow installed on switch {dpid}\n")
        
        if self.switches_connected == 4:
            print("="*70)
            print("  ✓✓✓ ALL 4 SWITCHES CONNECTED! SD-WAN IS READY! ✓✓✓")
            print("="*70)
            print("\n  Now test with: sudo ip netns exec s1h1 ping 10.2.0.11\n")
    
    def add_flow(self, datapath, priority, match, actions, idle_timeout=30):
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser
        
        inst = [parser.OFPInstructionActions(ofproto.OFPIT_APPLY_ACTIONS, actions)]
        mod = parser.OFPFlowMod(
            datapath=datapath,
            priority=priority,
            match=match,
            instructions=inst,
            idle_timeout=idle_timeout
        )
        datapath.send_msg(mod)
    
    @set_ev_cls(ofp_event.EventOFPPacketIn, MAIN_DISPATCHER)
    def packet_in_handler(self, ev):
        msg = ev.msg
        datapath = msg.datapath
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser
        in_port = msg.match['in_port']
        dpid = datapath.id
        
        pkt = packet.Packet(msg.data)
        eth = pkt.get_protocols(ethernet.ethernet)[0]
        
        # Ignore LLDP
        if eth.ethertype == 0x88cc:
            return
        
        dst = eth.dst
        src = eth.src
        
        # MAC learning
        self.mac_to_port.setdefault(dpid, {})
        
        if src not in self.mac_to_port[dpid]:
            print(f"→ MAC Learning: {src} on switch {dpid} port {in_port}")
        
        self.mac_to_port[dpid][src] = in_port
        
        # Determine output port
        if dst in self.mac_to_port[dpid]:
            out_port = self.mac_to_port[dpid][dst]
        else:
            out_port = ofproto.OFPP_FLOOD
        
        actions = [parser.OFPActionOutput(out_port)]
        
        # Install flow if we know the destination
        if out_port != ofproto.OFPP_FLOOD:
            match = parser.OFPMatch(in_port=in_port, eth_dst=dst)
            self.add_flow(datapath, 10, match, actions, idle_timeout=30)
            
            self.flow_count += 1
            if self.flow_count % 10 == 0:
                print(f"✓ {self.flow_count} flows installed")
        
        # Send packet out
        data = None
        if msg.buffer_id == ofproto.OFP_NO_BUFFER:
            data = msg.data
        
        out = parser.OFPPacketOut(
            datapath=datapath,
            buffer_id=msg.buffer_id,
            in_port=in_port,
            actions=actions,
            data=data
        )
        datapath.send_msg(out)


if __name__ == '__main__':
    sys.argv = ['sdwan_controller_final.py']
    from ryu.cmd import manager
    manager.main()
