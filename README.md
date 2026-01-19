# ServicioDirectorio_FIS
PROYECTO - Servicio Integrado de Directorio y Autenticación para la FIS

# 📘 Configuración Completa del Cliente LDAP + Kerberos (GSSAPI)

Este documento describe **paso a paso** la configuración correcta de un **cliente LDAP autenticado con Kerberos mediante SASL/GSSAPI**, así como comandos de verificación y solución de errores comunes.

---

## 1️⃣ Supuestos Previos (IMPORTANTE)

Antes de aplicar esta configuración, se **asume** que:

* El **KDC Kerberos funciona correctamente**
* El usuario puede obtener ticket con `kinit`
* El realm es **LCORONADO.COM**
* El servidor LDAP es `krb5.lcoronado.com`
* El DIT LDAP es `dc=fis,dc=epn,dc=ec`

**El cliente NO usa keytab**, solo tickets Kerberos.

---

## 2️⃣ Paquetes Necesarios en el Cliente

Instalar obligatoriamente:

```bash
sudo apt update
sudo apt install -y \
  ldap-utils \
  libsasl2-2 \
  libsasl2-modules \
  libsasl2-modules-gssapi-mit
```

Verificación:

```bash
dpkg -l | egrep 'ldap|sasl'
```

Debe aparecer `libsasl2-modules-gssapi-mit`.

---

## 3️⃣ Configuración de Kerberos (Cliente)

### 📄 `/etc/krb5.conf`

```ini
[libdefaults]
 default_realm = LCORONADO.COM
 dns_lookup_realm = false
 dns_lookup_kdc = false
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

Verificación:

```bash
kdestroy
kinit usuario@LCORONADO.COM
klist
```

---

## 4️⃣ Configuración LDAP del Cliente

### 📄 `/etc/ldap/ldap.conf`

```ini
BASE   dc=fis,dc=epn,dc=ec
URI    ldap://krb5.lcoronado.com

SASL_MECH GSSAPI
SASL_REALM LCORONADO.COM
SASL_NOCANON on
```

**Notas importantes**:

* El `URI` debe coincidir con el **principal LDAP del servidor**
* Realm en **mayúsculas**

---

## 5️⃣ Configuración SASL del Cliente

### 📄 `/etc/sasl2/ldap.conf`

```ini
mech_list: gssapi
```

El cliente **NO define keytab aquí**.

---

## 6️⃣ Comandos de Diagnóstico del Cliente

### 🔍 Ver mecanismos SASL disponibles

```bash
saslpluginviewer | grep GSSAPI
```

Debe mostrar:

```
GSSAPI
```

---

### 🔍 Verificar resolución DNS

```bash
getent hosts krb5.lcoronado.com
```

LDAP + Kerberos **NO funcionan con IP directa**.

---

### 🔍 Prueba LDAP sin autenticación (control)

```bash
ldapsearch -x -H ldap://krb5.lcoronado.com -b dc=fis,dc=epn,dc=ec dn
```

✔ Verifica conectividad y slapd

---

### 🔍 Prueba LDAP con Kerberos (principal)

```bash
ldapwhoami -Y GSSAPI -H ldap://krb5.lcoronado.com
```

Salida esperada:

```
dn:uid=usuario,ou=Profesores,ou=dicc,dc=fis,dc=epn,dc=ec
```

---

### 🔍 Búsqueda LDAP autenticada

```bash
ldapsearch -Y GSSAPI \
  -H ldap://krb5.lcoronado.com \
  -b dc=fis,dc=epn,dc=ec uid=usuario
```

---

## 7️⃣ Errores Comunes y Soluciones

| Error                                  | Causa                                   | Solución                                            |
| -------------------------------------- | --------------------------------------- | --------------------------------------------------- |
| `No worthy mechs found`                | Falta módulo GSSAPI                     | Instalar `libsasl2-modules-gssapi-mit`              |
| `Permission denied`                    | Error en `olcAuthzRegexp` o `olcAccess` | Revisar servidor LDAP                               |
| `Server krbtgt/LOCALDOMAIN`            | Realm mal definido                      | Corregir `/etc/krb5.conf`                           |
| Funciona con `-x` pero no con `GSSAPI` | Problema SASL/Kerberos                  | Revisar `/etc/sasl2/ldap.conf`                      |
| `Cannot contact LDAP server`           | DNS o slapd                             | Verificar `getent hosts` y `systemctl status slapd` |

---

## 8️⃣ Conceptos Clave (para no romper la config)

* **El cliente NO usa keytab**
* Solo usa **tickets Kerberos**
* LDAP confía en Kerberos para autenticar
* La autorización (DN final) se decide en el **servidor LDAP**

---

## 9️⃣ Checklist Final

✔ `kinit` funciona
✔ `klist` muestra ticket válido
✔ `ldapsearch -x` funciona
✔ `ldapwhoami -Y GSSAPI` funciona
✔ El DN devuelto existe en LDAP

---

## Estado Final

🎉 **Cliente LDAP + Kerberos correctamente configurado y funcional**

Este archivo puede guardarse como:

```
README-LDAP-KERBEROS-CLIENTE.md
```

y reutilizarse en futuras instalaciones.
