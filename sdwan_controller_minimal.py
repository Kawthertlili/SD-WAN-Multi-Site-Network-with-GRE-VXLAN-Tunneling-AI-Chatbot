#!/usr/bin/env python3
"""
SD-WAN Controller Minimal - Sans WSGI (Compatible Python 3.10+)
"""

import sys
import os

# Patch pour éviter l'import du WSGI problématique
import ryu.app.wsgi
class DummyWSGI:
    pass
ryu.app.wsgi._AlreadyHandledResponse = DummyWSGI

from ryu.base import app_manager
from ryu.controller import ofp_event
from ryu.controller.handler import CONFIG_DISPATCHER, MAIN_DISPATCHER
from ryu.controller.handler import set_ev_cls
from ryu.ofproto import ofproto_v1_3
from ryu.lib.packet import packet, ethernet
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s'
)
logger = logging.getLogger(__name__)


class MinimalSDWANController(app_manager.RyuApp):
    OFP_VERSIONS = [ofproto_v1_3.OFP_VERSION]
    
    def __init__(self, *args, **kwargs):
        super(MinimalSDWANController, self).__init__(*args, **kwargs)
        self.mac_to_port = {}
        logger.info("="*70)
        logger.info("  SD-WAN Minimal Controller Started")
        logger.info("  Compatible with Python 3.10+")
        logger.info("="*70)
    
    @set_ev_cls(ofp_event.EventOFPSwitchFeatures, CONFIG_DISPATCHER)
    def switch_features_handler(self, ev):
        """Gère la connexion d'un switch"""
        datapath = ev.msg.datapath
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser
        dpid = datapath.id
        
        logger.info(f"✓ Switch Connected: DPID={dpid}")
        
        # Installe la règle par défaut (envoie au contrôleur)
        match = parser.OFPMatch()
        actions = [parser.OFPActionOutput(ofproto.OFPP_CONTROLLER,
                                         ofproto.OFPCML_NO_BUFFER)]
        self.add_flow(datapath, 0, match, actions)
        
        logger.info(f"  Installed table-miss flow for DPID={dpid}")
    
    def add_flow(self, datapath, priority, match, actions, idle_timeout=0):
        """Ajoute une règle de flux au switch"""
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
        """Gère les paquets envoyés au contrôleur"""
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
        
        # Apprentissage MAC
        self.mac_to_port.setdefault(dpid, {})
        
        if src not in self.mac_to_port[dpid]:
            logger.info(f"  Learned: MAC {src} on port {in_port} (DPID={dpid})")
        
        self.mac_to_port[dpid][src] = in_port
        
        # Détermine le port de sortie
        if dst in self.mac_to_port[dpid]:
            out_port = self.mac_to_port[dpid][dst]
        else:
            out_port = ofproto.OFPP_FLOOD
        
        actions = [parser.OFPActionOutput(out_port)]
        
        # Installe une règle si on ne fait pas de flood
        if out_port != ofproto.OFPP_FLOOD:
            match = parser.OFPMatch(in_port=in_port, eth_dst=dst)
            self.add_flow(datapath, 10, match, actions, idle_timeout=30)
            logger.debug(f"  Flow installed: {src} -> {dst} via port {out_port}")
        
        # Envoie le paquet
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
    # Lance le contrôleur
    sys.argv = ['sdwan_controller_minimal.py', '--verbose']
    
    from ryu.cmd import manager
    manager.main()
