#!/bin/bash

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

log() { echo -e "${GREEN}[INFO]${RESET} $1"; }
warn() { echo -e "${YELLOW}[AVERTISSEMENT]${RESET} $1"; }
error() { echo -e "${RED}[ERREUR]${RESET} $1"; }

if [[ $EUID -ne 0 ]]; then
    error "Ce script doit être exécuté en tant que root."
    exit 1
fi

SSH_PORT=$(ss -tnlp | grep sshd | awk '{print $4}' | grep -oE '[0-9]+$' | head -n1)
[[ -z "$SSH_PORT" ]] && SSH_PORT=22

log "Port SSH détecté : $SSH_PORT"

echo
read -rp "Ce script va bloquer tout le trafic par défaut pour autoriser les ports spécifiés. Continuer ? (o/N) : " confirm
if [[ "$confirm" != "o" && "$confirm" != "O" ]]; then
    warn "Annulation de la configuration du pare-feu."
    exit 0
fi

# Réinitialisation des règles
iptables -F
iptables -X
iptables -Z

# Politique par défaut : tout bloquer
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# Autoriser loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Autoriser connexions établies
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Autoriser SSH
iptables -A INPUT -p tcp --dport "$SSH_PORT" -j ACCEPT
iptables -A OUTPUT -p tcp --sport "$SSH_PORT" -j ACCEPT
log "Connexion SSH autorisée sur le port $SSH_PORT"

# Menu interactif
while true; do
    echo -e "\n${GREEN}Configuration des ports${RESET}"
    echo "1) Ouvrir un port en entrée"
    echo "2) Ouvrir un port en sortie"
    echo "3) Fermer un port en entrée"
    echo "4) Fermer un port en sortie"
    echo "5) Afficher les règles actuelles"
    echo "6) Quitter"
    read -rp "Choix : " choice

    case "$choice" in
        1)
            read -rp "Numéro du port à OUVRIR en ENTRÉE : " port
            iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
            log "Port $port autorisé en entrée"
            ;;
        2)
            read -rp "Numéro du port à OUVRIR en SORTIE : " port
            iptables -A OUTPUT -p tcp --dport "$port" -j ACCEPT
            log "Port $port autorisé en sortie"
            ;;
        3)
            read -rp "Numéro du port à FERMER en ENTRÉE : " port
            iptables -D INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null \
                && log "Port $port fermé en entrée" \
                || warn "Aucune règle d'ouverture pour le port $port en entrée"
            ;;
        4)
            read -rp "Numéro du port à FERMER en SORTIE : " port
            iptables -D OUTPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null \
                && log "Port $port fermé en sortie" \
                || warn "Aucune règle d'ouverture pour le port $port en sortie"
            ;;
        5)
            echo -e "\n${YELLOW}Règles iptables actuelles :${RESET}"
            iptables -L -n -v --line-numbers
            ;;
        6)
            echo -e "\n${GREEN}Configuration du pare-feu terminée.${RESET}"
            break
            ;;
        *)
            warn "Choix invalide"
            ;;
    esac
done

