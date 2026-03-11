#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface PNNode : NSObject
@property (nonatomic, copy) NSString *nodeId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *type;       // "landmark", "exit", etc.
@property (nonatomic) CGFloat x;
@property (nonatomic) CGFloat y;
@property (nonatomic) double lat;
@property (nonatomic) double lng;
@property (nonatomic) uint32_t color;  // ARGB
@end

@interface PNStep : NSObject
@property (nonatomic, copy) NSString *nodeId;
@property (nonatomic, copy) NSString *instruction;
@property (nonatomic, copy) NSString *directionIcon;
@property (nonatomic) float distanceFt;
@property (nonatomic) NSInteger stepIndex;
@end

@interface PedNavCore : NSObject
- (BOOL)loadGraphFromJSON:(NSString *)jsonString;
- (NSArray<NSString *> *)findPathFrom:(NSString *)fromId to:(NSString *)toId;
- (NSArray<PNStep *> *)stepsForPath:(NSArray<NSString *> *)path;
- (NSArray<PNNode *> *)allNodes;
- (nullable PNNode *)nodeById:(NSString *)nodeId;
- (NSInteger)imageWidth;
- (NSInteger)imageHeight;
// Returns array of {"from": nodeId, "to": nodeId} dictionaries
- (NSArray<NSDictionary<NSString *, NSString *> *> *)allEdges;
@end

NS_ASSUME_NONNULL_END
