#!/bin/bash

# Horodatage
current_date_time=$(date +"%Y-%m-%d")

# Emplacement du fichier de log
LOG_FILE="/var/log/snmpd_install_and_config.log"

# Récupération des adresses IP 
ipaddress=$(ip a | grep ens | grep inet | awk '{print $2}' | cut -d '/' -f 1)
ipnetaddress=$(echo $ipaddress | cut -d '.' -f 1,2,3)

# Fonction pour la gestion des erreurs
function log_error {
    local MESSAGE="$1"
    local TIMESTAMP=$(date +'%Y-%m-%d %H:%M:%S')
    echo "ERREUR [$TIMESTAMP]: $MESSAGE" >&2
    echo "ERREUR [$TIMESTAMP]: $MESSAGE" >> "$LOG_FILE"
    exit 1
}

echo "1.Installation du protocole SNMP - [$current_date_time]." | tee -a "$LOG_FILE"

# Vérification des privilèges de l'utilisateur
if [[ $EUID -ne 0 ]]; then
  log_error "Ce script doit être exécuté en tant que root."
else 
  echo "L'utilisateur connecté est bien root." | tee -a "$LOG_FILE"
fi

# Vérification de la présence du protocole SNMP sur le système en fonction du VLAN
echo "Vérification de la présence du protocole SNMP sur le système." | tee -a "$LOG_FILE"

oceanet_oxalis_vlan=$(ip a | grep -i "10.249.0.255" | awk '{print $4}')
oceanet_gnau_vlan=$(ip a | grep -i "10.249.2.255" | awk '{print $4}')
synaaps_oxalis_vlan=$(ip a | grep -i "10.0.6.255" | awk '{print $4}')
synaaps_gnau_vlan=$(ip a | grep -i "10.0.150.255" | awk '{print $4}')

if [ -n "$oceanet_oxalis_vlan" ] || [ -n "$oceanet_gnau_vlan" ]; then
  echo "VLAN Oceanet." | tee -a "$LOG_FILE"
  if (dpkg --get-selections | grep -w "install" | grep -i "snmpd" > /dev/null) && (snmpwalk -v2c -c public 10.249.0.1 > /dev/null); then
    echo "VLAN Oxalis" | tee -a "$LOG_FILE"
    echo "Le protocole SNMP est déjà installé sur le système." | tee -a "$LOG_FILE"
    exit 0
  elif (dpkg --get-selections | grep -w "install" | grep -i "snmpd" > /dev/null) && (snmpwalk -v2c -c public 10.249.2.1 > /dev/null); then
    echo "VLAN GNAU" | tee -a "$LOG_FILE"
    echo "Le protocole SNMP est déjà installé sur le système." | tee -a "$LOG_FILE"
    exit 0
  else
    echo "Le protocole SNMP n'est pas installé sur le système, installation en cours..." | tee -a "$LOG_FILE"
  fi
elif [ -n "$synaaps_oxalis_vlan" ] || [ -n "$synaaps_gnau_vlan" ]; then
  echo "VLAN Synaaps." | tee -a "$LOG_FILE"
  if (dpkg --get-selections | grep -w "install" | grep -i "snmpd" > /dev/null) && (snmpwalk -v2c -c public 10.0.6.100 > /dev/null); then
    echo "VLAN Oxalis" | tee -a "$LOG_FILE"
    echo "Le protocole SNMP est déjà installé sur le système." | tee -a "$LOG_FILE"
    exit 0
  elif (dpkg --get-selections | grep -w "install" | grep -i "snmpd" > /dev/null) && (snmpwalk -v2c -c public 10.0.150.1 > /dev/null); then
    echo "VLAN GNAU" | tee -a "$LOG_FILE"
    echo "Le protocole SNMP est déjà installé sur le système." | tee -a "$LOG_FILE"
    exit 0
  else
    echo "Le protocole SNMP n'est pas installé sur le système, installation en cours..." | tee -a "$LOG_FILE"
  fi
else
  log_error "Le serveur cible n'est pas situé dans le VLAN de nagios." | tee -a "$LOG_FILE"
fi

# Vérification de la disponibilité du paquet d'installation du protocole SNMP
echo "Vérification de la disponibilité du paquet d'installation du protocole SNMP." | tee -a "$LOG_FILE"
if apt-cache policy snmpd > /dev/null; then
  echo "Le paquet snmpd est disponible." | tee -a "$LOG_FILE"
else
  log_error "Le paquet snmpd est introuvable."
fi

# Installation du protocole SNMP
echo "Installation protocole SNMP en cours..." | tee -a "$LOG_FILE"
apt-get -y update > /dev/null && apt-get -y install snmpd snmp libsnmp-dev > /dev/null
if ! command -v snmpd &>/dev/null; then
  log_error "Une erreur s'est produite lors de l'installation du protocole SNMP."
else
  echo "l'installation du protocole SNMP s'est déroulée avec succès." | tee -a "$LOG_FILE"
fi

# Sauvegarde des fichiers de configuration du protocole SNMP
echo "Sauvegarde des fichiers de configuration du protocole SNMP." | tee -a "$LOG_FILE"
if [[ -f /etc/snmp/snmpd.conf_${current_date_time}.bak ]]; then
  echo "le fichier snmpd.conf_${current_date_time}.bak existe déjà." | tee -a "$LOG_FILE"
else
  echo "Sauvegarde du fichier snmpd.conf." | tee -a "$LOG_FILE"
  cp /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf_${current_date_time}.bak
fi

# Vérification de la sauvegarde des fichiers de configuration du protocole SNMP
echo "Vérification de la sauvegarde des fichiers de configuration du protocole SNMP." | tee -a "$LOG_FILE"
if [[ -f /etc/snmp/snmpd.conf_${current_date_time}.bak ]]; then
    echo "Sauvegarde des fichiers de configuration effectuée avec succès." | tee -a "$LOG_FILE"
else
    log_error "La sauvegarde des fichiers de configuration a échoué."
fi

echo "2.Configuration du protocole SNMP - [$current_date_time]." | tee -a "$LOG_FILE"

# Configuration du protocole SNMP
echo "Modification des paramètres du fichier snmpd.conf en cours..." | tee -a "$LOG_FILE"
if grep -v '^ *#' /etc/snmp/snmpd.conf | grep -i "rocommunity  public default -V systemonly" > /dev/null; then
  echo "Le paramètre par défaut [rocommunity] est décommenté, Modification en cours..." | tee -a "$LOG_FILE"
  sed -i -e "s/rocommunit*/#rocommunity/g" /etc/snmp/snmpd.conf
  echo "rocommunity public "$ipnetaddress".0/24" >> /etc/snmp/snmpd.conf
else
    echo "Le paramètre par défaut [rocommunity] est bien commenté." | tee -a "$LOG_FILE"
fi

if grep -v '^ *#' /etc/snmp/snmpd.conf | grep -i "agentaddress  127.0.0.1,.*" > /dev/null; then
  echo "Le paramètre par défaut [agentaddress] est décommenté, Modification en cours..." | tee -a "$LOG_FILE"
  sed -i -e "s/agentaddress*/#agentAddress/g" /etc/snmp/snmpd.conf
  echo "agentAddress udp:127.0.0.1:161,udp:"$ipaddress":161,udp6:[::1]:161" >> /etc/snmp/snmpd.conf
else
  echo "Le paramètre par défaut [agentaddress] est bien commenté." | tee -a "$LOG_FILE"
fi

# Activation du protocole SNMP
echo "Activation du protocole SNMP au démarrage du système." | tee -a "$LOG_FILE"
systemctl enable --quiet snmpd

# Vérification de l'activation du protocole SNMP au démarrage
echo "Vérification de l'activation du protocole SNMP au démarrage." | tee -a "$LOG_FILE"
service_enabled=$(systemctl is-enabled --quiet snmpd)
if [[ $service_enabled -ne "enabled" ]]; then
  log_error "Le protocole SNMP n'est pas activé au démarrage du système."
else
  echo "Le protocole SNMP a bien été activé au démarrage du système." | tee -a "$LOG_FILE"
fi

# Redémarrage du protocole SNMP
echo "Redémarrage du protocole SNMP en cours..." | tee -a "$LOG_FILE"
systemctl restart --quiet snmpd 

# Vérification du redémarrage du protocole SNMP
echo "Vérification du redémarrage du protocole SNMP." | tee -a "$LOG_FILE"
service_active=$(systemctl is-active --quiet snmpd)
if [[ $service_active -ne "active" ]]; then
  log_error "Le démarrage du protocole SNMP a échoué."
else
  echo "Le protocole SNMP a démarré avec succès." | tee -a "$LOG_FILE"
fi

# Message de fin d'installation
echo "[Succès] $current_date_time - L'installation et la configuration du protocole SNMP sont terminées avec succès." | tee -a "$LOG_FILE"

exit 0
