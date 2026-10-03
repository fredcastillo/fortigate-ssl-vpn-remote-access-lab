# Scripts y procedencia

Todos los scripts persistidos utilizados en la resolución están incluidos. [Manifiesto con origen y hashes](../inventory/scripts-provenance.json). Las operaciones puntuales de consola se documentan en los procedimientos y en los colectores; las credenciales introducidas por stdin no se conservan.

## Originales de la sesión

En [originales/sesion-20261003](originales/sesion-20261003/):

| Script | Función | Ejecución / limitaciones |
|---|---|---|
| download-vpn-only.py | descarga oficial segmentada y verificada | host VM; descarga puede ofrecer otra versión en el futuro |
| install-vpn-only.sh | instala paquete VPN-only validado sobre cliente existente | host VM; exige respaldo y versión 7.4.3.5411 |
| restore-server-ssh.py | respaldo, OpenSSH, labssh y arranque del servidor | host VM; se detiene si el backup ya existe |
| gui-marionette.py | controla Firefox visible mediante GUI | namespace de Browser auxiliar; getpass oculto; no API de configuración del FortiGate |
| web-start-before.sh | arranque original del servidor | procedencia; no ejecutar sobre nodo activo |
| web-start-with-ssh.sh | arranque del servidor después de restaurar SSH | se ejecuta al iniciar el nodo |
| lab-vpn | conecta, comprueba y desconecta el túnel real | dentro del cliente, root para conectar/desconectar PPP |

Los originales conservan rutas y UUID de esta práctica. El helper final también se exportó en [configs/client/lab-vpn](../configs/client/lab-vpn).

## Operación y documentación

- [console-read.py](documentacion/console-read.py): consultas show/get por consola o Telnet, credenciales por prompt oculto.
- [ssh-read.py](documentacion/ssh-read.py): show por SSH desde namespace de red del cliente.
- [sanitize.py](documentacion/sanitize.py): redacción de exports antes de publicar.
- [collect-nodes.py](documentacion/collect-nodes.py): configuración y estado de contenedores actuales, sin reconfigurarlos.
- [render-evidence.py](documentacion/render-evidence.py): imagen SVG de la transcripción real JSON.
- [check-delivery.py](documentacion/check-delivery.py): enlaces, sintaxis y exclusiones documentales.
- [verify-connected.sh](operacion/verify-connected.sh): repite la validación positiva desde el cliente, sin desconectar la VPN.

Los SVG tienen sus fuentes editables en assets/; los diagramas también incluyen fuentes Mermaid. La consola del FortiGate se utilizó únicamente para lectura documental y no forma parte del video de demostración.

## Antecedentes encontrados

[originales/antecedentes](originales/antecedentes/) contiene archivos de construcción del cliente, Browser, web y DB, además de scripts de recuperación anteriores. Se incluyen para no perder los antecedentes existentes, pero **no se ejecutaron en la solución final de esta sesión**.

Algunos contienen recreaciones de infraestructura, borrados de carpetas de trabajo o supuestos antiguos. Son archivos históricos, no la secuencia recomendada. Las credenciales de aplicación se redactaron donde existían. No ejecutar todos los scripts del repositorio en bloque. El servidor DB es un antecedente de aplicación, no un requisito ni un componente recreado para esta práctica.

No se incluyen paquetes propietarios ni imágenes Docker dentro de Git. Sus metadatos y hashes están en inventory/.
