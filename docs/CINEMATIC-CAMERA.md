# Cinematic camera

Type `/cinecam` in chat to enter or leave filming mode. It works in Studio and live games for the user IDs in `Config.CinematicCamera.UserIds` (currently zebronr). The server removes you from the round, destroys your character, and frees your team slot. Leaving the mode assigns a team and spawns your character again. The camera and controls are local; no camera UI is shown. The HUD and core UI start hidden, and world billboards stay visible.

Press `H` to show the chat again before typing `/cinecam` to leave.

| Key | Action |
|-----|--------|
| `0` | Free camera |
| `1`–`9` | Focus the matching active player in join order |
| `Tab` | Next focused player |
| `Left Shift` + `Tab` | Previous focused player |
| `V` | Wide orbit of the map |
| `C` | Next focus angle |
| `Left Shift` + `C` | Previous focus angle |
| `W` | Move forward in free camera |
| `A` | Move left in free camera |
| `S` | Move backward in free camera |
| `D` | Move right in free camera |
| `Space` | Move up in free camera |
| `Left Shift` | Move down in free camera |
| Arrow keys | Turn and tilt the free camera |
| Mouse | Turn and tilt the free camera (the cursor is locked in the middle and hidden in free cam, and comes back in the other modes and while typing) |
| `Left Alt` | Slow free camera movement and looking (mouse and arrow keys) |
| `Left Control` | Fast free camera movement |
| `[` | Lower the base movement speed |
| `]` | Raise the base movement speed |
| `Z` | Hold to zoom in |
| `X` | Hold to zoom out |
| `R` | Reset the current mode's field of view |
| `H` | Show or hide HUD and core UI |
| `P` | Freeze or resume the camera |
| `T` | Pause or resume the round timer (only the clock: customers, orders and cooking keep going, and the round can't end while paused) |

Left Alt also slows mouse and arrow-key looking in free camera. Pausing the round clock stops only its countdown and prevents the round from ending. Customers, orders, and cooking keep running.

Focus angles are game view, over shoulder, front hero, side tracking, top down, and slow orbit. A focused player who temporarily has no character holds the last shot until they respawn. Camera movement, aim and zoom ease between shots. Depth of field is omitted because this project authors non-script instances in Studio.
