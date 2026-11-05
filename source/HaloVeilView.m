// Modified from HALOFLUX by Ryder191. https://github.com/Ryder191/haloflux
// Personal, noncommercial use. See the complete bundled LICENSE.
#import "HaloVeilView.h"
#import "Version.h"
#import <WebKit/WebKit.h>
#import <CommonCrypto/CommonDigest.h>
#import <objc/message.h>
#import <os/log.h>
#import <sys/file.h>
#import <fcntl.h>
#import <unistd.h>

static NSString *const ClaimNotification = @"dev.haloveil.claim-display.v1";
static NSUInteger ExitGeneration = 0;
static NSMapTable<NSNumber *,HaloVeilView *> *Owners(void) {
    static NSMapTable *value; static dispatch_once_t once;
    dispatch_once(&once, ^{ value=[NSMapTable strongToWeakObjectsMapTable]; }); return value;
}
static NSHashTable<HaloVeilView *> *Views(void) {
    static NSHashTable *value; static dispatch_once_t once;
    dispatch_once(&once, ^{ value=[NSHashTable weakObjectsHashTable]; }); return value;
}
static NSString *SHA256(NSData *data) {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH]; CC_SHA256(data.bytes,(CC_LONG)data.length,digest);
    NSMutableString *value=[NSMutableString string];
    for(NSUInteger i=0;i<sizeof(digest);i++) [value appendFormat:@"%02x",digest[i]]; return value;
}
static void Log(NSString *event,NSDictionary *fields) {
    NSMutableDictionary *record=[fields mutableCopy]; record[@"event"]=event; record[@"nativeRevision"]=HALOVEIL_VERSION;
    if([event isEqualToString:@"frame"]){
        // Keep startup samples below Unified Logging's message size limit.
        NSSet *keys=[NSSet setWithArray:@[@"event",@"nativeRevision",@"webRevision",@"build",@"instanceID",@"sessionID",@"screenID",@"running",@"pageReady",@"hasWebView",@"hasLease",@"activeInstancesInProcess",@"activeInstancesForDisplay",@"frames",@"measuredFPS",@"drawP95MS",@"gapP95MS",@"maxFrameMS",@"slotBuildCount",@"layoutBuilds",@"resizeSkips",@"warmupFrames",@"warmupMS",@"errors"]];
        for(NSString *key in record.allKeys)if(![keys containsObject:key])[record removeObjectForKey:key];
    }
    NSData *data=[NSJSONSerialization dataWithJSONObject:record options:0 error:nil];
    NSString *text=[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    os_log_with_type(os_log_create("dev.haloveil.screensaver","performance"),OS_LOG_TYPE_DEFAULT,"HALOVEIL metrics %{public}@",text?:@"{}");
}
@interface HaloVeilView () <WKNavigationDelegate>
@property(nonatomic,strong) WKWebView *webView;
@property(nonatomic,strong) NSView *startupCover;
@property(nonatomic,strong) NSURL *resources;
@property(nonatomic,strong) NSNumber *screenKey;
@property(nonatomic,weak) NSWindow *observedWindow;
@property(nonatomic,copy) NSString *instanceID;
@property(nonatomic,copy) NSString *sessionID;
@property(nonatomic,copy) NSString *leasePath;
@property(nonatomic,copy) NSString *lastError;
@property(nonatomic) BOOL running,pageReady,framePending,seenVisible,sleeping;
@property(nonatomic) BOOL preparing,presented;
@property(nonatomic) NSTimeInterval startupAt,startupReadyMS;
@property(nonatomic) NSInteger leaseFD;
@property(nonatomic) NSUInteger generation;
@property(nonatomic) NSInteger peakWindowLevel;
@property(nonatomic) NSTimeInterval claimEpoch,nextAttempt,nextDiagnostics;
@end
@implementation HaloVeilView
- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)preview {
    self=[super initWithFrame:frame isPreview:preview]; if(self)[self prepare]; return self;
}
- (instancetype)initWithCoder:(NSCoder *)coder { self=[super initWithCoder:coder];if(self)[self prepare];return self; }
- (void)prepare {
    self.leaseFD=-1; self.instanceID=NSUUID.UUID.UUIDString;
    self.animationTimeInterval=self.isPreview?1.0:1.0/60.0;
    self.resources=[NSBundle bundleForClass:HaloVeilView.class].resourceURL;
    self.wantsLayer=YES;self.layer.backgroundColor=[NSColor colorWithWhite:0.032 alpha:1].CGColor;
    [Views() addObject:self];
    if(self.isPreview){
        NSImageView *image=[[NSImageView alloc] initWithFrame:self.bounds];
        image.image=[[NSImage alloc] initWithContentsOfURL:[self.resources URLByAppendingPathComponent:@"thumbnail.png"]];
        image.imageScaling=NSImageScaleProportionallyUpOrDown;image.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
        [self addSubview:image];
    }
}
- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [NSDistributedNotificationCenter.defaultCenter removeObserver:self];
    [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self];
    if(_leaseFD>=0){flock((int)_leaseFD,LOCK_UN);close((int)_leaseFD);}
    _webView.navigationDelegate=nil;[_webView stopLoading];
}
- (BOOL)hasConfigureSheet{return NO;}
- (BOOL)acceptsFirstResponder{return NO;}
- (NSView *)hitTest:(NSPoint)point{return self;}
+ (BOOL)validateResourcesAtURL:(NSURL *)resources error:(NSError **)error {
    NSData *data=[NSData dataWithContentsOfURL:[resources URLByAppendingPathComponent:@"manifest.json"]];
    BOOL valid=data&&[SHA256(data) isEqualToString:HALOVEIL_MANIFEST_SHA];
    NSDictionary *manifest=valid?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
    valid=[manifest isKindOfClass:NSDictionary.class]&&manifest.count>0;
    for(NSString *path in manifest){
        if(![path hasPrefix:@"web/"]||[path.pathComponents containsObject:@".."]||![manifest[path] isKindOfClass:NSString.class]){valid=NO;break;}
        NSData *file=[NSData dataWithContentsOfURL:[resources URLByAppendingPathComponent:path]];
        if(!file||![SHA256(file) isEqualToString:manifest[path]]){valid=NO;break;}
    }
    if(!valid&&error)*error=[NSError errorWithDomain:@"HaloVeil" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Saver and web resources do not match. Reinstall the complete package."}];
    return valid;
}
- (BOOL)validateBundle {
    NSURL *url=[[NSBundle bundleForClass:HaloVeilView.class].bundleURL URLByAppendingPathComponent:@"Contents/Info.plist"];
    NSDictionary *info=[NSDictionary dictionaryWithContentsOfURL:url];
    if(![info[@"CFBundleShortVersionString"] isEqualToString:HALOVEIL_VERSION]||![info[@"CFBundleVersion"] isEqualToString:[@(HALOVEIL_BUILD) stringValue]]){
        self.lastError=@"An older saver is cached. Exit and reload the screen saver.";return NO;
    }
    NSError *error=nil;
    if(![HaloVeilView validateResourcesAtURL:self.resources error:&error]){self.lastError=error.localizedDescription;return NO;}
    return YES;
}
- (NSNumber *)displayIdentifier{return (self.window.screen?:NSScreen.mainScreen).deviceDescription[@"NSScreenNumber"]?:@0;}
+ (NSDictionary *)activeState {
    NSUInteger sessions=0,resources=0;NSMutableDictionary *screens=[NSMutableDictionary dictionary];
    for(HaloVeilView *view in Views().allObjects){
        if(view.running&&!view.isPreview)sessions++;
        if(view.webView){resources++;NSString *key=view.screenKey.stringValue?:@"unknown";screens[key]=@([screens[key] unsignedIntegerValue]+1);}
    }
    return @{@"sessions":@(sessions),@"webViews":@(resources),@"screens":screens};
}
- (NSDictionary *)lifecycleState {
    NSDictionary *all=[HaloVeilView activeState];
    return @{@"instanceID":self.instanceID,@"sessionID":self.sessionID?:@"",@"screenID":self.screenKey?:@0,
        @"running":@(self.running),@"pageReady":@(self.pageReady),@"hasWebView":@(self.webView!=nil),@"hasLease":@(self.leaseFD>=0),
        @"leasePath":self.leasePath?:@"",@"generation":@(self.generation),@"nativeRevision":HALOVEIL_VERSION,
        @"activeInstancesInProcess":all[@"webViews"],@"activeInstancesForDisplay":all[@"screens"][self.screenKey.stringValue?:@""]?:@0,
        @"preparing":@(self.preparing),@"presented":@(self.presented),@"startupReadyMS":@(self.startupReadyMS),@"error":self.lastError?:@""};
}
- (void)registerSignals {
    NSDistributedNotificationCenter *center=NSDistributedNotificationCenter.defaultCenter;
    for(NSString *name in @[@"com.apple.screensaver.willstop",@"com.apple.screensaver.didstop",@"com.apple.screenIsUnlocked"])
        [center addObserver:self selector:@selector(saverWillStop:) name:name object:nil suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
    [center addObserver:self selector:@selector(otherClaim:) name:ClaimNotification object:nil suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
    NSNotificationCenter *workspace=NSWorkspace.sharedWorkspace.notificationCenter;
    [workspace addObserver:self selector:@selector(displayDidSleep:) name:NSWorkspaceScreensDidSleepNotification object:nil];
    [workspace addObserver:self selector:@selector(displayDidWake:) name:NSWorkspaceScreensDidWakeNotification object:nil];
    [self observeWindow];
}
- (void)observeWindow {
    NSNotificationCenter *center=NSNotificationCenter.defaultCenter;
    if(self.observedWindow)[center removeObserver:self name:nil object:self.observedWindow];
    self.observedWindow=self.window;
    if(self.window){
        [center addObserver:self selector:@selector(windowWillClose:) name:NSWindowWillCloseNotification object:self.window];
        [center addObserver:self selector:@selector(windowScreenChanged:) name:NSWindowDidChangeScreenNotification object:self.window];
        [center addObserver:self selector:@selector(windowWillClose:) name:NSWindowDidMiniaturizeNotification object:self.window];
    }
}
- (void)requestHostExitIfIdle {
    NSString *process=NSProcessInfo.processInfo.processName,*identifier=NSBundle.mainBundle.bundleIdentifier?:@"";
    if(![process hasPrefix:@"legacyScreenSaver"]||![identifier hasPrefix:@"com.apple.ScreenSaver.Engine"]||[[HaloVeilView activeState][@"sessions"] unsignedIntegerValue])return;
    NSUInteger ticket=++ExitGeneration;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/5),dispatch_get_main_queue(),^{
        if(ticket!=ExitGeneration||[[HaloVeilView activeState][@"sessions"] unsignedIntegerValue])return;
        Log(@"host-exit",@{@"reason":@"no active HALOVEIL sessions"});
        // Sonoma may retain retired saver views indefinitely. This only exits
        // the dedicated saver extension, never login/credential or preview apps.
        _exit(EXIT_SUCCESS);
    });
}
- (void)startAnimation {
    if(self.isPreview){if(!self.isAnimating)[super startAnimation];return;}
    if(self.running)return;
    if(![self validateBundle]){[self showError:self.lastError];return;}
    ExitGeneration++;self.running=YES;self.seenVisible=NO;self.sleeping=NO;self.lastError=nil;self.peakWindowLevel=NSIntegerMin;
    self.startupAt=NSProcessInfo.processInfo.systemUptime;self.startupReadyMS=0;
    self.generation++;self.sessionID=NSUUID.UUID.UUIDString;self.claimEpoch=NSProcessInfo.processInfo.systemUptime;
    self.nextAttempt=self.nextDiagnostics=0;[self registerSignals];[super startAnimation];[self activateForWindow];
}
- (void)stopAnimation {
    BOOL wasRunning=self.running;self.running=NO;self.generation++;
    [NSNotificationCenter.defaultCenter removeObserver:self];[NSDistributedNotificationCenter.defaultCenter removeObserver:self];
    [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self];self.observedWindow=nil;
    [self unloadAnimation];[self releaseClaim];[super stopAnimation];
    if(wasRunning){Log(@"stop",[self lifecycleState]);[self requestHostExitIfIdle];}
}
- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    if(!self.window){[self stopAnimation];return;}
    if(self.running){[self observeWindow];[self activateForWindow];}
}
- (void)layout {
    [super layout];self.webView.frame=self.bounds;
    self.webView.pageZoom=MIN(1.0,MAX(0.1,self.bounds.size.width/1440.0));
}
- (void)windowWillClose:(NSNotification *)note{[self stopAnimation];}
- (void)windowScreenChanged:(NSNotification *)note{[self activateForWindow];}
- (void)saverWillStop:(NSNotification *)note{[self stopAnimation];}
- (void)displayDidSleep:(NSNotification *)note {
    self.sleeping=YES;[super stopAnimation];[self unloadAnimation];[self releaseClaim];
}
- (void)displayDidWake:(NSNotification *)note {
    self.sleeping=NO;if(self.running){[super startAnimation];[self activateForWindow];}
}
- (void)releaseClaim {
    if(self.leaseFD>=0){flock((int)self.leaseFD,LOCK_UN);close((int)self.leaseFD);self.leaseFD=-1;}
    if(self.screenKey&&[Owners() objectForKey:self.screenKey]==self)[Owners() removeObjectForKey:self.screenKey];
}
- (void)activateForWindow {
    if(!self.running||self.isPreview||!self.window||!self.window.isVisible)return;
    self.seenVisible=YES;NSNumber *screen=[self displayIdentifier];
    if(![self.screenKey isEqual:screen]||[Owners() objectForKey:screen]!=self){
        [self unloadAnimation];[self releaseClaim];self.screenKey=screen;
        HaloVeilView *previous=[Owners() objectForKey:screen];if(previous&&previous!=self)[previous stopAnimation];
        [Owners() setObject:self forKey:screen];self.claimEpoch=NSProcessInfo.processInfo.systemUptime;self.nextAttempt=0;
        // Sandboxed saver extensions cannot post a userInfo dictionary. Encode
        // the small claim in the permitted string object instead.
        NSData *claim=[NSJSONSerialization dataWithJSONObject:@{@"screen":screen,@"session":self.sessionID,@"epoch":@(self.claimEpoch)} options:0 error:nil];
        NSString *sender=[[NSString alloc] initWithData:claim encoding:NSUTF8StringEncoding];
        [NSDistributedNotificationCenter.defaultCenter postNotificationName:ClaimNotification object:sender userInfo:nil deliverImmediately:YES];
    }
    if(self.leaseFD<0){
        NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;if(now<self.nextAttempt)return;self.nextAttempt=now+0.1;
        NSURL *cache=[NSFileManager.defaultManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject;
        NSURL *directory=[cache URLByAppendingPathComponent:@"HaloVeil/leases" isDirectory:YES];
        [NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:nil];
        self.leasePath=[directory URLByAppendingPathComponent:[NSString stringWithFormat:@"display-%@.lock",screen]].path;
        int fd=open(self.leasePath.fileSystemRepresentation,O_CREAT|O_RDWR|O_CLOEXEC,0600);
        if(fd<0){[self showError:@"Cannot acquire the display lease. Exit and try again."];return;}
        if(flock(fd,LOCK_EX|LOCK_NB)!=0){close(fd);return;}self.leaseFD=fd;
    }
    if(!self.webView)[self loadAnimation];
}
- (void)otherClaim:(NSNotification *)note {
    if(![note.object isKindOfClass:NSString.class])return;
    NSData *data=[note.object dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *claim=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if(![claim isKindOfClass:NSDictionary.class]||![claim[@"session"] isKindOfClass:NSString.class])return;
    if(!self.running||![claim[@"screen"] isEqual:self.screenKey]||[claim[@"session"] isEqual:self.sessionID])return;
    NSTimeInterval epoch=[claim[@"epoch"] doubleValue];
    BOOL newer=epoch>self.claimEpoch||(epoch==self.claimEpoch&&[claim[@"session"] compare:self.sessionID]==NSOrderedDescending);
    if(newer)[self stopAnimation];
}
- (void)animateOneFrame {
    if(!self.running||self.isPreview||self.sleeping)return;
    if(!self.window){if(NSProcessInfo.processInfo.systemUptime-self.claimEpoch>2)[self stopAnimation];return;}
    if(self.seenVisible&&(!self.window.isVisible||self.isHiddenOrHasHiddenAncestor)){[self stopAnimation];return;}
    // Sonoma can demote a retired saver window to a wallpaper-level window
    // without detaching the view or calling stopAnimation.
    NSInteger level=self.window.level;
    if(self.seenVisible&&self.peakWindowLevel!=NSIntegerMin&&level<self.peakWindowLevel){[self stopAnimation];return;}
    self.peakWindowLevel=MAX(self.peakWindowLevel,level);
    if(!self.webView)[self activateForWindow];WKWebView *view=self.webView;
    if(self.preparing){[self prepareOneFrame];return;}
    if(!self.pageReady||!view||self.framePending||self.leaseFD<0||[Owners() objectForKey:self.screenKey]!=self)return;
    self.framePending=YES;NSUInteger generation=self.generation;NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;
    BOOL diagnostics=now>=self.nextDiagnostics;if(diagnostics)self.nextDiagnostics=now+(now-self.startupAt<6?1:5);
    NSString *script=diagnostics?@"HALOVEILHost.tick(); HALOVEILHost.getState()":@"HALOVEILHost.tick()";
    __weak HaloVeilView *weakSelf=self;__weak WKWebView *weakView=view;
    [view evaluateJavaScript:script completionHandler:^(id result,NSError *error){
        HaloVeilView *self=weakSelf;if(!self||weakView!=self.webView||generation!=self.generation)return;
        self.framePending=NO;
        if(diagnostics&&[result isKindOfClass:NSDictionary.class]){
            NSMutableDictionary *metrics=[result mutableCopy];[metrics addEntriesFromDictionary:[self lifecycleState]];Log(@"frame",metrics);
            if(!self.presented&&[result[@"frames"] unsignedIntegerValue]>0)[self revealAnimation];
        }
    }];
}
- (void)prepareOneFrame {
    if(self.framePending||!self.webView)return;
    self.framePending=YES;NSUInteger generation=self.generation;
    __weak HaloVeilView *weakSelf=self;__weak WKWebView *weakView=self.webView;
    [self.webView evaluateJavaScript:@"HALOVEILHost.prepareFrame()" completionHandler:^(id result,NSError *error){
        HaloVeilView *self=weakSelf;if(!self||weakView!=self.webView||generation!=self.generation)return;
        self.framePending=NO;
        if(error){[self showError:@"Startup preparation failed. Restart the screen saver."];return;}
        if(![result isKindOfClass:NSDictionary.class]||![result[@"prepared"] boolValue])return;
        self.preparing=NO;self.startupReadyMS=(NSProcessInfo.processInfo.systemUptime-self.startupAt)*1000;
        NSMutableDictionary *record=[result mutableCopy];record[@"startupReadyMS"]=@(self.startupReadyMS);record[@"sessionID"]=self.sessionID;Log(@"prepared",record);
        [self.webView evaluateJavaScript:@"HALOVEILHost.setActive(true)" completionHandler:^(id value,NSError *activationError){
            HaloVeilView *self=weakSelf;if(!self||weakView!=self.webView||generation!=self.generation)return;
            self.pageReady=activationError==nil&&self.running;self.nextDiagnostics=0;
        }];
    }];
}
- (void)revealAnimation {
    self.presented=YES;
    __weak HaloVeilView *weakSelf=self;__weak NSView *weakCover=self.startupCover;
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
        context.duration=0.18;self.startupCover.animator.alphaValue=0;
    } completionHandler:^{
        NSView *cover=weakCover;[cover removeFromSuperview];
        HaloVeilView *self=weakSelf;if(self.startupCover==cover)self.startupCover=nil;
    }];
}
- (void)loadAnimation {
    WKWebViewConfiguration *config=[[WKWebViewConfiguration alloc] init];config.websiteDataStore=WKWebsiteDataStore.nonPersistentDataStore;
    config.preferences.javaScriptCanOpenWindowsAutomatically=NO;config.mediaTypesRequiringUserActionForPlayback=WKAudiovisualMediaTypeAll;
    NSString *script=[NSString stringWithFormat:@"window.HALOVEIL_NATIVE=true;window.HALOVEIL_NATIVE_FRAME_DRIVER=true;window.HALOVEIL_NATIVE_RELEASE={version:'%@',build:%d,assetDigest:'%@'};",HALOVEIL_VERSION,HALOVEIL_BUILD,HALOVEIL_ASSET_DIGEST];
    [config.userContentController addUserScript:[[WKUserScript alloc] initWithSource:script injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES]];
    WKWebView *view=[[WKWebView alloc] initWithFrame:self.bounds configuration:config];view.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
    view.navigationDelegate=self;view.pageZoom=MIN(1.0,MAX(0.1,self.bounds.size.width/1440.0));view.underPageBackgroundColor=[NSColor colorWithWhite:0.032 alpha:1];
    SEL selector=NSSelectorFromString(@"_setWindowOcclusionDetectionEnabled:");if([view respondsToSelector:selector])((void(*)(id,SEL,BOOL))objc_msgSend)(view,selector,NO);
    self.webView=view;[self addSubview:view];
    NSView *cover=[[NSView alloc] initWithFrame:self.bounds];cover.wantsLayer=YES;cover.layer.backgroundColor=[NSColor colorWithWhite:0.032 alpha:1].CGColor;
    cover.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;self.startupCover=cover;[self addSubview:cover];
    NSURL *web=[self.resources URLByAppendingPathComponent:@"web" isDirectory:YES];
    [view loadFileURL:[web URLByAppendingPathComponent:@"index.html"] allowingReadAccessToURL:web];Log(@"load",[self lifecycleState]);
}
- (void)unloadAnimation {
    self.pageReady=NO;self.preparing=NO;self.presented=NO;self.framePending=NO;
    [self.startupCover removeFromSuperview];self.startupCover=nil;WKWebView *view=self.webView;self.webView=nil;if(!view)return;
    view.navigationDelegate=nil;[view evaluateJavaScript:@"window.HALOVEILHost?.dispose()" completionHandler:nil];
    [view stopLoading];[view removeFromSuperview];
}
- (void)webView:(WKWebView *)view didFinishNavigation:(WKNavigation *)navigation {
    NSUInteger generation=self.generation;__weak HaloVeilView *weakSelf=self;__weak WKWebView *weakView=view;
    [view evaluateJavaScript:@"window.HALOVEIL_RELEASE || null" completionHandler:^(id result,NSError *error){
        HaloVeilView *self=weakSelf;if(!self||weakView!=self.webView||generation!=self.generation)return;
        BOOL matched=[result isKindOfClass:NSDictionary.class]&&[result[@"version"] isEqualToString:HALOVEIL_VERSION]&&[result[@"build"] intValue]==HALOVEIL_BUILD&&[result[@"assetDigest"] isEqualToString:HALOVEIL_ASSET_DIGEST];
        if(!matched||error){[self showError:@"Web and native versions do not match. Reinstall the complete package."];return;}
        self.preparing=YES;
    }];
}
- (void)webView:(WKWebView *)view decidePolicyForNavigationAction:(WKNavigationAction *)action decisionHandler:(void(^)(WKNavigationActionPolicy))handler {
    NSURL *url=action.request.URL;NSString *prefix=[[self.resources URLByAppendingPathComponent:@"web"].URLByStandardizingPath.path stringByAppendingString:@"/"];
    handler(url.isFileURL&&[url.URLByStandardizingPath.path hasPrefix:prefix]&&action.targetFrame?WKNavigationActionPolicyAllow:WKNavigationActionPolicyCancel);
}
- (void)webView:(WKWebView *)view didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if(view==self.webView&&error.code!=NSURLErrorCancelled)[self showError:@"Cannot load the screen saver. Please restart it."];}
- (void)webView:(WKWebView *)view didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if(view==self.webView&&error.code!=NSURLErrorCancelled)[self showError:@"Cannot load the screen saver. Please restart it."];}
- (void)webViewWebContentProcessDidTerminate:(WKWebView *)view {
    if(view==self.webView)[self showError:@"The screen saver stopped. Exit and restart it."];}
- (void)showError:(NSString *)message {
    [self stopAnimation];self.lastError=message;
    for(NSView *view in self.subviews.copy)[view removeFromSuperview];
    NSTextField *label=[NSTextField wrappingLabelWithString:message];label.textColor=NSColor.lightGrayColor;label.alignment=NSTextAlignmentCenter;
    label.frame=NSInsetRect(self.bounds,24,MAX(24,self.bounds.size.height/2-24));label.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
    [self addSubview:label];Log(@"error",[self lifecycleState]);
}
@end
