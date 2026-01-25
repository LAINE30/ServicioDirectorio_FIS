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