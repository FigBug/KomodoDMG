/* KomodoDropCtrlr */

#import <Cocoa/Cocoa.h>
#import "KomodoTableView.h"

@interface KomodoDropCtrlr : NSObject<NSFileManagerDelegate>
{
    IBOutlet KomodoTableView *filelist;
	IBOutlet NSButton* clearButton;
	IBOutlet NSButton* createButton;
	IBOutlet NSTextField* totalSize;
	IBOutlet NSProgressIndicator* progress;
	NSMutableArray* files;
	NSMutableArray* fileSizes;
	
	NSString* lpc;
	NSString* fn;
	
	NSTimer* timer;
	BOOL finished;
}
- (void)threadFunction:(id)param;
- (void)timerCb:(NSTimer*)aTimer;

- (id)init;
- (IBAction)clear:(id)sender;
- (IBAction)createDmg:(id)sender;

- (int)numberOfRowsInTableView:(NSTableView*)aTableView;
- (id)tableView:(NSTableView*)aTableView objectValueForTableColumn:(NSTableColumn*)aTableColumn row:(int)rowIndex;

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard;
- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op;
- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation;

- (NSString *)stringFromFileSize:(unsigned long long)theSize;
- (NSNumber*)fileSize:(NSString*)filePath;

- (void)updateSize;

- (void)windowWillClose:(NSNotification *)aNotification;

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename;
- (void)application:(NSApplication *)theApplication openFiles:(NSArray *)filenames;

@end
