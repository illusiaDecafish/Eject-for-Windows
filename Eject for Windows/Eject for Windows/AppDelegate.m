//
//  AppDelegate.m
//  Eject for Windows
//
//  Created by decafish on 2019/08/19.
//  Copyright © 2019 illusia decafish. All rights reserved.
//

#import "AppDelegate.h"

#include <stdlib.h>
#include <string.h>

static BOOL runAlertPanel(NSString *info, NSString *message, NSString *firstButtonTitle, NSString *secondButtonTitle);
static BOOL runCriticalAlertPanel(NSString *info, NSString *message, NSString *firstButtonTitle);

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // currently do nothing.
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
    BOOL        yn = NO;
    NSString    *type;
    NSError     *error = nil;
    NSWorkspace *wspace = [NSWorkspace sharedWorkspace];
    type = [wspace typeOfFile:filename error:&error];
    if (error)
        yn = NO;
    else if ([type isEqualToString:(NSString *)kUTTypeVolume])
        yn = [self  checkVolume:filename];
    else if ([type isEqualToString:(NSString *)kUTTypeFolder])
        yn = [self querryForFolder:filename];
    else
        yn = [self performForOtherTypes:filename];
    [NSTimer scheduledTimerWithTimeInterval:0.5
                                     target:self
                                   selector:@selector(terminateApp:)
                                   userInfo:self
                                    repeats:NO];
    return yn;
}

- (void)terminateApp:(NSTimer *)timer
{
    [NSApp terminate:self];
}

- (BOOL)querryForFolder:(NSString *)filename
{
    if(runAlertPanel(NSLocalizedString(@"Do you want to continue to remove?", @""),
                     [NSString stringWithFormat:@"\"%@\" %@.", [filename lastPathComponent],
                      NSLocalizedString(@"is a folder", @"")],
                     NSLocalizedString(@"Suspend", @""),
                     NSLocalizedString(@"Continue", @"")))
        return YES;
    /*  NSRunAlertPanel() is deprecated
     if (NSRunAlertPanel(NSLocalizedString(@"Do you want to continue to remove?", @""),
     mes,
     NSLocalizedString(@"Suspend", @""),
     NSLocalizedString(@"Continue", @""),
     nil) == NSAlertDefaultReturn) {
     return YES;
     }
     */
    [self removeResource:filename];
    return YES;
}

- (BOOL)performForOtherTypes:(NSString *)filename
{
    return runCriticalAlertPanel(NSLocalizedString(@"Can not be carried out.", @""),
                                 [NSString stringWithFormat:@"\"%@\" %@.", [filename lastPathComponent],
                                  NSLocalizedString(@"is a normal file", @"")],
                                 @"OK");
    /*  NSRunCriticalAlertPanel() is deprecated
     NSRunCriticalAlertPanel (NSLocalizedString(@"Can not be carried out.", @""),
     mes,
     @"OK",
     nil,
     nil);
     */
    return YES;
}

- (BOOL)checkVolume:(NSString *)filename
{
    NSWorkspace *wspace = [NSWorkspace sharedWorkspace];
    BOOL        rem;
    BOOL        wri;
    BOOL        um;
    NSString    *desc;
    NSString    *type;
    NSString    *lastName = [filename lastPathComponent];
    NSString    *volumeName = [NSString stringWithFormat:@"%@ \"%@\"", NSLocalizedString(@"Volume", @""), lastName];
    [wspace getFileSystemInfoForPath:filename
                         isRemovable:&rem
                          isWritable:&wri
                       isUnmountable:&um
                         description:&desc
                                type:&type];
    if (! rem) {
        runCriticalAlertPanel (NSLocalizedString(@"Can not be carried out.", @""),
                               [NSString stringWithFormat:@"%@%@.", volumeName,
                                NSLocalizedString(@"is not removable", @"")],
                               @"OK");
        return YES;
    }
    if (! wri) {
        runCriticalAlertPanel (NSLocalizedString(@"Can not be carried out.", @""),
                               [NSString stringWithFormat:@"%@%@.", volumeName,
                                NSLocalizedString(@"is not writable", @"")],
                               @"OK");
        return YES;
    }
    if (! um) {
        runCriticalAlertPanel (NSLocalizedString(@"Can not be carried out.", @""),
                               [NSString stringWithFormat:@"%@%@.", volumeName,
                                NSLocalizedString(@"is not unmountable", @"")],
                               @"OK");
        return YES;
    }
    if (! ([type isEqualToString:@"msdos"] || [type isEqualToString:@"exfat"])) {
        if (runAlertPanel(NSLocalizedString(@"Do you want to continue to remove?", @""),
                          [NSString stringWithFormat:@"%@%@.", volumeName,
                           NSLocalizedString(@"is not a FAT format", @"")],
                          NSLocalizedString(@"Suspend", @""),
                          NSLocalizedString(@"Continue", @"")))
            return YES;
    }
    [self removeResourceAndEject:filename];
    
    return YES;
}

- (BOOL)removeResource:(NSString *)path
{
    const size_t    num = 1024 * 2;
    char            *buf = (char *)malloc(num * 2 * sizeof(char));
    char            *cpath = (char *)malloc(num * sizeof(char));
    
    if (! [path getCString:cpath maxLength:num encoding:NSUTF8StringEncoding]) {
        runCriticalAlertPanel (NSLocalizedString(@"Can not be carried out.", @""),
                               NSLocalizedString(@"Perhaps there is encoding error or something.", @""),
                               NSLocalizedString(@"OK", @""));
        return YES;
    }
    
    sprintf(buf, "find '%s' -name '._*' -delete", cpath);
    system(buf);
    sprintf(buf, "find '%s' -name '.DS_Store' -delete", cpath);
    system(buf);
    sprintf(buf, "rm -Rf '%s/.Trashes'", cpath);
    system(buf);
    sprintf(buf, "rm -Rf '%s/.Spotlight'", cpath);
    system(buf);
    sprintf(buf, "rm -Rf '%s/.Spotlight-V100'", cpath);
    system(buf);
    sprintf(buf, "rm -Rf '%s/.fseventsd'", cpath);
    system(buf);
    //    additional files to remove
    //    sprintf(buf, "rm -Rf '%s/others'", cpath);
    //    system(buf);
    
    free(cpath);
    free(buf);
    return YES;
}


- (BOOL)removeResourceAndEject:(NSString *)path
{
    NSWorkspace *wspace = [NSWorkspace sharedWorkspace];
    
    if (! [[wspace mountedRemovableMedia] containsObject:path]) {
        runCriticalAlertPanel (NSLocalizedString(@"Can not be carried out.", @""),
                               NSLocalizedString(@"The device is not mounted.", @""),
                               NSLocalizedString(@"OK", @""));
        return YES;
    }
    
    [self removeResource:path];
    if ([wspace respondsToSelector:@selector(unmountAndEjectDeviceAtURL:error:)]) {
        NSError     *error = nil;
        NSURL       *url = [NSURL fileURLWithPath:path];
        [wspace unmountAndEjectDeviceAtURL:url error:&error];
        if (error != nil) {
            if ([error code] != -47) {
                NSAlert *alert = [NSAlert alertWithError:error];
                [alert runModal];
            }
            else {
                runCriticalAlertPanel (NSLocalizedString(@"Can not be carried out.", @""),
                                       NSLocalizedString(@"An application currently uses the device.", @""),
                                       NSLocalizedString(@"OK", @""));
            }
        }
    }
    else {
        if (! [wspace unmountAndEjectDeviceAtPath:path])
            runCriticalAlertPanel (NSLocalizedString(@"Can not be carried out.", @""),
                                   NSLocalizedString(@"The device cannot be unmounted somehow.", @""),
                                   NSLocalizedString(@"OK", @""));
    }
    return YES;
}

@end


static BOOL runCriticalAlertPanel(NSString *info, NSString *message, NSString *firstButtonTitle)
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleCritical;
    alert.informativeText = info;
    alert.messageText = message;
    [alert addButtonWithTitle:firstButtonTitle];
    if ([alert runModal] == NSAlertFirstButtonReturn)
        return YES;
    //  there are currently no return values other than YES.
    return YES;
}

static BOOL runAlertPanel(NSString *info, NSString *message, NSString *firstButtonTitle, NSString *secondButtonTitle)
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.informativeText = info;
    alert.messageText = message;
    [alert addButtonWithTitle:firstButtonTitle];
    [alert addButtonWithTitle:secondButtonTitle];
    if ([alert runModal] == NSAlertFirstButtonReturn)
        return YES;
    //  there are currently no return values other than YES.
    return YES;
}
