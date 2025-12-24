#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Chatbot IA pour Monitoring SD-WAN
"""

import subprocess
import re
import unicodedata
from datetime import datetime

class SDWANChatbot:
    def __init__(self):
        self.name = "SD-WAN Assistant"
        self.version = "1.0"
        
        # Base de connaissances (avec et sans accents)
        self.commands = {
            'latence': self.get_latency,
            'ping': self.get_latency,
            'perte': self.get_packet_loss,
            'loss': self.get_packet_loss,
            'controleur': self.get_controller_status,
            'controller': self.get_controller_status,
            'contrôleur': self.get_controller_status,
            'flows': self.get_flows_count,
            'openflow': self.get_flows_count,
            'etat': self.get_network_status,
            'état': self.get_network_status,
            'status': self.get_network_status,
            'resume': self.get_summary,
            'résumé': self.get_summary,
            'summary': self.get_summary,
            'aide': self.show_help,
            'help': self.show_help,
            'anomalie': self.check_anomalies,
            'anomaly': self.check_anomalies,
            'site': self.get_site_info,
            'bridge': self.get_bridge_info,
        }
        
        self.colors = {
            'GREEN': '\033[0;32m',
            'YELLOW': '\033[1;33m',
            'RED': '\033[0;31m',
            'CYAN': '\033[0;36m',
            'BLUE': '\033[0;34m',
            'MAGENTA': '\033[0;35m',
            'NC': '\033[0m'
        }
    
    def remove_accents(self, text):
        """Retire les accents d'un texte"""
        nfd = unicodedata.normalize('NFD', text)
        return ''.join(char for char in nfd if unicodedata.category(char) != 'Mn')
    
    def print_color(self, text, color='NC', end='\n'):
        """Affiche du texte en couleur"""
        print(f"{self.colors[color]}{text}{self.colors['NC']}", end=end)
    
    def run_command(self, cmd):
        """Exécute une commande shell"""
        try:
            result = subprocess.run(
                cmd,
                shell=True,
                capture_output=True,
                text=True,
                timeout=10
            )
            return result.stdout
        except Exception as e:
            return f"Erreur: {str(e)}"
    
    def get_latency(self, args=None):
        """Mesure la latence entre sites"""
        self.print_color("\n🔍 Mesure de la latence...", 'CYAN')
        
        tests = [
            ('Site 1 → Site 2', 's1h1', '10.2.0.11'),
            ('Site 1 → Site 3', 's1h1', '10.3.0.11'),
            ('Site 2 → Site 3', 's2h1', '10.3.0.11'),
        ]
        
        results = []
        for name, ns, ip in tests:
            cmd = f"sudo ip netns exec {ns} ping -c 3 -W 2 {ip} 2>&1"
            output = self.run_command(cmd)
            
            if 'rtt min/avg/max' in output:
                rtt = re.search(r'rtt min/avg/max[^=]+=\s*[\d.]+/([\d.]+)/', output)
                if rtt:
                    latency = float(rtt.group(1))
                    results.append(f"  • {name}: {latency:.2f} ms")
            else:
                results.append(f"  • {name}: ❌ Échec")
        
        return "\n📊 Latences mesurées:\n" + "\n".join(results)
    
    def get_packet_loss(self, args=None):
        """Vérifie la perte de paquets"""
        self.print_color("\n🔍 Analyse de la perte de paquets...", 'CYAN')
        
        cmd = "sudo ip netns exec s1h1 ping -c 10 -W 2 10.2.0.11 2>&1"
        output = self.run_command(cmd)
        
        loss_match = re.search(r'(\d+)% packet loss', output)
        if loss_match:
            loss = int(loss_match.group(1))
            if loss == 0:
                return f"\n✅ Aucune perte de paquets détectée (0%)"
            elif loss < 5:
                return f"\n⚠️  Perte de paquets faible: {loss}%"
            else:
                return f"\n🚨 Perte de paquets élevée: {loss}%"
        
        return "\n❌ Impossible de mesurer la perte de paquets"
    
    def get_controller_status(self, args=None):
        """Vérifie l'état du contrôleur SDN"""
        self.print_color("\n🔍 Vérification du contrôleur SDN...", 'CYAN')
        
        cmd = "docker ps --filter name=sdwan-ryu --format '{{.Status}}'"
        output = self.run_command(cmd)
        
        if 'Up' in output:
            uptime = output.split('Up')[1].strip().split('\n')[0]
            return f"\n✅ Contrôleur Ryu actif depuis {uptime}"
        else:
            return "\n❌ Contrôleur Ryu inactif"
    
    def get_flows_count(self, args=None):
        """Compte les flows OpenFlow installés"""
        self.print_color("\n🔍 Analyse des flows OpenFlow...", 'CYAN')
        
        bridges = ['br-site1', 'br-site2', 'br-site3', 'br-wan']
        results = []
        total_flows = 0
        
        for bridge in bridges:
            cmd = f"sudo ovs-ofctl dump-flows {bridge} -O OpenFlow13 2>&1"
            output = self.run_command(cmd)
            count = output.count('priority=')
            total_flows += count
            results.append(f"  • {bridge}: {count} flows")
        
        return f"\n📊 Flows OpenFlow installés:\n" + "\n".join(results) + f"\n\n  Total: {total_flows} flows"
    
    def get_network_status(self, args=None):
        """État global du réseau"""
        self.print_color("\n🔍 Analyse de l'état du réseau...", 'CYAN')
        
        # Namespaces
        cmd = "sudo ip netns list | wc -l"
        ns_count = self.run_command(cmd).strip()
        
        # Bridges
        cmd = "sudo ovs-vsctl list-br | wc -l"
        br_count = self.run_command(cmd).strip()
        
        # Contrôleur
        cmd = "docker ps --filter name=sdwan-ryu --format '{{.Status}}'"
        controller = "Actif ✅" if 'Up' in self.run_command(cmd) else "Inactif ❌"
        
        # Test de connectivité
        cmd = "sudo ip netns exec s1h1 ping -c 2 -W 2 10.2.0.11 >/dev/null 2>&1 && echo 'OK' || echo 'FAIL'"
        connectivity = self.run_command(cmd).strip()
        
        return f"""
📊 État du Réseau SD-WAN:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  • Namespaces réseau: {ns_count}
  • Bridges OVS: {br_count}
  • Contrôleur SDN: {controller}
  • Connectivité inter-sites: {"✅ Opérationnelle" if connectivity == 'OK' else "❌ Problème détecté"}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"""
    
    def check_anomalies(self, args=None):
        """Détecte les anomalies réseau"""
        self.print_color("\n🔍 Recherche d'anomalies...", 'CYAN')
        
        anomalies = []
        
        # Vérifie la latence
        cmd = "sudo ip netns exec s1h1 ping -c 5 -W 2 10.2.0.11 2>&1"
        output = self.run_command(cmd)
        
        if 'rtt min/avg/max' in output:
            rtt = re.search(r'rtt min/avg/max[^=]+=\s*[\d.]+/([\d.]+)/', output)
            if rtt and float(rtt.group(1)) > 100:
                anomalies.append("⚠️  Latence élevée détectée (>100ms)")
        
        # Vérifie la perte de paquets
        loss_match = re.search(r'(\d+)% packet loss', output)
        if loss_match and int(loss_match.group(1)) > 0:
            anomalies.append(f"⚠️  Perte de paquets: {loss_match.group(1)}%")
        
        # Vérifie le contrôleur
        cmd = "docker ps --filter name=sdwan-ryu --format '{{.Status}}'"
        if 'Up' not in self.run_command(cmd):
            anomalies.append("🚨 Contrôleur SDN inactif")
        
        if anomalies:
            return "\n🚨 Anomalies détectées:\n  " + "\n  ".join(anomalies)
        else:
            return "\n✅ Aucune anomalie détectée. Le réseau fonctionne normalement."
    
    def get_summary(self, args=None):
        """Résumé complet du réseau"""
        self.print_color("\n📋 Génération du résumé complet...", 'CYAN')
        
        summary = f"""
╔══════════════════════════════════════════════════════════════════╗
║           RÉSUMÉ SD-WAN - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}           ║
╚══════════════════════════════════════════════════════════════════╝
"""
        summary += self.get_network_status()
        summary += "\n" + self.get_latency()
        summary += "\n" + self.get_flows_count()
        summary += "\n" + self.check_anomalies()
        
        return summary
    
    def get_site_info(self, args=None):
        """Informations sur les sites"""
        return """
📍 Sites configurés:

  Site 1: 10.1.0.0/24
    • Hosts: s1h1 (10.1.0.11), s1h2 (10.1.0.12)
    • Router: s1r (10.1.0.1)
    • WAN: 192.168.1.1, 192.168.1.2

  Site 2: 10.2.0.0/24
    • Hosts: s2h1 (10.2.0.11), s2h2 (10.2.0.12)
    • Router: s2r (10.2.0.1)
    • WAN: 192.168.2.1, 192.168.2.2

  Site 3: 10.3.0.0/24
    • Hosts: s3h1 (10.3.0.11), s3h2 (10.3.0.12)
    • Router: s3r (10.3.0.1)
    • WAN: 192.168.3.1, 192.168.3.2
"""
    
    def get_bridge_info(self, args=None):
        """Informations sur les bridges OVS"""
        self.print_color("\n🔍 Analyse des bridges...", 'CYAN')
        
        cmd = "sudo ovs-vsctl show"
        output = self.run_command(cmd)
        
        return f"\n📊 Configuration OVS:\n{output}"
    
    def show_help(self, args=None):
        """Affiche l'aide"""
        return """
🤖 Commandes disponibles:

  📊 Monitoring:
    • latence / ping      - Mesure la latence entre sites
    • perte / loss        - Vérifie la perte de paquets
    • etat / status       - État global du réseau
    • resume / summary    - Résumé complet
    • anomalie / anomaly  - Détecte les anomalies

  🔧 Infrastructure:
    • controleur          - État du contrôleur SDN
    • flows / openflow    - Compte les flows OpenFlow
    • site                - Informations sur les sites
    • bridge              - Configuration des bridges OVS

  ❓ Aide:
    • aide / help         - Affiche ce message
    • quit / exit         - Quitter le chatbot

Tapez votre question en langage naturel !
"""
    
    def process_query(self, query):
        """Traite la question de l'utilisateur"""
        query_lower = query.lower().strip()
        query_no_accent = self.remove_accents(query_lower)
        
        # Commandes de sortie
        if query_no_accent in ['quit', 'exit', 'q', 'quitter', 'sortir']:
            return None
        
        # Recherche de mots-clés dans la question (avec et sans accents)
        for keyword, function in self.commands.items():
            keyword_no_accent = self.remove_accents(keyword)
            if keyword in query_lower or keyword_no_accent in query_no_accent:
                return function()
        
        # Si aucun mot-clé trouvé
        return """
❓ Je n'ai pas compris votre question.

Essayez des questions comme:
  • "Quelle est la latence ?"
  • "Y a-t-il des anomalies ?"
  • "Quel est l'état du réseau ?"
  • "Combien de flows sont installés ?"
  • "Donne-moi un résumé"

Tapez 'aide' pour voir toutes les commandes.
"""
    
    def start(self):
        """Démarre le chatbot"""
        # Banner
        self.print_color("""
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║                 🤖 SD-WAN MONITORING CHATBOT 🤖                  ║
║                  Assistant IA pour votre réseau                  ║
║                                                                  ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
""", 'CYAN')
        
        self.print_color("\n💡 Tapez 'aide' pour voir les commandes disponibles", 'YELLOW')
        self.print_color("💡 Tapez 'quit' pour quitter\n", 'YELLOW')
        
        # Boucle principale
        while True:
            try:
                # Prompt
                self.print_color("Vous: ", 'GREEN', end='')
                query = input()
                
                if not query.strip():
                    continue
                
                # Traite la question
                response = self.process_query(query)
                
                # Si None, c'est une commande de sortie
                if response is None:
                    self.print_color("\n👋 Au revoir ! Merci d'avoir utilisé SD-WAN Chatbot.\n", 'CYAN')
                    break
                
                # Affiche la réponse
                self.print_color(f"\n🤖 Assistant: {response}\n", 'BLUE')
                
            except KeyboardInterrupt:
                self.print_color("\n\n👋 Au revoir !\n", 'CYAN')
                break
            except Exception as e:
                self.print_color(f"\n❌ Erreur: {str(e)}\n", 'RED')

def main():
    chatbot = SDWANChatbot()
    chatbot.start()

if __name__ == '__main__':
    main()
