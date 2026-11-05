#import <Cocoa/Cocoa.h>
#import <ScreenSaver/ScreenSaver.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import "../source/HaloVeilView.h"

static char DisplayKey;
static id FixtureDisplay(id self,SEL command){return objc_getAssociatedObject(self,&DisplayKey)?:@900001;}
@interface FixtureWindow:NSWindow @end
@implementation FixtureWindow
- (NSRect)constrainFrameRect:(NSRect)frame toScreen:(NSScreen *)screen{return frame;}
@end
@interface LifecycleQA:NSObject<NSApplicationDelegate,NSWindowDelegate>
@property NSBundle *bundle;
@property Class fixture;
@property NSWindow *window,*secondWindow;
@property HaloVeilView *current,*second;
@property NSMutableArray *retired,*cycles,*checks;
@property NSHashTable *weakViews;
@property NSMutableDictionary *report;
@property NSInteger cycle;
@property BOOL failed,finished;
@property double sampleStart;
@property NSInteger sampleFrames;
@end
@implementation LifecycleQA
- (NSString *)reportPath{return NSBundle.mainBundle.infoDictionary[@"ReportPath"];}
- (void)later:(double)delay block:(dispatch_block_t)block{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay*NSEC_PER_SEC)),dispatch_get_main_queue(),block);
}
- (void)check:(NSString *)name pass:(BOOL)pass details:(id)details{
    [self.checks addObject:@{@"name":name,@"pass":@(pass),@"details":details?:@{}}];
    if(!pass)self.failed=YES;
}
- (NSDictionary *)active{return [(id)self.fixture activeState];}
- (WKWebView *)web:(HaloVeilView *)view{
    for(NSView *child in view.subviews)if([child isKindOfClass:WKWebView.class])return (WKWebView *)child;return nil;
}
- (HaloVeilView *)make:(NSNumber *)display{
    HaloVeilView *view=[[self.fixture alloc] initWithFrame:NSMakeRect(0,0,1600,960) isPreview:NO];
    objc_setAssociatedObject(view,&DisplayKey,display,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self.weakViews addObject:view];return view;
}
- (void)state:(HaloVeilView *)view completion:(void(^)(NSDictionary *))completion{
    WKWebView *web=[self web:view];if(!web){completion(nil);return;}
    [web evaluateJavaScript:@"window.HALOVEILHost?.getState()" completionHandler:^(id state,NSError *error){
        completion([state isKindOfClass:NSDictionary.class]?state:nil);
    }];
}
- (void)ready:(HaloVeilView *)view retries:(NSInteger)retries completion:(void(^)(NSDictionary *))completion{
    [self state:view completion:^(NSDictionary *state){
        if([state[@"frames"] integerValue]>=20&&[view.lifecycleState[@"pageReady"] boolValue]){completion(state);return;}
        if(retries>0&&![view.lifecycleState[@"error"] length]){
            [self later:0.1 block:^{[self ready:view retries:retries-1 completion:completion];}];
        }else{[self check:@"page-ready" pass:NO details:view.lifecycleState];[self finish];}
    }];
}
- (int)helper:(NSString *)mode argument:(NSString *)argument{
    NSTask *task=[[NSTask alloc] init];task.executableURL=[NSBundle.mainBundle.executableURL.URLByDeletingLastPathComponent URLByAppendingPathComponent:@"LeaseProbe"];
    task.arguments=@[mode,argument];NSError *error=nil;
    if(![task launchAndReturnError:&error])return 3;
    [task waitUntilExit];return task.terminationStatus;
}
- (NSWindow *)newWindow{
    NSWindow *window=[[FixtureWindow alloc] initWithContentRect:NSMakeRect(0,0,1600,960)
        styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];
    window.title=@"HALOVEIL · 连续启停测试中";window.releasedWhenClosed=NO;window.delegate=self;
    if(getenv("HALOVEIL_TEST_HEADLESS"))[window setFrameOrigin:NSMakePoint(-20000,-20000)];else[window center];return window;
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification{
    self.report=[NSMutableDictionary dictionary];self.retired=[NSMutableArray array];self.cycles=[NSMutableArray array];self.checks=[NSMutableArray array];
    self.weakViews=[NSHashTable weakObjectsHashTable];self.report[@"physicalDisplayCount"]=@(NSScreen.screens.count);
    self.bundle=[NSBundle bundleWithPath:NSBundle.mainBundle.infoDictionary[@"SaverPath"]];NSError *error=nil;
    if(![self.bundle loadAndReturnError:&error]){[self check:@"load-bundle" pass:NO details:error.localizedDescription];[self finish];return;}
    self.fixture=objc_allocateClassPair(self.bundle.principalClass,"HaloVeilLifecycleFixture",0);
    class_addMethod(self.fixture,@selector(displayIdentifier),(IMP)FixtureDisplay,"@@:");objc_registerClassPair(self.fixture);
    self.window=[self newWindow];[self.window makeKeyAndOrderFront:nil];
    if(!getenv("HALOVEIL_TEST_HEADLESS"))[NSApp activateIgnoringOtherApps:YES];
    [self startCycle];
}
- (void)startCycle{
    self.window.title=[NSString stringWithFormat:@"HALOVEIL · 第 %ld/8 轮连续启动测试",(long)self.cycle+1];
    self.current=[self make:@900001];self.window.contentView=self.current;
    [self.current startAnimation];[self.current startAnimation];[self.current startAnimation];
    [self ready:self.current retries:100 completion:^(NSDictionary *state){
        NSDictionary *lifecycle=self.current.lifecycleState;
        [self check:@"one-active-instance" pass:[lifecycle[@"activeInstancesForDisplay"] integerValue]==1 details:lifecycle];
        [self check:@"kernel-lock-exclusive" pass:[self helper:@"probe" argument:lifecycle[@"leasePath"]]==2 details:@(self.cycle+1)];
        NSString *version=self.bundle.infoDictionary[@"CFBundleShortVersionString"];
        [self check:@"unified-version" pass:[state[@"webRevision"] isEqual:version]&&[lifecycle[@"nativeRevision"] isEqual:version] details:state[@"webRevision"]];
        [self check:@"startup-prepared-before-play" pass:[state[@"prepared"] boolValue]&&[state[@"warmupFrames"] integerValue]>=37 details:state];
        self.sampleFrames=[state[@"frames"] integerValue];self.sampleStart=NSProcessInfo.processInfo.systemUptime;
        [self later:4 block:^{[self endCycle];}];
    }];
}
- (void)endCycle{
    [self state:self.current completion:^(NSDictionary *state){
        double seconds=NSProcessInfo.processInfo.systemUptime-self.sampleStart;
        double fps=([state[@"frames"] integerValue]-self.sampleFrames)/seconds;
        [self.cycles addObject:@{@"cycle":@(self.cycle+1),@"fps":@(fps),@"sampleSeconds":@(seconds),@"state":state?:@{},@"lifecycle":self.current.lifecycleState}];
        [self check:@"script-errors" pass:[state[@"errors"] count]==0 details:state[@"errors"]];
        [self check:@"no-duplicate-startup-layout" pass:[state[@"layoutBuilds"] integerValue]==1 details:state[@"layoutBuilds"]];
        NSString *lease=self.current.lifecycleState[@"leasePath"];
        __weak WKWebView *weakWeb=[self web:self.current];
        [self.retired addObject:self.current];
        if(self.cycle%2==0)[self.current stopAnimation];
        // Odd cycles intentionally detach without stopAnimation, like the legacy host.
        self.window.contentView=[[NSView alloc] initWithFrame:NSMakeRect(0,0,1600,960)];self.current=nil;
        [self later:0.5 block:^{
            [self check:@"zero-active-after-exit" pass:[[self active][@"webViews"] integerValue]==0&&[[self active][@"sessions"] integerValue]==0 details:[self active]];
            [self check:@"webview-deallocated" pass:weakWeb==nil details:@(self.cycle+1)];
            [self check:@"kernel-lock-released" pass:[self helper:@"probe" argument:lease]==0 details:@(self.cycle+1)];
            self.cycle++;if(self.cycle<8)[self startCycle];else[self overlapTest];
        }];
    }];
}
- (void)overlapTest{
    self.window.title=@"HALOVEIL · 测试旧实例保留与新实例接管";
    self.current=[self make:@900001];self.window.contentView=self.current;[self.current startAnimation];
    [self ready:self.current retries:100 completion:^(NSDictionary *state){
        self.secondWindow=[self newWindow];[self.secondWindow makeKeyAndOrderFront:nil];
        self.second=[self make:@900001];self.secondWindow.contentView=self.second;[self.second startAnimation];
        [self ready:self.second retries:100 completion:^(NSDictionary *secondState){
            [self check:@"retained-old-instance-stopped" pass:![self.current.lifecycleState[@"running"] boolValue]&&![self.current.lifecycleState[@"hasWebView"] boolValue]&&!self.current.isAnimating details:self.current.lifecycleState];
            [self check:@"overlap-keeps-one" pass:[[self active][@"webViews"] integerValue]==1 details:[self active]];
            [self.secondWindow orderOut:nil];
            [self later:0.3 block:^{
                [self check:@"hidden-window-stops" pass:[[self active][@"webViews"] integerValue]==0 details:[self active]];
                self.secondWindow.contentView=nil;self.second=nil;
                self.second=[self make:@900001];self.secondWindow.contentView=self.second;[self.secondWindow makeKeyAndOrderFront:nil];[self.second startAnimation];
                [self ready:self.second retries:100 completion:^(NSDictionary *again){
                    self.secondWindow.level=NSFloatingWindowLevel;[self.second animateOneFrame];self.secondWindow.level=NSNormalWindowLevel;
                    [self later:0.2 block:^{
                        [self check:@"demoted-window-stops" pass:[[self active][@"webViews"] integerValue]==0 details:[self active]];
                        [self.second stopAnimation];self.secondWindow.contentView=nil;self.second=nil;
                        [self multiDisplayTest];
                    }];
                }];
            }];
        }];
    }];
}
- (void)multiDisplayTest{
    self.window.contentView=nil;self.current=[self make:@900001];self.window.contentView=self.current;[self.current startAnimation];
    [self.secondWindow makeKeyAndOrderFront:nil];self.second=[self make:@900002];self.secondWindow.contentView=self.second;[self.second startAnimation];
    [self ready:self.second retries:100 completion:^(NSDictionary *state){
        NSDictionary *active=[self active],*screens=active[@"screens"];
        [self check:@"two-display-isolation" pass:[screens[@"900001"] integerValue]==1&&[screens[@"900002"] integerValue]==1&&[active[@"webViews"] integerValue]==2 details:active];
        [self.second stopAnimation];self.secondWindow.contentView=nil;self.second=nil;[self.secondWindow orderOut:nil];
        [self.current performSelector:@selector(displayDidSleep:) withObject:nil];
        [self check:@"sleep-releases-webview" pass:[[self active][@"webViews"] integerValue]==0 details:[self active]];
        [self.current performSelector:@selector(displayDidWake:) withObject:nil];
        [self ready:self.current retries:100 completion:^(NSDictionary *resumed){[self remoteClaimTest];}];
    }];
}
- (void)remoteClaimTest{
    [self check:@"cross-process-claim-posted" pass:[self helper:@"claim" argument:@"900001"]==0 details:nil];
    [self later:0.5 block:^{
        [self check:@"cross-process-claim-retires-owner" pass:![self.current.lifecycleState[@"running"] boolValue]&&[[self active][@"webViews"] integerValue]==0 details:[self active]];
        self.window.contentView=nil;self.current=nil;
        [self warmupCancellationTest:150];
    }];
}
- (void)warmupCancellationTest:(NSInteger)retries {
    if(!self.current){self.current=[self make:@900001];self.window.contentView=self.current;[self.current startAnimation];}
    [self state:self.current completion:^(NSDictionary *state){
        NSDictionary *lifecycle=self.current.lifecycleState;
        if([lifecycle[@"preparing"] boolValue]&&[state[@"warmupFrames"] integerValue]>0){
            [self check:@"warmup-keeps-playback-paused" pass:![state[@"active"] boolValue]&&[state[@"frames"] integerValue]==0&&[state[@"pendingTimers"] integerValue]==0&&[state[@"time"] doubleValue]==0&&![lifecycle[@"pageReady"] boolValue]&&![lifecycle[@"presented"] boolValue] details:lifecycle];
            NSString *lease=lifecycle[@"leasePath"];__weak WKWebView *weakWeb=[self web:self.current];
            [self.current stopAnimation];self.window.contentView=nil;self.current=nil;
            [self later:0.4 block:^{
                [self check:@"stop-during-warmup-no-resurrection" pass:[[self active][@"webViews"] integerValue]==0&&[[self active][@"sessions"] integerValue]==0 details:[self active]];
                [self check:@"stop-during-warmup-deallocates-webview" pass:weakWeb==nil details:nil];
                [self check:@"stop-during-warmup-releases-lock" pass:[self helper:@"probe" argument:lease]==0 details:nil];
                [self raceAndIntegrityTest];
            }];
        }else if(retries>0){[self later:0.02 block:^{[self warmupCancellationTest:retries-1];}];}
        else{[self check:@"warmup-phase-observed" pass:NO details:lifecycle];[self finish];}
    }];
}
- (void)raceAndIntegrityTest{
    self.current=[self make:@900001];self.window.contentView=self.current;[self.current startAnimation];
    [self.current stopAnimation];self.window.contentView=nil;self.current=nil;
    [self later:0.7 block:^{
        [self check:@"stop-during-navigation" pass:[[self active][@"webViews"] integerValue]==0&&[[self active][@"sessions"] integerValue]==0 details:[self active]];
        NSError *error=nil;NSURL *resources=self.bundle.resourceURL;
        [self check:@"matching-assets-accepted" pass:[(id)self.fixture validateResourcesAtURL:resources error:&error] details:error.localizedDescription];
        NSURL *temporary=[NSURL fileURLWithPath:[[self reportPath].stringByDeletingLastPathComponent stringByAppendingPathComponent:NSUUID.UUID.UUIDString] isDirectory:YES];
        [NSFileManager.defaultManager createDirectoryAtURL:temporary withIntermediateDirectories:YES attributes:nil error:nil];
        for(NSString *path in @[@"web",@"manifest.json"])[NSFileManager.defaultManager copyItemAtURL:[resources URLByAppendingPathComponent:path] toURL:[temporary URLByAppendingPathComponent:path] error:nil];
        NSURL *animation=[temporary URLByAppendingPathComponent:@"web/animation.js"];
        NSMutableData *data=[[NSData dataWithContentsOfURL:animation] mutableCopy];[data appendData:[@"\n// deliberate fixture corruption\n" dataUsingEncoding:NSUTF8StringEncoding]];[data writeToURL:animation atomically:YES];
        error=nil;BOOL valid=[(id)self.fixture validateResourcesAtURL:temporary error:&error];
        [self check:@"mismatched-assets-rejected" pass:!valid&&error!=nil details:error.localizedDescription];
        [NSFileManager.defaultManager removeItemAtURL:temporary error:nil];
        [self.retired removeAllObjects];
        [self later:0.5 block:^{
            [self check:@"retired-saver-views-deallocated" pass:self.weakViews.allObjects.count==0 details:@(self.weakViews.allObjects.count)];
            [self finish];
        }];
    }];
}
- (void)finish{
    if(self.finished)return;self.finished=YES;
    [self.current stopAnimation];[self.second stopAnimation];
    self.report[@"cycles"]=self.cycles;self.report[@"checks"]=self.checks;self.report[@"pass"]=@(!self.failed);self.report[@"finalActiveState"]=[self active];
    if(self.cycles.count==8){
        double first=([self.cycles[0][@"fps"] doubleValue]+[self.cycles[1][@"fps"] doubleValue])/2;
        double last=([self.cycles[6][@"fps"] doubleValue]+[self.cycles[7][@"fps"] doubleValue])/2;
        self.report[@"firstTwoMeanFPS"]=@(first);self.report[@"lastTwoMeanFPS"]=@(last);
        self.report[@"noProgressiveSlowdown"]=@(last>=first*0.85);
        if(last<first*0.85)self.report[@"pass"]=@NO;
    }
    NSData *data=[NSJSONSerialization dataWithJSONObject:self.report options:NSJSONWritingPrettyPrinted error:nil];
    [data writeToFile:[self reportPath] atomically:YES];
    self.window.title=self.failed?@"HALOVEIL · 回归测试存在失败项":@"HALOVEIL · 连续启停回归测试完成";
    if(getenv("HALOVEIL_TEST_HEADLESS"))[NSApp terminate:nil];
}
- (void)windowWillClose:(NSNotification *)notification{
    if(self.finished){[NSApp terminate:nil];return;}
    [self check:@"test-interrupted" pass:NO details:nil];[self finish];[NSApp terminate:nil];
}
@end
int main(void){@autoreleasepool{NSApplication *app=NSApplication.sharedApplication;LifecycleQA *delegate=[[LifecycleQA alloc] init];app.delegate=delegate;[app setActivationPolicy:getenv("HALOVEIL_TEST_HEADLESS")?NSApplicationActivationPolicyAccessory:NSApplicationActivationPolicyRegular];[app run];}return 0;}
