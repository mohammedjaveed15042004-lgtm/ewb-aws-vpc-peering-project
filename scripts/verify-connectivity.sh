#!/usr/bin/env bash
set -euo pipefail

echo "This script runs from your laptop and expects SSH aliases in ~/.ssh/config."
echo
echo "1) Bastion connectivity"
ssh -o BatchMode=yes -o ConnectTimeout=10 ewb-bastion 'hostname'
echo
echo "2) App-A identity"
ssh -o BatchMode=yes -o ConnectTimeout=10 ewb-app-a 'hostname; hostname -I; ping -c 4 10.20.1.10'
echo
echo "3) App-B identity and reverse ping"
ssh -o BatchMode=yes -o ConnectTimeout=10 ewb-app-b 'hostname; hostname -I; ping -c 4 10.10.2.10'
echo
echo "4) App-B SSH via bastion succeeded if this script reached the end."
echo "Capture terminal output for your report. Run the controlled SG failure test manually."
