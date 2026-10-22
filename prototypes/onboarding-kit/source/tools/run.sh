#!/bin/sh
# render every probe command in the simulator, and a side-by-side with the canvas board where there is one
cd "$(dirname "$0")/../.."
A=probes/art-guide/PagleArtGuide; O=previews/guide; BG=../an/assets/world.jpg
run() { python3 sim/sim.py $A $O/$1.png "$2" --bg $BG --t ${3:-1.6} $4 2>&1 | grep -v "^chat\|^painted" ; }
run welcome "/pagleguide welcome"; run box "/pagleguide box"; run casting "/pagleguide casting"; run clothes "/pagleguide clothes"
run moments "/pagleguide moments"; run ledger "/pagleguide ledger"; run board "/pagleguide board"; run off "/pagleguide off"
run letter "/pagleguide letter"; run evening "/pagleguide evening"; run first "/pagleguide first"
for k in journal hunts stats board shop; do run look-$k "/pagleguide look $k"; done
run without "/pagleguide without"
true
