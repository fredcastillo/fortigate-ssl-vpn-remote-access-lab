# Validación del objetivo de seguridad

## Puntos de origen

Las pruebas deben ejecutarse desde Usuarios: Browser-PC-1 o CLIENTE-FORTICLIENT. No usar el host GNS3 VM como si fuera un usuario de la VLAN 10. `docker exec` abre un proceso dentro del nodo; el host solo administra Docker. Para herramientas ausentes en el Browser se usó un intérprete del host dentro del namespace de red del nodo, registrado explícitamente en las evidencias.

## Sin VPN

En el Browser de Usuarios, abrir por GUI `https://203.0.113.26`. Debe verse la página del servidor. En el video usar el Browser para mostrar la página, aunque la evidencia automatizada también registra HTTP 200.

Para repetir SSH desde CLIENTE-FORTICLIENT, primero comprobar que está desconectado; durante la preparación del video se puede cerrar su túnel. Dentro del cliente:

```sh
lab-vpn status
ip -br -4 addr
su - vpnuser -c 'ssh -o BatchMode=yes -o ConnectTimeout=5 labssh@10.21.75.130'
```

Se espera DISCONNECTED y timeout de SSH. `Permission denied` indicaría que el puerto fue alcanzado y falló la autenticación: no es la evidencia negativa de aislamiento esperada. La prueba histórica sin VPN de este repositorio fue TCP/22 desde Browser-PC-1 y agotó el tiempo de espera.

## Con VPN

Conectar desde otra consola del cliente mediante `lab-vpn connect`; introducir la contraseña en el prompt oculto. Después:

```sh
lab-vpn status
ip -br -4 addr show ppp0
ip route get 10.21.75.130
su - vpnuser -c 'ssh -o BatchMode=yes -o ConnectTimeout=5 labssh@10.21.75.130'
```

Debe haber una dirección del pool 10.212.134.200–210 y una ruta por ppp0. Dentro de SSH ejecutar `echo "$SSH_CONNECTION"`; el origen esperado es la dirección del pool cuando NAT está desactivado.

En el cliente, después de salir de SSH:

```sh
traceroute -T -p 22 -n -q 1 -w 2 10.21.75.130
```

El resultado verificado llegó al destino en el segundo salto; el primero fue `*`. No abrir ICMP/UDP adicional para modificar esa apariencia.

## FortiGate

Mostrar por **GUI** la sesión vpnuser en Dashboard → Network → SSL-VPN. Mostrar también el servicio SSH de la política ssl.root → port2 y el servicio HTTPS de la política que publica el VIP. [Pasos completos](FORTIGATE-GUI.md).

## Interpretación

La práctica confirma dos vías de acceso: HTTPS público mediante VIP y SSH privado después de autenticación SSL-VPN. Una VPN conectada sin SSH autenticado no basta, y un timeout sin un servicio sshd en funcionamiento tampoco basta. Las evidencias incluyen SSH positivo para demostrar que el servicio existe.

No se realizó una auditoría de todas las combinaciones posibles de tráfico. La afirmación comprobada se limita a los escenarios exigidos: sin VPN, HTTPS sí y SSH privado no; con VPN, SSH sí y sesión activa visible por GUI.
