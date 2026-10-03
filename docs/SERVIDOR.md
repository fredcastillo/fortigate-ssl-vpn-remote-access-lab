# Servidor web y SSH

Servidor existente: 10.21.75.130/28, gateway 10.21.75.129. Apache atiende HTTPS TCP/443. El VIP del FortiGate publica exclusivamente 203.0.113.26:443 → 10.21.75.130:443.

Después de una recreación del contenedor se constató que OpenSSH y labssh no estaban presentes en la imagen original. Se hizo un snapshot previo, se instalaron los paquetes OpenSSH ya descargados y se creó labssh. Se generó una clave Ed25519 del cliente y se autorizó su clave pública en el servidor. La clave privada permanece en el nodo; no está incluida en el repositorio.

La clave de host del servidor se incorporó a known_hosts del cliente para verificar la identidad SSH. No se desactivó esa comprobación. La autenticación SSH demostrada es por clave, no por una contraseña publicada.

El script `/start-network.sh` conserva la red y el inicio de Apache. Se añadió la creación de /run/sshd, `sshd -t` y el inicio de sshd. [Script final](../configs/server/start-network.sh). No ejecutar el script completo sobre un nodo en uso: contiene el arranque original que aplica su dirección a eth0.

## Configuración exportada

[configs/server](../configs/server/) contiene interfaces, rutas, puertos en escucha, sshd_config, parámetros efectivos obtenidos con `sshd -T`, virtual hosts Apache y versiones instaladas. No contiene claves privadas SSH, claves del certificado HTTPS ni credenciales de base de datos.

Los scripts antiguos de construcción del servidor incluían componentes de aplicación/DB de otro alcance. Se conservan como antecedentes sanitizados en scripts/originales, pero la solución académica actual no reconstruye Apache ni una base de datos.

## Prueba dentro del servidor

Desde el cliente con túnel activo:

```sh
su - vpnuser -c 'ssh -o ConnectTimeout=5 labssh@10.21.75.130'
```

Dentro de SSH:

```sh
whoami
hostname
echo "$SSH_CONNECTION"
exit
```

El primer campo de SSH_CONNECTION es el origen. En la evidencia se observa 10.212.134.200; el último campo es el puerto 22 del servidor. Esto prueba que la sesión autenticada llega desde el túnel, conservando su dirección.
