# Cliente SSL-VPN y compatibilidad

## Estado encontrado y solución

El FortiClient completo 7.2.15.1053 estaba bloqueado por trial vencido. El paquete VPN-only 7.0.9 esperado por un script anterior no existía en /home/gns3. Se respaldó el contenedor, se obtuvo el paquete VPN-only oficial 7.4.3.5411 y se instaló sobre el cliente existente. No se borraron licencias ni se alteraron fechas o ejecutables.

FortiClient VPN-only se probó como vpnuser. La conexión produjo `tlsv1 alert protocol version`. Entonces se comprobó TLS desde la red del cliente: la combinación aceptada fue TLSv1 y ECDHE-RSA-AES256-SHA. Un archivo OPENSSL_CONF de compatibilidad no resolvió la negociación del FortiClient instalado.

Se instaló openfortivpn 1.17.1, ppp 2.4.9 y libpcap desde paquetes Ubuntu oficiales, manteniendo el mismo nodo y red. La conexión autenticó a vpnuser y recibió 10.212.134.200. El nombre de GNS3 del nodo no cambia: CLIENTE-FORTICLIENT.

## Configuración funcional

[lab.conf](../configs/client/lab.conf) especifica endpoint 203.0.113.26:10443, vpnuser, certificado fijado por SHA-256, mínimo TLS 1.0, cipher-list restringida y ninguna modificación DNS. [lab-tls.cnf](../configs/client/lab-tls.cnf) es la compatibilidad aplicada solamente al proceso de openfortivpn.

Huella observada del endpoint:

```text
286efc05555bc05560acbbb14928b35b93b7da0e6a47e1a6701bc983704f1190
```

En una reproducción con otro FortiGate, obtener y verificar su certificado por un canal administrativo antes de reemplazar esta huella; no copiarla a ciegas ni desactivar la validación.

## Comandos dentro del nodo

Como root del nodo —PPP requiere privilegios—:

```sh
lab-vpn status
lab-vpn connect
```

La conexión solicita la contraseña sin guardarla y permanece en primer plano. Abrir otra consola para pruebas. Para terminar, `lab-vpn disconnect`. La contraseña no está en el repositorio. Los comandos de **FortiClient**, a diferencia de openfortivpn/PPP, deben ejecutarse como vpnuser:

```sh
su - vpnuser -c 'forticlient vpn status'
```

Ese último comando no informa del túnel openfortivpn. El indicador funcional de esta práctica es `lab-vpn status`, la dirección ppp0 y la sesión en la GUI del FortiGate.

## Rutas, NAT y permisos

La ruta privada a 10.21.75.130 se instala por ppp0. La política ssl.root → port2 acepta solo SSH al objeto WEBSERVER para SSLVPN_USERS y no aplica NAT. El servidor observó como origen la IP del pool, no 203.0.113.21.

El split tunnel se limita a los destinos autorizados. Usar traceroute TCP con puerto 22, porque un traceroute UDP o ICMP no está autorizado por esa política. Un `*` intermedio no invalida la llegada al destino.

## Fuentes y límites

- [VPN-only oficial de Fortinet](https://www.fortinet.com/support/product-downloads).
- [Proyecto openfortivpn y opciones](https://github.com/adrienverge/openfortivpn).
- [Archivo de configuración OpenSSL](https://docs.openssl.org/master/man5/config/).

No se atribuye la limitación TLS a una licencia concreta sin evidencia adicional. El dato demostrado es el protocolo que aceptó este endpoint. La compatibilidad es para esta práctica aislada y no se recomienda como perfil criptográfico de producción.
