#!/bin/bash
# set -x

# Check if apt is not lock !

# Default variables
user="minecraft"
password="minecraft"
bedrock_compatible=false
minecraft_version="latest"
java_version="19"
java_port="25565"
bedrock_port="19132"

# Regex
re_username="^[a-zA-Z0-9_\-\.]+$"
re_digit="^[0-9]+$"
re_version="^[0-9]+([.][0-9]+)*$"


function usage {
    echo "##############################################################"
    echo "A tool to install and update minecraft server based on spigot."
    echo "Works on Debian system"
    echo "--------------------------------------------------------------"
    echo "To install a new minecraft server :"
    echo "sudo ./minecraft_server_install.sh install [options]"
    echo "Options:"
    echo "  -h, --help                    : Display this help message"
    echo "  -u, --user {value}            : Set the default username (default is \"minecraft\")"
    echo "  -p, --password {value}        : Set the password for the user (default is \"minecraft\")"
    echo "  --bedrock-compatible          : To define if the serveur should be accessible for the bedrock client"
    echo "  --minecraft-version {value}   : Set the minecraft server version (default is \"latest\")"
    echo "  --java-version {value}        : Set the java version if not installed (default is ...)"
    echo "  --java-port {value}           : Set the port for the java server (default is \"25565\")"
    echo "  --bedrock-port {value}        : Set the port for the bedrock server (default is \"19132\")"
}

function start_and_stop_server {
    pushd "/home/$user/Minecraft_server" > /dev/null
    startup_path="/home/$user/Minecraft_server/server_startup.log"
    echo "[*] Start the server ..."
    java -Xms1G -Xmx2G -jar $spigot_file_name nogui 2>&1 > $startup_path &
    sleep 1
    pid=$!
    until tail $startup_path | grep -q "For help, type \"help\""
    do
        sleep 5
    done
    echo "[+] Server started"
    echo "[*] Killing the server ..."
    kill -SIGKILL $pid
    echo "[+] Done"
    rm $startup_path
    popd > /dev/null
}


if ! [[ $(id -u) == 0 ]]; then
    echo '[-] Error: You need to run me as root.' >&2
    exit 127
fi


# Check if at least 1 parameter is given
if [ $# -lt 1 ]; then
    usage
    exit 3
fi

# Check and set the parameters
case $1 in
    install)
        shift 1
        while [[ $# -ge 1 ]]; do
            case $1 in
                -h | --help)
                    usage
                    exit 0;;

                -u | --user)
                    if ! [[ "$2" =~ $re_username ]]; then
                        echo "[-] Error: The username is incorrect $2" >&2
                        exit 2
                    fi
                    user="$2"
                    shift 2;;

                -p | --password)
                    password="$2"
                    shift 2;;

                --bedrock-compatible)
                    bedrock_compatible=true
                    shift 1;;

                --minecraft-version)
                    if [[ "$2" =~ $re_version ]]; then
                        minecraft_version="$2"
                        shift 2
                    else
                        echo "[-] Error: incorrect value '$2' for '$1'" >&2
                        exit 2
                    fi;;

                --java-version)
                    if [[ "$2" =~ $re_version ]]; then
                        minecraft_version="$2"
                        shift 2
                    else
                        echo "[-] Error: incorrect value '$2' for '$1'" >&2
                        exit 2
                    fi;;

                --java-port)
                    if [[ "$2" =~ $re_digit ]]; then
                        java_port="$2"
                        shift 2
                    else
                        echo "[-] Error: incorrect value '$2' for '$1'" >&2
                        exit 2
                    fi;;

                --bedrock-port)
                    if [[ "$2" =~ $re_digit ]]; then
                        bedrock_port="$2"
                        shift 2
                    else
                        echo "[-] Error: incorrect value '$2' for '$1'" >&2
                        exit 2
                    fi;;

                *)
                    echo "[-] Error: Unknown option $1" >&2
                    usage
                    exit 1
            esac
        done;;
    
    *)
        usage
        exit 1;;
esac

# echo "User:$user"
# echo "Password:$password"
# echo "Bedrock compatible:$bedrock_compatible"
# echo "Minecraft version:$minecraft_version"
# echo "java version:$java_version"
# echo "Java port:$java_port"
# echo "Bedrock port:$bedrock_port"
# echo && echo "Success"

# Check if user if created
if ! grep -q "^$user:" /etc/passwd; then
    echo "[*] User $user no exists"
    # Check if perl is installed
    if [[ -z $(which perl) ]]; then
        echo "[*] Installing perl ..."
        apt-get install -y perl 2>&1 > /dev/null
        echo "[+] Done"
    fi
    pass_hash=$(perl -e 'print crypt($ARGV[0], "password")' $password)
    useradd -m -p "$pass_hash" "$user"
    echo "[+] User $user created !"
else
    echo "[+] User $user already exists !"
fi

# Check if java is installed
if [[ -z $(which java) ]]; then
    echo "[*] Java is not installed"
    if [[ -z $java_version ]]; then
        echo "[*] Installing the default-jre-headless ..."
        apt-get install -y default-jre-headless 2>&1 > /dev/null
        echo "[+] Done, java version is $(java --version)"
    else
        echo "[*] Installing openjdk-${java_version}-jre-headless ..."
        apt-get install -y openjdk-${java_version}-jre-headless 2>&1 > /dev/null
        echo "[+] Done"
    fi
else
    echo "[+] Java is already installed (version $(java --version)). If you another version of Java, you should upgrade it"
fi


# Create the good folder
mkdir -p /home/$user/Minecraft_server -v
cd /home/$user/Minecraft_server

# Download the server installer
echo "[*] Download the server installer ..."
curl -s -o BuildTools.jar https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar
echo "[+] Done"

# Install the good version of spigot
echo "[*] Installing the server ..."
java -jar BuildTools.jar --rev $minecraft_version
if [ $? -ne 0 ]; then 
    echo "[-] Error: This version doesn't exists ($minecraft_version) ..."  >&2
    exit 4
fi
echo "[+] Done"

spigot_file_name=$(ls spigot*)
echo "[*] ${spigot_file_name}"

# Launch the server one time and stop it when files are generated
echo "[*] Launching the server until files are genereted"
java -Xms1G -Xmx2G -jar $spigot_file_name nogui 2>&1 > /dev/null &
until [ -f eula.txt ]
do 
    sleep 5
done
echo "[+] Done"

# Accept the eula
echo "[*] Accept the eula terms ..."
sed -i "s/eula=false/eula=true/" eula.txt
echo "[+] Done"

# Restart the server
start_and_stop_server

if [ $bedrock_compatible ]; then
    pushd plugins
    echo "[*] Installing geyser plugin ..."
    wget https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot
    mv spigot geyser-spigot.jar
    echo "[+] Done"
    echo "[*] Installing floodgate plugin ..."
    wget https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot
    mv spigot floodgate-spigot.jar
    echo "[+] Done"
    popd

    # Restart server
    start_and_stop_server

    # Copy the key
    cp /home/$user/Minecraft_server/plugins/floodgate/key.pem /home/$user/Minecraft_server/plugins/Geyser-Spigot/
fi

# Modification of server-port value
if [ $java_port != "25565" ]; then
    echo "[*] Update the config with the custom java port ..."
    sed -i "s/^server-port=.*/server-port=$java_port/" server.properties
    echo "[+] Done"
fi
if [[ $bedrock_compatible && $bedrock_port != "19132" ]]; then
    echo "[*] Update the config with the custom bedrock port ..."
    sed -i "s/port: 19132/port: $bedrock_port/" plugins/Geyser-Spigot/config.yml
    echo "[+] Done"
fi

# Create start.sh
echo "[*] Create start.sh file ..."
cat <<EOF > /home/$user/Minecraft_server/start.sh
#!/bin/bash

/usr/bin/java -Xms1G -Xmx2G -jar /home/$user/Minecraft_server/$spigot_file_name nogui
EOF


chmod u+x start.sh
echo "[+] Done"

# Own the server directory by the user
chown -R $user:$user /home/$user/Minecraft_server

# Firewall opening
echo "[*] Allowing $java_port port in the firewall"
iptables -I INPUT -p tcp --dport $java_port -j ACCEPT -m comment --comment "Minecraft java server"
if [ $bedrock_compatible ]; then
    echo "[*] Allowing $bedrock_port port in the firewall"
    iptables -I INPUT -p tcp --dport $bedrock_port -j ACCEPT -m comment --comment "Minecraft bedrock server"
    iptables -I INPUT -p udp --dport $bedrock_port -j ACCEPT -m comment --comment "Minecraft bedrock server"
fi

# Create service file if not exists
echo "[+] Create the service file"
cat <<EOF > /etc/systemd/system/minecraft@.service
[Unit]
Description=Minecraft server of %I
After=local-fs.target network.target

[Service]
WorkingDirectory=/home/%I/Minecraft_server
User=%I
Group=%I
Type=forking
# Run it as a non-root user in a specific directory

ExecStart=/usr/bin/screen -h 1024 -dmS minecraft ./start.sh
# I like to keep my commandline to launch it in a separate file
# because sometimes I want to change it or launch it manually
# If it's in the WorkingDirectory, then we can use a relative path

# Send "stop" to the Minecraft server console
ExecStop=/usr/bin/screen -p 0 -S minecraft -X eval 'stuff \"stop\"\015'
# Wait for the PID to die - otherwise it's killed after this command finishes!
ExecStop=/bin/bash -c "while ps -p \$MAINPID > /dev/null; do /bin/sleep 1; done"
# Note that absolute paths for all executables are required!

[Install]
WantedBy=multi-user.target
EOF
echo "[+] Done"


if [ -z $(which screen) ]; then
    echo "[*] Installing screen ..."
    apt-get install -y screen 2>&1 > /dev/null
    echo "[+] Done"
fi


echo "[*] Enable and start the server ..."
systemctl enable minecraft@$user.service
systemctl start minecraft@$user.service
echo "[+] Done"
