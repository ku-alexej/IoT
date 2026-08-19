clear
echo "Cleaning: START"

echo "[1/3] vagrant halt..."
vagrant halt

echo "[2/3] vagrant destroy..."
vagrant destroy -f

echo "[3/3] remove vagrant folder..."
rm -rf .vagrant/

echo "Cleaning: DONE"