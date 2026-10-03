# FortiGate: configuración y demostración por GUI

FortiOS observado: 7.0.9 build0444, FortiGate-VM64-KVM. La consulta de configuración por consola para documentación es de lectura. **En el video, toda la configuración y demostración del FortiGate se muestra por GUI. No abrir su consola CLI.** Los pasos siguientes son para revisar la configuración existente; no es necesario guardar cambios para grabar.

## Acceso administrativo

Usar el Browser auxiliar conectado a port5 y abrir `http://20.21.75.1`. La sesión autenticada y las claves no deben aparecer en la grabación. Este HTTP es el acceso administrativo auxiliar que ya existía en el laboratorio; no es el HTTPS público del servidor.

Si el Browser auxiliar aún tiene únicamente su dirección original, se puede usar la IP secundaria temporal autorizada según [preparación](../video/PREPARACION.md), retirándola después. No modificar los gateways ni direcciones permanentes.

## Interfaces y ruta

1. **Network → Interfaces**: mostrar port1 203.0.113.26/30, port2 10.21.75.129/28 y port5 20.21.75.1/24. Abrir la interfaz para leer sus campos y cerrar sin aplicar cambios.
2. **Network → Static Routes**: mostrar la ruta existente hacia el ISP. Comparar con el export; no crear rutas nuevas.

## Objetos y HTTPS público

1. **Policy & Objects → Addresses**: mostrar WEBSERVER, dirección 10.21.75.130/32.
2. **Policy & Objects → Virtual IPs**: abrir el VIP HTTPS existente. Comprobar externo 203.0.113.26 TCP/443 y destino 10.21.75.130 TCP/443. El nombre del VIP puede diferir; localizarlo por esos campos.
3. **Policy & Objects → Firewall Policy**: abrir la política WAN → port2 cuyo destino es el VIP, servicio HTTPS, acción ACCEPT y NAT desactivado. La traducción de destino la realiza el VIP; no añadir SNAT.

## SSL-VPN, portal y autenticación

1. **VPN → SSL-VPN Settings**: interfaz port1, puerto 10443, certificado Fortinet_Factory, pool SSLVPN_TUNNEL_ADDR1 y regla del grupo SSLVPN_USERS hacia REMOTE_ACCESS.
2. **VPN → SSL-VPN Portals**: abrir REMOTE_ACCESS. Mostrar Tunnel Mode habilitado y split tunneling basado en destinos de políticas.
3. **User & Authentication → User Groups**: mostrar SSLVPN_USERS y la pertenencia de vpnuser. No editar ni revelar la contraseña.
4. **Policy & Objects → Firewall Policy**: abrir la política existente `SLVPN_to_WEBSERVER_SSH` —nombre observado, con una sola S inicial—: incoming ssl.root, outgoing port2, destino WEBSERVER, grupo SSLVPN_USERS, servicio SSH, ACCEPT, NAT desactivado.

No existe una publicación SSH requerida en WAN. La demostración verifica acceso privado mediante el túnel; no crear VIP ni política pública para TCP/22.

## Sesión activa por GUI

**Dashboard → Network → widget SSL-VPN → expandir**. En la instancia observada la vista expandida es `/ng/system/dashboard/3?zoomedWidget=5`. Los IDs de dashboard/widget pueden variar; navegar por el menú es preferible a asumir el mismo ID.

Debe aparecer vpnuser, un túnel conectado y un usuario activo. El host remoto 203.0.113.21 es el origen tras NAT de Cisco. La dirección asignada 10.212.134.200 se comprueba en el cliente y en SSH; no confundirla con el host remoto.

![Captura auténtica del monitor](../assets/images/fortigate-ssl-vpn-monitor.png)

## Exportar configuración desde GUI

Menú superior del administrador → **Configuration → Backup** → destino local → descargar. Conservar una copia privada íntegra fuera del repositorio y publicar únicamente una copia sanitizada. Según el idioma/versión, los rótulos del menú pueden variar. No usar Restore para documentar.

Los exports presentes tienen su procedencia y alcance declarados en [configs/README.md](../configs/README.md). Un extracto no debe presentarse como backup completo, y un archivo redactado requiere reintroducir credenciales antes de una restauración.
