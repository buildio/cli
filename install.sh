curl -fsSL https://buildio.github.io/cli/apt/gpg.key | gpg --batch --yes --dearmor | sudo tee /usr/share/keyrings/buildio-archive-keyring.gpg >/dev/null
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/buildio-archive-keyring.gpg] https://buildio.github.io/cli/apt stable main" | sudo tee /etc/apt/sources.list.d/buildio-cli.list >/dev/null
sudo apt-get update -o Dir::Etc::sourcelist="sources.list.d/buildio-cli.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"
sudo apt-get install -y buildio-archive-keyring bld
