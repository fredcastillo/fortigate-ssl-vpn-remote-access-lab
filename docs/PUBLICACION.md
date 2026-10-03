# Publicar la entrega en GitHub

La entrega se preparó como carpeta y ZIP dentro de la GNS3 VM a petición del usuario. No se publicó automáticamente en un repositorio remoto.

1. Copiar el ZIP y extraerlo. La carpeta raíz es Seguridad-de-Redes-SSLVPN-GNS3.
2. Crear en GitHub un repositorio con nombre sugerido `seguridad-redes-https-ssh-ssl-vpn-gns3` y descripción: «Laboratorio GNS3: HTTPS público y administración SSH autenticada por SSL-VPN, con FortiGate GUI, Cisco, scripts y evidencias».
3. Subir el contenido de la carpeta raíz, conservando su estructura. Para Git CLI:

```sh
git init -b main
git add .
git commit -m 'Documentar laboratorio HTTPS público y SSH mediante SSL-VPN'
git remote add origin https://github.com/TU_USUARIO/seguridad-redes-https-ssh-ssl-vpn-gns3.git
git push -u origin main
```

La autenticación se hace por el método habitual de GitHub; no escribir tokens en archivos del repositorio. Si ya se inicializó Git o existe un remote, consultar su estado antes de repetir estos comandos. [Guía oficial de GitHub](https://docs.github.com/en/migrations/importing-source-code/using-the-command-line-to-import-source-code/adding-locally-hosted-code-to-github).

4. Grabar el video siguiendo [GUION-5m40s.md](../video/GUION-5m40s.md). Subirlo a una plataforma accesible para el docente y conservar un enlace real.
5. En la sección inicial del README sustituir el estado pendiente y la portada por un enlace al video. Ejemplo, reemplazando URL_REAL por el enlace obtenido:

```md
[![Ver demostración — 5:40](assets/images/portada-video.svg)](URL_REAL)
```

GitHub renderiza el diagrama Mermaid y las imágenes locales del README. Mantener assets/ en el repositorio para conservar los enlaces.

## Verificación local

```sh
python3 scripts/documentacion/check-delivery.py
```

La revisión comprueba enlaces locales, archivos esperados, sintaxis de scripts y ausencia de claves privadas y paquetes/discos excluidos. Revisa también los avisos de procedencia de configs y scripts. No sustituye la demostración del laboratorio.
