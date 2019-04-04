# WCSessionFileTransfer-NSProgress
Drop-in NSProgress backport in WatchConnectivity for iOS 11 and lower & watchOS 4 and lower with Sample Project

Extra delegate function added for both watchOS and iOS:

```
- (void) session:(WCSession *)session didBeginIncomingTransfer:(WCSessionFileTransfer *)fileTransfer;
```

This will allow you to monitor the progress of receiving a file via WatchConnectivity just like you can for sending. 

## USAGE:

Monitor NSProgress just like you would on iOS 12/watchOS 5 with the additional option to monitor an incoming transfer:

```
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
```

### iOS

```
static void *ProgressObserverContext = &ProgressObserverContext;

WCSessionFileTransfer *transfer = [_session transferFile:fileURL metadata:@{@"key" : @"value"}];
            
//Suppress @available iOS 12 warning (optional)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

[transfer.progress addObserver:self 
                    forKeyPath:NSStringFromSelector(@selector(fractionCompleted))
                       options:NSKeyValueObservingOptionInitial
                       context:ProgressObserverContext];
                       
#pragma clang diagnostics pop
```            
   
### watchOS

```
static void *ProgressObserverContextIncoming = &ProgressObserverContextIncoming;

- (void) session:(WCSession *)session didBeginIncomingTransfer:(WCSessionFileTransfer *) fileTransfer {

    //Suppress @available watchOS 5.0 warning (optional)
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wunguarded-availability-new"
    
    [fileTransfer.progress addObserver:self
                            forKeyPath:NSStringFromSelector(@selector(fractionCompleted))
                               options:NSKeyValueObservingOptionInitial
                               context:ProgressObserverContextIncoming];
                           
    #pragma clang diagnostics pop

}
```


