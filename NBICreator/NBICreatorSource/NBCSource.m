//
//  NBCSource.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-02-25.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCSource.h"

#import "NBCDiskImageController.h"
#import "NBCLogging.h"

DDLogLevel ddLogLevel;

NSString *const NBCSourceTypeInstallerApplication = @"InstallerApplication";
NSString *const NBCSourceTypeInstallESDDiskImage = @"InstallESDDiskImage";
NSString *const NBCSourceTypeSystemDiskImage = @"SystemDiskImage";
NSString *const NBCSourceTypeSystemDisk = @"SystemDisk";
NSString *const NBCSourceTypeNBI = @"NBI";
NSString *const NBCSourceTypeUnknown = @"Unknown";

@implementation NBCSource

- (id)initWithSourceType:(NSString *)sourceType {
    self = [super init];
    if (self) {
        _sourceType = sourceType;
    }
    return self;
}

- (BOOL)detachImage {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL retval = YES;
    if ( _systemVolumeURL != nil ) {
        retval = [NBCDiskImageController detachDiskImageAtPath:[_systemVolumeURL path]];
    }
    return retval;
} // detachImage

- (BOOL)unmountImage {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL retval = YES;
    if ( [[_systemVolumeURL path] length] != 0 ) {
        if ( [NBCDiskImageController unmountVolumeAtPath:[_systemVolumeURL path]] ) {
            // Unset _imageMountURL…
        } else {
            retval = NO;
        }
    }
    return retval;
} // unmountImage

- (BOOL)detachRecoveryHD {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL retval = YES;
    if ( [[_recoveryVolumeURL path] length] != 0 ) {
        retval = [NBCDiskImageController detachDiskImageAtPath:[_recoveryVolumeURL path]];
    }
    return retval;
} // detachImage

- (BOOL)unmountRecoveryHD {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL retval = YES;
    if ( [[_recoveryVolumeURL path] length] != 0 ) {
        retval = [NBCDiskImageController unmountVolumeAtPath:[_recoveryVolumeURL path]];
    }
    return retval;
} // unmountRecoveryHD

- (BOOL)detachBaseSystem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL retval = YES;
    if ( [_baseSystemDisk isMounted] ) {
        retval = [NBCDiskImageController unmountVolumeAtPath:[_baseSystemVolumeURL path]];
    }

    if ( retval ) {
        retval = [NBCDiskImageController detachDiskImageDevice:_baseSystemVolumeBSDIdentifier];
    }
    return retval;
} // detachBaseSystem

- (BOOL)unmountBaseSystem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL retval = YES;
    if ( [[_baseSystemVolumeURL path] length] != 0 ) {
        retval = [NBCDiskImageController unmountVolumeAtPath:[_baseSystemVolumeURL path]];
    }
    return retval;
} // unmountBaseSystem

- (BOOL)detachAll {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL retval = YES;
        if ( [[_baseSystemVolumeURL path] length] != 0 ) {
            retval = [self unmountBaseSystem];
        }
    
        if ( [[_recoveryVolumeURL path] length] != 0 ) {
            retval = [self unmountRecoveryHD];
        }
        
        if ( [[_systemVolumeURL path] length] != 0 ) {
            retval = [self unmountImage];
        }
    return retval;
} // detachAll

- (NSString *)expandVariables:(NSString *)string {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSString *newString = string;
    NSString *variableOSVersion = @"%OSVERSION%";
    NSString *variableOSMajorVersion = @"%OSMAJOR%";
    NSString *variableOSMinorVersion = @"%OSMINOR%";
    NSString *variableOSPatchVersion = @"%OSPATCH%";
    NSString *variableOSBuildVersion = @"%OSBUILD%";
    NSString *variableOSIndex = @"%OSINDEX%";
    NSString *variableSourceURL = @"%SOURCEURL%";
    
    // --------------------------------------------------------------
    //  Expand %OSVERSION%
    // --------------------------------------------------------------
    NSString *osVersion;
    
    if ( [_sourceVersion length] != 0 ) {
        osVersion = _sourceVersion;
    } else {
        osVersion = @"10.9.5";
    }
    newString = [newString stringByReplacingOccurrencesOfString:variableOSVersion
                                               withString:osVersion];
    
    // --------------------------------------------------------------
    //  Expand %OSMAAJOR%, %OSMINOR%, %OSPATCH%
    // --------------------------------------------------------------
    NSString *osMajorVersion;
    NSString *osMinorVersion;
    NSString *osPatchVersion;
    NSArray *osVersionString = [osVersion componentsSeparatedByString:@"."];
    osMajorVersion = [osVersion componentsSeparatedByString:@"."][0];
    osMinorVersion = [osVersion componentsSeparatedByString:@"."][1];
    if ( [osVersionString count] == 3 ) {
        osPatchVersion = [osVersion componentsSeparatedByString:@"."][2];
    } else {
        osPatchVersion = @"0";
    }
    
    newString = [newString stringByReplacingOccurrencesOfString:variableOSMajorVersion
                                               withString:osMajorVersion];
    
    newString = [newString stringByReplacingOccurrencesOfString:variableOSMinorVersion
                                               withString:osMinorVersion];
    
    newString = [newString stringByReplacingOccurrencesOfString:variableOSPatchVersion
                                               withString:osPatchVersion];
    
    // --------------------------------------------------------------
    //  Expand %OSBUILD%
    // --------------------------------------------------------------
    NSString *osBuildVersion;
    if ( [_sourceBuild length] != 0 ) {
        osBuildVersion = _sourceBuild;
    } else {
        osBuildVersion = @"13F34";
    }
    
    newString = [newString stringByReplacingOccurrencesOfString:variableOSBuildVersion
                                               withString:osBuildVersion];
    
    // --------------------------------------------------------------
    //  Expand %OSINDEX%
    // --------------------------------------------------------------
    NSString *osIndex;
    NSUInteger substringIndex;
    if ( [osMinorVersion integerValue] <= 9 ) {
        substringIndex=(NSUInteger)2;
    } else {
        substringIndex=(NSUInteger)1;
    }
    osIndex = [NSString stringWithFormat:@"%@%@%@", [osMajorVersion substringToIndex:substringIndex], osMinorVersion, osPatchVersion];
    
    newString = [newString stringByReplacingOccurrencesOfString:variableOSIndex
                                               withString:osIndex];
    
    // --------------------------------------------------------------
    //  Expand %SOURCEURL%
    // --------------------------------------------------------------
    NSString *sourceURL;
    if ( [[_systemVolumeURL path] length] != 0 ) {
        sourceURL = [NSString stringWithFormat:@"%@", [_systemVolumeURL path]];
    } else {
        sourceURL = @"";
    }
    
    newString = [newString stringByReplacingOccurrencesOfString:variableSourceURL
                                               withString:sourceURL];
    
    return newString;
}

- (NSImage *)productImageForOSVersion:(NSString *)osVersion {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSImage *productImage;
    if ([osVersion containsString:@"10.6"]) {
        productImage = [[NSImage alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"IconYosemite" withExtension:@"icns"]];
    } else if ([osVersion containsString:@"10.7"]) {
        productImage = [[NSImage alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"IconLion" withExtension:@"icns"]];
    } else if ([osVersion containsString:@"10.8"]) {
        productImage = [[NSImage alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"IconMountainLion" withExtension:@"icns"]];
    } else if ([osVersion containsString:@"10.9"]) {
        productImage = [[NSImage alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"IconMavericks" withExtension:@"icns"]];
    } else if ([osVersion containsString:@"10.10"]) {
        productImage = [[NSImage alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"IconYosemite" withExtension:@"icns"]];
    } else if ([osVersion containsString:@"10.11"] ) {
        productImage = [[NSImage alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"IconElCapitanBeta" withExtension:@"icns"]];
    }
    return productImage;
}

- (void)printAllVariables {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogDebug(@"sourceVersion=%@", _sourceVersion);
    DDLogDebug(@"sourceBuild=%@", _sourceBuild);
    DDLogDebug(@"sourceType=%@", _sourceType);
    DDLogDebug(@"sourceMenuName=%@", _sourceMenuName);
    DDLogDebug(@"installESDDisk=%@", _installESDDisk);
    DDLogDebug(@"installESDDiskImageURL=%@", _installESDDiskImageURL);
    DDLogDebug(@"installESDVolumeURL=%@", _installESDVolumeURL);
    DDLogDebug(@"installESDDiskImageDict=%@", _installESDDiskImageDict);
    DDLogDebug(@"installESDVolumeBSDIdentifier=%@", _installESDVolumeBSDIdentifier);
    DDLogDebug(@"osxInstallerURL=%@", _osxInstallerURL);
    DDLogDebug(@"osxInstallerIconURL=%@", _osxInstallerIconURL);
    DDLogDebug(@"systemDisk=%@", _systemDisk);
    DDLogDebug(@"systemDiskImageURL=%@", _systemDiskImageURL);
    DDLogDebug(@"systemDiskImageDict=%@", _systemDiskImageDict);
    DDLogDebug(@"systemVolumeURL=%@", _systemVolumeURL);
    DDLogDebug(@"systemOSVersion=%@", _systemOSVersion);
    DDLogDebug(@"systemOSBuild=%@", _systemOSBuild);
    DDLogDebug(@"systemVolumeBSDIdentifier=%@", _systemVolumeBSDIdentifier);
    DDLogDebug(@"recoveryDisk=%@", _recoveryDisk);
    DDLogDebug(@"recoveryDiskImageURL=%@", _recoveryDiskImageURL);
    DDLogDebug(@"recoveryDiskImageDict=%@", _recoveryDiskImageDict);
    DDLogDebug(@"recoveryVolumeURL=%@", _recoveryVolumeURL);
    DDLogDebug(@"recoveryVolumeBSDIdentifier=%@", _recoveryVolumeBSDIdentifier);
    DDLogDebug(@"baseSystemDisk=%@", _baseSystemDisk);
    DDLogDebug(@"baseSystemURL=%@", _baseSystemURL);
    DDLogDebug(@"baseSystemVolumeURL=%@", _baseSystemVolumeURL);
    DDLogDebug(@"baseSystemDiskImageDict=%@", _baseSystemDiskImageDict);
    DDLogDebug(@"baseSystemOSVersion=%@", _baseSystemOSVersion);
    DDLogDebug(@"baseSystemOSBuild=%@", _baseSystemOSBuild);
}

@end
