# Servicio Integrado de Directorio y Autenticación para la FIS

**Autor:** Luis Coronado  
**Institución:** Escuela Politécnica Nacional - Facultad de Ingeniería de Sistemas  
---

## 📋 Tabla de Contenidos

- [Descripción del Proyecto](#descripción-del-proyecto)
- [Arquitectura del Sistema](#arquitectura-del-sistema)
- [Requisitos del Sistema](#requisitos-del-sistema)
- [Instalación y Configuración](#instalación-y-configuración)
- [Servicios Implementados](#servicios-implementados)
- [Pruebas y Validación](#pruebas-y-validación)
- [Estructura del Repositorio](#estructura-del-repositorio)
- [Troubleshooting](#troubleshooting)
- [Referencias](#referencias)

---

## 🎯 Descripción del Proyecto

Este proyecto implementa un **sistema integrado de directorio y autenticación** diseñado para mejorar los servicios de la Facultad de Ingeniería de Sistemas (FIS). El sistema proporciona una infraestructura centralizada y segura para la gestión de usuarios, autenticación y servicios de red mediante la integración de tecnologías estándar de la industria.

---

## 🏗️ Arquitectura del Sistema

### Diagrama de Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                    SERVIDOR INTEGRADO                       │
│                  krb5.lcoronado.com                         │
│                   (172.27.133.157)                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │   DNS        │  │   NTP        │  │   LDAP       │    │
│  │   BIND9      │  │   Chrony     │  │   OpenLDAP   │    │
│  │   :53        │  │   :123       │  │   :389       │    │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘    │
│         │                 │                 │             │
│         └─────────────────┼─────────────────┘             │
│                           │                               │
│                  ┌────────▼────────┐                      │
│                  │   KERBEROS      │                      │
│                  │   MIT KDC       │                      │
│                  │   :88, :464     │                      │
│                  └─────────────────┘                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ SASL/GSSAPI
                            ▼
                   ┌─────────────────┐
                   │    CLIENTES     │
                   │  Linux/Windows  │
                   └─────────────────┘
```

### Componentes del Sistema

| Componente | Tecnología | Puerto | Función |
|------------|-----------|--------|----------|
| DNS | BIND9 | 53 | Resolución de nombres y registros SRV |
| NTP | Chrony | 123 | Sincronización de tiempo |
| LDAP | OpenLDAP | 389 | Directorio de usuarios y recursos |
| Kerberos KDC | MIT Kerberos | 88, 750 | Autenticación segura |
| Kerberos Admin | kadmind | 464 | Administración de principals |

---

### Software Base
- **Sistema Operativo:** Ubuntu 24.04 LTS (Noble Numbat)
- **Entorno:** WSL2 (Windows Subsystem for Linux) o nativo
- **Privilegios:** Acceso root (sudo)

### Puertos Requeridos/Utilizados
```
DNS:        53/TCP, 53/UDP
NTP:        123/UDP
LDAP:       389/TCP
Kerberos:   88/TCP, 88/UDP, 464/TCP, 464/UDP, 750/TCP
```

---

## 🚀 Instalación y Configuración

### Instalación Automática

El proyecto incluye un script de instalación automatizada que configura todos los servicios.

#### Paso 1: Clonar el Repositorio

```bash
git clone https://github.com/LAINE30/Proyecto2-FIS.git
```
#### Paso 2: Clonar el Repositorio

```bash
cd Proyecto2-FIS
```

#### Paso 3: Ejecutar el Script de Instalación

```bash
# Dar permisos de ejecución
chmod +x CoronadoL-Proyecto2.sh

# Ejecutar como root
sudo ./CoronadoL-Proyecto2.sh
```

El script realizará automáticamente:
1. Actualización del sistema
2. Configuración de hostname y hosts
3. Instalación y configuración de DNS (BIND9)
4. Instalación y configuración de NTP (Chrony)
5. Instalación y configuración de LDAP (OpenLDAP)
6. Instalación y configuración de Kerberos
7. Integración LDAP-Kerberos
8. Configuración de NSS y PAM

#### Paso 4: Verificar la Instalación

```bash
# Verificar servicios activos
systemctl status bind9
systemctl status chrony
systemctl status slapd
systemctl status krb5-kdc
systemctl status krb5-admin-server
```

### Parámetros de Configuración

| Parámetro | Valor |
|-----------|-------|
| Dominio | lcoronado.com |
| Realm Kerberos | LCORONADO.COM |
| Base DN LDAP | dc=lcoronado,dc=com |
| FQDN Servidor | krb5.lcoronado.com |
| IP Servidor | 172.27.133.157 |
| Admin LDAP | cn=admin,dc=lcoronado,dc=com |
| Contraseña LDAP | admin |
| Admin Kerberos | admin/admin@LCORONADO.COM |
| Contraseña Kerberos | admin |

### Usuarios Preconfigurados

| Usuario | UID | Nombre Completo | Rol | Email |
|---------|-----|----------------|-----|-------|
| lcoronado | 1000 | Luis Coronado | Administrador | lcoronado@lcoronado.com |
| emafla | 1001 | Enrique Mafla | Profesor | enrique.mafla@epn.edu.ec |

**Contraseña por defecto:** `admin`

---

## ⚙️ Servicios Implementados

### 1. DNS (BIND9)

#### Funcionalidad
- Resolución de nombres para el dominio `lcoronado.com`
- Registros A para hosts
- Registros SRV para Kerberos y LDAP
- Forwarding a DNS públicos (8.8.8.8, 8.8.4.4)

#### Archivo de Zona
```bash
cat /etc/bind/db.lcoronado.com
```

#### Comandos de Prueba
```bash
# Resolver hostname
nslookup krb5.lcoronado.com

# Test de resolución DNS
dig @localhost lcoronado.com
```

### 2. NTP (Chrony)

#### Funcionalidad
- Sincronización con pool NTP público
- Servidor NTP local para la red
- Stratum 10 cuando no hay conexión externa

#### Configuración
```bash
cat /etc/chrony/chrony.conf
```

#### Comandos de Prueba
```bash
# Ver fuentes NTP
chronyc sources

# Ver estado de sincronización
chronyc tracking

# Estadísticas de tiempo
chronyc sourcestats
```

### 3. LDAP (OpenLDAP)

#### Funcionalidad
- Directorio centralizado de usuarios
- Estructura organizacional

#### Estructura del Directorio
```
dc=lcoronado,dc=com
├── ou=People
│   ├── uid=lcoronado
│   └── uid=emafla
└── ou=Groups
    └── cn=users
```

#### Comandos de Prueba
```bash
# Buscar todos los usuarios
ldapsearch -x -b "dc=lcoronado,dc=com"

# Buscar usuario específico
ldapsearch -x -b "dc=lcoronado,dc=com" "(uid=emafla)"

# Autenticación simple
ldapwhoami -x -D "uid=emafla,ou=People,dc=lcoronado,dc=com" -W

# Ver estructura organizacional
ldapsearch -x -b "dc=lcoronado,dc=com" "(objectClass=organizationalUnit)"
```

### 4. Kerberos

#### Funcionalidad
- Autenticación segura mediante tickets
- Single Sign-On (SSO)
- Integración con LDAP vía SASL/GSSAPI

#### Realm y Configuración
- **Realm:** LCORONADO.COM
- **KDC:** krb5.lcoronado.com
- **Admin Server:** krb5.lcoronado.com

#### Comandos de Prueba
```bash
# Obtener ticket de usuario
kinit emafla@LCORONADO.COM
# Contraseña: admin

# Ver tickets activos
klist

# Destruir ticket
kdestroy

# Listar todos los principals (como admin)
sudo kadmin.local -q "listprincs"
```

#### Crear Nuevo Principal
```bash
# Entrar a kadmin
sudo kadmin.local

# Crear principal para usuario
kadmin.local: addprinc usuario@LCORONADO.COM

# Crear principal para servicio
kadmin.local: addprinc -randkey host/servidor.lcoronado.com@LCORONADO.COM

# Salir
kadmin.local: quit
```

### 5. Integración LDAP-Kerberos

#### Características
- Autenticación Kerberos con datos en LDAP
- SASL/GSSAPI para comunicación segura
- Keytab para servicio LDAP

#### Verificar Integración
```bash
# Obtener ticket Kerberos
kinit emafla@LCORONADO.COM

# Buscar en LDAP usando Kerberos
ldapsearch -Y GSSAPI -b "dc=lcoronado,dc=com" "(uid=emafla)"

# Verificar keytab LDAP
sudo klist -k /etc/ldap/ldap.keytab
```
---

## 📁 Estructura del Repositorio

```
servicio-directorio-fis/
├── README.md                          # Este archivo
├── CoronadoL-Proyecto2.sh            # Script de instalación automatizada
├── docs/
│   ├── analisis-requerimientos.md    # Análisis de requerimientos (30%)
│   ├── diseño-sistema.md             # Diseño del sistema (30%)
│   ├── manual-instalacion.md         # Manual detallado de instalación
│   ├── manual-usuario.md             # Guía para usuarios finales
│   └── arquitectura.png              # Diagrama de arquitectura
├── config/
│   ├── dns/
│   │   ├── named.conf.local          # Configuración de zonas DNS
│   │   ├── named.conf.options        # Opciones de BIND9
│   │   └── db.lcoronado.com          # Archivo de zona
│   ├── ntp/
│   │   └── chrony.conf               # Configuración de Chrony
│   ├── ldap/
│   │   ├── base_structure.ldif       # Estructura base del directorio
│   │   ├── users.ldif                # Usuarios de ejemplo
│   │   └── groups.ldif               # Grupos de ejemplo
│   └── kerberos/
│       ├── krb5.conf                 # Configuración del cliente
│       ├── kdc.conf                  # Configuración del KDC
│       └── kadm5.acl                 # ACLs de administración
├── scripts/
│   ├── test-dns.sh                   # Pruebas de DNS
│   ├── test-ntp.sh                   # Pruebas de NTP
│   ├── test-ldap.sh                  # Pruebas de LDAP
│   ├── test-kerberos.sh              # Pruebas de Kerberos
│   ├── test-integration.sh           # Pruebas de integración
│   └── backup-config.sh              # Backup de configuraciones
└── LICENSE                           # Licencia del proyecto
```
---

**Última actualización:** Enero 2026  
**Versión:** 1.0.0