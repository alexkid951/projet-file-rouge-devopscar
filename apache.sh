#!/bin/bash

# Fonction pour afficher un message d'erreur et quitter
function error_exit {
    echo "Erreur : $1"
    exit 1
}

# Installation et mise à jour des paquets
echo "Mise à jour des paquets..."
sudo apt update && sudo apt install apache2 openssl -y || error_exit "Échec de l'installation des paquets."

# Vérification de l'installation d'Apache
if ! systemctl status apache2 > /dev/null; then
    error_exit "Apache ne s'est pas installé correctement."
fi

# Démarrer le service Apache
echo "Démarrage du service Apache..."
sudo systemctl start apache2.service 

# Vérification du démarrage du service
if ! systemctl is-active --quiet apache2; then
    error_exit "Apache n'a pas pu démarrer."
fi

# Fonction pour créer une page web
function create_site {
    # Demande d'informations pour la nouvelle page web
    read -p "Nom du fichier pour la page web (ex: Devops.html): " PHTML
    read -p "Titre de la page web: " TITRE
    read -p "Titre principal de la page web: " TITRE2
    read -p "Contenu de la page web: " CONTENU
    read -p "Adresse IP pour le Virtual Host (ou laissez vide pour toutes): " IP
    read -p "Port pour le Virtual Host (par défaut 80): " PORT

    # Utilisation du port par défaut si aucun n'est fourni
    PORT=${PORT:-80}

    # Vérification du nom de fichier
    if [[ -z "$PHTML" ]]; then
        error_exit "Le nom de fichier ne peut pas être vide."
    fi

    # Configuration de la page web
    echo "Configuration de la page web..."
    cat > /var/www/html/$PHTML <<- EOF
<!DOCTYPE html>
<html>
<head>
    <title>$TITRE</title>
</head>
<body>
    <h1>$TITRE2</h1>
    <p>$CONTENU</p>
</body>
</html>
EOF

    # Création du répertoire pour le DocumentRoot
    DOCROOT="/var/www/$TITRE-apache"
    sudo mkdir -p $DOCROOT
    sudo chown -R www-data:www-data $DOCROOT
    sudo chmod -R 755 $DOCROOT

    # Copier le fichier dans le DocumentRoot
    sudo cp /var/www/html/$PHTML $DOCROOT/

    # Créer et configurer le Virtual Host
    echo "Configuration du Virtual Host..."
    VHOST_CONFIG="/etc/apache2/sites-available/$TITRE-apache.conf"
    sudo tee $VHOST_CONFIG > /dev/null <<- EOF
<VirtualHost ${IP:-*}:$PORT>
    ServerName $TITRE-apache.mon-domaine.local
    ServerAdmin webmaster@localhost
    DocumentRoot $DOCROOT

    <Directory "$DOCROOT">
        AllowOverride all
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

    # Génération des certificats SSL
    SSL_DIR="/etc/ssl/private/$TITRE-apache"
    sudo mkdir -p $SSL_DIR
    KEYFILE="$SSL_DIR/key.pem"
    CERTFILE="$SSL_DIR/cert.pem"
    
    # Générer une clé privée
    echo "Génération de la clé privée pour $TITRE..."
    if ! sudo openssl genrsa -out "$KEYFILE" 2048; then
        error_exit "La génération de la clé privée pour $TITRE a échoué."
    fi

    # Créer un certificat auto-signé
    echo "Création d'un certificat SSL auto-signé pour $TITRE..."
    if ! sudo openssl req -new -x509 -key "$KEYFILE" -out "$CERTFILE" -days 365 -subj "/C=FR/ST=Île-de-France/L=Paris/O=DevOpsCar/CN=$TITRE-apache.mon-domaine.local"; then
        error_exit "La création du certificat SSL pour $TITRE a échoué."
    fi

    # Configuration SSL pour le Virtual Host
    echo "Ajout de la configuration SSL au Virtual Host..."
    sudo tee -a $VHOST_CONFIG > /dev/null <<- EOF
    SSLEngine on
    SSLCertificateFile $CERTFILE
    SSLCertificateKeyFile $KEYFILE
</VirtualHost>
EOF

    # Activer le nouveau site et recharger Apache
    sudo a2ensite "$TITRE-apache.conf" || error_exit "Échec de l'activation du site."
    sudo systemctl reload apache2

    echo "Page créée avec succès. Vous pouvez accéder à votre page via http://${IP:-*}:$PORT/$PHTML"
}

# Boucle pour créer plusieurs sites
while true; do
    create_site
    read -p "Souhaitez-vous créer un autre site web ? (o/n) : " REPEAT
    if [[ ! "$REPEAT" =~ ^[Oo]$ ]]; then
        break
    fi
done

# Recharger Apache pour prendre en compte la nouvelle configuration
sudo systemctl reload apache2

s