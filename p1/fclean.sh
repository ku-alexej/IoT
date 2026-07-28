echo "[1/4] vagrant halt..."
vagrant halt

echo "[2/4] vagrant destroy..."
vagrant destroy

echo "[3/4] remove token..."
rm node-token

echo "[4/4] remove vagrant folder..."
rm -rf .vagrant/

echo "DONE"