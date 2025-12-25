# 🌐 SD-WAN Multi-Sites avec Tunneling GRE/VXLAN

Architecture SD-WAN interconnectant 3 sites géographiques via tunnels GRE et VXLAN, contrôleur SDN centralisé et chatbot IA pour le monitoring.

---

## 📋 Vue d'ensemble

Projet d'infrastructure réseau SD-WAN avec :
- **Tunnels GRE** : Encapsulation IP-in-IP pour interconnexion sites
- **Tunnels VXLAN** : Overlay réseau L2 sur L3
- **Contrôleur SDN** : Ryu avec OpenFlow 1.3
- **Chatbot IA** : Assistant intelligent de monitoring
- **Automation** : Déploiement et tests automatisés

---

## 🏗️ Architecture
```
                 Contrôleur SDN (Ryu)
                      OpenFlow
                          |
        ┌─────────────────┼─────────────────┐
        │                 │                 │
   ┌────▼────┐       ┌────▼────┐       ┌────▼────┐
   │ SITE 1  │       │ SITE 2  │       │ SITE 3  │
   │10.1.0/24│       │10.2.0/24│       │10.3.0/24│
   └────┬────┘       └────┬────┘       └────┬────┘
        │                 │                 │
        └─────────────────┴─────────────────┘
           Tunnels GRE + VXLAN sur WAN
```

### Composants
- **3 Sites** : 2 hosts + 1 routeur par site
- **9 Namespaces** : Isolation réseau Linux
- **4 Bridges OVS** : Software-defined switching
- **6 Tunnels GRE** : Interconnexion IP-in-IP
- **6 Tunnels VXLAN** : Extension L2 sur L3

---

## 🔐 Tunneling

### Tunnels GRE (172.16.x.x)

| Tunnel | Réseau | Usage |
|--------|--------|-------|
| Site 1 ↔ Site 2 | 172.16.12.0/30 | Tunnel primaire |
| Site 1 ↔ Site 3 | 172.16.13.0/30 | Tunnel primaire |
| Site 2 ↔ Site 3 | 172.16.23.0/30 | Tunnel primaire |

**Avantages** : Encapsulation légère, multiprotocole, simple

### Tunnels VXLAN (10.100.x.x)

| Tunnel | Réseau | VNI |
|--------|--------|-----|
| Site 1 ↔ Site 2 | 10.100.12.0/24 | 12 |
| Site 1 ↔ Site 3 | 10.100.13.0/24 | 13 |
| Site 2 ↔ Site 3 | 10.100.23.0/24 | 23 |

**Avantages** : Segmentation (VNI), 16M réseaux virtuels, overlay L2/L3

---

## 🛠️ Technologies

### Infrastructure
- **Open vSwitch** : SDN switching
- **OpenFlow 1.3** : Protocole de contrôle
- **GRE** : Encapsulation IP-in-IP
- **VXLAN** : Virtual eXtensible LAN (RFC 7348)
- **Network Namespaces** : Isolation Linux
- **Linux TC** : Traffic Control (QoS)

### Contrôle & Automation
- **Ryu SDN Controller** : Contrôle centralisé
- **Docker** : Conteneurisation contrôleur
- **Bash** : Infrastructure as Code
- **Python** : Automation & monitoring

### Intelligence Artificielle
- **Chatbot** : Monitoring conversationnel
- **NLP** : Traitement langage naturel
- **Détection d'anomalies** : Analyse métriques

---

## ✨ Fonctionnalités

- [x] Tunnels GRE point-à-point
- [x] Tunnels VXLAN avec VNI
- [x] Contrôleur SDN centralisé
- [x] Multi-path WAN (2 liens/site)
- [x] MAC learning automatique
- [x] Chatbot IA de monitoring
- [x] Déploiement automatisé
- [x] Tests automatisés
- [x] Simulation WAN réaliste

---

## 🚀 Installation

### Déploiement Complet
```bash
cd ~/sdwan-project

# Déploiement infrastructure + tunnels + contrôleur + démo
sudo ./prepare_demo.sh
```

**Temps** : 2-3 minutes  
**Résultat** : Infrastructure complète opérationnelle + démo interactive

---

## 📖 Utilisation

### Chatbot IA
```bash
sudo python3 chatbot_monitoring.py
```

**Questions supportées** :
- "Quelle est la latence ?"
- "Y a-t-il des anomalies ?"
- "Donne-moi un résumé"
- "État du contrôleur"
- "Combien de flows ?"

### Monitoring
```bash
# Monitoring automatisé
sudo python3 sdwan_monitor.py

# Démo complète
sudo ./demo_complete.sh
```

### Tests Tunnels
```bash
# Test tunnel GRE
sudo ip netns exec s1r ping 172.16.12.2

# Test tunnel VXLAN
sudo ip netns exec s1r ping 10.100.12.2

# Test end-to-end
sudo ip netns exec s1h1 ping 10.2.0.11

# Flows OpenFlow
sudo ovs-ofctl dump-flows br-site1 -O OpenFlow13
```

### Gestion Tunnels
```bash
# Configuration tunnels GRE/VXLAN
sudo ./setup_tunnels.sh

# Suppression tunnels
sudo ./cleanup_tunnels.sh
```

---

## 📁 Fichiers Principaux
```
sdwan-project/
├── deploy_sdwan.sh              # Déploiement infrastructure
├── setup_complete_network.sh    # Configuration routage
├── setup_tunnels.sh            # Configuration GRE/VXLAN ⭐
├── cleanup_tunnels.sh          # Suppression tunnels
├── prepare_demo.sh             # Déploiement complet ⭐
├── demo_complete.sh            # Démo interactive ⭐
├── chatbot_monitoring.py       # Chatbot IA ⭐
├── sdwan_monitor.py            # Monitoring automatisé
├── test_sdwan.sh               # Tests automatisés
└── README.md                   # Documentation
```

---

## 📊 Résultats

### Performance

| Métrique | Valeur |
|----------|--------|
| Latence moyenne | 20-72 ms |
| Packet loss | 0% |
| Health score | 82-94/100 |
| Déploiement | 2-3 min |
| Taux de réussite | 100% |

### Infrastructure

- **12 tunnels actifs** (6 GRE + 6 VXLAN)
- **9 namespaces réseau**
- **4 bridges OVS**
- **15-20 flows OpenFlow**

---

## 🎓 Compétences Démontrées

### Réseau
- Architecture SD-WAN
- Tunneling (GRE, VXLAN)
- Protocole OpenFlow
- Open vSwitch
- Routage avancé

### Automation
- Infrastructure as Code
- Scripting Bash/Python
- Tests automatisés
- Docker

### IA
- Chatbot NLP
- Détection d'anomalies
- Monitoring intelligent

---

## 📚 Documentation Technique

### GRE (Generic Routing Encapsulation)
- **RFC 2784**
- Mode point-to-point
- Overhead : 24 bytes
- Encapsulation : IP → GRE → IP

### VXLAN (Virtual eXtensible LAN)
- **RFC 7348**
- UDP port : 4789
- VNI : 24 bits (16M réseaux)
- Encapsulation : Ethernet → UDP → IP

### OpenFlow 1.3
- Contrôle centralisé des flows
- MAC learning
- Table de flows dynamique

---

## 🏆 Points Forts

✅ **Architecture SD-WAN complète** : Multi-sites avec tunneling  
✅ **Double tunneling** : GRE + VXLAN pour flexibilité  
✅ **Automation 100%** : Déploiement en une commande  
✅ **Innovation IA** : Chatbot de monitoring  
✅ **Production-ready** : Tests, monitoring, documentation  

---

## 🔧 Commandes Utiles
```bash
# Redéploiement rapide
sudo ./prepare_demo.sh

# Vérifier tunnels GRE
sudo ip netns exec s1r ip tunnel show

# Vérifier tunnels VXLAN
sudo ip netns exec s1r ip -d link show type vxlan

# État contrôleur
docker ps | grep sdwan-ryu

# Logs contrôleur
docker logs -f sdwan-ryu

# Routes configurées
sudo ip netns exec s1r ip route
```

---

## 💡 Architecture Réseau Détaillée

### Réseaux LAN
- Site 1 : `10.1.0.0/24`
- Site 2 : `10.2.0.0/24`
- Site 3 : `10.3.0.0/24`

### Réseaux WAN
- Site 1 : `192.168.1.0/24`
- Site 2 : `192.168.2.0/24`
- Site 3 : `192.168.3.0/24`

### Réseaux Tunnels GRE
- S1↔S2 : `172.16.12.0/30`
- S1↔S3 : `172.16.13.0/30`
- S2↔S3 : `172.16.23.0/30`

### Réseaux Tunnels VXLAN
- S1↔S2 : `10.100.12.0/24` (VNI 12)
- S1↔S3 : `10.100.13.0/24` (VNI 13)
- S2↔S3 : `10.100.23.0/24` (VNI 23)

---
## 🎥 Vidéo de Démonstration

[![Regarder la Démo](https://img.shields.io/badge/▶️_Regarder_la_Démo-1AB7EA?style=for-the-badge&logo=vimeo&logoColor=white)](https://vimeo.com/1149253959)

**Démo complète (1 minute)** : Déploiement, tunnels GRE/VXLAN, contrôleur SDN, chatbot IA, tests de performance

> 🎬 Cliquez sur le bouton pour visionner la vidéo complète
---

## ⚡ Démarrage Rapide (Quick Start)

### Installation en Une Commande
```bash
# 1. Téléchargez tous les fichiers du projet
git clone https://github.com/Kawthertlili/SD-WAN-Multi-Site-Network-with-GRE-VXLAN-Tunneling-AI-Chatbot.git
cd SD-WAN-Multi-Site-Network-with-GRE-VXLAN-Tunneling-AI-Chatbot

# 2. Rendez les scripts exécutables
chmod +x *.sh *.py

# 3. Lancez le déploiement complet

$ sudo ./prepare_demo.sh
[████████████████████] 100% 
✅ 3 sites connected
✅ 12 tunnels alive  
✅ 1 AI chatbot vibing
✅ 0 manual configs needed
```

**Remember**: Friends don't let friends configure networks manually 🤝


