#!/bin/bash

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

log() { echo -e "${GREEN}[INFO]${RESET} $1"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
error() { echo -e "${RED}[ERREUR]${RESET} $1"; }

pause() {
    read -rp "Appuyez sur Entrée pour continuer..."
}

if [[ $EUID -ne 0 ]]; then
    error "Ce script doit être exécuté en tant que root."
    exit 1
fi

already_updated=false

update_system() {
    if [ "$already_updated" = false ]; then
        log "🔄 Mise à jour du système..."
        apt update && apt upgrade -y || error "Échec de la mise à jour"
        already_updated=true
    fi
}

set_hostname() {
    update_system
    read -rp "Nom d'hôte souhaité (laisser vide pour conserver l'actuel) : " hostname
    if [[ -n "$hostname" ]]; then
        hostnamectl set-hostname "$hostname"
        if ! grep -q "127.0.1.1 $hostname" /etc/hosts; then
            echo "127.0.1.1 $hostname" >> /etc/hosts
        fi
        log "Nom d'hôte défini : $hostname"
    else
        log "Aucun nom d'hôte saisi. Aucun changement effectué."
    fi
}

create_user() {
    update_system
    read -rp "Nom de l'utilisateur à créer (laisser vide pour annuler) : " username
    if [[ -z "$username" ]]; then
        log "Aucun nom d'utilisateur saisi. Aucun utilisateur créé."
        return
    fi

    if id "$username" &>/dev/null; then
        warn "Utilisateur '$username' existe déjà"
    else
        adduser "$username" && usermod -aG sudo "$username"
        log "Utilisateur créé : $username (ajouté au groupe sudo)"

        echo -e "${YELLOW}Souhaitez-vous restreindre l'accès au compte root ?${RESET}"
        echo "1) Bloquer seulement SSH (déjà appliqué automatiquement)"
        echo "2) Bloquer console/TTY (changer le shell de root)"
        echo "3) Verrouiller complètement le compte root (désactive mot de passe)"
        echo "4) Ne rien faire"
        read -rp "Choix (1-4) : " choice

        case "$choice" in
            1)
                log "Accès SSH root déjà désactivé (PermitRootLogin no)"
                ;;
            2)
                chsh -s /usr/sbin/nologin root && \
                log "Shell root changé : /usr/sbin/nologin (plus d'accès console)"
                ;;
            3)
                passwd -l root && \
                log "Compte root verrouillé (mot de passe désactivé)"
                ;;
            4)
                log "Aucune restriction supplémentaire appliquée à root."
                ;;
            *)
                warn "Choix invalide. Aucune action appliquée."
                ;;
        esac
    fi
}

secure_ssh() {
    update_system
    ssh_config="/etc/ssh/sshd_config"
    cp "$ssh_config" "${ssh_config}.bak"

    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' "$ssh_config"
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' "$ssh_config"
    sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' "$ssh_config"

    read -rp "Nom de l'utilisateur autorisé par clé SSH (laisser vide pour annuler) : " ssh_user
    if [[ -z "$ssh_user" ]]; then
        log "Aucun utilisateur SSH spécifié. Configuration SSH non modifiée."
        return
    fi

    if ! id "$ssh_user" &>/dev/null; then
        error "L'utilisateur '$ssh_user' n'existe pas. Veuillez le créer d'abord."
        return
    fi

    su - "$ssh_user" -c "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
    
    read -rp "Clé publique à ajouter pour $ssh_user (laisser vide pour annuler) : " pubkey
    if [[ -z "$pubkey" ]]; then
        log "Aucune clé publique fournie. Configuration SSH annulée pour cet utilisateur."
        return
    fi

    echo "$pubkey" > /home/$ssh_user/.ssh/authorized_keys
    chmod 600 /home/$ssh_user/.ssh/authorized_keys
    chown "$ssh_user:$ssh_user" /home/$ssh_user/.ssh/authorized_keys

    systemctl restart sshd
    log "SSH sécurisé (clé publique uniquement) pour : $ssh_user"
}

call_fail2ban_script() {
    update_system
    if [[ -f ./modules-ubd/config_fail2ban.sh ]]; then
        chmod +x ./modules-ubd/config_fail2ban.sh
        ./modules-ubd/config_fail2ban.sh
    else
        warn "Script Fail2ban non trouvé"
    fi
}

call_firewall_script() {
    update_system
    if [[ -f ./modules-ubd/config_firewall.sh ]]; then
        chmod +x ./modules-ubd/config_firewall.sh
        ./modules-ubd/config_firewall.sh
        log "Script de pare-feu exécuté"
    else
        warn "Script pare-feu non trouvé"
    fi
}

call_lamp_script() {
    update_system
    if [[ -f ./modules-ubd/setup_lamp.sh ]]; then
        chmod +x ./modules-ubd/setup_lamp.sh
        ./modules-ubd/setup_lamp.sh
    else
        warn "Script LAMP non trouvé"
    fi
}

main_menu() {
    clear
    echo -e "${GREEN}Bienvenue dans le script un_bon_debut pour Debian.${RESET}"
    echo "----------------------------------------------"
    PS3="Sélectionnez une option : "
    options=(
        "Définir le nom d'hôte"
        "Créer un utilisateur sudo"
        "Sécuriser SSH (clé uniquement)"
        "Configurer Fail2Ban"
        "Configuration du pare-feu"
        "Configuration du serveur LAMP"
        "Tout exécuter"
        "Quitter"
    )
    select opt in "${options[@]}"; do
        case $REPLY in
            1) set_hostname ;;
            2) create_user ;;
            3) secure_ssh ;;
            4) call_fail2ban_script ;;
            5) call_firewall_script ;;
            6) call_lamp_script ;;
            7)
                set_hostname
                create_user
                secure_ssh
                call_fail2ban_script
                call_firewall_script
                call_lamp_script
                ;;
            8) break ;;
            *) warn "Choix invalide." ;;
        esac
        pause
        clear
    done
}

main_menu
