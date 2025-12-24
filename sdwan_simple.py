#!/usr/bin/env python3
import sys
import types
import eventlet
eventlet.monkey_patch()

# Patch WSGI
fake_wsgi = types.ModuleType('ryu.app.wsgi')
fake_wsgi._AlreadyHandledResponse = object
fake_wsgi.start_service = lambda app_mgr: None
fake_wsgi.WSGIApplication = object
sys.modules['ryu.app.wsgi'] = fake_wsgi

from ryu.base import app_manager
from ryu.controller import ofp_event
from ryu.controller.handler import CONFIG_DISPATCHER, MAIN_DISPATCHER, set_ev_cls
from ryu.ofproto import ofproto_v1_3
from ryu.lib.packet import packet, ethernet


class SimpleSDWAN(app_manager.RyuApp):
    OFP_VERSIONS = [ofproto_v1_3.OFP_VERSION]
    
    def __init__(self, *args, **kwargs):
        super(SimpleSDWAN, self).__init__(*args, **kwargs)
        self.mac_to_port = {}
        print("\n" + "="*70)
        print("SD-WAN CONTROLLER STARTED - Waiting for switches...")
        print("="*70 + "\n")
        sys.stdout.flush()
    
    @set_ev_cls(ofp_event.EventOFPSwitchFeatures, CONFIG_DISPATCHER)
    def switch_handler(self, ev):
        dp = ev.msg.datapath
        print(f"SWITCH CONNECTED: DPID={dp.id}")
        sys.stdout.flush()
        
        # Default flow
        match = dp.ofproto_parser.OFPMatch()
        actions = [dp.ofproto_parser.OFPActionOutput(dp.ofproto.OFPP_CONTROLLER, dp.ofproto.OFPCML_NO_BUFFER)]
        inst = [dp.ofproto_parser.OFPInstructionActions(dp.ofproto.OFPIT_APPLY_ACTIONS, actions)]
        mod = dp.ofproto_parser.OFPFlowMod(datapath=dp, priority=0, match=match, instructions=inst)
        dp.send_msg(mod)
    
    @set_ev_cls(ofp_event.EventOFPPacketIn, MAIN_DISPATCHER)
    def packet_handler(self, ev):
        msg = ev.msg
        dp = msg.datapath
        pkt = packet.Packet(msg.data)
        eth = pkt.get_protocol(ethernet.ethernet)
        
        if eth.ethertype == 0x88cc:
            return
        
        self.mac_to_port.setdefault(dp.id, {})
        self.mac_to_port[dp.id][eth.src] = msg.match['in_port']
        
        out_port = self.mac_to_port[dp.id].get(eth.dst, dp.ofproto.OFPP_FLOOD)
        actions = [dp.ofproto_parser.OFPActionOutput(out_port)]
        
        if out_port != dp.ofproto.OFPP_FLOOD:
            match = dp.ofproto_parser.OFPMatch(in_port=msg.match['in_port'], eth_dst=eth.dst)
            inst = [dp.ofproto_parser.OFPInstructionActions(dp.ofproto.OFPIT_APPLY_ACTIONS, actions)]
            mod = dp.ofproto_parser.OFPFlowMod(datapath=dp, priority=1, match=match, instructions=inst, idle_timeout=30)
            dp.send_msg(mod)
        
        data = msg.data if msg.buffer_id == dp.ofproto.OFP_NO_BUFFER else None
        out = dp.ofproto_parser.OFPPacketOut(datapath=dp, buffer_id=msg.buffer_id,
                                             in_port=msg.match['in_port'], actions=actions, data=data)
        dp.send_msg(out)


if __name__ == '__main__':
    from ryu.cmd import manager
    sys.argv = [sys.argv[0]]
    manager.main()
