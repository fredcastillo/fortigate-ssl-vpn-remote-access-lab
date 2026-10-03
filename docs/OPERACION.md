# Operación, reproducción y respaldo

## Prerrequisitos

GNS3 2.2.61 y Docker 29.6.2 fueron observados en la VM Ubuntu; el cliente y servidor usan Ubuntu 22.04 en sus contenedores. Se necesitan imágenes/licencias propias de FortiGate y Cisco. No se redistribuyen en GitHub.

La reproducción parte de los nodos existentes o de nodos equivalentes conectados según [RED.md](RED.md). No se incluye un `.gns3` inventado: el archivo del proyecto reside en el controlador externo y no fue obtenido de la VM. Crear o exportar un proyecto portable desde el controlador es una actividad adicional, diferente de este repositorio documental.

## Recuperación realizada

1. Inspección de host, Docker, redes de contenedores, usuarios, procesos y paquetes.
2. Snapshot del cliente y volumen de interfaces antes de sustituir FortiClient.
3. Descarga oficial verificada y actualización a VPN-only, conservando el resto del nodo.
4. Diagnóstico TLS tras el fallo del cliente válido; instalación de openfortivpn/PPP y configuración local de compatibilidad.
5. Snapshot del servidor y restauración de OpenSSH con arranque permanente.
6. Verificación sin VPN desde Usuarios y con VPN desde el cliente.
7. Captura de SSL-VPN Monitor por GUI, cierre de sesión administrativa y retiro de IP auxiliar temporal.
8. Commit de imágenes corregidas y conservación de originales bajo etiquetas de backup.

## Imágenes finales

| Función | Imagen final | Etiqueta referenciada por el proyecto |
|---|---|---|
| Cliente | forticlient-vpn-lab:tls10-ready | forticlient-lite:7.2-fix3 |
| Servidor | web-server-lab:ssh-enabled | web-server-lab:latest |

El nombre histórico `7.2-fix3` no refleja la versión instalada actual. GNS3 sigue usando la etiqueta existente y los cambios permanecen al recrear el contenedor. Un commit Docker guarda archivos, no procesos activos, interfaces PPP ni una sesión VPN; después de un reinicio se conecta manualmente con `lab-vpn connect`.

[Identificadores y backups](../inventory/images-final.json). Para revertir únicamente las referencias de futuras creaciones, desde el host GNS3 VM:

```sh
docker tag lab-backup/client-image-original:20261003 forticlient-lite:7.2-fix3
docker tag lab-backup/web-image-original:20261003 web-server-lab:latest
```

No borrar imágenes, proyectos o contenedores. Revertir etiquetas no modifica los nodos que ya están ejecutándose.

## Scripts

Los [originales](../scripts/README.md) incluyen scripts con rutas y UUID de esta sesión y condiciones que evitan repetir una instalación sobre un estado desconocido. Son procedencia de la solución, no un instalador universal. Los scripts históricos encontrados pero no ejecutados se identifican explícitamente y no deben lanzarse como recuperación masiva.

Los instaladores esperan paquetes en rutas concretas. Los paquetes quedan fuera del ZIP; [metadatos](../inventory/README.md) permiten saber cuáles se usaron. La descarga oficial puede cambiar de versión con el tiempo: `install-vpn-only.sh` exige 7.4.3.5411 para reproducir esta sesión y se detendrá ante otro paquete.

## Límites documentados

El FortiGate de evaluación y su compatibilidad TLS no se rediseñaron. El Browser auxiliar conserva su dirección original. La advertencia de comprobación de filesystem tras el reinicio no se usó para provocar una reparación o reinicio durante la práctica. Estos asuntos no impiden los escenarios comprobados, pero no deben confundirse con un entorno definitivo de producción.
