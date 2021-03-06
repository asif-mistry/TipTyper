//
//  BPDocument.m
//  TipTyper
//
//  Created by Bruno Philipe on 2/9/14.
//  TipTyper – The simple plain-text editor for OS X.
//  Copyright (c) 2014 Bruno Philipe. All rights reserved.
//  
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.

#import "BPDocument.h"
#import "BPEncodingTool.h"

@interface BPDocument ()

//@property (strong) NSFileHandle *fileHandle;

@property BOOL loadedSuccessfully;

@end

@implementation BPDocument

- (id)init
{
    self = [super init];
    if (self)
	{
		_fileString = @"";
		_encoding = NSUTF8StringEncoding;
    }
    return self;
}

- (NSString *)windowNibName
{
	return @"BPDocument";
}

- (BOOL)isLoadedFromFile
{
	return self.fileURL != nil;
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
	[super windowControllerDidLoadNib:aController];

	[self setDisplayWindow:(BPDocumentWindow*)aController.window];
	[self.displayWindow setDocument:self];
	[self.displayWindow construct];
	[self.displayWindow updateTextViewContents];
}

+ (BOOL)autosavesInPlace
{
    return YES;
}

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing *)outError
{
	NSStringEncoding usedEncoding = 0;
	NSError *error = nil;
	NSString *string = nil;
	
	if ([[url pathExtension] isEqualToString:@"pdf"] || [typeName rangeOfString:@".pdf"].location != NSNotFound)
	{
		if (*outError != nil)
		{
			*outError = [NSError errorWithDomain:@"TipTyper"
											code:0x1002
										userInfo:@{NSLocalizedFailureReasonErrorKey:
													   NSLocalizedString(@"BP_ERROR_FILETYPE", nil)}];
		}
		return NO;
	}
	
	error = [self checkSizeWithUrl:url];
	
	if (error)
	{
		*outError = error;
		return NO;
	}
	
	string = [NSString stringWithContentsOfURL:url usedEncoding:&usedEncoding error:&error];
	
	if (string && usedEncoding > 0 && !error)
	{
		_encoding = usedEncoding;
		
		[self setFileString:string];
		[self.displayWindow updateTextViewContents];
	}
	else
	{
		usedEncoding = 0;
		
		string = [BPEncodingTool loadStringWithPathAskingForEncoding:url usedEncoding:&usedEncoding];
		
		if (string && usedEncoding > 0)
		{
			_encoding = usedEncoding;
			
			[self setFileString:string];
			[self.displayWindow updateTextViewContents];
		}
	}
	
	return string != nil;
}

- (BOOL)writeToURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing *)outError
{
	return [[self.displayWindow.textView string] writeToURL:url atomically:YES encoding:self.encoding error:outError];
}

- (BOOL)revertToContentsOfURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing *)outError
{
	if ([[NSFileManager defaultManager] fileExistsAtPath:[url relativePath]])
	{
		NSError *error = [self checkSizeWithUrl:url];

		if (error)
		{
			*outError = error;
			return NO;
		}
		
		return [self readFromURL:url ofType:typeName error:outError];
	}

	return NO;
}

- (NSPrintOperation *)printOperationWithSettings:(NSDictionary *)printSettings error:(NSError **)outError
{
	NSPrintInfo *prtInfo = [self printInfo];

	[prtInfo setVerticallyCentered:NO];

	NSPrintOperation *prtOpr = [NSPrintOperation printOperationWithView:self.displayWindow.textView printInfo:prtInfo];
	[prtOpr setJobTitle:self.displayName];
	return prtOpr;
}

- (void)canCloseDocumentWithDelegate:(id)delegate shouldCloseSelector:(SEL)shouldCloseSelector contextInfo:(void *)contextInfo
{
	[super canCloseDocumentWithDelegate:delegate shouldCloseSelector:shouldCloseSelector contextInfo:contextInfo];
}

- (NSError*)checkSizeWithUrl:(NSURL*)url
{
	NSError *error = nil;
	NSNumber *fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:[url relativePath]
																		   error:&error] objectForKey:NSFileSize];
	
	if (error)
	{
		return error;
	}
	
	if ([fileSize unsignedIntegerValue] > 500 * 1000000) //Filesize > 500MB
	{
		return [NSError errorWithDomain:@"TipTyper"
								   code:0x1001
							   userInfo:@{NSLocalizedFailureReasonErrorKey:
											  NSLocalizedString(@"BP_ERROR_FILESIZE", nil)}];
	}
	
	return nil;
}

#pragma mark - Save Panel

- (NSString*)fileNameExtensionForType:(NSString *)typeName saveOperation:(NSSaveOperationType)saveOperation
{
	NSString *currentExtension = [self.fileURL pathExtension];
	if (currentExtension) {
		return currentExtension;
	} else
		return @"txt";
}

- (BOOL)shouldRunSavePanelWithAccessoryView
{
	return NO;
}

- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel
{
	if ([savePanel respondsToSelector:@selector(setShowsTagField:)])
	{
		[savePanel setShowsTagField:YES];
	}
	
	[savePanel setAllowsOtherFileTypes:YES];
	[savePanel setExtensionHidden:NO];
  
	return YES;
}

#pragma mark - Actions

- (IBAction)pickEncodingAndReload:(id)sender
{
	NSStringEncoding usedEncoding = self.encoding;
	NSString *string = [BPEncodingTool loadStringWithPathAskingForEncoding:self.fileURL usedEncoding:&usedEncoding];

	if (string && usedEncoding > 0)
	{
		_encoding = usedEncoding;
		
		[self setFileString:string];
		[self.displayWindow updateTextViewContents];
	}
}

- (IBAction)pickEncodingAndSave:(id)sender
{
	NSStringEncoding encoding = [BPEncodingTool requestEncoding:self.encoding];
	
	if (encoding > 0)
	{
		_encoding = encoding;
		
		[self saveDocument:sender];
		[self.displayWindow updateEncodingLabel];
	}
}

- (void)toggleLinesCounter:(id)sender
{
	[self.displayWindow toggleLinesCounter];
}

- (void)toggleInfoView:(id)sender
{
	[self.displayWindow toggleInfoView];
}

- (void)toggleInvisibles:(id)sender
{
	[self.displayWindow toggleInvisibles];
}

@end
