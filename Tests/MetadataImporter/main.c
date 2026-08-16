#include <CoreFoundation/CFPlugInCOM.h>
#include <CoreServices/CoreServices.h>
#include <stdio.h>
#include <string.h>

static int fail(const char *message) {
    fprintf(stderr, "%s\n", message);
    return 1;
}

int main(int argc, const char *argv[]) {
    if (argc != 4) {
        return fail("usage: metadata-importer-tests IMPORTER FILE UTI");
    }

    CFURLRef importerURL = CFURLCreateFromFileSystemRepresentation(
        kCFAllocatorDefault, (const UInt8 *)argv[1], strlen(argv[1]), true);
    CFPlugInRef plugin = CFPlugInCreate(kCFAllocatorDefault, importerURL);
    CFRelease(importerURL);
    if (plugin == NULL) {
        return fail("could not create metadata importer plug-in");
    }

    CFArrayRef factories =
        CFPlugInFindFactoriesForPlugInTypeInPlugIn(kMDImporterTypeID, plugin);
    if (factories == NULL || CFArrayGetCount(factories) != 1) {
        if (factories != NULL) CFRelease(factories);
        CFRelease(plugin);
        return fail("metadata importer factory was not registered");
    }

    CFUUIDRef factoryID = (CFUUIDRef)CFArrayGetValueAtIndex(factories, 0);
    MDImporterInterfaceStruct **instance =
        CFPlugInInstanceCreate(kCFAllocatorDefault, factoryID, kMDImporterTypeID);
    if (instance == NULL) {
        CFRelease(factories);
        CFRelease(plugin);
        return fail("metadata importer instance could not be created");
    }

    CFMutableDictionaryRef attributes = CFDictionaryCreateMutable(
        kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks,
        &kCFTypeDictionaryValueCallBacks);
    CFStringRef path = CFStringCreateWithFileSystemRepresentation(kCFAllocatorDefault, argv[2]);
    CFStringRef uti = CFStringCreateWithCString(kCFAllocatorDefault, argv[3], kCFStringEncodingUTF8);
    Boolean imported = (*instance)->ImporterImportData(instance, attributes, uti, path);

    CFStringRef format = CFDictionaryGetValue(attributes, CFSTR("dev_bbcat_format"));
    CFNumberRef columns = CFDictionaryGetValue(attributes, CFSTR("dev_bbcat_columns"));
    CFStringRef characterGrid =
        CFDictionaryGetValue(attributes, CFSTR("dev_bbcat_character_grid"));
    CFBooleanRef trueColor = CFDictionaryGetValue(attributes, CFSTR("dev_bbcat_true_color"));
    Boolean hasIrrelevantFlags =
        CFDictionaryContainsKey(attributes, CFSTR("dev_bbcat_animated")) ||
        CFDictionaryContainsKey(attributes, CFSTR("dev_bbcat_frame_count")) ||
        CFDictionaryContainsKey(attributes, CFSTR("dev_bbcat_embedded_font")) ||
        CFDictionaryContainsKey(attributes, CFSTR("dev_bbcat_ice_colors"));
    int result = 0;
    if (!imported || format == NULL || columns == NULL || characterGrid == NULL ||
        trueColor == NULL || CFBooleanGetValue(trueColor) || hasIrrelevantFlags) {
        result = fail("metadata importer did not return expected document information");
    } else {
        puts("Metadata importer tests passed");
    }

    CFRelease(uti);
    CFRelease(path);
    CFRelease(attributes);
    (*instance)->Release(instance);
    CFRelease(factories);
    CFRelease(plugin);
    return result;
}
