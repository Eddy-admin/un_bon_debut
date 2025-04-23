# un_bon_debut - Initialisation d’un serveur Debian

un_bon_debut.sh` est un script interactif conçu pour automatiser la configuration de base d’un serveur Debian
____________________________________________________________________________________________________
FONCTIONNALITÉS PRINCIPALES 
🔄 Mise à jour automatique du système

La mise à jour du système est effectuée automatiquement à chaque étape, même si l’option ne s’affiche pas dans le menu.
👤 Création d’un utilisateur sudo

    Ajout au groupe sudo

    Possibilité de restreindre les accès au compte root (SSH, console, verrouillage total)

🛡️ Sécurisation SSH

    Authentification par clé uniquement

    Désactivation de l’accès root par SSH

    Ajout d’une clé publique pour un utilisateur autorisé

🏷️ Définition du nom d'hôte

L'utilisateur peut définir un nom d’hôte personnalisé (option facultative, peut être laissée vide).

🔥 config_firewall.sh

Script de configuration d’un pare-feu iptables :

    Blocage complet en entrée/sortie

    Autorisation des connexions SSH en cours

    Menu pour ouvrir/fermer dynamiquement des ports spécifiques

    ⚠️ Une confirmation est demandée avant toute modification active des règles, pour éviter toute coupure SSH.

🔒 config_fail2ban.sh

Script interactif pour personnaliser :

    les services protégés (ssh, nginx, apache, etc.)

    les durées de ban, tentatives max, etc.

    activation/désactivation de la surveillance pour chaque service

🌐 setup_lamp.sh

Installation personnalisée d’un serveur LAMP :

    Choix d’installer MySQL localement ou se connecter à une base distante

    Configuration sécurisée de MySQL

    Installation d’Apache et PHP

    Infos de configuration stockées dans un fichier temporaire

💡 Recommandations de sécurité

    Ne jamais supprimer toutes les règles iptables sans précautions si vous êtes connecté en SSH

    Ne pas supprimer accidentellement tous les accès root sans avoir testé la connexion avec le nouvel utilisateur sudo

    Gardez une copie du script accessible en local en cas de coupure

