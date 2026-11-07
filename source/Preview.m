// A windowed preview of the native renderer, without installing a screen saver.
#import <Cocoa/Cocoa.h>
#import <ScreenSaver/ScreenSaver.h>

@interface PreviewDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) ScreenSaverView *saver;
@property(nonatomic, strong) NSBundle *saverBundle;
@end

@implementation PreviewDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSMenu *menu = [[NSMenu alloc] init];
    NSMenuItem *applicationMenuItem = [[NSMenuItem alloc] init];
    NSMenu *applicationMenu = [[NSMenu alloc] initWithTitle:@"HaloVeil Preview"];
    [applicationMenu addItemWithTitle:@"Quit HaloVeil Preview"
                              action:@selector(terminate:) keyEquivalent:@"q"];
    applicationMenuItem.submenu = applicationMenu;
    [menu addItem:applicationMenuItem];
    NSApp.mainMenu = menu;
    NSURL *url = [NSBundle.mainBundle.builtInPlugInsURL URLByAppendingPathComponent:@"HaloVeilRenderer.bundle"];
    // Release builds still embed the installable saver. Development builds use
    // a private renderer bundle so updating Preview does not rebuild that saver.
    if (![NSFileManager.defaultManager fileExistsAtPath:url.path])
        url = [NSBundle.mainBundle.builtInPlugInsURL URLByAppendingPathComponent:@"HaloVeil.saver"];
    self.saverBundle = [NSBundle bundleWithURL:url];
    NSError *error = nil;
    if (![self.saverBundle loadAndReturnError:&error]) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Cannot open HaloVeil Preview";
        alert.informativeText = error.localizedDescription ?: @"Extract the complete package and try again.";
        [alert runModal];
        [NSApp terminate:nil];
        return;
    }
    NSRect frame = NSMakeRect(0, 0, MIN(1600, NSScreen.mainScreen.visibleFrame.size.width - 40), MIN(1000, NSScreen.mainScreen.visibleFrame.size.height - 60));
    self.window = [[NSWindow alloc] initWithContentRect:frame
               styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                         NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                 backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"HaloVeil · Silent Preview (close window to quit)";
    self.window.minSize = NSMakeSize(640, 440);
    self.window.delegate = self;
    self.window.releasedWhenClosed = NO;
    self.saver = [[self.saverBundle.principalClass alloc] initWithFrame:frame isPreview:NO];
    self.window.contentView = self.saver;
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    [self.saver startAnimation];
    [NSApp activateIgnoringOtherApps:YES];
}
- (void)windowWillClose:(NSNotification *)notification {
    [self.saver stopAnimation];
    [NSApp terminate:nil];
}
- (void)applicationWillTerminate:(NSNotification *)notification { [self.saver stopAnimation]; }
- (void)windowDidMiniaturize:(NSNotification *)notification { [self.saver stopAnimation]; }
- (void)windowDidDeminiaturize:(NSNotification *)notification { [self.saver startAnimation]; }
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { return YES; }
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        PreviewDelegate *delegate = [[PreviewDelegate alloc] init];
        app.delegate = delegate;
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        [app run];
    }
    return 0;
}
