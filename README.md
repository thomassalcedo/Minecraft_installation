# Minecraft_installation
This script automatically install a minecraft server for you.
/!\ It works only on Debian based system

- It will create an user
- Install java
- Download spigot server
- Install some plugins if you want it to be compatible with Bedrock edition
- Modify the server's ports if you want some custom
- Enable trafic through iptables firewall
- Create a service and enable it

## Manual
sudo ./minecraft_server_install.sh install [options]
Options:
  -h, --help                    : Display this help message
  -u, --user {value}            : Set the default username (default is "minecraft")
  -p, --password {value}        : Set the password for the user (default is "minecraft")
  --bedrock-compatible          : To define if the serveur should be accessible for the bedrock client
  --minecraft-version {value}   : Set the minecraft server version (default is "latest")
  --java-version {value}        : Set the java version if not installed (default is ...)
  --java-port {value}           : Set the port for the java server (default is "25565")
  --bedrock-port {value}        : Set the port for the bedrock server (default is "19132")

