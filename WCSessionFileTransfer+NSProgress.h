//
//  WCSessionFileTransfer+NSProgress.h
//  Testing
//
//  Created by spiral on 19/3/19.
//  Copyright © 2019 spiral. All rights reserved.
//

#import <WatchConnectivity/WatchConnectivity.h>


@interface WCSessionGroupFile : NSObject

@property (nonatomic, strong) NSURL *fileURL;
@property (nonatomic, strong) NSDictionary *metadata;

- (instancetype) initWithURL:(NSURL *) url metadata:(NSDictionary *) metadata;

@end

@interface WCSessionGroupFileTransfer : NSObject

@property (nonatomic, strong) NSProgress *progress;
@property (nonatomic, strong) WCSessionGroupFile *file;

@property (nonatomic) int chunkSize;
@property (nonatomic) int currentChunk;
@property (nonatomic) int totalChunks;

+ (instancetype) transfertWithURL:(NSURL *) url metadata:(NSDictionary *) metadata;

@end

@interface WCSessionFileTransfer (Overrides)

@property (nonatomic, strong) NSProgress *progress;
@property (nonatomic, strong) WCSessionFile *wholeFile;

@end

@interface WCSession (Overrides) <WCSessionDelegate>

@property (nonatomic, strong) id delegate;
@property (nonatomic, strong) id forwardDelegate;

@property (nonatomic, strong) NSMutableDictionary *transfers;
@property (nonatomic, strong) NSMutableDictionary *incomingTransfers;


+ (BOOL) legacyMode;

- (WCSessionFileTransfer *) transferFileLegacy:(NSURL *)url metadata:(NSDictionary *)metadata;
- (void) cancelTransfer:(NSString *) fileName;

- (id) forwardDelegate;

@end


