#import "KomodoDropCtrlr.h"

@implementation KomodoDropCtrlr

- (id)init
{
	self = [super init];
    if (self)
    {
        files = [[NSMutableArray alloc] init];
        fileSizes = [[NSMutableArray alloc] init];
    }
	return self;
}

- (IBAction)clear:(id)sender
{
	[files removeAllObjects];
	[fileSizes removeAllObjects];
	[filelist reloadData];
	
	[clearButton setEnabled: [files count] > 0 ? YES : NO];
	[createButton setEnabled: [files count] > 0 ? YES : NO];
	[self updateSize];
}

- (IBAction)createDmg:(id)sender
{
	NSSavePanel* panel = [NSSavePanel savePanel];
	[panel setTitle: @"Create DMG"];
	[panel setAllowedFileTypes: [NSArray arrayWithObject: @"dmg"]];
	[panel setPrompt: @"Create"];

	int res = [panel runModal];
	if (res == NSFileHandlingPanelOKButton)
	{	
		[createButton setEnabled: NO];
		[clearButton setEnabled: NO];
		[filelist setEnabled: NO];
		
		[totalSize setHidden: YES];
		[progress setHidden: NO]; 
		[progress setIndeterminate: YES];
		[progress startAnimation: self];
		
		[NSThread detachNewThreadSelector:@selector(threadFunction:) toTarget: self withObject:nil];
		
		lpc = [[[panel URL] path] lastPathComponent];
		fn =  [[panel URL] path];
		
		finished = NO;
		timer = [NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(timerCb:) userInfo:nil repeats:YES];
	}
}

- (void)timerCb:(NSTimer*)aTimer
{
	if (finished)
	{
		[timer invalidate];
        timer = nil;
		
		NSAlert* alert = [NSAlert alertWithMessageText:@"Complete" defaultButton:@"ok" alternateButton:nil otherButton:nil informativeTextWithFormat:@"The DMG file has been created"];
		[alert runModal];
		
		[progress stopAnimation: self];
		[progress setHidden: YES];
		[totalSize setHidden: NO];
		
		[createButton setEnabled: YES];
		[clearButton setEnabled: YES];	
		[filelist setEnabled: YES];
	}
}

- (void)threadFunction:(id)param
{	
    @autoreleasepool
    {
        unsigned long long size = 0;
        int i;
        for (i = 0; i < [fileSizes count]; i++)
            size += [[fileSizes objectAtIndex: i] unsignedLongLongValue];
        
        int megaBytes;
        megaBytes = (int)((double)(size) / (1024 * 1024) + 1) + 1;
        
        char buffer[1024];
        
        system("rm /tmp/temp.dmg");
        system("rm /tmp/vol.txt");
        
        sprintf(buffer, "hdiutil create -megabytes %d /tmp/temp.dmg", megaBytes);
        system(buffer);
        system("hdid -nomount /tmp/temp.dmg > /tmp/vol.txt");
        
        char vol[1024];
        strcpy(vol, [[NSString stringWithContentsOfFile: @"/tmp/vol.txt" encoding:NSASCIIStringEncoding error:nil] UTF8String]);
        
        char* c;
        c = strchr(vol, ' ');
        if (c) *c = 0;
        c = strchr(vol, '\n');
        if (c) *c = 0;
        
        char name[1024];
        strcpy(name, [lpc UTF8String]);
        *strrchr(name, '.') = 0;
        
        sprintf(buffer, "newfs_hfs -v \"%s\" %s", name, vol);
        system(buffer);
        sprintf(buffer, "hdiutil eject %s", vol);
        system(buffer);
        system("hdid /tmp/temp.dmg");
        
        for (i = 0; i < [files count]; i++)
        {
            sprintf(buffer, "cp -R -f \"%s\" \"/Volumes/%s\"", [[files objectAtIndex: i] UTF8String], name);
            system(buffer);
        }
        
        sprintf(buffer, "hdiutil eject %s", vol);
        system(buffer);
        sprintf(buffer, "hdiutil convert -format UDZO /tmp/temp.dmg -o \"%s\"", [fn UTF8String]);
        system(buffer);
        
        system("rm /tmp/temp.dmg");
        system("rm /tmp/vol.txt");
        
        finished = YES;
    }
}

- (void)awakeFromNib
{
	[NSApp setDelegate: self];
	
	NSArray* types = [NSArray arrayWithObject: NSFilenamesPboardType];	
	[filelist registerForDraggedTypes:types];	
	
	NSArray* cols = [filelist tableColumns];
	[[cols objectAtIndex: 0] setIdentifier: @"Icon"];
	[[cols objectAtIndex: 1] setIdentifier: @"File"];
	[[cols objectAtIndex: 2] setIdentifier: @"Size"];
	
	[clearButton setEnabled: [files count] > 0 ? YES : NO];
	[createButton setEnabled: [files count] > 0 ? YES : NO];	
	[self updateSize];
}

- (int)numberOfRowsInTableView:(NSTableView*)aTableView
{
	return [files count];
}

- (id)tableView:(NSTableView*)aTableView objectValueForTableColumn:(NSTableColumn*)aTableColumn row:(int)rowIndex
{
	id ident = [aTableColumn identifier];
	if ([ident isEqual: @"File"])
	{
		NSFileManager *fileManager = [NSFileManager defaultManager];		
		return [fileManager displayNameAtPath: [files objectAtIndex: rowIndex]];
	}
	else if ([ident isEqual: @"Size"])
	{
		return [self stringFromFileSize: [[fileSizes objectAtIndex: rowIndex] unsignedLongLongValue]];
	}
	else if ([ident isEqual: @"Icon"])
	{
		NSWorkspace* ws = [NSWorkspace sharedWorkspace];
		return [ws iconForFile: [files objectAtIndex: rowIndex]];
	}
	return nil;
}

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard
{
	return NO;
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op
{
	return NSDragOperationEvery;
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation;
{
	NSPasteboard* pb = [info draggingPasteboard];
	
	if ([[pb types] containsObject:NSFilenamesPboardType])
	{
		NSArray *filesDropped = [pb propertyListForType:NSFilenamesPboardType];
		int numberOfFiles = [filesDropped count];
		
		NSFileManager *fileManager = [NSFileManager defaultManager];
		
		int i;
		for (i = 0; i < numberOfFiles; i++)
		{
			NSString* file = [filesDropped objectAtIndex: i];
			
			BOOL dir;
			BOOL exists;
			exists = [fileManager fileExistsAtPath: file isDirectory: &dir];
			
			if (exists)		
			{
				BOOL dupe = NO;
				int j;
				for (j = 0; j < [files count]; j++)
				{
					if ([[files objectAtIndex: j] isEqual: [filesDropped objectAtIndex: i]])
						dupe = YES;
				}						
				if (dupe == NO)
				{
					[files addObject: file];		
					[fileSizes addObject: [self fileSize: [filesDropped objectAtIndex: i]]];
				}					
			}
		}
	}
		
	[filelist reloadData];
	
	[clearButton setEnabled: [files count] > 0 ? YES : NO];
	[createButton setEnabled: [files count] > 0 ? YES : NO];
	[self updateSize];
	
	return YES;
}

- (NSString *)stringFromFileSize:(unsigned long long)theSize
{
	float floatSize = theSize;
	if (theSize<1023)
		return([NSString stringWithFormat: @"%d bytes", (int)theSize]);
	floatSize = floatSize / 1024;
	if (floatSize<1023)
		return([NSString stringWithFormat: @"%1.1f KB", floatSize]);
	floatSize = floatSize / 1024;
	if (floatSize<1023)
		return([NSString stringWithFormat: @"%1.1f MB", floatSize]);
	floatSize = floatSize / 1024;
	
	// Add as many as you like
	
	return([NSString stringWithFormat:@"%1.1f GB",floatSize]);
}

- (NSNumber*)fileSize:(NSString*)filePath
{
	NSFileManager* fm = [NSFileManager defaultManager];
	BOOL isDirectory = NO;
		
	// Determine Paths to Add
	[fm fileExistsAtPath:filePath isDirectory:&isDirectory];
	if (isDirectory) 
	{
		unsigned long long size = 0;	
        NSArray* contents = [fm contentsOfDirectoryAtPath:filePath error:nil];
		int i;
		
		for (i = 0; i < [contents count]; i++)
		{
			NSString* itm = [NSString stringWithFormat: @"%@/%@", filePath, [contents objectAtIndex: i]];
			
			[fm fileExistsAtPath: itm isDirectory: &isDirectory];
			if (isDirectory)
			{
				size += [[self fileSize: itm] unsignedLongLongValue];
			}
			else
			{
				NSDictionary* attr = [fm attributesOfItemAtPath:itm error:nil];
				size += [[attr objectForKey: NSFileSize] unsignedLongLongValue];
			}
		}
		return [NSNumber numberWithUnsignedLongLong: size];
	} 
	else 
	{
        NSDictionary* attr = [fm attributesOfItemAtPath:filePath error:nil];
        NSLog(@"%@: %@", filePath, [attr objectForKey: NSFileSize]);
		return [attr objectForKey: NSFileSize];
	}
	return [NSNumber numberWithInt: 0];
}

- (void)updateSize
{
	unsigned long long size = 0;
	
	int i;
	for (i = 0; i < [fileSizes count]; i++)
	{
		size += [[fileSizes objectAtIndex: i] unsignedLongLongValue];
	}
	NSString* msg = [NSString stringWithFormat: @"Total size: %@", [self stringFromFileSize: size]];
	[totalSize setStringValue: msg];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
	NSApplication* app = [NSApplication sharedApplication];
	[app terminate: self];
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
		
	BOOL dir;
	BOOL exists;
	exists = [fileManager fileExistsAtPath: filename isDirectory: &dir];
	
	if (exists)		
	{
		BOOL dupe = NO;
		int j;
		for (j = 0; j < [files count]; j++)
		{
			if ([[files objectAtIndex: j] isEqual: filename])
				dupe = YES;
		}						
		if (dupe == NO)
		{
			[files addObject: filename];		
			[fileSizes addObject: [self fileSize: filename]];
		}					
	}

	[filelist reloadData];
	
	[clearButton setEnabled: [files count] > 0 ? YES : NO];
	[createButton setEnabled: [files count] > 0 ? YES : NO];
	[self updateSize];	
	
	return YES;
}

- (void)application:(NSApplication *)theApplication openFiles:(NSArray *)filenames
{
	int numberOfFiles = [filenames count];
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	int i;
	for (i = 0; i < numberOfFiles; i++)
	{
		NSString* file = [filenames objectAtIndex: i];
		
		BOOL dir;
		BOOL exists;
		exists = [fileManager fileExistsAtPath: file isDirectory: &dir];
		
		if (exists)		
		{
			BOOL dupe = NO;
			int j;
			for (j = 0; j < [files count]; j++)
			{
				if ([[files objectAtIndex: j] isEqual: file])
					dupe = YES;
			}						
			if (dupe == NO)
			{
				[files addObject: file];		
				[fileSizes addObject: [self fileSize: file]];
			}					
		}
	}
	
	[filelist reloadData];
	
	[clearButton setEnabled: [files count] > 0 ? YES : NO];
	[createButton setEnabled: [files count] > 0 ? YES : NO];
	[self updateSize];	
	
	[NSApp replyToOpenOrPrint: NSApplicationDelegateReplySuccess];
}

@end
