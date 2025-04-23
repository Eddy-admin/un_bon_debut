#!/bin/bash

TMP_RESULT_FILE="/tmp/lamp_info.tmp"
> "$TMP_RESULT_FILE"

echo "Installation de LAMP..."

apt update -qq
apt install -y apache2 php libapache2-mod-php php-mysql

systemctl enable apache2
systemctl start apache2

echo "Apache et PHP installés." >> "$TMP_RESULT_FILE"
echo "Adresse : http://$(hostname -I | awk '{print $1}')" >> "$TMP_RESULT_FILE"

read -rp "Souhaitez-vous installer la base de données en local ? (y/n) : " local_db

if [[ "$local_db" =~ ^[Yy]$ ]]; then
    apt install -y mariadb-server
    systemctl enable mariadb
    systemctl start mariadb

    mysql_secure_installation

    read -rp "Nom de la base : " db_name
    read -rp "Utilisateur DB : " db_user
    read -rsp "Mot de passe : " db_pass; echo

    mysql -e "CREATE DATABASE $db_name;"
    mysql -e "CREATE USER '$db_user'@'localhost' IDENTIFIED BY '$db_pass';"
    mysql -e "GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"

    echo "Base locale : $db_name" >> "$TMP_RESULT_FILE"
    echo "Utilisateur : $db_user" >> "$TMP_RESULT_FILE"
    echo "Mot de passe : $db_pass" >> "$TMP_RESULT_FILE"
else
    read -rp "IP/host DB distante : " db_host
    read -rp "Port (default 3306) : " db_port
    read -rp "Nom de la base : " db_name
    read -rp "Utilisateur : " db_user
    read -rsp "Mot de passe : " db_pass; echo

    db_port=${db_port:-3306}

    echo "Base distante : $db_host:$db_port" >> "$TMP_RESULT_FILE"
    echo "Base : $db_name" >> "$TMP_RESULT_FILE"
    echo "Utilisateur : $db_user" >> "$TMP_RESULT_FILE"
    echo "Mot de passe : $db_pass" >> "$TMP_RESULT_FILE"
fi

