//
//  NBCWorkflowProgressViewController.m
//  NBICreator
//
//  Created by Erik Berglund.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

#import "NBCWorkflowProgressViewController.h"
#import "NBCConstants.h"
#import "NBCLog.h"
#import "NBCLogging.h"
#import "NBCError.h"

DDLogLevel ddLogLevel;

@interface NBCWorkflowProgressViewController ()

@end

@implementation NBCWorkflowProgressViewController

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Initialization
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (id)init {
    self = [super initWithNibName:@"NBCWorkflowProgressViewController" bundle:nil];
    if (self != nil) {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(workflowCompleteNBI:) name:NBCNotificationWorkflowCompleteNBI object:nil];
        [center addObserver:self selector:@selector(workflowCompleteResources:) name:NBCNotificationWorkflowCompleteResources object:nil];
    }
    return self;
} // init

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setWorkflowComplete:NO];
    [self updateProgressStatus:@"Waiting..." workflow:self];
} // viewDidLoad

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
} // dealloc

- (void)workflowCompleteNBI:(NSNotification *)notification {
#pragma unused(notification)
    [self setWorkflowNBIComplete:YES];
    if ( ! _workflowNBIResourcesComplete ) {
        if ( [_workflowNBIResourcesLastStatus length] == 0 ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateProgressStatus:@"Preparing Resources to be added to NBI..." workflow:self];
                [self updateProgressBar:60.0];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateProgressStatus:self->_workflowNBIResourcesLastStatus workflow:self];
            });
        }
    }
} // workflowCompleteNBI

- (void)workflowCompleteResources:(NSNotification *)notification {
#pragma unused(notification)
    [self setWorkflowNBIResourcesComplete:YES];
} // workflowCompleteResources

- (IBAction)buttonCancel:(id)sender {
#pragma unused(sender)
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc postNotificationName:NBCNotificationRemoveWorkflowItemUserInfoWorkflowItem
                      object:self
                    userInfo:@{ NBCNotificationAddWorkflowItemToQueueUserInfoWorkflowItem : _workflowItem }];
    
    if ( _isRunning ) {
        DDLogWarn(@"[WARN] User canceled workflow...");
        [nc postNotificationName:NBCNotificationWorkflowFailed
                          object:self
                        userInfo:@{ NBCUserInfoNSErrorKey : [NBCError errorWithDescription:@"User Canceled"] }];
    }
} // buttonCancel

- (void)updateProgressStatus:(NSString *)statusMessage workflow:(id)workflow {
    if ( [workflow isEqualTo:[_workflowItem workflowNBI]] && ! _workflowNBIComplete ) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_textFieldStatusInfo setStringValue:statusMessage];
        });
    } else if ( [workflow isEqualTo:[_workflowItem workflowResources]] && _workflowNBIComplete ) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_textFieldStatusInfo setStringValue:statusMessage];
        });
    } else if ( [workflow isEqualTo:[_workflowItem workflowResources]] && ! _workflowNBIComplete ) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setWorkflowNBIResourcesLastStatus:statusMessage];
        });
    } else if ( [workflow isEqualTo:[_workflowItem workflowModifyNBI]] ) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_textFieldStatusInfo setStringValue:statusMessage];
        });
    } else if ( ! [workflow isEqualTo:[_workflowItem workflowNBI]] ) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_textFieldStatusInfo setStringValue:statusMessage];
        });
    }
} // updateProgressStatus

- (void)updateProgressBar:(double)value {
    if ( _progressIndicator ) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_progressIndicator setDoubleValue:value];
            [self->_progressIndicator setNeedsDisplay:YES];
        });
    }
} // updateProgressBar

- (void)incrementProgressBar:(double)value {
    if ( _progressIndicator ) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_progressIndicator setDoubleValue:( [self->_progressIndicator doubleValue] + value )];
            [self->_progressIndicator setNeedsDisplay:YES];
        });
    }
} // incrementProgressBar

- (IBAction)buttonShowInFinder:(id)sender {
#pragma unused(sender)
    
    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(taskQueue, ^{
        
        if ( self->_nbiURL ) {
            NSError *error = nil;
            NSString *destinationFileName = [self->_nbiURL lastPathComponent];
            if ( [destinationFileName containsString:@" "] ) {
                destinationFileName = [destinationFileName stringByReplacingOccurrencesOfString:@" " withString:@"-"];
                [self setNbiURL:[[self->_nbiURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:destinationFileName]];
                if ( ! [self->_nbiURL checkResourceIsReachableAndReturnError:&error] ) {
                    DDLogError(@"[ERROR] %@", [error localizedDescription]);
                    return;
                }
            }
            [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[ self->_nbiURL ]];
        } else {
            DDLogError(@"[ERROR] ");
        }
        
    });
} // buttonShowInFinder

- (IBAction)buttonOpenLog:(id)sender {
#pragma unused(sender)
    
    DDLogDebug(@"[DEBUG] Open Log!");
    
    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(taskQueue, ^{
        
        DDFileLogger *fileLogger = [NBCLog fileLogger];
        if ( fileLogger ) {
            NSString *logFilePath = [[fileLogger currentLogFileInfo] filePath];
            DDLogDebug(@"[DEBUG] Log file path: %@", logFilePath);
            
            if ( [logFilePath length] != 0 ) {
                NSError *error = nil;
                NSURL *logFileURL = [NSURL fileURLWithPath:logFilePath];
                if ( [logFileURL checkResourceIsReachableAndReturnError:&error] ) {
                    [[NSWorkspace sharedWorkspace] openURL:logFileURL];
                } else {
                    DDLogError(@"[ERROR] %@", [error localizedDescription] ?: [NSString stringWithFormat:@"Log file at path: %@ doesn't exist", [logFileURL path]]);
                    return;
                }
            }
        }
        
    });
} // buttonOpenLog

- (void)workflowStartedForItem:(NBCWorkflowItem *)workflowItem {
    [self setWorkflowItem:workflowItem];
    [self setNbiURL:[_workflowItem nbiURL]];
    [self setIsRunning:YES];
    if ( [[[NSUserDefaults standardUserDefaults] objectForKey:NBCUserDefaultsWorkflowTimerEnabled] boolValue] ) {
        [self setTimer:[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(timerTick) userInfo:nil repeats:YES]];
        [_textFieldTimer setHidden:NO];
    }
    [_layoutContraintStatusInfoLeading setConstant:24.0];
} // workflowStartedForItem

- (void)timerTick {
    static NSDateComponentsFormatter *dateComponentsFormatter;
    if ( ! dateComponentsFormatter) {
        dateComponentsFormatter = [[NSDateComponentsFormatter alloc] init];
        dateComponentsFormatter.maximumUnitCount = 4;
        dateComponentsFormatter.allowedUnits = NSCalendarUnitMinute + NSCalendarUnitSecond;
        dateComponentsFormatter.unitsStyle = NSDateComponentsFormatterUnitsStylePositional;
        dateComponentsFormatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorPad;
        
        NSCalendar *calendarUS = [NSCalendar calendarWithIdentifier: NSCalendarIdentifierGregorian];
        calendarUS.locale = [NSLocale localeWithLocaleIdentifier: @"en_US"];
        dateComponentsFormatter.calendar = calendarUS;
    }
    
    NSDate *startTime = [_workflowItem startTime];
    if ( startTime ) {
        NSTimeInterval secondsBetween = [[NSDate date] timeIntervalSinceDate:startTime];
        NSString *workflowTime = [dateComponentsFormatter stringFromTimeInterval:secondsBetween];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_textFieldTimer setStringValue:workflowTime];
        });
    } else {
        DDLogError(@"[ERROR] Workflow start time NOT set!");
    }
} // timerTick

- (void)workflowFailedWithError:(NSString *)errorMessage {
    
    // -------------------------------------------------------------
    //  Make sure the first error encoutered is the one displayed
    // -------------------------------------------------------------
    if ( _workflowFailed ) {
        DDLogError(@"[ERROR][SILENCED] %@", errorMessage);
        return;
    } else {
        [self setWorkflowFailed:YES];
    }
    
    [_layoutContraintStatusInfoLeading setConstant:1.0];
    [_progressIndicator setHidden:YES];
    [_progressIndicator stopAnimation:self];
    [_buttonOpenLog setHidden:NO];
    [self setIsRunning:NO];
    if ( _timer ) {
        [_timer invalidate];
        [_textFieldTimer setHidden:YES];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_textFieldStatusTitle setStringValue:@"Workflow Failed"];
        [self->_textFieldStatusInfo setStringValue:errorMessage ?: @""];
    });
} // workflowFailedWithError

- (void)updateProgressStatus:(NSString *)statusMessage {
    if ( ! [statusMessage hasPrefix:@"update_dyld_shared_cache: Omitting development cache"] ) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_textFieldStatusInfo setStringValue:statusMessage];
        });
    }
} // updateProgressStatus

- (void)workflowCompleted {
    [_layoutContraintStatusInfoLeading setConstant:1.0];
    
    NSCalendar *calendarUS = [NSCalendar calendarWithIdentifier: NSCalendarIdentifierGregorian];
    calendarUS.locale = [NSLocale localeWithLocaleIdentifier: @"en_US"];
    
    NSDate *startTime = [_workflowItem startTime];
    NSDate *endTime = [NSDate date];
    NSTimeInterval secondsBetween = [endTime timeIntervalSinceDate:startTime];
    NSDateComponentsFormatter *dateComponentsFormatter = [[NSDateComponentsFormatter alloc] init];
    dateComponentsFormatter.maximumUnitCount = 3;
    dateComponentsFormatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
    dateComponentsFormatter.calendar = calendarUS;
    
    NSString *workflowTime = [dateComponentsFormatter stringFromTimeInterval:secondsBetween];
    if ( [workflowTime length] != 0 ) {
        [_workflowItem setWorkflowTime:workflowTime];
    }
    
    [self setWorkflowComplete:YES];
    [_buttonOpenLog setHidden:NO];
    [_progressIndicator setHidden:YES];
    [_progressIndicator stopAnimation:self];
    [self setIsRunning:NO];
    if ( _timer ) {
        [_timer invalidate];
        [_textFieldTimer setHidden:YES];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateProgressStatus:[NSString stringWithFormat:@"NBI created successfully in %@!", workflowTime] workflow:self];
    });
}

- (void)logDebug:(NSString *)logMessage {
    DDLogDebug(@"[DEBUG] %@", logMessage);
}

- (void)logInfo:(NSString *)logMessage {
    DDLogInfo(@"%@", logMessage);
}

- (void)logWarn:(NSString *)logMessage {
    DDLogWarn(@"[WARN] %@", logMessage);
}

- (void)logError:(NSString *)logMessage {
    DDLogError(@"[ERROR] %@", logMessage);
}

- (void)logStdOut:(NSString *)stdOutString {
    DDLogDebug(@"[stdout] %@", stdOutString);
}

- (void)logStdErr:(NSString *)stdErrString {
    DDLogDebug(@"[stderr] %@", stdErrString);
}

@end
