#!/usr/bin/env python3
"""
SD-WAN Controller - Version qui fonctionne vraiment !
Contourne complètement le problème WSGI
"""

import sys

# CRITIQUE : Empêche l'import de wsgi AVANT d'importer ryu
import importlib.util
import types

# Crée un module wsgi factice
fake_wsgi = types.ModuleType('ryu.app.wsgi')
fake_wsgi._AlreadyHandledResponse = object
sys.modules['ryu.app.wsgi'] = fake_wsgi

# Maintenant on peut importer ryu sans problème
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


class WorkingSDWANController(app_manager.RyuApp):
    OFP_VERSIONS = [ofproto_v1_3.OFP_VERSION]
    
    def __init__(self, *args, **kwargs):
        super(WorkingSDWANController, self).__init__(*args, **kwargs)
        self.mac_to_port = {}
        self.packet_count = 0
        
        logger.info("="*70)
        logger.info("  ✓ SD-WAN Controller Successfully Started!")
        logger.info("  ✓ Python 3.10+ Compatible")
        logger.info("  ✓ Waiting for switches to connect...")
        logger.info("="*70)
    
    @set_ev_cls(ofp_event.EventOFPSwitchFeatures, CONFIG_DISPATCHER)
    def switch_features_handler(self, ev):
        """Gère la connexion d'un switch"""
        datapath = ev.msg.datapath
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser
        dpid = datapath.id
        
        logger.info(f"✓ Switch Connected: DPID={dpid}")
        
        # Installe la règle par défaut
        match = parser.OFPMatch()
        actions = [parser.OFPActionOutput(ofproto.OFPP_CONTROLLER,
                                         ofproto.OFPCML_NO_BUFFER)]
        self.add_flow(datapath, 0, match, actions)
        
        logger.info(f"  → Table-miss flow installed for switch {dpid}")
    
    def add_flow(self, datapath, priority, match, actions, idle_timeout=30):
        """Ajoute une règle de flux"""
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
        """Gère les paquets"""
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
            logger.info(f"  → Learned: {src} on port {in_port} (switch {dpid})")
        
        self.mac_to_port[dpid][src] = in_port
        
        # Détermine le port de sortie
        if dst in self.mac_to_port[dpid]:
            out_port = self.mac_to_port[dpid][dst]
        else:
            out_port = ofproto.OFPP_FLOOD
        
        actions = [parser.OFPActionOutput(out_port)]
        
        # Installe une règle si on connaît la destination
        if out_port != ofproto.OFPP_FLOOD:
            match = parser.OFPMatch(in_port=in_port, eth_dst=dst)
            self.add_flow(datapath, 10, match, actions)
            
            self.packet_count += 1
            if self.packet_count % 10 == 0:
                logger.info(f"  → {self.packet_count} flows installed")
        
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
    sys.argv = ['sdwan_controller_working.py', '--verbose']
    from ryu.cmd import manager
    manager.main()
