# Character atlas integration

Each transparent layer uses the same `800 × 448` atlas:

- Cell size: `80 × 64`
- Grid: 10 columns × 7 rows
- Row 0: idle, 5 frames
- Row 1: walk, 8 frames
- Row 2: run, 8 frames
- Row 3: jump, 4 frames
- Row 4: alternate/special movement, 4 frames
- Row 5: attack/guard, 6 frames
- Row 6: defeat, 10 frames

Skin, underwear, lower clothing, upper clothing, footwear, hair and weapon
layers are composited with the same cell rectangle. Runtime appearance is
selected from a synchronized random seed so every multiplayer client renders
the same character.

See `READ ME.txt` for the original asset license. Do not redistribute these
source assets separately from the game.
