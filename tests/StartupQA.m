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
@property NSDictionary *panelChecks;
@property NSInteger cycle, targetCycles;
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
    const char *cycleValue=getenv("HALOVEIL_TEST_CYCLES");char *cycleEnd=NULL;
    self.targetCycles=cycleValue?strtol(cycleValue,&cycleEnd,10):3;
    if(self.targetCycles<1||(cycleValue&&(cycleEnd==cycleValue||*cycleEnd))){
        fprintf(stderr,"HALOVEIL_TEST_CYCLES must be a positive integer\n");exit(2);
    }
    self.bundle=[NSBundle bundleWithPath:NSProcessInfo.processInfo.arguments[1]];
    NSError *error=nil;
    if (![self.bundle loadAndReturnError:&error]) { NSLog(@"%@",error); exit(2); }
    self.fixture=objc_allocateClassPair(self.bundle.principalClass,"HaloVeilStartupFixture",0);
    class_addMethod(self.fixture,@selector(displayIdentifier),(IMP)StartupDisplay,"@@:");objc_registerClassPair(self.fixture);
    if(getenv("HALOVEIL_TEST_AGENT_STATUS"))class_addMethod(self.fixture,@selector(agentStatusURL),(IMP)StatusFixtureURL,"@@:");
    BOOL visible=getenv("HALOVEIL_TEST_VISIBLE")!=NULL;
    // Match Preview.m's actual default content size, including smaller screens.
    NSRect frame=NSMakeRect(visible?0:-20000,visible?0:-20000,
        MIN(1600,NSScreen.mainScreen.visibleFrame.size.width-40),
        MIN(1000,NSScreen.mainScreen.visibleFrame.size.height-60));
    self.window=[[StartupWindow alloc] initWithContentRect:frame
        styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|
                  NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered defer:NO];
    self.window.title=@"HaloVeil Preview · Startup check";
    if(visible){[self.window center];[NSApp activateIgnoringOtherApps:YES];}
    [self.window makeKeyAndOrderFront:nil];[self start];
}
- (void)start {
    self.samples=[NSMutableArray array];self.firstFrame=0;self.started=NSProcessInfo.processInfo.systemUptime;
    self.view=[[self.fixture alloc] initWithFrame:self.window.contentView.bounds isPreview:NO];
    self.window.contentView=self.view;[self.view startAnimation];
    WKUserScript *script=[[WKUserScript alloc] initWithSource:[self probe] injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
    [self.web.configuration.userContentController addUserScript:script];
    [self poll];
}
- (void)poll {
    if(!self.web){
        if(NSProcessInfo.processInfo.systemUptime-self.started>25){fprintf(stderr,"Startup test lost its web view\n");exit(3);}
        [self later:0.08 block:^{[self poll];}];return;
    }
    NSString *script=[[self probe] stringByAppendingString:@"; JSON.stringify({state:window.HALOVEILHost?.getState()||null,probe:window.__HALOProbe||null,agent:{badge:document.getElementById('codexBadge').textContent,usage:document.getElementById('codexWindows').textContent,expiry:document.getElementById('codexExpiry').textContent,count:document.getElementById('codexResetCount').textContent}})"];
    [self.web evaluateJavaScript:script completionHandler:^(id value,NSError *error){
        NSDictionary *result=[value isKindOfClass:NSString.class]?[NSJSONSerialization JSONObjectWithData:[value dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil]:nil;
        NSDictionary *state=[result[@"state"] isKindOfClass:NSDictionary.class]?result[@"state"]:nil;
        double now=NSProcessInfo.processInfo.systemUptime;
        if ([state[@"frames"] integerValue]>0 && self.firstFrame==0) self.firstFrame=now;
        if(state) [self.samples addObject:@{@"atMS":@((now-self.started)*1000),@"state":state,@"lifecycle":self.view.lifecycleState,@"agent":result[@"agent"]?:@{}}];
        if(self.firstFrame && now-self.firstFrame>=10.2) {
            NSDictionary *geometry=@{@"width":@(self.view.bounds.size.width),@"height":@(self.view.bounds.size.height),
                @"backingScaleFactor":@(self.window.backingScaleFactor),@"pageZoom":@(self.web.pageZoom)};
            [self.cycles addObject:@{@"cycle":@(self.cycle+1),@"firstFrameMS":@((self.firstFrame-self.started)*1000),
                @"geometry":geometry,@"samples":self.samples,@"probe":result[@"probe"]?:@{}}];
            if(self.cycle+1==self.targetCycles){
                [self verifyPanels];
            }else[self endCycle];
        } else if (now-self.started>25) { NSLog(@"startup timed out %@",self.view.lifecycleState);exit(3); }
        // Watch startup closely, then reduce cross-process sampling during
        // playback so diagnostics do not compete with the animation clock.
        else [self later:self.firstFrame?0.5:0.08 block:^{[self poll];}];
    }];
}
- (void)verifyPanels {
    // Read DOM/layout once after pacing capture, so the checks cannot perturb
    // the measured startup frames.
    NSString *script=@"(() => {"
        "const grid=document.querySelector('.panels'),panels=Array.from(grid?.children||[]);"
        "const codex=document.getElementById('codexStatus'),agents=document.getElementById('agents');"
        "const rows=Array.from(agents?.children||[]).filter(row=>row.classList.contains('ag'));"
        "const state=window.HALOVEILHost?.getState(),roles=['read','build','review','qa'];"
        "return {"
        "codexFirst:!!codex&&codex.closest('.p')===panels[0],"
        "dispatchSeventh:!!agents&&agents.closest('.p')===panels[6],"
        "fourColumns:!!grid&&getComputedStyle(grid).gridTemplateColumns.trim().split(/\\s+/).length===4,"
        "eightPanels:panels.length===8&&panels.every(panel=>panel.classList.contains('p')),"
        "twelveAgentRows:rows.length===12,"
        "sixCellsEach:rows.length===12&&rows.every(row=>row.querySelectorAll('.cells > i').length===6),"
        "threeEachRole:roles.every(role=>rows.filter(row=>row.querySelector('.rl')?.textContent.trim()===role).length===3),"
        "validStates:rows.length===12&&rows.every(row=>['dispatch','working','idle'].includes(row.querySelector('.st')?.textContent.trim())),"
        "animationUpdated:state?.agentPanel?.rows===12&&state.agentPanel.updates>state.agentPanel.rows,"
        "noFeed:document.getElementById('feed')===null"
        "};})()";
    [self.web evaluateJavaScript:script completionHandler:^(id value,NSError *error){
        self.panelChecks=[value isKindOfClass:NSDictionary.class]?value:@{};
        if(error||self.panelChecks.count!=10){NSLog(@"Panel checks failed %@: %@",self.panelChecks,error);exit(4);}
        for(NSNumber *passed in self.panelChecks.allValues)if(!passed.boolValue){NSLog(@"Panel checks failed %@",self.panelChecks);exit(4);}
        [self verifyStatusAndSnapshot];
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
        "s=base();s.refreshIntervalSecs=3600;s.fetchedAt=now-1800;update(s);checks.hourlyFresh=el('codexBadge').textContent==='SYNCED';"
        "s=base();s.refreshIntervalSecs=3600;s.fetchedAt=now-4501;update(s);checks.hourlyStale=el('codexBadge').textContent==='STALE';"
        "s=base();s.fullReset.availableCount=null;s.limits[0].windows[0].usedPercent=null;update(s);checks.unknown=el('codexResetCount').textContent==='UNKNOWN'&&el('codexWindows').textContent.includes('usage unknown');"
        "s=base();s.limits[0].windows[0].resetsAt=now-1;s.fullReset.expiresAt=now-1;update(s);checks.elapsed=el('codexWindows').textContent.includes('awaiting sync')&&el('codexExpiry').textContent.includes('awaiting sync');"
        "s=base();s.limits[0].id='other';s.limits[0].name='<img src=x onerror=alert(1)>';update(s);checks.textOnly=el('codexWindows').querySelector('img')===null&&el('codexWindows').textContent.includes('<img');"
        "s=base();s.fetchedAt=now+120;update(s);checks.future=el('codexBadge').textContent==='NO DATA';"
        "update({state:'unavailable'});checks.missing=el('codexBadge').textContent==='NO DATA'&&el('codexResetCount').textContent==='UNKNOWN';"
        "update(restore);return checks;";
    [self.web callAsyncJavaScript:script arguments:@{@"restore":restore?:@{}} inFrame:nil inContentWorld:WKContentWorld.pageWorld completionHandler:^(id value,NSError *error){
        self.statusChecks=[value isKindOfClass:NSDictionary.class]?value:@{};
        if(error||self.statusChecks.count!=9){NSLog(@"Account status UI checks failed");exit(4);}
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
    NSRect bounds=self.window.contentView.bounds;
    [self.view stopAnimation];self.window.contentView=[[NSView alloc] initWithFrame:bounds];self.view=nil;self.cycle++;
    if(self.cycle<self.targetCycles)[self later:0.3 block:^{[self start];}];else[self finish];
}
- (void)finish {
    NSString *note=getenv("HALOVEIL_TEST_VISIBLE")?@"Visible WKWebView draw submissions; not physical display presentation timestamps.":@"Offscreen WKWebView draw submissions; not physical display presentation timestamps.";
    NSDictionary *report=@{@"cycles":self.cycles,@"requestedCycles":@(self.targetCycles),@"statusChecks":self.statusChecks?:@{},@"panelChecks":self.panelChecks?:@{},@"physicalDisplayCount":@(NSScreen.screens.count),@"finalActiveState":[(id)self.fixture activeState],@"note":note};
    NSData *data=[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil];
    [data writeToFile:NSProcessInfo.processInfo.arguments[2] atomically:YES];[NSApp terminate:nil];
}
@end
int main(void) { @autoreleasepool { NSApplication *app=NSApplication.sharedApplication;StartupQA *qa=[[StartupQA alloc] init];app.delegate=qa;[app setActivationPolicy:getenv("HALOVEIL_TEST_VISIBLE")?NSApplicationActivationPolicyRegular:NSApplicationActivationPolicyAccessory];[app run]; } return 0; }
