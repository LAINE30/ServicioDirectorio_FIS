#!/bin/bash
# Script de configuración para cliente - Proyecto 2
# Estudiante: Luis Coronado
# Servidor: krb5.lcoronado.com (172.27.133.157)

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variables de configuración
DOMAIN="lcoronado.com"
REALM="LCORONADO.COM"
SERVER_IP="172.27.133.157"
SERVER_HOSTNAME="krb5.lcoronado.com"
USER_PRINCIPAL="lcoronado@${REALM}"
TEST_USER="emafla@${REALM}"

echo -e "${GREEN}=== Script de Configuración para Cliente - Proyecto 2 ===${NC}"
echo -e "${GREEN}Estudiante: Luis Coronado${NC}"
echo -e "${GREEN}Servidor: ${SERVER_HOSTNAME} (${SERVER_IP})${NC}\n"

# Función para verificar comandos
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${YELLOW}Instalando $1...${NC}"
        sudo apt-get update > /dev/null 2>&1
        sudo apt-get install -y $1 > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}$1 instalado correctamente${NC}"
        else
            echo -e "${RED}Error instalando $1${NC}"
            exit 1
        fi
    fi
}

# Función para probar conexión
test_connection() {
    echo -e "\n${YELLOW}Probando conectividad con el servidor...${NC}"
    
    # Prueba ping
    if ping -c 2 $SERVER_IP > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Conectividad IP: OK${NC}"
    else
        echo -e "${RED}✗ No hay conectividad con el servidor${NC}"
        exit 1
    fi
    
    # Prueba resolución DNS
    if host $SERVER_HOSTNAME > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Resolución DNS: OK${NC}"
    else
        echo -e "${YELLOW}⚠ Resolución DNS falló, usando IP directamente${NC}"
    fi
}

# 1. Instalar paquetes necesarios
echo -e "${YELLOW}1. Instalando paquetes requeridos...${NC}"
check_command "krb5-user"
check_command "ldap-utils"
check_command "openssh-server"
check_command "chrony"
check_command "dnsutils"

# 2. Configurar resolución DNS
echo -e "\n${YELLOW}2. Configurando DNS...${NC}"
sudo tee /etc/resolv.conf > /dev/null << EOF
# Configuración DNS para Proyecto 2
domain ${DOMAIN}
search ${DOMAIN}
nameserver ${SERVER_IP}
nameserver 8.8.8.8
EOF

# Agregar entrada al /etc/hosts
sudo tee -a /etc/hosts > /dev/null << EOF

# Servidor Proyecto 2 - Luis Coronado
${SERVER_IP} ${SERVER_HOSTNAME} krb5 ldap
EOF

echo -e "${GREEN}✓ DNS configurado${NC}"

# 3. Configurar NTP/Chrony
echo -e "\n${YELLOW}3. Configurando sincronización de tiempo (NTP)...${NC}"
sudo tee /etc/chrony/chrony.conf > /dev/null << EOF
# Configuración NTP para Kerberos
pool pool.ntp.org iburst
server ${SERVER_HOSTNAME} iburst prefer
driftfile /var/lib/chrony/chrony.drift
logdir /var/log/chrony
maxupdateskew 100.0
makestep 1 3
EOF

sudo systemctl restart chrony
sudo chronyc waitsync 2>/dev/null
echo -e "${GREEN}✓ NTP configurado${NC}"

# 4. Configurar Kerberos
echo -e "\n${YELLOW}4. Configurando Kerberos...${NC}"
sudo tee /etc/krb5.conf > /dev/null << EOF
[libdefaults]
    default_realm = ${REALM}
    dns_lookup_realm = false
    dns_lookup_kdc = true
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true
    default_tgs_enctypes = aes256-cts aes128-cts
    default_tkt_enctypes = aes256-cts aes128-cts
    permitted_enctypes = aes256-cts aes128-cts
    clockskew = 300

[realms]
    ${REALM} = {
        kdc = ${SERVER_HOSTNAME}
        admin_server = ${SERVER_HOSTNAME}
        default_domain = ${DOMAIN}
    }

[domain_realm]
    .${DOMAIN} = ${REALM}
    ${DOMAIN} = ${REALM}
EOF

echo -e "${GREEN}✓ Kerberos configurado${NC}"

# 5. Configurar LDAP
echo -e "\n${YELLOW}5. Configurando LDAP...${NC}"
sudo tee /etc/ldap/ldap.conf > /dev/null << EOF
# Configuración LDAP
BASE    dc=lcoronado,dc=com
URI     ldap://${SERVER_HOSTNAME}

TLS_CACERT      /etc/ssl/certs/ca-certificates.crt
SASL_MECH       GSSAPI
SASL_REALM      ${REALM}

# Timeouts
TIMEOUT 15
TIMELIMIT 15
EOF

echo -e "${GREEN}✓ LDAP configurado${NC}"

# 6. Configurar PAM para autenticación
echo -e "\n${YELLOW}6. Configurando autenticación PAM...${NC}"
sudo tee /usr/share/pam-configs/my_mkhomedir > /dev/null << EOF
Name: activate mkhomedir
Default: yes
Priority: 900
Session-Type: Additional
Session:
    required                        pam_mkhomedir.so umask=0022 skel=/etc/skel
EOF

sudo pam-auth-update --enable mkhomedir

# 7. Configurar nsswitch
echo -e "\n${YELLOW}7. Configurando NSS...${NC}"
sudo tee /etc/nsswitch.conf > /dev/null << EOF
# /etc/nsswitch.conf
passwd:         compat systemd ldap
group:          compat systemd ldap
shadow:         compat ldap
gshadow:        files

hosts:          files dns
networks:       files

protocols:      db files
services:       db files
ethers:         db files
rpc:            db files

netgroup:       nis ldap
EOF

echo -e "${GREEN}✓ NSS configurado${NC}"

# 8. Configurar SSH para Kerberos
echo -e "\n${YELLOW}8. Configurando SSH...${NC}"
sudo tee -a /etc/ssh/ssh_config > /dev/null << EOF

# Configuración Kerberos para SSH
Host ${SERVER_HOSTNAME}
    GSSAPIAuthentication yes
    GSSAPIDelegateCredentials yes

Host *
    GSSAPIAuthentication yes
    GSSAPIDelegateCredentials yes
EOF

sudo tee -a /etc/ssh/sshd_config > /dev/null << EOF

# Configuración Kerberos para SSHD
GSSAPIAuthentication yes
GSSAPICleanupCredentials yes
KerberosAuthentication yes
KerberosTicketCleanup yes
KerberosGetAFSToken no
EOF

sudo systemctl restart ssh

# 9. Script de prueba
echo -e "\n${YELLOW}9. Creando script de pruebas...${NC}"
sudo tee /usr/local/bin/test-proyecto2.sh > /dev/null << 'EOF'
#!/bin/bash
echo "=== Pruebas de Conexión Proyecto 2 ==="
echo "Fecha: $(date)"
echo ""

# Variables
SERVER="krb5.lcoronado.com"
DOMAIN="lcoronado.com"
REALM="LCORONADO.COM"

# 1. Prueba de conectividad básica
echo "1. Pruebas de conectividad:"
echo -n "  Ping al servidor: "
if ping -c 1 $SERVER &> /dev/null; then
    echo "OK"
else
    echo "FALLÓ"
fi

echo -n "  Resolución DNS: "
if host $SERVER &> /dev/null; then
    echo "OK"
else
    echo "FALLÓ"
fi

# 2. Prueba de puertos Kerberos/LDAP
echo -e "\n2. Pruebas de puertos:"
for port in 88 389 53; do
    echo -n "  Puerto $port: "
    if timeout 2 bash -c "cat < /dev/null > /dev/tcp/$SERVER/$port" 2>/dev/null; then
        echo "ABIERTO"
    else
        echo "CERRADO"
    fi
done

# 3. Prueba de tiempo
echo -e "\n3. Sincronización de tiempo:"
echo -n "  Diferencia de tiempo: "
chronyc sources | grep -E "^^\*" | awk '{print $5 " " $6}' || echo "No disponible"

# 4. Prueba de tickets Kerberos
echo -e "\n4. Estado de Kerberos:"
echo -n "  Configuración: "
if [ -f /etc/krb5.conf ]; then
    grep "default_realm" /etc/krb5.conf | head -1
else
    echo "No configurado"
fi

echo -n "  Tickets actuales: "
klist 2>/dev/null | grep "Default principal" || echo "No hay tickets"

# 5. Prueba LDAP básica
echo -e "\n5. Prueba LDAP:"
echo -n "  Búsqueda básica: "
if ldapsearch -x -LLL -b "dc=lcoronado,dc=com" -h $SERVER "(objectClass=*)" dn 2>/dev/null | head -5; then
    echo "OK"
else
    echo "FALLÓ"
fi

echo -e "\n=== Instrucciones para probar ==="
echo "1. Obtener ticket Kerberos:"
echo "   kinit tu_usuario"
echo ""
echo "2. Listar tickets:"
echo "   klist"
echo ""
echo "3. Probar autenticación LDAP con Kerberos:"
echo "   ldapsearch -Y GSSAPI -b 'dc=lcoronado,dc=com'"
echo ""
echo "4. Conectar via SSH con Kerberos:"
echo "   ssh -o GSSAPIAuthentication=yes tu_usuario@krb5.lcoronado.com"
EOF

sudo chmod +x /usr/local/bin/test-proyecto2.sh

# 10. Mensaje final
echo -e "\n${GREEN}=== Configuración completada ===${NC}"
echo -e "${YELLOW}Para probar la configuración, ejecuta:${NC}"
echo -e "  ${GREEN}test-proyecto2.sh${NC}"
echo ""
echo -e "${YELLOW}Pasos para autenticarse:${NC}"
echo "1. Obtener ticket Kerberos:"
echo -e "   ${GREEN}kinit ${USER_PRINCIPAL}${NC}"
echo ""
echo "2. Verificar ticket:"
echo -e "   ${GREEN}klist${NC}"
echo ""
echo "3. Probar LDAP con Kerberos:"
echo -e "   ${GREEN}ldapsearch -Y GSSAPI -b 'dc=lcoronado,dc=com'${NC}"
echo ""
echo "4. Conectar via SSH:"
echo -e "   ${GREEN}ssh ${USER_PRINCIPAL%@*}@${SERVER_HOSTNAME}${NC}"
echo ""
echo -e "${YELLOW}Nota: Asegúrate de que la contraseña del usuario '${USER_PRINCIPAL}' esté configurada en el servidor${NC}"

# Crear alias útiles
echo -e "\n${YELLOW}Creando alias en .bashrc...${NC}"
cat >> ~/.bashrc << EOF

# Alias para Proyecto 2 - Luis Coronado
alias kinit-proyecto='kinit ${USER_PRINCIPAL}'
alias klist-proyecto='klist'
alias ldap-proyecto='ldapsearch -Y GSSAPI -b "dc=lcoronado,dc=com"'
alias ssh-proyecto='ssh ${USER_PRINCIPAL%@*}@${SERVER_HOSTNAME}'
alias test-proyecto='test-proyecto2.sh'
EOF

echo -e "\n${GREEN}✓ Script de configuración completado${NC}"
echo -e "${YELLOW}Reinicia la terminal o ejecuta: source ~/.bashrc${NC}"