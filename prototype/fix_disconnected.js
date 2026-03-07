// fix_disconnected.js
// Finds building nodes with no edges, connects each to the nearest exit/entrance node.

const fs = require('fs');
const path = require('path');

const jsonPath = path.join(__dirname, 'pedway_graph.json');
const data = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));

const { nodes, edges } = data;

// Build set of node IDs that appear in at least one edge
const connected = new Set();
for (const e of edges) {
  connected.add(e.from);
  connected.add(e.to);
}

// Find disconnected nodes (not in any edge)
const disconnected = nodes.filter(n => !connected.has(n.id));
console.log(`Total nodes: ${nodes.length}`);
console.log(`Connected nodes: ${connected.size}`);
console.log(`Disconnected nodes: ${disconnected.length}`);
disconnected.forEach(n => console.log(`  ${n.id} [${n.type}] "${n.name}" @ (${n.x}, ${n.y})`));

// Candidate anchor nodes = exit + entrance types that ARE connected
// (also include junctions since they form the backbone)
const anchors = nodes.filter(n => connected.has(n.id));

function dist(a, b) {
  return Math.hypot(a.x - b.x, a.y - b.y);
}

function nearestAnchor(node) {
  let best = null, bd = Infinity;
  for (const a of anchors) {
    const d = dist(node, a);
    if (d < bd) { bd = d; best = a; }
  }
  return { node: best, distance: Math.round(bd) };
}

// Generate new edges
const newEdges = [];
let nextEdgeId = edges.length + 1;

for (const n of disconnected) {
  const { node: anchor, distance } = nearestAnchor(n);
  if (!anchor) continue;
  const edgeId = `e_auto_${nextEdgeId++}`;
  newEdges.push({ id: edgeId, from: n.id, to: anchor.id, distance });
  console.log(`\nConnecting ${n.id} "${n.name}" → ${anchor.id} "${anchor.name}" [${anchor.type}] dist=${distance}`);
}

console.log(`\nAdding ${newEdges.length} new edges.`);

// Merge and write
data.edges = [...edges, ...newEdges];
data.meta.edgeCount = data.edges.length;
data.meta.exportedAt = new Date().toISOString();

fs.writeFileSync(jsonPath, JSON.stringify(data, null, 2));
console.log(`\nWritten to ${jsonPath}`);
console.log(`New edge count: ${data.edges.length}`);
