FROM osrg/ryu:latest

# Copie le contrôleur
COPY controller_sdwan.py /root/

WORKDIR /root

# Lance Ryu
CMD ["ryu-manager", "--verbose", "controller_sdwan.py"]
