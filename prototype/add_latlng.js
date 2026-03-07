// add_latlng.js
// Adds lat/lng to every node via affine pixel→geographic transform.
// Calibrated from 3 known Chicago landmarks in the graph:
//   n58 Merchandise Mart:   pixel(1093, 1075) → 41.8882°N, -87.6360°W
//   n53 Union Station:      pixel(339,  3411) → 41.8786°N, -87.6398°W
//   n38 Millennium Station: pixel(3465, 2076) → 41.8847°N, -87.6247°W
//
// Solved 3-point affine (exact):
//   lat = a_lat*x + b_lat*y + c_lat
//   lng = a_lng*x + b_lng*y + c_lng

const fs   = require('fs');
const path = require('path');

// Affine coefficients (solved from 3 reference points — see comment above)
const a_lat =  0.000000234;
const b_lat = -0.000004034;
const c_lat =  41.892281;

const a_lng =  0.000004797;
const b_lng = -0.0000000791;
const c_lng = -87.641158;

function toLatLng(x, y) {
  return {
    lat: parseFloat((a_lat * x + b_lat * y + c_lat).toFixed(6)),
    lng: parseFloat((a_lng * x + b_lng * y + c_lng).toFixed(6)),
  };
}

const jsonPath = path.join(__dirname, 'pedway_graph.json');
const data = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));

let updated = 0;
for (const n of data.nodes) {
  const { lat, lng } = toLatLng(n.x, n.y);
  n.lat = lat;
  n.lng = lng;
  updated++;
}

data.meta.exportedAt = new Date().toISOString();
fs.writeFileSync(jsonPath, JSON.stringify(data, null, 2));
console.log(`Added lat/lng to ${updated} nodes → ${jsonPath}`);

// Spot-check known landmarks
const checks = [
  { id: 'n58', name: 'Merchandise Mart',   expectedLat: 41.8882, expectedLng: -87.6360 },
  { id: 'n53', name: 'Union Station',      expectedLat: 41.8786, expectedLng: -87.6398 },
  { id: 'n38', name: 'Millennium Station', expectedLat: 41.8847, expectedLng: -87.6247 },
];
console.log('\nSpot-check (should match reference coords):');
const nodeMap = Object.fromEntries(data.nodes.map(n => [n.id, n]));
for (const c of checks) {
  const n = nodeMap[c.id];
  if (!n) { console.log(`  ${c.id}: NOT FOUND`); continue; }
  const dLat = Math.abs(n.lat - c.expectedLat);
  const dLng = Math.abs(n.lng - c.expectedLng);
  console.log(`  ${c.name}: lat=${n.lat} (Δ${dLat.toFixed(6)})  lng=${n.lng} (Δ${dLng.toFixed(6)})`);
}
