// Test fixture. If this runs, the install script was NOT blocked.
require("fs").writeFileSync(process.env.MARKER_FILE || "/tmp/install-script-ran", "ran\n");
