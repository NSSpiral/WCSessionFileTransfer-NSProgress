//
//  WCSessionFileTransfer+NSProgress.m
//  Testing
//
//  Created by spiral on 19/3/19.
//  Copyright © 2019 spiral. All rights reserved.
//

#import "WCSessionFileTransfer+NSProgress.h"
#import <WatchConnectivity/WatchConnectivity.h>
#import <objc/runtime.h>


@implementation WCSessionGroupFile

- (instancetype) initWithURL:(NSURL *) url metadata:(NSDictionary *) metadata {
    
    self = [super init];
    
    _fileURL = url;
    _metadata = metadata;
    
    return self;
}

@end

@implementation WCSessionGroupFileTransfer

+ (instancetype) transferWithURL:(NSURL *) url metadata:(NSDictionary *) metadata {
    WCSessionGroupFileTransfer *transfer = [[WCSessionGroupFileTransfer alloc] init];
    
    WCSessionGroupFile *file = [[WCSessionGroupFile alloc] initWithURL:url metadata:metadata];
    transfer.file = file;
    transfer.progress = [NSProgress progressWithTotalUnitCount:100];
    
    return transfer;
}

- (BOOL) transferring {
    if([_progress fractionCompleted] == 1.0) {
        return NO;
    }
    
    return YES;
}

- (void) cancel {
    NSString *fileName = [[[_file fileURL] path] lastPathComponent];
    [[WCSession defaultSession] cancelTransfer:fileName];
}

@end


     
@implementation WCSession (Overrides)

+ (void) load {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        if([WCSession legacyMode]) {
            
            NSLog(@"[WCSessionFileTransfer+NSProgress] Swizzling methods");
            
            SEL originalSelector = @selector(transferFile:metadata:);
            SEL swizzledSelector = @selector(transferFileLegacy:metadata:);
            
            Method originalMethod = class_getInstanceMethod([WCSession class], originalSelector);
            Method swizzledMethod = class_getInstanceMethod([WCSession class], swizzledSelector);
            
            BOOL didAddMethod = class_addMethod([WCSession class],
                                                originalSelector,
                                                method_getImplementation(swizzledMethod),
                                                method_getTypeEncoding(swizzledMethod));
            if(didAddMethod) {
                
                class_replaceMethod([WCSession class],
                                    swizzledSelector,
                                    method_getImplementation(originalMethod),
                                    method_getTypeEncoding(originalMethod));
                
            }
            else {
                
                method_exchangeImplementations(originalMethod, swizzledMethod);
            }
            
        }
        
    });
    
    [[WCSession defaultSession] setTransfers:[[NSMutableDictionary alloc] init]];
    [[WCSession defaultSession] setIncomingTransfers:[[NSMutableDictionary alloc] init]];
    
}

+ (BOOL) legacyMode {
    return YES;
    //if(@available(watchOS 5.0, iOS 12.0, *)) return NO;
    //else return YES;

}
     
- (void) setDelegate:(id<WCSessionDelegate>)delegate {
    [self setForwardDelegate:delegate];
}

- (id) delegate {
    return self;
}

- (void)setForwardDelegate:(id) forwardDelegate {
    objc_setAssociatedObject(self, @selector(forwardDelegate), forwardDelegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id)forwardDelegate {
    return objc_getAssociatedObject(self, @selector(forwardDelegate));
}

- (void) setIncomingTransfers:(NSMutableDictionary *) incomingTransfers {
    objc_setAssociatedObject(self, @selector(incomingTransfers), incomingTransfers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void) setTransfers:(NSMutableDictionary *) transfers {
    objc_setAssociatedObject(self, @selector(transfers), transfers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableDictionary *) incomingTransfers {
    return objc_getAssociatedObject(self, @selector(incomingTransfers));
}

- (NSMutableDictionary *) transfers {
    return objc_getAssociatedObject(self, @selector(transfers));
}



- (void) cancelTransfer:(NSString *) fileName {
    NSMutableDictionary *transfers = [self transfers];
    NSMutableDictionary *transfer = transfers[fileName];
    
    WCSessionFileTransfer *t = transfer[@"transfer"];
    NSString *filePath = [[[t file] fileURL] path];
    NSString *rootPath = [filePath componentsSeparatedByString:@"_WCPart"][0];
    int chunk = [transfer[@"chunk"] intValue];
    transfers[fileName] = nil;
    
    [t cancel];
    
    
    int i = chunk;
    NSString *removePath = [NSString stringWithFormat:@"%@_WCPart%d", rootPath, i];
    [[NSFileManager defaultManager] removeItemAtPath:removePath error:nil];
    
}

/*
- (void) purgeFilesWithName:(NSString *) fileName {
    NSString *path = [NSString stringWithFormat:@"%@%@_WCPart", NSTemporaryDirectory(), fileName];
    
    int i = 1;
    NSString *filePath = [NSString stringWithFormat:@"%@%d", path, i];

    while(i <= 100) {
        filePath = [NSString stringWithFormat:@"%@%d", path, i];
        NSLog(@"Should remove file %@", filePath);
        //[[NSFileManager defaultManager] removeItemAtPath:filePath];
        
        i++;
    }
}
 */

- (void) session:(WCSession *)session didReceiveFile:(WCSessionFile *)file {
    
    NSString *path = [[file fileURL] path];
    NSString *lastComponent = [path lastPathComponent];
    
    NSArray *arr = [lastComponent componentsSeparatedByString:@"_WCPart"];
    
    NSString *fileName = arr[0];
    NSString *combinedFilePath = [NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), fileName];
    
    int fileSize = [[file metadata][@"fileSize"] intValue];
    int chunkSize = [[file metadata][@"chunkSize"] intValue];
    
    NSData *fileData;
    
    if(![[NSFileManager defaultManager] fileExistsAtPath:combinedFilePath]) {
        
        NSLog(@"Creating %@", combinedFilePath);
        fileData = [NSMutableData dataWithLength:fileSize];
        [fileData writeToFile:combinedFilePath atomically:YES];
    }
    
    WCSessionGroupFileTransfer *incomingTransfer;
    
    NSMutableDictionary *incomingTransfers = [self incomingTransfers];
    if(![[incomingTransfers allKeys] containsObject:fileName]) {
        incomingTransfer = [WCSessionGroupFileTransfer transferWithURL:[NSURL fileURLWithPath:combinedFilePath] metadata:[file metadata][@"metadata"]];
        
        id forwardDelegate = [self forwardDelegate];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        if([forwardDelegate respondsToSelector:@selector(session:didBeginIncomingTransfer:)]) {
            [forwardDelegate performSelector:@selector(session:didBeginIncomingTransfer:) withObject:session withObject:incomingTransfer];
        }
#pragma clang diagnostic pop
        
        incomingTransfers[fileName] = incomingTransfer;
    }
    else {
        incomingTransfer = incomingTransfers[fileName];
    }
    
    fileData = [NSData dataWithContentsOfURL:[file fileURL]];
    NSNumber *chunkNumber = [file metadata][@"chunk"];
    int chunk = [chunkNumber intValue];
    
    [incomingTransfer.progress setCompletedUnitCount:chunk];
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:combinedFilePath];
    [fileHandle seekToFileOffset:chunk * chunkSize];
    [fileHandle writeData:fileData];
    [fileHandle synchronizeFile];
    //[fileHandle closeFile];
    
    
    NSLog(@"Chunk number %d (%d bytes) written to (%d)", chunk, chunkSize, fileSize);
    NSLog(@"data: %@", [fileData subdataWithRange:NSMakeRange(0, 40)]);
    NSLog(@"-> %@", combinedFilePath);
    
    if(chunk == 99) {
        NSLog(@"Received last chunk");
        NSURL *fileURL = [NSURL fileURLWithPath:combinedFilePath];
        NSDictionary *metadata = [file metadata][@"metadata"];
        WCSessionGroupFile *groupFile = [[WCSessionGroupFile alloc] initWithURL:fileURL metadata:metadata];
        
        
        id forwardDelegate = [self forwardDelegate];
        
        if([forwardDelegate respondsToSelector:@selector(session:didReceiveFile:)]) {
            [forwardDelegate session:session didReceiveFile:(WCSessionFile *)groupFile];
        }
        
        incomingTransfers[fileName] = nil;
    }
}

- (void) session:(WCSession *)session didFinishFileTransfer:(WCSessionFileTransfer *)fileTransfer error:(NSError *)error {
    NSString *path = [[[fileTransfer file] fileURL] path];
    
    
    NSString *fileName = [[path componentsSeparatedByString:@"_WCPart"][0] lastPathComponent];
        
    NSMutableDictionary *transfers = [self transfers];
    NSNumber *currentChunk = transfers[fileName][@"chunk"];
    
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    
    if([currentChunk intValue] == 100) {
        transfers[fileName] = nil;
        return;
    }
    
    NSNumber *nextChunk = [NSNumber numberWithInt:[currentChunk intValue] + 1];
    transfers[fileName][@"chunk"] = nextChunk;
    
    if([currentChunk intValue] < 99) {
        [self sendChunkFromFile:fileName];
    }

}

- (void)session:(nonnull WCSession *)session activationDidCompleteWithState:(WCSessionActivationState)activationState error:(nullable NSError *)error {
    
    id fdel = [self forwardDelegate];
    
    if([fdel respondsToSelector:@selector(session:activationDidCompleteWithState:error:)]){
        [fdel session:session activationDidCompleteWithState:activationState error:error];
    }
}

- (WCSessionFileTransfer *) transferFileLegacy:(NSURL *)url metadata:(NSDictionary *)metadata {
    
    //NSLog(@"Transferring url %@", url);
    NSString *path = [url path];
    
    if(![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSLog(@"File doesn't exist!");
        return nil;
    }
    
    NSString *fileName = [path lastPathComponent];
    NSMutableDictionary *transfers = [self transfers];
    
    
    if([[transfers allKeys] containsObject:fileName]){
        NSLog(@"Already sending...");
        return nil;
    }
    
    WCSessionGroupFileTransfer *groupFileTransfer = [[WCSessionGroupFileTransfer alloc] init];
    
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:100];
    groupFileTransfer.progress = progress;
    
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL];
    unsigned long long fileSize = [attributes fileSize];
    
    transfers[fileName] = [@{
                             @"fileLocation" : path,
                             @"chunk" : [NSNumber numberWithInt:0],
                             @"fileSize" : [NSNumber numberWithLongLong:fileSize],
                             @"metadata" : metadata,
                             @"progress" : progress
                           } mutableCopy];
    
    [self sendChunkFromFile:fileName];
    
    return (WCSessionFileTransfer *)groupFileTransfer;

}

- (NSMutableDictionary *) transfer:(NSString *) fileName {
    
    NSMutableDictionary *transfers = [self transfers];
    return transfers[fileName];
}


- (void) sendChunkFromFile:(NSString *) fileName {
    
    NSMutableDictionary *transfer = [self transfer:fileName];
    NSString *path = transfer[@"fileLocation"];
    
    double fileSize = [transfer[@"fileSize"] doubleValue];
    int chunk = [transfer[@"chunk"] intValue];
    int chunkSize = fileSize / 100;
    
    NSDictionary *metadata = transfer[@"metadata"];
    
    NSMutableDictionary *transferMetadata = [@{ @"chunk" : @(chunk),
                                                @"chunkSize" : @(chunkSize),
                                                @"fileSize" : @(fileSize),
                                                @"metadata" : metadata
                                              } mutableCopy];
    
    NSProgress *progress = transfer[@"progress"];
    [progress setCompletedUnitCount:chunk+1];

    NSString *tmpDirectory = NSTemporaryDirectory();
    NSString *tempPath = [tmpDirectory stringByAppendingPathComponent:fileName];
    tempPath = [NSString stringWithFormat:@"%@_WCPart%d", tempPath, chunk+1];
    
    //NSLog(@"Temp path %@", tempPath);
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:path];
    [fileHandle seekToFileOffset:chunk * chunkSize];
    
    NSData *data;
    if(chunk != 99) data = [fileHandle readDataOfLength:chunkSize];
    else data = [fileHandle readDataToEndOfFile];
    
    [data writeToFile:tempPath atomically:YES];
    
    NSLog(@"Sending chunk %d/100 from %@ (%d/%f)", chunk+1, path, chunkSize, fileSize);
    
    NSURL *url = [NSURL fileURLWithPath:tempPath];
    WCSessionFileTransfer *t = [self transferFileLegacy:url metadata:transferMetadata]; //This is actually the regular transferFile
    transfer[@"transfer"] = t;
    
}

@end

