# Figma workflow

How Claude reads designs from Figma and turns them into Roblox assets. No Figma API token is needed: everything goes
through the Figma desktop app.

## Setup (once per Figma session)

1. Open the file in the **Figma desktop app**.
2. Run the **Desktop Bridge** plugin there (Plugins > Development > Figma Desktop Bridge; manifest at
   `C:\Users\Zebron\.figma-console-mcp\plugin\manifest.json`). Keep its window open; it connects to the
   `figma-console` MCP over a local WebSocket (port 9223).
3. Claude checks the link with `figma_get_status` (`probe: true`). If it reports no connection, re-run the plugin, then
   `figma_reconnect`. `figma_list_open_files` shows which files are connected.

Never paste a Figma token into the chat. If a tool ever needs one, set it yourself in your own terminal.

## Finding a node

Name the layer in Figma (for example `icon cutout`) and tell Claude the name. Claude finds it with `figma_execute`:

```js
await figma.loadAllPagesAsync();
return figma.root.findAll(n => n.name === 'icon cutout').map(n => ({ id: n.id, type: n.type, w: n.width, h: n.height }));
```

## Exporting

- **Look at it:** `figma_take_screenshot` with the node id (PNG, any scale).
- **Vector shapes:** `figma_execute` with `await node.exportAsync({ format: 'SVG_STRING' })` returns the path data.
  Claude rebuilds the image locally with Pillow in a script under `art/<topic>/`, so it can be re-run (for example
  `art/intro/icon_hole.py` turns the icon outline into a black image with a hole).
- **Bitmaps:** `exportAsync({ format: 'PNG', constraint: { type: 'SCALE', value: 2 } })`, or a screenshot.

Keep images at 1024 px or less on each side (the Roblox limit) and check them before upload.

## Uploading to Roblox

1. Serve the folder locally: `python -I -m http.server <free port> --bind 127.0.0.1 --directory art/<topic>`
   (another server may hold a port; pick a free one).
2. `upload_image` (Roblox Studio MCP) with `http://localhost:<port>/<file>.png` returns `rbxassetid://...`.
3. Stop the server.
4. Put the id where it belongs: in the Studio instance (made through the MCP, per CLAUDE.md) or in `Config`.

## Building the UI

UI instances are made in Studio through the MCP, never in code. Add the names and classes code relies on to
`docs/UI-GUIDE.md`, and list stand-ins in `docs/PLACEHOLDER-UI.md`.
