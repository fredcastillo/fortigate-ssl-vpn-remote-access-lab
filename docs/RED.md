# Red y direccionamiento

## Recorrido del tráfico

Usuarios → Switch-A VLAN 10 → R1-CISCO-VPN → Router-ISP → FortiGate-B → servidor. El Browser-PC-1 pertenece a Usuarios. browser-2 es auxiliar y está conectado a port5; su dirección inicial coincide con la del Browser de Usuarios, pero están en segmentos diferentes. No elegir el nodo de pruebas solo por la dirección.

| Segmento | Red / máscara | Hosts utilizables | Broadcast | Uso |
|---|---|---|---|---|
| Usuarios | 10.21.75.0/25 — 255.255.255.128 | .1–.126 | 10.21.75.127 | VLAN 10, DHCP |
| Servidor | 10.21.75.128/28 — 255.255.255.240 | .129–.142 | 10.21.75.143 | HTTPS y SSH |
| R1–ISP | 203.0.113.20/30 — 255.255.255.252 | .21–.22 | 203.0.113.23 | WAN de Usuarios |
| ISP–FortiGate | 203.0.113.24/30 — 255.255.255.252 | .25–.26 | 203.0.113.27 | WAN del FortiGate |
| Auxiliar | 20.21.75.0/24 | port5 20.21.75.1 | 20.21.75.255 | GUI administrativa del laboratorio |
| Pool SSL-VPN | 10.212.134.200–10.212.134.210 | 11 direcciones del pool | no aplica | direcciones asignadas al túnel |

| Equipo | Interfaz / dirección | Función |
|---|---|---|
| Cliente VPN | eth0 10.21.75.10/25 | dirección recibida por DHCP |
| Browser-PC-1 | eth0 10.21.75.110/25 | pruebas del usuario sin VPN |
| R1-CISCO-VPN | Gi2/0 10.21.75.1/25 | gateway de Usuarios, NAT inside |
| R1-CISCO-VPN | Gi1/0 203.0.113.21/30 | NAT outside |
| Router-ISP | Gi1/0 203.0.113.22/30; Gi2/0 203.0.113.25/30 | tránsito simulado |
| FortiGate-B | port1 203.0.113.26/30 | VIP HTTPS y endpoint SSL-VPN |
| FortiGate-B | port2 10.21.75.129/28 | gateway del servidor |
| FortiGate-B | port5 20.21.75.1/24 | administración auxiliar |
| Web Server | eth0 10.21.75.130/28 | gateway 10.21.75.129 |
| GNS3 VM | 192.168.232.130 | gestión del host, fuera de la topología |

## NAT y rutas

En R1 la ACL NAT-USERS excluye 10.21.75.0/25 → 10.21.75.128/28 y permite el resto del origen Usuarios. `ip nat inside source list NAT-USERS interface GigabitEthernet1/0 overload` traduce las conexiones públicas al origen 203.0.113.21. La ruta por defecto de R1 usa 203.0.113.22.

La exclusión de NAT no concede acceso SSH: las rutas y la política del FortiGate determinan qué tráfico llega al servidor. La sesión VPN vista en la GUI muestra como host remoto 203.0.113.21 por el NAT de R1. Una vez dentro del túnel, la política SSL-VPN sin NAT conserva el origen 10.212.134.200 hasta SSH.

El cliente conectado mantiene eth0 y su ruta por defecto. Añade una ruta de destino 10.21.75.130 por ppp0; la conexión al endpoint VPN sigue por 10.21.75.1. El servidor devuelve tráfico del pool a través de 10.21.75.129.

## VLAN y DHCP

La VLAN 10, llamada LAN_Usuarios, está en Switch-A con Gi0/0, Gi0/1 y Gi0/2 en modo access y conectados. R1 tiene el pool VLAN10-USERS para 10.21.75.0/25, gateway 10.21.75.1 y DNS 8.8.8.8. Excluye .1–.9 y .101–.126; el rango disponible es .10–.100. La asignación comprobada del cliente es 10.21.75.10/25. Estos datos provienen del running-config y del diagnóstico real, no de una inferencia basada únicamente en una concesión.

La existencia de interfaces libres o configuraciones IPsec históricas no indica un túnel activo. La deshabilitación anterior retiró el crypto map de Gi1/0. No reactivarlo para esta práctica.

## Direcciones públicas simuladas

203.0.113.0/24 es [TEST-NET-3](https://www.iana.org/assignments/iana-ipv4-special-registry/iana-ipv4-special-registry.xhtml). Aquí representa el ISP y la publicación externa dentro de GNS3. 20.21.75.0/24 se conserva porque es el direccionamiento existente de administración; tampoco implica que el laboratorio utilice o posea ese bloque en Internet.
