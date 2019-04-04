//
//  InterfaceController.m
//  Testing watchOS Extension
//
//  Created by spiral on 19/3/19.
//  Copyright © 2019 spiral. All rights reserved.
//

#import "InterfaceController.h"
#import <WatchConnectivity/WatchConnectivity.h>

@interface InterfaceController()
@property (weak, nonatomic) WCSession *session;
@end


@implementation InterfaceController

static void *ProgressObserverContext = &ProgressObserverContext;
static void *ProgressObserverContextIncoming = &ProgressObserverContextIncoming;

- (void)awakeWithContext:(id)context {
    [super awakeWithContext:context];
    
    
    if([WCSession isSupported]) {
        _session = [WCSession defaultSession];
        _session.delegate = (id)self;
        [_session activateSession];
    }
    
}

- (void)willActivate {
    // This method is called when watch view controller is about to be visible to user
    [super willActivate];
}

- (void)didDeactivate {
    // This method is called when watch view controller is no longer visible
    [super didDeactivate];
}

-(void) session:(WCSession *)session didFinishFileTransfer:(WCSessionFileTransfer *)fileTransfer error:(NSError *)error {
    
    NSLog(@"Finished transfer to iOS");
    NSLog(@"error: %@", error);
    
}

- (void) session:(WCSession *)session didReceiveFile:(nonnull WCSessionFile *)file {
    
    NSLog(@"Received file from iOS");
    NSLog(@"fileURL %@", [file fileURL]);
    NSLog(@"metadata %@", [file metadata]);
    
}

- (void) session:(WCSession *)session didBeginIncomingTransfer:(WCSessionFileTransfer *) fileTransfer {
    NSLog(@"Beginning incoming transfer");
    WCSessionFile *file = fileTransfer.file;
    NSLog(@"fileURL %@", [file fileURL]);
    NSLog(@"metadata %@", [file metadata]);
    
    //Suppress @available watchOS 5.0 warning (optional)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
    [fileTransfer.progress addObserver:self
                            forKeyPath:NSStringFromSelector(@selector(fractionCompleted))
                               options:NSKeyValueObservingOptionInitial
                               context:ProgressObserverContextIncoming];
#pragma clang diagnostics pop
    
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context {
    
    if (context == ProgressObserverContext) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            NSProgress *progress = object;
            NSLog(@"[NSProgress] Fraction sent : %f", progress.fractionCompleted);
        }];
        
        return;
    }
    
    if (context == ProgressObserverContextIncoming) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            NSProgress *progress = object;
            NSLog(@"[NSProgress] Fraction received : %f", progress.fractionCompleted);
        }];
        return;
    }
    
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

@end



