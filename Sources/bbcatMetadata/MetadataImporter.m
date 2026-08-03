#import <CoreServices/CoreServices.h>
#import <Foundation/Foundation.h>

#import "bbcat_bridge.h"

#define PLUGIN_ID "36B40F05-4408-4A7B-8AFD-C6CF9430C996"

typedef struct MetadataImporterPlugin {
    MDImporterInterfaceStruct *interface;
    CFUUIDRef factoryID;
    UInt32 refCount;
} MetadataImporterPlugin;

static HRESULT MetadataImporterQueryInterface(void *instance, REFIID iid, LPVOID *result);
static ULONG MetadataImporterAddRef(void *instance);
static ULONG MetadataImporterRelease(void *instance);
static Boolean GetMetadataForFile(void *instance, CFMutableDictionaryRef attributes,
                                  CFStringRef contentTypeUTI, CFStringRef pathToFile);

static MDImporterInterfaceStruct kMetadataImporterInterface = {
    NULL,
    MetadataImporterQueryInterface,
    MetadataImporterAddRef,
    MetadataImporterRelease,
    GetMetadataForFile,
};

static HRESULT MetadataImporterQueryInterface(void *instance, REFIID iid, LPVOID *result) {
    if (result == NULL) {
        return E_INVALIDARG;
    }
    *result = NULL;

    CFUUIDRef interfaceID = CFUUIDCreateFromUUIDBytes(kCFAllocatorDefault, iid);
    Boolean supported = CFEqual(interfaceID, kMDImporterInterfaceID) ||
                        CFEqual(interfaceID, IUnknownUUID);
    CFRelease(interfaceID);
    if (!supported) {
        return E_NOINTERFACE;
    }

    MetadataImporterAddRef(instance);
    *result = instance;
    return S_OK;
}

static ULONG MetadataImporterAddRef(void *instance) {
    MetadataImporterPlugin *plugin = instance;
    return ++plugin->refCount;
}

static ULONG MetadataImporterRelease(void *instance) {
    MetadataImporterPlugin *plugin = instance;
    UInt32 remaining = --plugin->refCount;
    if (remaining == 0) {
        CFPlugInRemoveInstanceForFactory(plugin->factoryID);
        CFRelease(plugin->factoryID);
        CFAllocatorDeallocate(kCFAllocatorDefault, plugin);
    }
    return remaining;
}

void *MetadataImporterPluginFactory(CFAllocatorRef allocator, CFUUIDRef typeID) {
    if (!CFEqual(typeID, kMDImporterTypeID)) {
        return NULL;
    }

    MetadataImporterPlugin *plugin =
        CFAllocatorAllocate(allocator, sizeof(MetadataImporterPlugin), 0);
    if (plugin == NULL) {
        return NULL;
    }
    plugin->interface = &kMetadataImporterInterface;
    plugin->factoryID = CFUUIDCreateFromString(kCFAllocatorDefault, CFSTR(PLUGIN_ID));
    plugin->refCount = 1;
    CFPlugInAddInstanceForFactory(plugin->factoryID);
    return plugin;
}

static NSString *CopyMetadataString(BbcatDocument *document, int32_t field) {
    char *bytes = bbcat_document_copy_metadata_string(document, field);
    if (bytes == NULL) {
        return nil;
    }
    NSString *value = [[NSString alloc] initWithUTF8String:bytes];
    bbcat_string_free(bytes);
    return value.length > 0 ? value : nil;
}

static NSDate *SauceDate(NSString *value) {
    if (value.length != 8 ||
        [value rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet.invertedSet].location !=
            NSNotFound) {
        return nil;
    }
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    formatter.dateFormat = @"yyyyMMdd";
    return [formatter dateFromString:value];
}

static void SetValue(NSMutableDictionary *attributes, NSString *key, id value) {
    if (value != nil) {
        attributes[key] = value;
    }
}

static Boolean GetMetadataForFile(void *instance, CFMutableDictionaryRef rawAttributes,
                                  CFStringRef contentTypeUTI, CFStringRef pathToFile) {
    (void)instance;
    (void)contentTypeUTI;
    if (rawAttributes == NULL || pathToFile == NULL) {
        return false;
    }

    @autoreleasepool {
        NSString *path = (__bridge NSString *)pathToFile;
        BbcatDocument *document = bbcat_document_open(path.fileSystemRepresentation);
        if (document == NULL) {
            return false;
        }

        BbcatDocumentInfo info = {0};
        if (!bbcat_document_copy_info(document, &info)) {
            bbcat_document_free(document);
            return false;
        }

        NSMutableDictionary *attributes = (__bridge NSMutableDictionary *)rawAttributes;
        NSString *format = CopyMetadataString(document, BBCAT_METADATA_FORMAT);
        NSString *title = CopyMetadataString(document, BBCAT_METADATA_TITLE);
        NSString *author = CopyMetadataString(document, BBCAT_METADATA_AUTHOR);
        NSString *group = CopyMetadataString(document, BBCAT_METADATA_GROUP);
        NSString *date = CopyMetadataString(document, BBCAT_METADATA_DATE);
        NSString *fontName = CopyMetadataString(document, BBCAT_METADATA_FONT_NAME);

        SetValue(attributes, (__bridge NSString *)kMDItemTitle, title);
        SetValue(attributes, (__bridge NSString *)kMDItemAuthors,
                 author == nil ? nil : @[ author ]);
        SetValue(attributes, (__bridge NSString *)kMDItemOrganizations,
                 group == nil ? nil : @[ group ]);
        SetValue(attributes, (__bridge NSString *)kMDItemContentCreationDate, SauceDate(date));

        NSString *description = [NSString stringWithFormat:@"%@ — %zu × %zu characters",
                                                           format, info.columns, info.rows];
        NSString *characterGrid = [NSString stringWithFormat:@"%zu × %zu characters",
                                                             info.columns, info.rows];
        SetValue(attributes, (__bridge NSString *)kMDItemDescription, description);
        if (info.has_pixel_dimensions) {
            attributes[(__bridge NSString *)kMDItemPixelWidth] = @(info.pixel_width);
            attributes[(__bridge NSString *)kMDItemPixelHeight] = @(info.pixel_height);
        }

        SetValue(attributes, @"dev_bbcat_format", format);
        attributes[@"dev_bbcat_columns"] = @(info.columns);
        attributes[@"dev_bbcat_rows"] = @(info.rows);
        attributes[@"dev_bbcat_character_grid"] = characterGrid;
        attributes[@"dev_bbcat_glyph_width"] = @(info.glyph_width);
        attributes[@"dev_bbcat_glyph_height"] = @(info.glyph_height);
        attributes[@"dev_bbcat_raster"] = @(info.raster != 0);
        attributes[@"dev_bbcat_utf8_supported"] = @(info.utf8_supported != 0);
        if (info.embedded_font) {
            attributes[@"dev_bbcat_embedded_font"] = @YES;
        }
        if (info.animated) {
            attributes[@"dev_bbcat_animated"] = @YES;
            attributes[@"dev_bbcat_frame_count"] = @(info.frame_count);
        }
        SetValue(attributes, @"dev_bbcat_group", group);
        SetValue(attributes, @"dev_bbcat_font_name", fontName);
        if (info.has_sauce) {
            if (info.sauce_ice_colors) {
                attributes[@"dev_bbcat_ice_colors"] = @YES;
            }
            if (info.sauce_letter_spacing != 0) {
                attributes[@"dev_bbcat_letter_spacing"] = @(info.sauce_letter_spacing);
            }
        }

        bbcat_document_free(document);
        return true;
    }
}
