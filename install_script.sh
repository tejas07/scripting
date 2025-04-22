#!/bin/bash
set -e

# ========== SETUP ==========
USERNAME=$(whoami)
LOG_FILE="setup_${USERNAME}.log"
touch "$LOG_FILE"
echo -e "\n\n========== Setup Started for ${USERNAME} at $(date) ==========" >> "$LOG_FILE"

# Detect shell
SHELL_CONFIG="$HOME/.bashrc"
[[ "$SHELL" == */zsh ]] && SHELL_CONFIG="$HOME/.zshrc"

# Detect environment
PLATFORM="linux"
if grep -qi microsoft /proc/version; then
  PLATFORM="wsl"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  PLATFORM="macos"
fi

echo "Detected platform: $PLATFORM"
echo "Using shell config: $SHELL_CONFIG"

update_path() {
  local export_line=$1
  if ! grep -Fxq "$export_line" "$SHELL_CONFIG"; then
    echo "$export_line" >> "$SHELL_CONFIG"
    echo "Added to PATH: $export_line" >> "$LOG_FILE"
  fi
}

log_installed() {
  echo "[INSTALLED] $1" >> "$LOG_FILE"
}

# ========== INSTALL FUNCTIONS ==========

install_java() {
  if command -v java >/dev/null 2>&1; then
    echo "Java already installed: $(java -version 2>&1 | head -n 1)"
    return
  fi
  read -p "Enter Java version (e.g., 17): " JAVA_VERSION
  sudo apt update
  sudo apt install -y openjdk-${JAVA_VERSION}-jdk
  JAVA_HOME="/usr/lib/jvm/java-${JAVA_VERSION}-openjdk-amd64"
  update_path "export JAVA_HOME=${JAVA_HOME}"
  update_path "export PATH=\$JAVA_HOME/bin:\$PATH"
  log_installed "Java $JAVA_VERSION"
}

install_maven() {
  if command -v mvn >/dev/null 2>&1; then
    echo "Maven already installed: $(mvn -v | head -n 1)"
    return
  fi
  read -p "Enter Maven version (e.g., 3.9.5): " MAVEN_VERSION
  wget https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz
  sudo tar xzvf apache-maven-${MAVEN_VERSION}-bin.tar.gz -C /opt
  update_path "export M2_HOME=/opt/apache-maven-${MAVEN_VERSION}"
  update_path "export PATH=\$M2_HOME/bin:\$PATH"
  log_installed "Maven $MAVEN_VERSION"
}

install_git() {
  if command -v git >/dev/null 2>&1; then
    echo "Git already installed: $(git --version)"
    return
  fi
  read -p "Enter Git version (e.g., 2.43.0): " GIT_VERSION
  sudo add-apt-repository ppa:git-core/ppa -y
  sudo apt update
  sudo apt install -y git
  read -p "Enter your Git email for SSH setup: " GIT_EMAIL
  git config --global user.email "$GIT_EMAIL"
  ssh-keygen -t ed25519 -C "$GIT_EMAIL"
  log_installed "Git $GIT_VERSION (email: $GIT_EMAIL)"
}

install_intellij() {
  if compgen -G "/opt/idea-IC*" > /dev/null; then
    echo "IntelliJ already installed."
    return
  fi
  wget https://download.jetbrains.com/idea/ideaIC-latest.tar.gz -O idea.tar.gz
  sudo tar -xzf idea.tar.gz -C /opt
  IDEA_DIR=$(tar -tzf idea.tar.gz | head -1 | cut -f1 -d"/")
  sudo ln -sf /opt/${IDEA_DIR}/bin/idea.sh /usr/local/bin/intellij
  log_installed "IntelliJ IDEA (latest)"
}

install_kafka() {
  if compgen -G "$HOME/kafka_2.13-*" > /dev/null; then
    echo "Kafka already installed."
    return
  fi
  read -p "Enter Kafka version (e.g., 3.6.1): " KAFKA_VERSION
  wget https://downloads.apache.org/kafka/${KAFKA_VERSION}/kafka_2.13-${KAFKA_VERSION}.tgz
  tar -xzf kafka_2.13-${KAFKA_VERSION}.tgz -C ~/
  update_path "export PATH=\$HOME/kafka_2.13-${KAFKA_VERSION}/bin:\$PATH"
  log_installed "Kafka $KAFKA_VERSION"
}

install_mysql() {
  if command -v mysql >/dev/null 2>&1; then
    echo "MySQL already installed: $(mysql --version)"
    return
  fi
  read -p "Enter MySQL version (e.g., 8.0): " MYSQL_VERSION
  sudo apt update
  sudo apt install -y mysql-server
  log_installed "MySQL $MYSQL_VERSION"
}

install_mongodb() {
  if command -v mongod >/dev/null 2>&1; then
    echo "MongoDB already installed: $(mongod --version | head -n 1)"
    return
  fi
  read -p "Enter MongoDB version (e.g., 6.0): " MONGO_VERSION
  wget -qO - https://www.mongodb.org/static/pgp/server-${MONGO_VERSION}.asc | sudo apt-key add -
  echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/${MONGO_VERSION} multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-${MONGO_VERSION}.list
  sudo apt update
  sudo apt install -y mongodb-org
  log_installed "MongoDB $MONGO_VERSION"
}

install_warp() {
  if command -v warp-terminal >/dev/null 2>&1; then
    echo "Warp already installed."
    return
  fi
  echo "Downloading Warp..."
  WARP_DEB=$(curl -s https://app.warp.dev/download | grep -oP 'https://.*?\.deb' | head -n1)
  wget "$WARP_DEB" -O warp.deb
  sudo dpkg -i warp.deb || sudo apt-get install -f -y
  log_installed "Warp (latest)"
}

# ========== MENU ==========
echo "=== ${USERNAME^}'s Dev Machine Setup ==="
PS3="Choose what to install (or 'Done' to finish): "
options=("Java" "Maven" "Git + SSH" "IntelliJ IDEA" "Kafka" "MySQL" "MongoDB" "Warp" "Done")
select opt in "${options[@]}"; do
  case $opt in
    "Java") install_java ;;
    "Maven") install_maven ;;
    "Git + SSH") install_git ;;
    "IntelliJ IDEA") install_intellij ;;
    "Kafka") install_kafka ;;
    "MySQL") install_mysql ;;
    "MongoDB") install_mongodb ;;
    "Warp") install_warp ;;
    "Done") break ;;
    *) echo "Invalid option $REPLY";;
  esac
done

# ========== SUMMARY ==========
echo -e "\n=== Setup Complete for ${USERNAME}! ==="
echo "Log file created: $LOG_FILE"
echo -e "\nInstalled tools:"
grep "\[INSTALLED\]" "$LOG_FILE" | sed 's/\[INSTALLED\] //'

echo -e "\nTo apply PATH changes, run:"
echo "source $SHELL_CONFIG"
