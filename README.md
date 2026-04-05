demo: https://lcanunayon.github.io/demonhacks/

# PedNav PWA

Progressive Web App build of the Chicago Pedway navigator.

## Folder structure

```
pwa/
  index.html      — main app (copy of pednav-withAR.html + PWA tags)
  manifest.json   — PWA install metadata
  sw.js           — service worker (offline caching)
  icons/          — app icons (you need to add these, see below)
    icon-192.png
    icon-512.png
```

The original prototype files remain untouched in the parent folder.

---

## Icons (required before deploying)

PWA install on iOS requires at least one apple-touch-icon. Generate icons from the logo:

1. Open `assets/logo.png` (or any square image)
2. Export at 192×192 and 512×512 PNG
3. Save them as `pwa/icons/icon-192.png` and `pwa/icons/icon-512.png`

Quick option — use a generator site like realfavicongenerator.net or squoosh.app.

---

## Hosting options (pick one)

### Option A — GitHub Pages (free, easiest)

1. Push this repo to GitHub
2. Go to repo Settings > Pages > Source: Deploy from branch > select `main` > folder `/pwa`
3. Your app is live at `https://<username>.github.io/<repo>/`

### Option B — Netlify (free, drag-and-drop)

1. Go to app.netlify.com > "Add new site" > "Deploy manually"
2. Drag the entire `pwa/` folder into the deploy dropzone
3. Netlify gives you a public URL instantly

### Option C — Local network (for quick testing without hosting)

Run a local HTTPS server (service workers require HTTPS or localhost):

```bash
# Requires Node.js
npx serve pwa --ssl-cert <cert.pem> --ssl-key <key.pem>
```

Or use VS Code's "Live Server" extension pointed at the `pwa/` folder, then
access it from your iPhone via your PC's local IP (e.g. `http://192.168.x.x:5500/pwa/`).
Note: camera/AR requires HTTPS — use a tunnel like `npx cloudflared tunnel` or
`npx localtunnel --port 5500` to get an HTTPS URL for your local server.

---

## Testing on iPhone

1. Open Safari on your iPhone and navigate to the hosted URL
2. Tap the Share button (box with up arrow)
3. Scroll down and tap "Add to Home Screen"
4. Tap "Add" — the app icon appears on your home screen
5. Launch it from the home screen — it runs fullscreen like a native app

### What works on iOS Safari

- Fullscreen standalone mode
- Offline navigation (graph data is embedded in the HTML)
- Camera access for AR view (iOS 16.4+ required; user must grant permission)
- Touch/pan/zoom on the map

### Known iOS limitations

- `DeviceOrientationEvent` requires a user gesture to activate on iOS 13+
  (the AR compass/heading). The app already handles the permission prompt.
- Google Fonts load from the network; offline fallback is the system sans-serif font.
- No push notifications (not needed for this app).

---

## Updating the app

After making changes to `index.html`, bump the cache version in `sw.js`:

```js
const CACHE_NAME = 'pednav-v2';  // increment this
```

This forces the service worker to invalidate the old cache on the next visit.
