#import "PedNavBridge.h"
#include "Graph.hpp"
#include "Pathfinder.hpp"
#include "StepGenerator.hpp"

@implementation PNNode @end
@implementation PNStep @end

@interface PedNavCore () {
    PedNav::Graph _graph;
    PedNav::AStarPathfinder _finder;
    PedNav::StepGenerator _stepGen;
    BOOL _loaded;
}
@end

@implementation PedNavCore

- (instancetype)init {
    self = [super init];
    if (self) {
        _loaded = NO;
    }
    return self;
}

- (BOOL)loadGraphFromJSON:(NSString *)jsonString {
    NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) return NO;

    NSError *error = nil;
    NSDictionary *root = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (!root || error) {
        NSLog(@"PedNavCore: JSON parse error: %@", error);
        return NO;
    }

    // Reset graph
    _graph = PedNav::Graph();

    NSDictionary *meta = root[@"meta"];
    if (meta) {
        _graph.meta.imageWidth  = [meta[@"imageWidth"]  intValue] ?: 4900;
        _graph.meta.imageHeight = [meta[@"imageHeight"] intValue] ?: 7300;
    }

    NSArray *nodesArray = root[@"nodes"];
    if ([nodesArray isKindOfClass:[NSArray class]]) {
        _graph.nodes.reserve(nodesArray.count);
        for (NSDictionary *n in nodesArray) {
            if (![n isKindOfClass:[NSDictionary class]]) continue;
            PedNav::GraphNode node;
            NSString *nid   = n[@"id"];
            NSString *nname = n[@"name"];
            NSString *ntype = n[@"type"];
            node.id   = nid   ? [nid   UTF8String] : "";
            node.name = nname ? [nname UTF8String] : "";
            node.type = PedNav::nodeTypeFromString(ntype ? [ntype UTF8String] : "");
            node.x    = [n[@"x"]   floatValue];
            node.y    = [n[@"y"]   floatValue];
            node.lat  = [n[@"lat"] doubleValue];
            node.lng  = [n[@"lng"] doubleValue];
            _graph.nodes.push_back(std::move(node));
        }
    }

    NSArray *edgesArray = root[@"edges"];
    if ([edgesArray isKindOfClass:[NSArray class]]) {
        _graph.edges.reserve(edgesArray.count);
        for (NSDictionary *e in edgesArray) {
            if (![e isKindOfClass:[NSDictionary class]]) continue;
            PedNav::GraphEdge edge;
            NSString *efrom = e[@"from"];
            NSString *eto   = e[@"to"];
            edge.from     = efrom ? [efrom UTF8String] : "";
            edge.to       = eto   ? [eto   UTF8String] : "";
            edge.distance = [e[@"distance"] floatValue];
            _graph.edges.push_back(std::move(edge));
        }
    }

    _graph.buildIndex();
    _graph.meta.nodeCount = (int)_graph.nodes.size();
    _graph.meta.edgeCount = (int)_graph.edges.size();
    _loaded = YES;

    NSLog(@"PedNavCore: Loaded %d nodes, %d edges",
          _graph.meta.nodeCount, _graph.meta.edgeCount);
    return YES;
}

- (NSArray<NSString *> *)findPathFrom:(NSString *)fromId to:(NSString *)toId {
    if (!_loaded || !fromId || !toId) return @[];
    auto path = _finder.findPath(_graph, [fromId UTF8String], [toId UTF8String]);
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:path.size()];
    for (const auto& nid : path) {
        [result addObject:@(nid.c_str())];
    }
    return result;
}

- (NSArray<PNStep *> *)stepsForPath:(NSArray<NSString *> *)path {
    if (!_loaded || !path) return @[];
    std::vector<std::string> cpath;
    cpath.reserve(path.count);
    for (NSString *nid in path) {
        if (nid) cpath.push_back([nid UTF8String]);
    }
    auto steps = _stepGen.generate(_graph, cpath);
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:steps.size()];
    for (const auto& s : steps) {
        PNStep *step = [[PNStep alloc] init];
        step.nodeId        = @(s.nodeId.c_str());
        step.instruction   = @(s.instruction.c_str());
        step.directionIcon = @(s.directionIcon.c_str());
        step.distanceFt    = s.distanceFt;
        step.stepIndex     = s.stepIndex;
        [result addObject:step];
    }
    return result;
}

- (NSArray<PNNode *> *)allNodes {
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:_graph.nodes.size()];
    for (const auto& n : _graph.nodes) {
        PNNode *node = [self pnNodeFromCpp:n];
        [result addObject:node];
    }
    return result;
}

- (nullable PNNode *)nodeById:(NSString *)nodeId {
    if (!nodeId) return nil;
    const PedNav::GraphNode *n = _graph.nodeById([nodeId UTF8String]);
    if (!n) return nil;
    return [self pnNodeFromCpp:*n];
}

- (PNNode *)pnNodeFromCpp:(const PedNav::GraphNode&)n {
    PNNode *node = [[PNNode alloc] init];
    node.nodeId = @(n.id.c_str());
    node.name   = @(n.name.c_str());
    node.type   = @(PedNav::nodeTypeToString(n.type).c_str());
    node.x      = (CGFloat)n.x;
    node.y      = (CGFloat)n.y;
    node.lat    = n.lat;
    node.lng    = n.lng;
    node.color  = PedNav::nodeTypeColor(n.type);
    return node;
}

- (NSInteger)imageWidth  { return _graph.meta.imageWidth; }
- (NSInteger)imageHeight { return _graph.meta.imageHeight; }

- (NSArray<NSDictionary<NSString *, NSString *> *> *)allEdges {
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:_graph.edges.size()];
    for (const auto& e : _graph.edges) {
        NSDictionary *d = @{
            @"from": @(e.from.c_str()),
            @"to":   @(e.to.c_str())
        };
        [result addObject:d];
    }
    return result;
}

@end
