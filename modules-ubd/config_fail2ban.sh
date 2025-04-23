#!/bin/bash

TMP_RESULT_FILE="/tmp/fail2ban_info.tmp"
JAIL_LOCAL="/etc/fail2ban/jail.local"
> "$TMP_RESULT_FILE"

GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

log() { echo -e "${GREEN}[OK]${RESET} $1"; echo "$1" >> "$TMP_RESULT_FILE"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; echo "$1" >> "$TMP_RESULT_FILE"; }
error() { echo -e "${RED}[ERREUR]${RESET} $1"; echo "$1" >> "$TMP_RESULT_FILE"; }

echo -e "\n🔧 Installation de Fail2ban..."
apt update -qq && apt install -y fail2ban

echo -e "\n🎛  Configuration des paramètres globaux (laisser vide pour valeurs par défaut)"

read -rp "Ignore IP (ex: 127.0.0.1/8) [Facultatif] : " ignoreip
read -rp "Bantime (ex: 10m, 1h, -1) [Défaut: 10m] : " bantime
bantime=${bantime:-10m}
read -rp "Findtime (ex: 10m) [Défaut: 10m] : " findtime
findtime=${findtime:-10m}
read -rp "Maxretry (ex: 5) [Défaut: 5] : " maxretry
maxretry=${maxretry:-5}
read -rp "Banaction (ex: iptables-multiport, ufw) [Facultatif] : " banaction
read -rp "Backend (ex: systemd, auto) [Défaut: auto] : " backend
backend=${backend:-auto}
read -rp "Usedns (warn, no, yes) [Défaut: warn] : " usedns
usedns=${usedns:-warn}

echo -e "\nGénération de $JAIL_LOCAL..."

cat > "$JAIL_LOCAL" <<EOF
[DEFAULT]
bantime = $bantime
findtime = $findtime
maxretry = $maxretry
backend = $backend
usedns = $usedns
EOF

[[ -n "$ignoreip" ]] && echo "ignoreip = $ignoreip" >> "$JAIL_LOCAL"
[[ -n "$banaction" ]] && echo "banaction = $banaction" >> "$JAIL_LOCAL"

log "Paramètres globaux définis (bantime=$bantime, findtime=$findtime, maxretry=$maxretry)"

# === SERVICES À CONFIGURER ===
declare -A services=(
  ["sshd"]="Connexion SSH"
  ["apache-auth"]="Authentification Apache"
  ["nginx-http-auth"]="Authentification Nginx"
  ["postfix"]="Serveur mail Postfix"
  ["dovecot"]="Serveur IMAP/POP Dovecot"
  ["vsftpd"]="Serveur FTP vsFTPd"
)

echo -e "\nSélectionnez les services à protéger (ex: 1 2 5)"
i=1
for service in "${!services[@]}"; do
  echo "$i. ${services[$service]} ($service)"
  keys[$i]=$service
  ((i++))
done

read -rp "Votre sélection : " selected
selected_services=()
for index in $selected; do
  selected_services+=("${keys[$index]}")
done

# === CONFIG JAIL POUR CHAQUE SERVICE ===
for srv in "${selected_services[@]}"; do
  echo -e "\n⚙  Configuration de [$srv] (${services[$srv]})"
  
  read -rp "Activer ce service ? (true/false) [Défaut: true] : " enabled
  enabled=${enabled:-true}
  read -rp "Port (ex: ssh, 22) [Facultatif] : " port
  read -rp "Nom du filtre (défaut = nom du service) [Facultatif] : " filter
  filter=${filter:-$srv}
  read -rp "Chemin du journal (ex: /var/log/auth.log) [Facultatif] : " logpath
  read -rp "maxretry personnalisé ? [Facultatif] : " srv_maxretry
  read -rp "bantime personnalisé ? [Facultatif] : " srv_bantime
  read -rp "findtime personnalisé ? [Facultatif] : " srv_findtime
  read -rp "Action spécifique ? (ex: iptables-allports) [Facultatif] : " srv_action

  echo -e "\n[$srv]" >> "$JAIL_LOCAL"
  echo "enabled = $enabled" >> "$JAIL_LOCAL"
  [[ -n "$port" ]] && echo "port = $port" >> "$JAIL_LOCAL"
  [[ -n "$filter" ]] && echo "filter = $filter" >> "$JAIL_LOCAL"
  [[ -n "$logpath" ]] && echo "logpath = $logpath" >> "$JAIL_LOCAL"
  [[ -n "$srv_maxretry" ]] && echo "maxretry = $srv_maxretry" >> "$JAIL_LOCAL"
  [[ -n "$srv_bantime" ]] && echo "bantime = $srv_bantime" >> "$JAIL_LOCAL"
  [[ -n "$srv_findtime" ]] && echo "findtime = $srv_findtime" >> "$JAIL_LOCAL"
  [[ -n "$srv_action" ]] && echo "action = $srv_action" >> "$JAIL_LOCAL"

  log "Service $srv configuré (enabled=$enabled, filter=$filter)"
done

systemctl enable fail2ban
systemctl restart fail2ban && log "Fail2ban redémarré avec succès."

fail2ban-client status >> "$TMP_RESULT_FILE" 2>/dev/null

log "Configuration de Fail2ban terminée."

