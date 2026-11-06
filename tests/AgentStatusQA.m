#import "../source/AgentStatus.h"

int main(void) { @autoreleasepool {
    NSString *directory=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    NSURL *url=[NSURL fileURLWithPath:[directory stringByAppendingPathComponent:@"status.json"]];
    __block NSUInteger checks=0;
    void (^check)(BOOL)=^(BOOL passed){checks++;if(!passed){NSLog(@"Status reader check %lu failed",(unsigned long)checks);exit(1);}};
    void (^write)(id)=^(id value){
        [[NSJSONSerialization dataWithJSONObject:value options:0 error:nil] writeToURL:url atomically:YES];chmod(url.fileSystemRepresentation,0600);
    };
    check([ReadAgentStatus(url)[@"state"] isEqual:@"unavailable"]);
    NSDictionary *valid=@{@"schemaVersion":@1,@"provider":@"codex",@"state":@"ok",@"fetchedAt":@1000,
        @"accountId":@"should-not-pass",@"limits":@[@{@"id":@"codex",@"name":@"Codex",@"windows":@[@{@"name":@"primary",@"usedPercent":@2,@"windowDurationMins":@10080,@"resetsAt":@5000}]}],
        @"fullReset":@{@"availableCount":@3,@"expiresAt":@4000,@"detailsKnown":@YES}};
    write(valid);NSDictionary *result=ReadAgentStatus(url);
    check([result[@"state"] isEqual:@"ok"]&&[result[@"fullReset"][@"expiresAt"] isEqual:@4000]);
    check(result[@"accountId"]==nil&&[result[@"limits"][0][@"windows"][0][@"usedPercent"] isEqual:@2]);
    chmod(url.fileSystemRepresentation,0644);check([ReadAgentStatus(url)[@"state"] isEqual:@"unavailable"]);
    write(@[]);check([ReadAgentStatus(url)[@"state"] isEqual:@"unavailable"]);
    NSMutableDictionary *bad=[valid mutableCopy];bad[@"schemaVersion"]=@YES;write(bad);check([ReadAgentStatus(url)[@"state"] isEqual:@"unavailable"]);
    bad=[valid mutableCopy];bad[@"fetchedAt"]=@"1000";write(bad);check([ReadAgentStatus(url)[@"state"] isEqual:@"unavailable"]);
    bad=[valid mutableCopy];bad[@"limits"]=@[@{@"id":@"codex",@"name":@"Codex",@"windows":@[@{@"name":@"primary",@"usedPercent":@YES}]}];
    write(bad);check(ReadAgentStatus(url)[@"limits"][0][@"windows"][0][@"usedPercent"]==NSNull.null);
    [[@"{" dataUsingEncoding:NSUTF8StringEncoding] writeToURL:url atomically:YES];chmod(url.fileSystemRepresentation,0600);
    check([ReadAgentStatus(url)[@"state"] isEqual:@"unavailable"]);
    NSMutableData *large=[NSMutableData dataWithLength:65537];[large writeToURL:url atomically:YES];chmod(url.fileSystemRepresentation,0600);
    check([ReadAgentStatus(url)[@"state"] isEqual:@"unavailable"]);
    [NSFileManager.defaultManager removeItemAtURL:url error:nil];mkfifo(url.fileSystemRepresentation,0600);
    check([ReadAgentStatus(url)[@"state"] isEqual:@"unavailable"]);
    [NSFileManager.defaultManager removeItemAtURL:url error:nil];symlink("/dev/null",url.fileSystemRepresentation);
    check([ReadAgentStatus(url)[@"state"] isEqual:@"unavailable"]);
    [NSFileManager.defaultManager removeItemAtPath:directory error:nil];
    printf("PASS: %lu native status reader checks\n",(unsigned long)checks);
} return 0; }
