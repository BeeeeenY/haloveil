#import <Foundation/Foundation.h>
#import <sys/file.h>
#import <fcntl.h>
#import <unistd.h>
int main(int argc,const char *argv[]){
    @autoreleasepool {
        if(argc!=3)return 3;
        if(strcmp(argv[1],"probe")==0){
            int fd=open(argv[2],O_RDWR|O_CLOEXEC);if(fd<0)return 3;
            int result=flock(fd,LOCK_EX|LOCK_NB);if(result==0)flock(fd,LOCK_UN);close(fd);return result==0?0:2;
        }
        if(strcmp(argv[1],"claim")==0){
            NSDictionary *info=@{@"screen":@([[NSString stringWithUTF8String:argv[2]] integerValue]),@"session":NSUUID.UUID.UUIDString,@"epoch":@(NSProcessInfo.processInfo.systemUptime)};
            NSData *data=[NSJSONSerialization dataWithJSONObject:info options:0 error:nil];
            NSString *sender=[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            [NSDistributedNotificationCenter.defaultCenter postNotificationName:@"dev.haloveil.claim-display.v1" object:sender userInfo:nil deliverImmediately:YES];
            [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];return 0;
        }
    }
    return 3;
}
