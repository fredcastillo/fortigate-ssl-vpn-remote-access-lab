# Configuraciones exportadas del laboratorio

Fecha de colección: 2026-10-03 UTC. Se consultaron los equipos existentes; no se aplicaron cambios para generar los exports. [Procedencia y hashes](../inventory/configs-provenance.json).

| Equipo | Archivos | Alcance y obtención |
|---|---|---|
| FortiGate-B | [running-config.sanitized.conf](fortigate/running-config.sanitized.conf) | secciones reales de interfaces, rutas, objetos, VIP, políticas, SSL-VPN y usuarios mediante `show` individual, solo lectura |
| R1-CISCO-VPN | [running-config](cisco/R1-CISCO-VPN.running-config.txt) | `show running-config` completo por SSH desde la red del cliente |
| Router-ISP | [running-config](cisco/Router-ISP.running-config.txt) | `show running-config` completo por Telnet desde la red del cliente |
| Switch-A | [running-config](switch/Switch-A.running-config.txt) | `show running-config` completo por consola; VLAN y puertos confirmados en diagnóstico separado |
| Web Server | [directorio server](server/) | archivos de arranque, red, Apache, OpenSSH y parámetros efectivos |
| Cliente VPN | [directorio client](client/) | interfaces, rutas, VPN, compatibilidad TLS, arranque y versiones |
| Browsers | [directorio browsers](browsers/) | red y estado real, diferenciando Users y auxiliar |

Los secretos se sustituyen por `[REDACTED]`. No se incluyen hashes de contraseñas, PSK ni claves privadas. Las copias privadas originales permanecen fuera del ZIP, en un directorio protegido de la VM.

En FortiGate, `show` omite valores predeterminados. Eso no equivale a `show full-configuration`. Un export sanitizado es evidencia documental; no es un backup listo para importar. La configuración y demostración académica del FortiGate se realizan por GUI según [FORTIGATE-GUI.md](../docs/FORTIGATE-GUI.md).

**Alcance del FortiGate:** se incluyen todas las secciones consultadas que implementan los objetivos académicos. No es un export íntegro de todos los subsistemas del appliance. Los intentos de `show` global terminaron paginados antes de alcanzar VPN; se sustituyeron por consultas individuales verificadas, sin rellenar configuración desconocida. Para un backup íntegro adicional, usar Configuration → Backup por GUI.

[network-ssl-vpn.sanitized.conf](fortigate/network-ssl-vpn.sanitized.conf) facilita la lectura de las secciones de red, VIP, políticas, SSL-VPN y usuarios, consultadas individualmente. Los valores efectivos de TCP/10443 y NAT desactivado se verificaron en las consultas de diagnóstico y en las pruebas; los valores predeterminados no aparecen necesariamente en `show`.

Las configuraciones Cisco mantienen los bloques IPsec históricos que existían, con secretos redactados. R1 no tiene crypto map aplicado en Gi1/0 y el diagnóstico no muestra SAs activas. No reactivar esos bloques.

El estado de VLAN está también en [switch-diagnostics.txt](../evidence/switch-diagnostics.txt): VLAN 10 LAN_Usuarios, Gi0/0–Gi0/2 conectados en VLAN 10. Una VLAN almacenada en vlan.dat puede no aparecer como declaración en show running-config.

Las rutas del cliente incluyen ppp0 porque el túnel estaba conectado al exportar. Es estado de ejecución, no una interfaz permanente ni una dirección que deba fijarse manualmente al arrancar.
