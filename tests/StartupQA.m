#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <ScreenSaver/ScreenSaver.h>
#import <objc/runtime.h>
#import "../source/HaloVeilView.h"

static id StartupDisplay(id object, SEL command) { return @900101; }
static id StatusFixtureURL(id object, SEL command) {
    return [NSURL fileURLWithPath:@(getenv("HALOVEIL_TEST_AGENT_STATUS"))];
}
@interface StartupWindow : NSWindow @end
@implementation StartupWindow
- (NSRect)constrainFrameRect:(NSRect)frame toScreen:(NSScreen *)screen { return frame; }
@end
@interface StartupQA : NSObject <NSApplicationDelegate>
@property NSBundle *bundle;
@property Class fixture;
@property NSWindow *window;
@property HaloVeilView *view;
@property NSMutableArray *cycles, *samples;
@property NSDictionary *statusChecks;
@property NSInteger cycle;
@property double started, firstFrame;
@property BOOL sampling;
@end
@implementation StartupQA
- (void)later:(double)delay block:(dispatch_block_t)block {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay*NSEC_PER_SEC)),dispatch_get_main_queue(),block);
}
- (WKWebView *)web {
    for (NSView *child in self.view.subviews) if ([child isKindOfClass:WKWebView.class]) return (WKWebView *)child;
    return nil;
}
- (NSString *)probe {
    return @"if(!window.__HALOProbe && typeof renderFrame==='function'){ window.__HALOProbe={first:0,last:0,frames:[]}; const original=renderFrame; renderFrame=function(now){const before=frames,t=performance.now();original(now);if(frames>before){const p=window.__HALOProbe;if(!p.first)p.first=now;p.frames.push({at:now-p.first,gap:p.last?now-p.last:0,cost:performance.now()-t,slotBuildCount});p.last=now;}};}";
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.cycles=[NSMutableArray array];
    self.bundle=[NSBundle bundleWithPath:NSProcessInfo.processInfo.arguments[1]];
    NSError *error=nil;
    if (![self.bundle loadAndReturnError:&error]) { NSLog(@"%@",error); exit(2); }
    self.fixture=objc_allocateClassPair(self.bundle.principalClass,"HaloVeilStartupFixture",0);
    class_addMethod(self.fixture,@selector(displayIdentifier),(IMP)StartupDisplay,"@@:");objc_registerClassPair(self.fixture);
    if(getenv("HALOVEIL_TEST_AGENT_STATUS"))class_addMethod(self.fixture,@selector(agentStatusURL),(IMP)StatusFixtureURL,"@@:");
    self.window=[[StartupWindow alloc] initWithContentRect:NSMakeRect(-20000,-20000,1440,900) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
    [self.window makeKeyAndOrderFront:nil];[self start];
}
- (void)start {
    self.samples=[NSMutableArray array];self.firstFrame=0;self.started=NSProcessInfo.processInfo.systemUptime;
    self.view=[[self.fixture alloc] initWithFrame:NSMakeRect(0,0,1440,900) isPreview:NO];
    self.window.contentView=self.view;[self.view startAnimation];
    WKUserScript *script=[[WKUserScript alloc] initWithSource:[self probe] injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
    [self.web.configuration.userContentController addUserScript:script];
    [self poll];
}
- (void)poll {
    NSString *script=[[self probe] stringByAppendingString:@"; JSON.stringify({state:window.HALOVEILHost?.getState()||null,probe:window.__HALOProbe||null,agent:{badge:document.getElementById('codexBadge').textContent,usage:document.getElementById('codexWindows').textContent,expiry:document.getElementById('codexExpiry').textContent,count:document.getElementById('codexResetCount').textContent}})"];
    [self.web evaluateJavaScript:script completionHandler:^(id value,NSError *error){
        NSDictionary *result=[value isKindOfClass:NSString.class]?[NSJSONSerialization JSONObjectWithData:[value dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil]:nil;
        NSDictionary *state=[result[@"state"] isKindOfClass:NSDictionary.class]?result[@"state"]:nil;
        double now=NSProcessInfo.processInfo.systemUptime;
        if ([state[@"frames"] integerValue]>0 && self.firstFrame==0) self.firstFrame=now;
        if(state) [self.samples addObject:@{@"atMS":@((now-self.started)*1000),@"state":state,@"lifecycle":self.view.lifecycleState,@"agent":result[@"agent"]?:@{}}];
        if(self.firstFrame && now-self.firstFrame>=5.2) {
            [self.cycles addObject:@{@"cycle":@(self.cycle+1),@"firstFrameMS":@((self.firstFrame-self.started)*1000),@"samples":self.samples,@"probe":result[@"probe"]?:@{}}];
            if(self.cycle==2){
                [self verifyStatusAndSnapshot];
            }else[self endCycle];
        } else if (now-self.started>15) { NSLog(@"startup timed out %@",self.view.lifecycleState);exit(3); }
        else [self later:0.08 block:^{[self poll];}];
    }];
}
- (void)verifyStatusAndSnapshot {
    if(!getenv("HALOVEIL_TEST_AGENT_STATUS")){[self snapshotAndEnd];return;}
    NSData *data=[NSData dataWithContentsOfFile:@(getenv("HALOVEIL_TEST_AGENT_STATUS"))];
    NSDictionary *restore=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:@{};
    NSString *script=@"const now=Date.now()/1000,checks={};"
        "const base=()=>({state:'ok',fetchedAt:now,limits:[{id:'codex',name:'Codex',windows:[{name:'primary',usedPercent:2,windowDurationMins:10080,resetsAt:now+1000}]}],fullReset:{availableCount:3,expiresAt:now+1000}});"
        "const update=s=>window.HALOVEILAgentStatus.update(s),el=id=>document.getElementById(id);"
        "let s=base();update(s);checks.percent=el('codexWindows').textContent.includes('2% used · 98% left');"
        "s=base();s.fetchedAt=now-901;update(s);checks.stale=el('codexBadge').textContent==='STALE';"
        "s=base();s.fullReset.availableCount=null;s.limits[0].windows[0].usedPercent=null;update(s);checks.unknown=el('codexResetCount').textContent==='UNKNOWN'&&el('codexWindows').textContent.includes('usage unknown');"
        "s=base();s.limits[0].windows[0].resetsAt=now-1;s.fullReset.expiresAt=now-1;update(s);checks.elapsed=el('codexWindows').textContent.includes('awaiting sync')&&el('codexExpiry').textContent.includes('awaiting sync');"
        "s=base();s.limits[0].id='other';s.limits[0].name='<img src=x onerror=alert(1)>';update(s);checks.textOnly=el('codexWindows').querySelector('img')===null&&el('codexWindows').textContent.includes('<img');"
        "s=base();s.fetchedAt=now+120;update(s);checks.future=el('codexBadge').textContent==='NO DATA';"
        "update({state:'unavailable'});checks.missing=el('codexBadge').textContent==='NO DATA'&&el('codexResetCount').textContent==='UNKNOWN';"
        "update(restore);return checks;";
    [self.web callAsyncJavaScript:script arguments:@{@"restore":restore?:@{}} inFrame:nil inContentWorld:WKContentWorld.pageWorld completionHandler:^(id value,NSError *error){
        self.statusChecks=[value isKindOfClass:NSDictionary.class]?value:@{};
        if(error||self.statusChecks.count!=7){NSLog(@"Account status UI checks failed");exit(4);}
        for(NSNumber *passed in self.statusChecks.allValues)if(!passed.boolValue){NSLog(@"Account status UI checks failed %@",self.statusChecks);exit(4);}
        [self snapshotAndEnd];
    }];
}
- (void)snapshotAndEnd {
    [self.web takeSnapshotWithConfiguration:nil completionHandler:^(NSImage *image,NSError *snapshotError){
        if(image){
            NSBitmapImageRep *bitmap=[NSBitmapImageRep imageRepWithData:image.TIFFRepresentation];
            NSData *png=[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
            [png writeToFile:[NSProcessInfo.processInfo.arguments[2].stringByDeletingPathExtension stringByAppendingPathExtension:@"png"] atomically:YES];
        }
        [self endCycle];
    }];
}
- (void)endCycle {
    [self.view stopAnimation];self.window.contentView=nil;self.view=nil;self.cycle++;
    if(self.cycle<3)[self later:0.3 block:^{[self start];}];else[self finish];
}
- (void)finish {
    NSDictionary *report=@{@"cycles":self.cycles,@"statusChecks":self.statusChecks?:@{},@"physicalDisplayCount":@(NSScreen.screens.count),@"finalActiveState":[(id)self.fixture activeState],@"note":@"Offscreen WKWebView draw submissions; not physical display presentation timestamps."};
    NSData *data=[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil];
    [data writeToFile:NSProcessInfo.processInfo.arguments[2] atomically:YES];[NSApp terminate:nil];
}
@end
int main(void) { @autoreleasepool { NSApplication *app=NSApplication.sharedApplication;StartupQA *qa=[[StartupQA alloc] init];app.delegate=qa;[app setActivationPolicy:NSApplicationActivationPolicyAccessory];[app run]; } return 0; }
