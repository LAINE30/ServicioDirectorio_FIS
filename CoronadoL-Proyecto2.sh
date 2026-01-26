#!/bin/bash

################################################################################
# Script de Instalación y Configuración del Servidor
# Proyecto 2 - Luis Coronado
# Servicios: DNS (BIND9), NTP (Chrony), LDAP (OpenLDAP), Kerberos
# Sistema: Ubuntu 24.04 LTS en WSL
################################################################################

set -e  # Detener en caso de error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables de configuración
DOMAIN="lcoronado.com"
REALM="LCORONADO.COM"
HOSTNAME="krb5"
FQDN="${HOSTNAME}.${DOMAIN}"
IP_ADDRESS="172.27.133.157"
LDAP_ADMIN_PASSWORD="admin"
KERBEROS_ADMIN_PASSWORD="admin"
LDAP_BASE_DN="dc=lcoronado,dc=com"

# Función para imprimir mensajes
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_section() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

# Verificar que se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   print_error "Este script debe ejecutarse como root (sudo)"
   exit 1
fi

# Verificar que es Ubuntu
if ! grep -q "Ubuntu" /etc/os-release; then
    print_error "Este script está diseñado para Ubuntu"
    exit 1
fi

################################################################################
# 1. ACTUALIZACIÓN DEL SISTEMA
################################################################################
print_section "1. Actualizando el sistema"
apt-get update
apt-get upgrade -y
print_message "Sistema actualizado correctamente"

################################################################################
# 2. CONFIGURACIÓN DE HOSTNAME Y HOSTS
################################################################################
print_section "2. Configurando hostname y archivo hosts"

# Configurar hostname
hostnamectl set-hostname ${FQDN}
echo "${FQDN}" > /etc/hostname

# Configurar /etc/hosts
cat > /etc/hosts << EOF
127.0.0.1       localhost
127.0.1.1       ${FQDN} ${HOSTNAME}
${IP_ADDRESS}   ${FQDN} ${HOSTNAME}

# Docker entries
192.168.1.105   host.docker.internal
192.168.1.105   gateway.docker.internal
127.0.0.1       kubernetes.docker.internal

# IPv6
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

print_message "Hostname configurado: ${FQDN}"

################################################################################
# 3. INSTALACIÓN Y CONFIGURACIÓN DE DNS (BIND9)
################################################################################
print_section "3. Instalando y configurando DNS (BIND9)"

# Instalar BIND9
DEBIAN_FRONTEND=noninteractive apt-get install -y bind9 bind9utils bind9-doc dnsutils

# Configurar named.conf.options
cat > /etc/bind/named.conf.options << EOF
options {
    directory "/var/cache/bind";
    
    recursion yes;
    allow-query { any; };
    allow-recursion { any; };
    
    forwarders {
        8.8.8.8;
        8.8.4.4;
    };
    
    dnssec-validation auto;
    
    listen-on-v6 { any; };
};
EOF

# Configurar zona local
cat > /etc/bind/named.conf.local << EOF
zone "${DOMAIN}" {
    type master;
    file "/etc/bind/db.${DOMAIN}";
    allow-query { any; };
};
EOF

# Crear archivo de zona
cat > /etc/bind/db.${DOMAIN} << EOF
\$TTL    604800
@       IN      SOA     ${FQDN}. admin.${DOMAIN}. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ${FQDN}.
@       IN      A       ${IP_ADDRESS}
${HOSTNAME}    IN      A       ${IP_ADDRESS}
ldap    IN      A       ${IP_ADDRESS}
www     IN      A       ${IP_ADDRESS}

; Registros SRV para Kerberos
_kerberos._tcp          IN      SRV     0 0 88      ${FQDN}.
_kerberos._udp          IN      SRV     0 0 88      ${FQDN}.
_kerberos-master._tcp   IN      SRV     0 0 88      ${FQDN}.
_kerberos-master._udp   IN      SRV     0 0 88      ${FQDN}.
_kpasswd._tcp           IN      SRV     0 0 464     ${FQDN}.
_kpasswd._udp           IN      SRV     0 0 464     ${FQDN}.

; Registros SRV para LDAP
_ldap._tcp              IN      SRV     0 0 389     ${FQDN}.
EOF

# Verificar configuración
named-checkconf
named-checkzone ${DOMAIN} /etc/bind/db.${DOMAIN}

# Reiniciar BIND9
systemctl restart bind9
systemctl enable bind9

print_message "DNS (BIND9) configurado correctamente"

################################################################################
# 4. INSTALACIÓN Y CONFIGURACIÓN DE NTP (CHRONY)
################################################################################
print_section "4. Instalando y configurando NTP (Chrony)"

# Instalar Chrony
apt-get install -y chrony

# Configurar Chrony
cat > /etc/chrony/chrony.conf << EOF
# Usar pool de servidores NTP públicos
pool pool.ntp.org iburst

# Permitir acceso desde redes locales
allow 172.27.0.0/16
allow 192.168.1.0/24
allow 127.0.0.1

# Actuar como servidor NTP local
local stratum 10

# Archivos de configuración
driftfile /var/lib/chrony/chrony.drift
logdir /var/log/chrony
maxupdateskew 100.0
rtcsync
makestep 1 3
EOF

# Reiniciar Chrony
systemctl restart chrony
systemctl enable chrony

print_message "NTP (Chrony) configurado correctamente"

################################################################################
# 5. INSTALACIÓN Y CONFIGURACIÓN DE LDAP (OpenLDAP)
################################################################################
print_section "5. Instalando y configurando LDAP (OpenLDAP)"

# Preconfigurar respuestas para slapd
debconf-set-selections << EOF
slapd slapd/internal/generated_adminpw password ${LDAP_ADMIN_PASSWORD}
slapd slapd/internal/adminpw password ${LDAP_ADMIN_PASSWORD}
slapd slapd/password2 password ${LDAP_ADMIN_PASSWORD}
slapd slapd/password1 password ${LDAP_ADMIN_PASSWORD}
slapd slapd/dump_database_destdir string /var/backups/slapd-VERSION
slapd slapd/domain string ${DOMAIN}
slapd shared/organization string LCORONADO
slapd slapd/backend string MDB
slapd slapd/purge_database boolean true
slapd slapd/move_old_database boolean true
slapd slapd/allow_ldap_v2 boolean false
slapd slapd/no_configuration boolean false
slapd slapd/dump_database select when needed
EOF

# Instalar OpenLDAP
DEBIAN_FRONTEND=noninteractive apt-get install -y slapd ldap-utils

# Reconfigurar slapd
dpkg-reconfigure -f noninteractive slapd

# Esperar a que slapd esté listo
sleep 3

# Crear estructura LDAP base
print_message "Creando estructura LDAP..."

# Crear archivo LDIF para la estructura base
cat > /tmp/base_structure.ldif << EOF
dn: ou=People,${LDAP_BASE_DN}
objectClass: organizationalUnit
ou: People

dn: ou=Groups,${LDAP_BASE_DN}
objectClass: organizationalUnit
ou: Groups
EOF

ldapadd -x -D "cn=admin,${LDAP_BASE_DN}" -w ${LDAP_ADMIN_PASSWORD} -f /tmp/base_structure.ldif || true

# Crear grupo users
cat > /tmp/group_users.ldif << EOF
dn: cn=users,ou=Groups,${LDAP_BASE_DN}
objectClass: posixGroup
cn: users
gidNumber: 5000
EOF

ldapadd -x -D "cn=admin,${LDAP_BASE_DN}" -w ${LDAP_ADMIN_PASSWORD} -f /tmp/group_users.ldif || true

# Crear usuario lcoronado
cat > /tmp/user_lcoronado.ldif << EOF
dn: uid=lcoronado,ou=People,${LDAP_BASE_DN}
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: lcoronado
cn: Luis
sn: Coronado
givenName: Luis
mail: lcoronado@${DOMAIN}
employeeType: Administrador
employeeNumber: 1000
loginShell: /bin/bash
uidNumber: 1000
gidNumber: 5001
homeDirectory: /home/lcoronado
userPassword: {SSHA}$(slappasswd -s admin -h {SSHA} | cut -d'}' -f2)
EOF

ldapadd -x -D "cn=admin,${LDAP_BASE_DN}" -w ${LDAP_ADMIN_PASSWORD} -f /tmp/user_lcoronado.ldif || true

# Crear usuario emafla
cat > /tmp/user_emafla.ldif << EOF
dn: uid=emafla,ou=People,${LDAP_BASE_DN}
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: emafla
cn: Enrique
sn: Mafla
givenName: Enrique
title: Profesor de Sistemas Operativos
mail: enrique.mafla@epn.edu.ec
employeeType: Profesor
employeeNumber: 100
departmentNumber: 001
roomNumber: 205
loginShell: /bin/bash
uidNumber: 1001
gidNumber: 5001
homeDirectory: /home/emafla
userPassword: {SSHA}$(slappasswd -s admin -h {SSHA} | cut -d'}' -f2)
EOF

ldapadd -x -D "cn=admin,${LDAP_BASE_DN}" -w ${LDAP_ADMIN_PASSWORD} -f /tmp/user_emafla.ldif || true

# Configurar índices
cat > /tmp/indexes.ldif << EOF
dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcDbIndex
olcDbIndex: cn,uid eq
-
add: olcDbIndex
olcDbIndex: uidNumber,gidNumber eq
-
add: olcDbIndex
olcDbIndex: member,memberUid eq
EOF

ldapmodify -Y EXTERNAL -H ldapi:/// -f /tmp/indexes.ldif || true

systemctl restart slapd
systemctl enable slapd

print_message "LDAP (OpenLDAP) configurado correctamente"

################################################################################
# 6. INSTALACIÓN Y CONFIGURACIÓN DE KERBEROS
################################################################################
print_section "6. Instalando y configurando Kerberos"

# Preconfigurar Kerberos
debconf-set-selections << EOF
krb5-config krb5-config/default_realm string ${REALM}
krb5-config krb5-config/kerberos_servers string ${FQDN}
krb5-config krb5-config/admin_server string ${FQDN}
krb5-admin-server krb5-admin-server/kadmind boolean true
EOF

# Instalar Kerberos
DEBIAN_FRONTEND=noninteractive apt-get install -y krb5-kdc krb5-admin-server krb5-user libpam-krb5 libsasl2-modules-gssapi-mit

# Configurar krb5.conf
cat > /etc/krb5.conf << EOF
[libdefaults]
    default_realm = ${REALM}
    dns_lookup_kdc = false
    dns_lookup_realm = false
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true
    rdns = false
    canonicalize = false

[realms]
    ${REALM} = {
        kdc = ${FQDN}
        admin_server = ${FQDN}
    }

[domain_realm]
    .${DOMAIN} = ${REALM}
    ${DOMAIN} = ${REALM}
EOF

# Configurar kdc.conf
cat > /etc/krb5kdc/kdc.conf << EOF
[kdcdefaults]
    kdc_ports = 750,88

[realms]
    ${REALM} = {
        database_name = /var/lib/krb5kdc/principal
        admin_keytab = FILE:/etc/krb5kdc/kadm5.keytab
        acl_file = /etc/krb5kdc/kadm5.acl
        key_stash_file = /etc/krb5kdc/stash
        kdc_ports = 750,88
        max_life = 10h 0m 0s
        max_renewable_life = 7d 0h 0m 0s
        default_principal_flags = +preauth
    }
EOF

# Crear base de datos Kerberos
print_message "Creando base de datos Kerberos..."
echo -e "${KERBEROS_ADMIN_PASSWORD}\n${KERBEROS_ADMIN_PASSWORD}" | kdb5_util create -s

# Configurar ACL
cat > /etc/krb5kdc/kadm5.acl << EOF
*/admin@${REALM} *
EOF

# Crear principals
print_message "Creando principals de Kerberos..."

kadmin.local -q "addprinc -pw ${KERBEROS_ADMIN_PASSWORD} admin/admin@${REALM}"
kadmin.local -q "addprinc -pw ${KERBEROS_ADMIN_PASSWORD} root/admin@${REALM}"
kadmin.local -q "addprinc -randkey host/${FQDN}@${REALM}"
kadmin.local -q "addprinc -randkey ldap/${FQDN}@${REALM}"
kadmin.local -q "addprinc -pw admin lcoronado@${REALM}"
kadmin.local -q "addprinc -pw admin emafla@${REALM}"

# Crear keytabs
print_message "Creando keytabs..."
kadmin.local -q "ktadd -k /etc/krb5.keytab host/${FQDN}@${REALM}"
kadmin.local -q "ktadd -k /etc/ldap/ldap.keytab ldap/${FQDN}@${REALM}"

# Permisos para keytab de LDAP
chown openldap:openldap /etc/ldap/ldap.keytab
chmod 600 /etc/ldap/ldap.keytab

# Reiniciar servicios Kerberos
systemctl restart krb5-kdc
systemctl restart krb5-admin-server
systemctl enable krb5-kdc
systemctl enable krb5-admin-server

print_message "Kerberos configurado correctamente"

################################################################################
# 7. INTEGRACIÓN LDAP-KERBEROS (SASL)
################################################################################
print_section "7. Configurando integración LDAP-Kerberos"

# Configurar variables de entorno para LDAP con Kerberos
cat > /etc/default/slapd << EOF
SLAPD_CONF=
SLAPD_USER="openldap"
SLAPD_GROUP="openldap"
SLAPD_PIDFILE=
SLAPD_SERVICES="ldap:/// ldapi:///"
SLAPD_SENTINEL_FILE=/etc/ldap/noslapd
SLAPD_OPTIONS=""
KRB5_KTNAME=/etc/ldap/ldap.keytab
export KRB5_KTNAME
EOF

systemctl restart slapd

print_message "Integración LDAP-Kerberos configurada"

################################################################################
# 8. CONFIGURACIÓN DE CLIENTES
################################################################################
print_section "8. Configurando NSS y PAM"

# Instalar paquetes necesarios
apt-get install -y libnss-ldap libpam-ldap ldap-utils nscd

# Configurar nsswitch.conf
cat > /etc/nsswitch.conf << EOF
passwd:         files ldap
group:          files ldap
shadow:         files ldap
gshadow:        files

hosts:          files dns
networks:       files

protocols:      db files
services:       db files
ethers:         db files
rpc:            db files

netgroup:       nis
EOF

# Configurar PAM para LDAP y Kerberos
pam-auth-update --enable ldap --enable krb5 --enable mkhomedir

systemctl restart nscd

print_message "NSS y PAM configurados"

################################################################################
# 9. LIMPIEZA Y VERIFICACIÓN
################################################################################
print_section "9. Limpieza y verificación"

# Limpiar archivos temporales
rm -f /tmp/*.ldif

# Verificar servicios
print_message "Verificando estado de servicios..."
echo ""
systemctl status bind9 --no-pager | head -n 3
systemctl status chrony --no-pager | head -n 3
systemctl status slapd --no-pager | head -n 3
systemctl status krb5-kdc --no-pager | head -n 3
systemctl status krb5-admin-server --no-pager | head -n 3

################################################################################
# 10. RESUMEN Y PRUEBAS
################################################################################
print_section "INSTALACIÓN COMPLETADA"

cat << EOF

${GREEN}╔════════════════════════════════════════════════════════════════╗
║           CONFIGURACIÓN COMPLETADA EXITOSAMENTE                ║
╚════════════════════════════════════════════════════════════════╝${NC}

${BLUE}Información del Sistema:${NC}
  - Dominio:        ${DOMAIN}
  - FQDN:           ${FQDN}
  - IP Address:     ${IP_ADDRESS}
  - Realm Kerberos: ${REALM}

${BLUE}Servicios Configurados:${NC}
  ✓ DNS (BIND9)
  ✓ NTP (Chrony)
  ✓ LDAP (OpenLDAP)
  ✓ Kerberos (KDC + Admin Server)

${BLUE}Credenciales:${NC}
  - LDAP Admin:     cn=admin,${LDAP_BASE_DN} / ${LDAP_ADMIN_PASSWORD}
  - Kerberos Admin: admin/admin@${REALM} / ${KERBEROS_ADMIN_PASSWORD}

${BLUE}Usuarios Creados:${NC}
  - lcoronado (UID: 1000)
  - emafla (UID: 1001)

${YELLOW}Comandos de Prueba:${NC}

  # Verificar DNS
  nslookup ${FQDN}
  
  # Verificar NTP
  chronyc sources
  
  # Verificar LDAP
  ldapsearch -x -b "${LDAP_BASE_DN}"
  
  # Verificar Kerberos
  kinit emafla@${REALM}
  klist
  
  # Listar principals
  sudo kadmin.local -q "listprincs"

${GREEN}¡Instalación completada con éxito!${NC}

EOF

# Opcional: Reiniciar todos los servicios para asegurar que todo funciona
print_message "Reiniciando todos los servicios..."
systemctl restart bind9 chrony slapd krb5-kdc krb5-admin-server

print_message "Script finalizado. El servidor está listo para usar."