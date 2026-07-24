#!/bin/bash
set -euo pipefail

DEST_DIR="firmware/dhrystone"
mkdir -p "$DEST_DIR"

echo "Downloading Dhrystone 2.1 source..."
wget -q https://raw.githubusercontent.com/YosysHQ/picorv32/master/dhrystone/dhry_1.c -O "$DEST_DIR/dhry_1.c"
wget -q https://raw.githubusercontent.com/YosysHQ/picorv32/master/dhrystone/dhry_2.c -O "$DEST_DIR/dhry_2.c"
wget -q https://raw.githubusercontent.com/YosysHQ/picorv32/master/dhrystone/dhry.h -O "$DEST_DIR/dhry.h"

echo "Dhrystone files fetched successfully."
