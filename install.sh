curl -fsSL https://buildio.github.io/cli/apt/gpg.key | gpg --batch --yes --dearmor | sudo tee /usr/share/keyrings/buildio-archive-keyring.gpg >/dev/null
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/buildio-archive-keyring.gpg] https://buildio.github.io/cli/apt stable main" | sudo tee /etc/apt/sources.list.d/buildio-cli.list >/dev/null
echo 'Dir::Etc{SourceList sources.list.d/buildio-cli.list;SourceParts /dev/null}#clear APT::Update;'|sudo apt-get -c/dev/fd/0 update --no-list-cleanup
sudo apt-get install -y buildio-archive-keyring bld
