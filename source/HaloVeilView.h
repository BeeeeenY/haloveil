#import <ScreenSaver/ScreenSaver.h>
@interface HaloVeilView : ScreenSaverView
- (NSNumber *)displayIdentifier;
- (NSDictionary *)lifecycleState;
+ (NSDictionary *)activeState;
+ (BOOL)validateResourcesAtURL:(NSURL *)resources error:(NSError **)error;
@end
