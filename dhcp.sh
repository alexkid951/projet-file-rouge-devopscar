#!/bin/bash

# Fonction pour afficher l'aide
function afficher_aide {
    echo "Aide pour l'installation et la configuration du serveur DHCP :"
    echo "1. Ce script installe le serveur DHCP ISC."
    echo "2. Il vous guide à travers les étapes de configuration."
    echo "3. Assurez-vous d'entrer des adresses IP valides."
    echo "4. La configuration est écrite dans /etc/dhcp/dhcpd.conf."
    echo "5. Pour vérifier les baux DHCP, consultez : /var/lib/dhcp/dhcpd.leases"
    echo ""
}


echo "----------------------------"
echo "Installation"
echo "----------------------------"
sleep 1 

# Mise à jour des paquets et installation du serveur DHCP
apt update 
apt install isc-dhcp-server -y

# Configuration du fichier /etc/dhcp/dhcpd.conf
read -p "Quel est le nom de domaine ? -exemple devops.lan: " DOMAINE 
read -p "Quelle est l'adresse du serveur ? -exemple 192.168.1.1: " ADRESSE
read -p "Quelle est la plage d'adresse de départ ? -exemple 10.10.10.101: " RANGE1
read -p "Quelle est l'adresse de fin ? -exemple 10.10.10.150: " RANGE2
read -p "Quel est le masque de sous-réseau ? -exemple 255.255.255.0: " MASK
read -p "Option routers ? -exemple 192.168.1.254 : " ROUTAGE
# Option de réservation d'adresse, décommenter si nécessaire
# read -p "Réservation d'adresse ? : " RESA
# echo "$DOMAINE, $ADRESSE,RANGE1,RANGE2,MASK,ROUTAGE"

# Fonction pour valider les adresses IP
function validate_ip() {
    local ip=$1
    0if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        IFS='.' read -r i1 i2 i3 i4 0<<< "$ip"
        if (( i1 <= 255 && i2 <= 255 0&& i3 <= 255 && i4 <= 255 )); then
            return 0
        fi
    fi
    return 1
}

# Validation des entrées
for var in ADRESSE RANGE1 RANGE2 ROUTAGE MASK; do
    if ! validate_ip "${!var}"; then
        echo "Erreur : $var ($var) n'est pas une adresse IP valide."
        exit 1
    fi
done

echo "Configuration terminée."

echo "Copie du fichier dhcpd.conf"

# Sauvegarde de la configuration actuelle
mv -i /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf-bak

# Écriture de la nouvelle configuration
cat > /etc/dhcp/dhcpd.conf <<- EOF
option domain-name "$DOMAINE";
option domain-name-servers $ADRESSE;

default-lease-time 86400;
max-lease-time 604800;
authoritative;

subnet 192.168.1.0 netmask $MASK {
    range $RANGE1 $RANGE2;
    option subnet-mask $MASK;
    option routers $ROUTAGE;
}

# Exemple d'hôte fixe (décommenter et adapter si nécessaire)
# host Portable {
#     hardware ethernet 00:0C:30:CD:2C:99;
#     fixed-address $RESA;
# }

ddns-update-style none;
EOF 

echo "Redémarrage du service DHCP"

# Démarrer le service ISC DHCP
systemctl start isc-dhcp-server 

# Vérification du statut du service
systemctl status isc-dhcp-server

# Afficher le fichier de baux
echo "Pour vérifier les baux DHCP, consultez : /var/lib/dhcp/dhcpd.leases"
