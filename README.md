# **ServicioDirectorio_FIS - Configuración Completa**

## **PROYECTO - Servicio Integrado de Directorio y Autenticación para la FIS**

# 📘 Configuración Completa del Sistema Integrado

Este documento describe **paso a paso** la configuración completa de un sistema integrado de directorio y autenticación para la Facultad de Ingeniería de Sistemas, incluyendo **Kerberos, LDAP, DNS y NTP**.

---

## 1️⃣ ARQUITECTURA DEL SISTEMA

###  Diagrama de Componentes
```
Cliente FIS <---> [Servidor Integrado]
                     ↓
         +-----------------------+
         |  DNS (BIND9)          | ← Resolución nombres
         |  NTP (Chrony)         | ← Sincronización tiempo
         |  Kerberos (KDC)       | ← Autenticación
         |  LDAP (OpenLDAP)      | ← Directorio
         +-----------------------+
```

###  Especificaciones Técnicas
- **Servidor:** krb5.lcoronado.com
- **IP de WSL:** 172.27.133.157
- **Dominio:** lcoronado.com
- **Reino Kerberos:** LCORONADO.COM
- **Base LDAP:** dc=lcoronado,dc=com

---

## 2️⃣ CONFIGURACIÓN KERBEROS (SERVIDOR)

### 📄 `/etc/krb5.conf`
```ini
[libdefaults]
    default_realm = LCORONADO.COM
    dns_lookup_kdc = false
    dns_lookup_realm = false
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true
    rdns = false
    canonicalize = false
    rdns = false

[realms]
    LCORONADO.COM = {
        kdc = krb5.lcoronado.com
        admin_server = krb5.lcoronado.com
    }

[domain_realm]
    .lcoronado.com = LCORONADO.COM
    lcoronado.com = LCORONADO.COM
```

### 📄 `/etc/krb5kdc/kdc.conf`
```ini
[kdcdefaults]
    kdc_ports = 750,88

[realms]
    LCORONADO.COM = {
        database_name = /var/lib/krb5kdc/principal
        admin_keytab = FILE:/etc/krb5kdc/kadm5.keytab
        acl_file = /etc/krb5kdc/kadm5.acl
        key_stash_file = /etc/krb5kdc/stash
        kdc_ports = 750,88
        max_life = 10h 0m 0s
        max_renewable_life = 7d 0h 0m 0s
        #master_key_type = aes256-cts
        #supported_enctypes = aes256-cts:normal aes128-cts:normal
        default_principal_flags = +preauth
    }
```

### 📄 `/etc/krb5kdc/kadm5.acl`
```ini
*/admin@LCORONADO.COM    *
```

---

## 3️⃣ CONFIGURACIÓN LDAP (SERVIDOR)

### 📄 `/etc/ldap/ldap.conf`
```ini
# Configuración LDAP
BASE    dc=lcoronado,dc=com
URI     ldap://krb5.lcoronado.com

TLS_CACERT      /etc/ssl/certs/ca-certificates.crt
SASL_MECH       GSSAPI
SASL_REALM      LCORONADO.COM

# Timeouts
TIMEOUT 15
TIMELIMIT 15
```

### 📄 Estructura Base LDAP (`base.ldif`)
```ldif
dn: dc=lcoronado,dc=com
objectClass: top
objectClass: dcObject
objectClass: organization
o: Facultad de Ingenieria de Sistemas
dc: lcoronado

dn: cn=admin,dc=lcoronado,dc=com
objectClass: simpleSecurityObject
objectClass: organizationalRole
cn: admin
description: LDAP administrator

dn: ou=People,dc=lcoronado,dc=com
objectClass: organizationalUnit
ou: People

dn: ou=Groups,dc=lcoronado,dc=com
objectClass: organizationalUnit
ou: Groups

dn: ou=Services,dc=lcoronado,dc=com
objectClass: organizationalUnit
ou: Services
```

### 📄 Configuración SASL LDAP
```bash
# /etc/default/slapd
SLAPD_SERVICES="ldap:/// ldapi:///"

# /etc/ldap/sasl2/slapd.conf
mech_list: gssapi
keytab: /etc/krb5.keytab
```

---

## 4️⃣ CONFIGURACIÓN DNS (BIND9)

### 📄 `/etc/bind/named.conf.local`
```bind
zone "lcoronado.com" {
    type master;
    file "/etc/bind/db.lcoronado.com";
    allow-transfer { none; };
};

zone "133.27.172.in-addr.arpa" {
    type master;
    file "/etc/bind/db.172.27.133";
    allow-transfer { none; };
};
```

### 📄 `/etc/bind/db.lcoronado.com`
```bind
$TTL    604800
@       IN      SOA     krb5.lcoronado.com. admin.lcoronado.com. (
                              2         ; Serial (incrementado)
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      krb5.lcoronado.com.
@       IN      A       172.27.133.157
krb5    IN      A       172.27.133.157
ldap    IN      A       172.27.133.157
www     IN      A       172.27.133.157
```

### 📄 `/etc/bind/named.conf.options`
```bind
options {
    directory "/var/cache/bind";
    forwarders {
        8.8.8.8;
        8.8.4.4;
    };
    dnssec-validation auto;
    auth-nxdomain no;
    listen-on { any; };
    allow-query { any; };
    recursion yes;
};
```

---

## 5️⃣ CONFIGURACIÓN NTP (CHRONY)

###  `/etc/chrony/chrony.conf`
```conf
# Configuración NTP para Proyecto 2
pool pool.ntp.org iburst
allow 172.27.133.0/24
local stratum 10
makestep 1.0 3
rtcsync
driftfile /var/lib/chrony/chrony.drift
logdir /var/log/chrony
```

---

## 6️⃣ CONFIGURACIÓN CLIENTE LDAP + KERBEROS (GSSAPI)

### 📋 Paquetes Necesarios en el Cliente
```bash
sudo apt update
sudo apt install -y \
  ldap-utils \
  krb5-user \
  libsasl2-2 \
  libsasl2-modules \
  libsasl2-modules-gssapi-mit \
  openssh-server \
  chrony
```

### 📄 `/etc/krb5.conf` (Cliente)
```ini
[libdefaults]
 default_realm = LCORONADO.COM
 dns_lookup_realm = false
 dns_lookup_kdc = true
 ticket_lifetime = 10h
 renew_lifetime = 7d
 forwardable = true

[realms]
 LCORONADO.COM = {
  kdc = krb5.lcoronado.com
  admin_server = krb5.lcoronado.com
 }

[domain_realm]
 .lcoronado.com = LCORONADO.COM
 lcoronado.com = LCORONADO.COM
```

### 📄 `/etc/ldap/ldap.conf` (Cliente)
```ini
BASE   dc=lcoronado,dc=com
URI    ldap://krb5.lcoronado.com

SASL_MECH GSSAPI
SASL_REALM LCORONADO.COM
SASL_NOCANON on

TLS_CACERT      /etc/ssl/certs/ca-certificates.crt
```

### 📄 `/etc/sasl2/ldap.conf` (Cliente)
```ini
mech_list: gssapi
```

---

## 7️⃣ INTEGRACIÓN DE SERVICIOS

### 🔗 Kerberos + LDAP
```bash
# Crear principal LDAP en Kerberos
sudo kadmin.local -q "addprinc -randkey ldap/krb5.lcoronado.com"

# Crear keytab para LDAP
sudo kadmin.local -q "ktadd -k /etc/krb5.keytab ldap/krb5.lcoronado.com"

# Asignar permisos
sudo chown openldap:openldap /etc/krb5.keytab
```

### 🔗 Usuarios LDAP con Kerberos
```ldif
# Ejemplo de usuario integrado
dn: uid=lcoronado,ou=People,dc=lcoronado,dc=com
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
objectClass: krbPrincipalAux
uid: lcoronado
cn: Luis Coronado
sn: Coronado
krbPrincipalName: lcoronado@LCORONADO.COM
```

---

## 8️⃣ COMANDOS DE VERIFICACIÓN

### 🔍 Verificar Servidor
```bash
# 1. Servicios activos
systemctl status named chrony krb5-kdc slapd

# 2. Puertos escuchando
sudo netstat -tulpn | grep -E ":88|:389|:53|:123"

# 3. Principios Kerberos
sudo kadmin.local -q "listprincs"

# 4. Estructura LDAP
ldapsearch -Y GSSAPI -H ldap://krb5.lcoronado.com -b "dc=emafla,dc=com"
```

### 🔍 Verificar Cliente
```bash
# 1. Obtener ticket
kinit emafla@LCORONADO.COM

# 2. Ver ticket
klist

# 3. Probar LDAP con Kerberos
ldapwhoami -Y GSSAPI -H ldap://krb5.lcoronado.com

# 4. Búsqueda autenticada
ldapsearch -Y GSSAPI -b "dc=lcoronado,dc=com" "(uid=*)"
```

### 🔍 Verificar DNS
```bash
# Resolución directa
nslookup krb5.lcoronado.com
nslookup ldap.lcoronado.com

# Registros SRV
host -t SRV _kerberos._tcp.lcoronado.com
host -t SRV _ldap._tcp.lcoronado.com
```

### 🔍 Verificar NTP
```bash
# Sincronización
chronyc tracking
chronyc sources

# Ver diferencia de tiempo
chronyc sourcestats
```

---

## 9️⃣ SCRIPT DE INSTALACIÓN AUTOMÁTICA

### 📄 `CoronadoL-Proyecto2.sh` (Servidor)
```bash
#!/bin/bash
# Script de configuración completa del servidor integrado
# Incluye: DNS, NTP, Kerberos, LDAP
# Ver archivo completo en el repositorio
```

### 📄 `CoronadoL-Proyecto2-cliente.sh` (Cliente)
```bash
#!/bin/bash
# Script de configuración del cliente
# Configura: Kerberos, LDAP, DNS, NTP
# Ver archivo completo en el repositorio
```

---

## 1️⃣1️⃣ USUARIOS DE PRUEBA CONFIGURADOS

| Usuario | Kerberos Principal | LDAP DN | Rol |
|---------|-------------------|---------|-----|
| lcoronado | lcoronado@LCORONADO.COM | uid=lcoronado,ou=People,dc=lcoronado,dc=com | Administrador |
| emafla | emafla@LCORONADO.COM | uid=emafla,ou=People,dc=lcoronado,dc=com | Usuario prueba |
| liam | liam@LCORONADO.COM | uid=liam,ou=People,dc=lcoronado,dc=com | Usuario adicional |
| luis | luis@LCORONADO.COM | uid=luis,ou=People,dc=lcoronado,dc=com | Usuario adicional |

**Contraseña usuario emafla:** `emafla`

---

## 1️⃣2️⃣ SEGURIDAD IMPLEMENTADA

### 🔒 Medidas de Seguridad
1. **Autenticación:** Kerberos con tickets de tiempo limitado
2. **Encriptación:** AES-256 para tickets Kerberos
3. **Autorización:** Control de acceso LDAP por DN
4. **Firewall:** Solo puertos necesarios abiertos (22, 53, 88, 123, 389, 464)

### 🔒 Hardening
```bash
# Tiempo de vida de tickets limitado
ticket_lifetime = 24h
renew_lifetime = 7d

# Encriptación fuerte
supported_enctypes = aes256-cts:normal aes128-cts:normal

# Pre-autenticación requerida
default_principal_flags = +preauth
```
---

## 1️⃣4️⃣ ESTRUCTURA DE ARCHIVOS DEL PROYECTO

```
Proyecto2-FIS/
├── CoronadoL-Proyecto2.sh              # Script servidor
├── CoronadoL-Proyecto2-cliente.sh      # Script cliente
├── README.md                           # Este documento
├── configuraciones/
│   ├── dns/
│   │   ├── named.conf.local
│   │   ├── db.lcoronado.com
│   │   └── named.conf.options
│   ├── kerberos/
│   │   ├── krb5.conf
│   │   └── kdc.conf
│   ├── ldap/
│   │   ├── ldap.conf
│   │   └── base.ldif
│   └── ntp/
│       └── chrony.conf
├── datos/
│   ├── usuarios.ldif
│   ├── grupos.ldif
│   └── *.ldif
├── scripts/
│   ├── test-servicio-integrado.sh
│   ├── backup-configuracion.sh
│   └── monitoreo-servicios.sh
└── docs/
    ├── diagrama-arquitectura.png
    ├── principios-kerberos.txt
    └── manual-usuario.pdf
```

---