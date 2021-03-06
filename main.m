/* main.m - Secure dialog for PIN entry.
 Copyright (C) 2002 Klar<E4>lvdalens Datakonsult AB
 Copyright (C) 2003 g10 Code GmbH
 Copyright (c) 2006 Benjamin Donnachie.
 Copyright (C) 2010 Roman Zechmeister
 Written by Steffen Hansen <steffen@klaralvdalens-datakonsult.se>.
 Modified by Marcus Brinkmann <marcus@g10code.de>.
 Adapted / rewritten by Benjamin Donnachie <benjamin@py-soft.co.uk> for MacOS X.
 Modified by Roman Zechmeister <Roman.Zechmeister@aon.at>
   
 Dieses Programm ist freie Software. Sie können es unter den Bedingungen 
 der GNU General Public License, wie von der Free Software Foundation 
 veröffentlicht, weitergeben und/oder modifizieren, entweder gemäß 
 Version 3 der Lizenz oder (nach Ihrer Option) jeder späteren Version.
 
 Die Veröffentlichung dieses Programms erfolgt in der Hoffnung, daß es Ihnen 
 von Nutzen sein wird, aber ohne irgendeine Garantie, sogar ohne die implizite 
 Garantie der Marktreife oder der Verwendbarkeit für einen bestimmten Zweck. 
 Details finden Sie in der GNU General Public License.
 
 Sie sollten ein Exemplar der GNU General Public License zusammen mit diesem 
 Programm erhalten haben. Falls nicht, siehe <http://www.gnu.org/licenses/>.
*/


#import <Cocoa/Cocoa.h>
#include "pinentry.h"
#include "PinentryController.h"
#import "GPGDefaults.h"
#import "KeychainSupport.h"

static int mac_cmd_handler (pinentry_t pe);
pinentry_cmd_handler_t pinentry_cmd_handler = mac_cmd_handler;


int main(int argc, char *argv[]) {
	pinentry_init ("pinentry-mac");
	
	/* Consumes all arguments.  */
	if (pinentry_parse_opts(argc, argv)) {
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		const char *version = [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"] UTF8String];
		printf("pinentry-mac (pinentry) %s \n", version);
		
		[pool drain];
		return 0;
    }
	
	if (pinentry_loop()) {
		return 1;
	}
	
	return 0;
}


static int mac_cmd_handler (pinentry_t pe) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	if (pe->cache_id && pe->pin) {
		
		//if ([[GPGDefaults gpgDefaults] boolForKey:@"GPGUsesKeychain"]) {
			if (pe->error) {
				storePassphraseInKeychain(pe->cache_id, nil);
			} else {
				char *passphrase;
				passphrase = getPassphraseFromKeychain(pe->cache_id);
				if (passphrase) {
					int len = strlen(passphrase);
					pinentry_setbufferlen(pe, len + 1);
					if (pe->pin) {
						strcpy(pe->pin, passphrase);
						[pool drain];
						return len;
					} else {
						[pool drain];
						return -1;
					}
				}				
			}
		//}
	}
	
	
	PinentryController *pinentry = [[[PinentryController alloc] init] autorelease];
	
	pinentry.grab = pe->grab;
	
	NSString *description = nil;
	if (pe->description) {
		description = [[NSString stringWithUTF8String:pe->description] stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"];
	}
		
	if (pe->pin) { // want_pass.
		if (pe->prompt)
			pinentry.promptText = [NSString stringWithUTF8String:pe->prompt];
		if (description)
			pinentry.descriptionText = description;
		if (pe->ok)
			pinentry.okButtonText = [NSString stringWithUTF8String:pe->ok];
		if (pe->cancel)
			pinentry.cancelButtonText = [NSString stringWithUTF8String:pe->cancel];
		if (pe->error)
			pinentry.errorText = [NSString stringWithUTF8String:pe->error];
		if (pe->cache_id)
			pinentry.canUseKeychain = YES;

		
		if (![pinentry runModal]) {
			[pool drain];
			return -1;
		}
		
		
		const char *passphrase = [pinentry.passphrase ? pinentry.passphrase : @"" UTF8String];
		if (!passphrase) {
			[pool drain];
			return -1;
		}
		
		if (pinentry.saveInKeychain && pe->cache_id) {
			storePassphraseInKeychain(pe->cache_id, passphrase);
		}
		
		
		int len = strlen(passphrase);
		pinentry_setbufferlen(pe, len + 1);
		if (pe->pin) {
			strcpy(pe->pin, passphrase);
			[pool drain];
			return len;
		}
	} else {
		pinentry.confirmMode = YES;
		pinentry.descriptionText = description ? description : @"Confirm";
		pinentry.okButtonText = pe->ok ? [NSString stringWithUTF8String:pe->ok] : nil;
		pinentry.cancelButtonText = pe->cancel ? [NSString stringWithUTF8String:pe->cancel] : nil;
		pinentry.oneButton = pe->one_button;
		
		NSInteger retVal = [pinentry runModal];
		
		[pool drain];
		return retVal;
	}
	
	[pool drain];
	return -1; // Shouldn't get this far.
}


