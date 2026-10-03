# Inventario, versiones y procedencia

- [nodes.json](nodes.json): contenedores existentes, roles, imágenes y arranque al exportar.
- [images-final.json](images-final.json): imágenes finales y backups conservados en la VM.
- [configs-provenance.json](configs-provenance.json): obtención, alcance y hashes de los exports.
- [scripts-provenance.json](scripts-provenance.json): origen, uso y hashes de scripts originales/históricos.
- [download.json](download.json): URL oficial, tamaño y SHA-256 del paquete FortiClient VPN-only 7.4.3.5411.
- [openfortivpn-package-sources.json](openfortivpn-package-sources.json): paquetes Ubuntu de openfortivpn, PPP y libpcap.

GNS3 observado: 2.2.61. Docker: 29.6.2. FortiOS: 7.0.9 build0444. Client/server Ubuntu 22.04. Las versiones concretas de paquetes de los nodos están en configs/client/packages.txt y configs/server/packages.txt. Los identificadores de contenedor sirven como evidencia de esta sesión; no deben fijarse como IDs para futuras recreaciones.

No se redistribuyen imágenes FortiGate/Cisco, paquetes FortiClient, certificados privados, contraseñas ni claves SSH privadas. Las claves públicas utilizadas para autenticación tampoco se necesitan para entender la práctica; cada reproducción debe gestionar sus propias claves.

SHA256SUMS.txt en la raíz verifica la integridad de los archivos de la entrega. Los hashes son control de integridad de esta colección, no firmas de confianza de un fabricante.
