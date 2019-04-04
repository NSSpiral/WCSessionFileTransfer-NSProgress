//
//  ViewController.m
//  Testing iOS
//
//  Created by spiral on 19/3/19.
//  Copyright © 2019 spiral. All rights reserved.
//

#import "ViewController.h"
#import <WatchConnectivity/WatchConnectivity.h>
#import "WCSessionFileTransfer+NSProgress.h"


@interface ViewController ()
@property (weak, nonatomic) WCSession *session;
@end


@implementation ViewController

static void *ProgressObserverContext = &ProgressObserverContext;
static void *ProgressObserverContextIncoming = &ProgressObserverContextIncoming;

- (void)viewDidLoad {
    [super viewDidLoad];

    if([WCSession isSupported]) {
        _session = [WCSession defaultSession];
        _session.delegate = (id)self;
        NSLog(@"Set delegate");
        
        [_session activateSession];
        
        NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"testfile" ofType:@""];
        NSURL *fileURL = [NSURL fileURLWithPath:bundlePath];
        

        WCSessionFileTransfer *transfer = [_session transferFile:fileURL metadata:@{@"key" : @"value"}];
        
        /*
        NSLog(@"Internal Delegate %@", _session.delegate);
        
        if([_session respondsToSelector:@selector(forwardDelegate)]) {
            NSLog(@"User Set Delegate %@", [_session forwardDelegate]);
        }
        */
        
        if (@available(iOS 9.0, *)) {
            
            //Suppress @available iOS 12 warning (optional)
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wunguarded-availability-new"
            
            [transfer.progress addObserver:self
                                forKeyPath:NSStringFromSelector(@selector(fractionCompleted)) options:NSKeyValueObservingOptionInitial
                                   context:ProgressObserverContext];
            #pragma clang diagnostics pop
            
        }
        
    }
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
    }

    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

-(void)session:(WCSession *)session didFinishFileTransfer:(WCSessionFileTransfer *)fileTransfer error:(NSError *)error {
    NSLog(@"Finished transfer");
    NSLog(@"error: %@", error);
}

- (void)session:(WCSession *)session didReceiveFile:(nonnull WCSessionFile *)file {
    
    NSLog(@"Received file from watchOS");
    NSLog(@"fileURL %@", [file fileURL]);
    NSLog(@"metadata %@", [file metadata]);
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
