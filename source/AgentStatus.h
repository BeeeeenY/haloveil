// External, read-only account telemetry. This code never opens Codex credentials.
#import <Foundation/Foundation.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <unistd.h>
#import <errno.h>
#import <math.h>

static BOOL StatusNumber(id value) {
    return [value isKindOfClass:NSNumber.class] && CFGetTypeID((__bridge CFTypeRef)value)!=CFBooleanGetTypeID() && isfinite([value doubleValue]);
}
static id StatusTime(id value) {
    return StatusNumber(value)&&[value doubleValue]>0&&[value doubleValue]<253402300800.0?value:NSNull.null;
}
static NSDictionary *ReadAgentStatus(NSURL *url) {
    NSDictionary *unavailable=@{@"state":@"unavailable"};
    // Nonblocking/no-follow also prevents a replaced FIFO or symlink from hanging the host.
    int fd=open(url.fileSystemRepresentation,O_RDONLY|O_CLOEXEC|O_NONBLOCK|O_NOFOLLOW);
    if(fd<0)return unavailable;
    struct stat info;
    BOOL valid=fstat(fd,&info)==0&&S_ISREG(info.st_mode)&&info.st_uid==getuid()&&!(info.st_mode&0077)&&info.st_size>0&&info.st_size<=65536;
    NSMutableData *data=[NSMutableData data];unsigned char buffer[4096];
    while(valid){
        ssize_t count=read(fd,buffer,sizeof(buffer));
        if(count<0&&errno==EINTR)continue;
        if(count<0){valid=NO;break;}if(count==0)break;
        [data appendBytes:buffer length:(NSUInteger)count];if(data.length>65536)valid=NO;
    }
    close(fd);if(!valid)return unavailable;
    NSDictionary *raw=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if(![raw isKindOfClass:NSDictionary.class]||!StatusNumber(raw[@"schemaVersion"])||![raw[@"schemaVersion"] isEqual:@1]||![raw[@"provider"] isEqual:@"codex"]||![raw[@"state"] isEqual:@"ok"]||StatusTime(raw[@"fetchedAt"])==NSNull.null)return unavailable;
    NSMutableArray *limits=[NSMutableArray array];
    if([raw[@"limits"] isKindOfClass:NSArray.class])for(id bucket in raw[@"limits"]){
        if(limits.count>=8)break;
        if(![bucket isKindOfClass:NSDictionary.class]||![bucket[@"id"] isKindOfClass:NSString.class]||[bucket[@"id"] length]>64||![bucket[@"name"] isKindOfClass:NSString.class]||[bucket[@"name"] length]>64)continue;
        NSMutableArray *windows=[NSMutableArray array];
        if([bucket[@"windows"] isKindOfClass:NSArray.class])for(id window in bucket[@"windows"]){
            if(windows.count>=2)break;
            if(![window isKindOfClass:NSDictionary.class]||![@[@"primary",@"secondary"] containsObject:window[@"name"]])continue;
            id used=window[@"usedPercent"],duration=window[@"windowDurationMins"];
            [windows addObject:@{@"name":window[@"name"],@"usedPercent":StatusNumber(used)?@(MAX(0,MIN(100,[used doubleValue]))):NSNull.null,
                @"windowDurationMins":StatusNumber(duration)&&[duration doubleValue]>0?duration:NSNull.null,@"resetsAt":StatusTime(window[@"resetsAt"])}];
        }
        [limits addObject:@{@"id":bucket[@"id"],@"name":bucket[@"name"],@"windows":windows}];
    }
    NSDictionary *reset=[raw[@"fullReset"] isKindOfClass:NSDictionary.class]?raw[@"fullReset"]:@{};
    id count=reset[@"availableCount"];
    return @{@"state":@"ok",@"fetchedAt":raw[@"fetchedAt"],@"limits":limits,
        @"fullReset":@{@"availableCount":StatusNumber(count)&&[count doubleValue]>=0&&floor([count doubleValue])==[count doubleValue]?count:NSNull.null,
            @"expiresAt":StatusTime(reset[@"expiresAt"]),@"detailsKnown":@([reset[@"detailsKnown"] isEqual:@YES])}};
}
