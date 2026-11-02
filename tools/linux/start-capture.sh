#!/bin/bash
# Runs only inside the prepared SystemRescue environment, on its local console.
python3 /run/archiso/bootmnt/usb4/capture_usb4.py --capture
printf '\nCollector exited. Results, if created, remain on the boot USB. This shell stays open.\n'
exec /bin/bash --noprofile --norc
