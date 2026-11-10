#include "4DPluginAPI.h"
#include "PrivateTypes.h"
#include "EntryPoints.h"

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <map>
#include <string>

static std::map<PA_Unichar*, size_t> strings;
static std::map<PA_Handle, size_t> handles;
struct HostPicture { unsigned refs; };
static std::map<PA_Picture, HostPicture*> pictures;
static bool nullEmpty;
static bool commandFailure;
static CUTF16String expected;

static void check(bool condition, const char* message)
{
    if (!condition) {
        std::fprintf(stderr, "ownership assertion: %s\n", message);
        std::exit(1);
    }
}

static PA_Unistring makeString(const PA_Unichar* text)
{
    size_t n = 0;
    if (text) while (text[n]) ++n;
    PA_Unistring result = {};
    if (n || !nullEmpty) {
        result.fString = new PA_Unichar[n + 1];
        if (n) std::memcpy(result.fString, text, n * sizeof(PA_Unichar));
        result.fString[n] = 0;
        result.fLength = static_cast<PA_long32>(n);
        strings[static_cast<PA_Unichar*>(result.fString)] = n;
    }
    return result;
}

static CUTF16String readString(PA_Unistring text)
{
    if (!text.fString) {
        check(text.fLength == 0, "null text length");
        return CUTF16String();
    }
    check(strings.count(static_cast<PA_Unichar*>(text.fString)) == 1, "read of released string");
    check(strings.at(static_cast<PA_Unichar*>(text.fString)) == static_cast<size_t>(text.fLength), "exact text length");
    check(text.fString[text.fLength] == 0, "text terminator");
    return CUTF16String(text.fString, text.fLength);
}

static void disposeString(PA_Unistring text)
{
    if (text.fString) {
        check(strings.erase(static_cast<PA_Unichar*>(text.fString)) == 1, "double string disposal");
        delete[] text.fString;
    }
}

static PA_Picture makePicture()
{
    HostPicture* p = new HostPicture{1};
    pictures[p] = p;
    return p;
}

static HostPicture* picture(PA_Picture p)
{
    check(pictures.count(p) == 1, "released picture");
    return pictures.at(p);
}

static void disposePicture(PA_Picture p)
{
    if (p && --picture(p)->refs == 0) {
        HostPicture* value = pictures.at(p);
        pictures.erase(p);
        delete value;
    }
}

static void clear(PA_Variable* v)
{
    switch (v->fType) {
        case eVK_Unistring: disposeString(v->uValue.fString); break;
        case eVK_Picture: disposePicture(v->uValue.fPicture); break;
        case eVK_ArrayUnicode: {
            PA_Handle h = v->uValue.fArray.fData;
            if (h) {
                check(handles.count(h) == 1, "array handle ownership");
                check(handles.at(h) >= (v->uValue.fArray.fNbElements + 1) * sizeof(PA_Unistring),
                      "array count fits allocation");
                PA_Unistring* data = reinterpret_cast<PA_Unistring*>(*h);
                for (PA_long32 i = 0; i <= v->uValue.fArray.fNbElements; ++i)
                    disposeString(data[i]);
                handles.erase(h);
                std::free(*h);
                delete h;
            }
            break;
        }
        case eVK_Undefined:
        case eVK_Longint:
            break;
        default: check(false, "unmodeled variable clear");
    }
    std::memset(v, 0, sizeof(*v));
    v->fType = eVK_Undefined;
}

static CUTF16String fromUTF8(const char* bytes, size_t size)
{
    CFStringRef s = CFStringCreateWithBytes(kCFAllocatorDefault,
        reinterpret_cast<const UInt8*>(bytes), size, kCFStringEncodingUTF8, false);
    check(s != nullptr, "synthetic valid UTF-8");
    CUTF16String result(CFStringGetLength(s), 0);
    if (!result.empty())
        CFStringGetCharacters(s, CFRangeMake(0, result.size()), &result[0]);
    CFRelease(s);
    return result;
}

static void host(short selector, EngineBlock* eb)
{
    switch (selector) {
        case EX_CREATE_UNISTRING:
            eb->fUniString1 = makeString(reinterpret_cast<PA_Unichar*>(eb->fHandle));
            break;
        case EX_DISPOSE_UNISTRING: disposeString(eb->fUniString1); break;
        case EX_SET_UNISTRING: {
            PA_Unistring copy = makeString(reinterpret_cast<PA_Unichar*>(eb->fHandle));
            disposeString(eb->fUniString1);
            eb->fUniString1 = copy;
            break;
        }
        case EX_CREATE_PICTURE:
            check(eb->fParam1 == 0 || eb->fPtr1 != nullptr, "picture bytes");
            eb->fPicture = makePicture();
            eb->fError = 0;
            break;
        case EX_DUPLICATE_PICTURE:
            if (eb->fPicture) {
                if (eb->fParam1 == 0) ++picture(eb->fPicture)->refs;
                else {
                    picture(eb->fPicture);
                    eb->fPicture = makePicture();
                }
            }
            break;
        case EX_DISPOSE_PICTURE: disposePicture(eb->fPicture); break;
        case EX_GET_PICTURE_DATA:
            picture(eb->fPicture);
            // No representations. Failed output is deliberately unusable.
            eb->fError = eER_IncompatibleTypes;
            std::memset(&eb->fUniString1, 0xa5, sizeof(eb->fUniString1));
            break;
        case EX_CLEAR_VARIABLE: clear(static_cast<PA_Variable*>(eb->fPtr1)); break;
        case EX_HANDLE_MANAGER: {
            eb->fError = 0;
            if (eb->fParam1 == 1) {
                PA_Handle h = new char*;
                sLONG_PTR length = eb->fParam2;
                *h = static_cast<char*>(std::calloc(std::max<sLONG_PTR>(1, length), 1));
                check(*h != nullptr, "host handle allocation");
                handles[h] = eb->fParam2;
                eb->fHandle = h;
            } else {
                PA_Handle handle = eb->fHandle;
                check(handles.count(handle) == 1, "live handle");
                switch (eb->fParam1) {
                    case 2:
                        handles.erase(handle);
                        std::free(*handle);
                        delete handle;
                        break;
                    case 3: {
                        sLONG_PTR length = eb->fParam2;
                        char* p = static_cast<char*>(std::realloc(*handle,
                            std::max<sLONG_PTR>(1, length)));
                        check(p != nullptr, "host handle resize");
                        *handle = p;
                        handles[handle] = length;
                        break;
                    }
                    case 4: eb->fParam2 = handles.at(handle); break;
                    case 5: eb->fParam3 = reinterpret_cast<sLONG_PTR>(*handle); break;
                    case 6: break;
                    default: check(false, "unmodeled handle operation");
                }
            }
            break;
        }
        case EX_CONVERT_CHARSET_TO_CHARSET: {
            check(eb->fParam2 == eVTC_UTF_8 && eb->fParam4 == eVTC_UTF_16,
                  "conversion direction");
            CUTF16String text = fromUTF8(static_cast<char*>(eb->fPtr1), eb->fParam1);
            size_t bytes = text.size() * sizeof(PA_Unichar);
            check(bytes <= static_cast<size_t>(eb->fParam3), "conversion byte capacity");
            if (bytes) std::memcpy(eb->fPtr2, text.data(), bytes);
            // SDK explicitly returns bytes, excluding any terminator.
            eb->fParam3 = bytes;
            eb->fError = 0;
            break;
        }
        case EX_EXECUTE_COMMAND_BY_ID: {
            PA_Variable** args = static_cast<PA_Variable**>(eb->fPtr1);
            PA_Variable* result = static_cast<PA_Variable*>(eb->fPtr2);
            result->fType = eVK_Undefined;
            eb->fError = commandFailure ? eER_IncompatibleTypes : eER_NoErr;
            switch (eb->fParam1) {
                case 678:
                    check(readString(args[0]->uValue.fString) == expected, "exact file path");
                    if (!commandFailure) {
                        clear(args[1]);
                        PA_SetPictureVariable(args[1], makePicture());
                    }
                    break;
                case 1002:
                    check(readString(args[1]->uValue.fString) == expected, "exact conversion type");
                    picture(args[0]->uValue.fPicture);
                    break;
                case 988: picture(args[0]->uValue.fPicture); break;
                case 457:
                    picture(args[0]->uValue.fPicture);
                    PA_SetLongintVariable(args[1], 17);
                    PA_SetLongintVariable(args[2], 23);
                    break;
                case 679:
                    picture(args[0]->uValue.fPicture);
                    if (!commandFailure) {
                        clear(args[1]);
                        PA_SetPictureVariable(args[1], makePicture());
                    }
                    break;
                default: check(false, "unmodeled command");
            }
            break;
        }
        default:
            std::fprintf(stderr, "unexpected engine selector: %d\n", selector);
            check(false, "unmodeled engine entry");
    }
}

static void balanced()
{
    if (!strings.empty() || !handles.empty() || !pictures.empty())
        std::fprintf(stderr, "remaining strings=%zu handles=%zu pictures=%zu\n",
                     strings.size(), handles.size(), pictures.size());
    check(strings.empty(), "string allocation balance");
    check(handles.empty(), "handle allocation balance");
    check(pictures.empty(), "picture reference balance");
}

static void churn()
{
    for (int i = 0; i < 100; ++i) {
        PA_Unistring s = makeString(expected.c_str());
        disposeString(s);
    }
}

static void textTests()
{
    const char* fixtures[] = {"ASCII", "\xe6\x97\xa5", "\xf0\x9f\x98\x80", ""};
    for (const char* utf8 : fixtures) {
        expected = fromUTF8(utf8, std::strlen(utf8));
        C_TEXT scalar;
        CUTF8String u8(reinterpret_cast<const uint8_t*>(utf8));
        scalar.setUTF8String(&u8);
        check(CUTF16String(scalar.getUTF16StringPtr(), scalar.getUTF16Length()) == expected,
              "scalar conversion exact units");
        PA_Unistring s = makeString(expected.c_str());
        BytePtr scalarArgs[] = {reinterpret_cast<BytePtr>(&s)};
        scalar.fromParamAtIndex(scalarArgs, 1);
        PA_DisposeUnistring(&s);
        scalar.toParamAtIndex(scalarArgs, 1);
        check(readString(s) == expected, "scalar copied before owner disposal");
        PA_DisposeUnistring(&s);
        PA_Unistring* result = &s;
        scalar.setReturn(reinterpret_cast<sLONG_PTR*>(&result));
        check(readString(s) == expected, "scalar return content setter");
        PA_DisposeUnistring(&s);

        PA_Variable a = PA_CreateVariable(eVK_Undefined);
        PA_Variable b = PA_CreateVariable(eVK_Undefined);
        BytePtr params[] = {reinterpret_cast<BytePtr>(&a), reinterpret_cast<BytePtr>(&b)};
        ARRAY_TEXT values;
        values.setSize(1);
        values.appendUTF8String(&u8);
        values.appendUTF8String(&u8);
        values.toParamAtIndex(params, 1);
        values.toParamAtIndex(params, 2);
        check(PA_GetArrayNbElements(a) == 2, "array count");
        PA_Unistring first = PA_GetStringInArray(a, 1);
        PA_Unistring second = PA_GetStringInArray(a, 2);
        if (!expected.empty() || !nullEmpty) {
            check(first.fString != second.fString, "independent elements");
            check(first.fString != PA_GetStringInArray(b, 1).fString, "independent outputs");
        }
        check(readString(first) == expected, "array exact UTF-16");
        ARRAY_TEXT copy;
        copy.fromParamAtIndex(params, 1);
        values.toParamAtIndex(params, 1);
        PA_ResizeArray(&a, 0);
        PA_ClearVariable(&a);
        churn();
        check(readString(PA_GetStringInArray(b, 1)) == expected, "other owner survives clear");
        copy.toParamAtIndex(params, 1);
        check(readString(PA_GetStringInArray(a, 1)) == expected, "borrowed input copied");
        PA_ClearVariable(&a);
        PA_ClearVariable(&b);

        PA_Variable ar = PA_CreateVariable(eVK_ArrayUnicode);
        PA_ResizeArray(&ar, 1);
        for (int rejection = 0; rejection < 4; ++rejection) {
            PA_Unistring owned = makeString(expected.c_str());
            PA_Variable target = ar;
            PA_long32 index = 1;
            if (rejection == 0) target.fType = eVK_Longint;
            if (rejection == 1) target.uValue.fArray.fData = nullptr;
            if (rejection == 2) index = -1;
            if (rejection == 3) index = 2;
            PA_SetStringInArray(target, index, &owned);
            check(readString(owned) == expected, "rejection retains caller ownership");
            PA_DisposeUnistring(&owned);
        }
        PA_SetStringInArray(ar, 0, nullptr);
        PA_Unistring owned = makeString(expected.c_str());
        PA_SetStringInArray(ar, 0, &owned);
        check(PA_GetStringInArray(ar, 0).fString == owned.fString, "accepted shallow transfer");
        PA_Variable callback = PA_CreateVariable(eVK_Undefined);
        PA_Unistring independent = makeString(expected.c_str());
        PA_SetStringVariable(&callback, &independent);
        check(readString(callback.uValue.fString) == expected, "scalar shallow alias");
        PA_ClearVariable(&callback);
        churn();
        check(readString(PA_GetStringInArray(ar, 0)) == expected, "callback cleanup independent");
        PA_ClearVariable(&ar);

        std::vector<PA_Unichar> buffer(expected.size() + 2, 0x7777);
        PA_long32 bytes = PA_ConvertCharsetToCharset(const_cast<char*>(utf8),
            std::strlen(utf8), eVTC_UTF_8, reinterpret_cast<char*>(buffer.data()),
            expected.size() * sizeof(PA_Unichar), eVTC_UTF_16);
        check(bytes == expected.size() * sizeof(PA_Unichar), "conversion returns bytes");
        check(CUTF16String(buffer.data(), expected.size()) == expected, "exact conversion content");
        check(buffer[expected.size()] == 0x7777, "conversion respects byte boundary");
        balanced();
    }
}

static void pictureTests(const std::string& scenario)
{
    const char* fixtures[] = {".png", "\xe6\x97\xa5", "\xf0\x9f\x98\x80", ""};
    for (const char* text : fixtures) {
        if ((scenario == "copy-empty" || scenario == "path-empty") && *text) continue;
        expected = fromUTF8(text, std::strlen(text));
        PA_Picture handoff = nullptr;
        {
            CPicture p;
            if (scenario == "path" || scenario == "path-empty") {
                CUTF8String path(reinterpret_cast<const uint8_t*>(text));
                p.fromFileAtPath(&path);
                picture(p.getPicture());
            } else if (scenario == "bytes") {
                const uint8_t bytes[] = {1, 2, 3};
                p.setBytes(bytes, sizeof(bytes));
                p.setBytes(bytes, sizeof(bytes));
                picture(p.getPicture());
            } else if (scenario == "copy" || scenario == "copy-empty") {
                handoff = p.createCopy(text);
            } else if (scenario == "gray") {
                handoff = p.createGrayScale();
            } else if (scenario == "size") {
                unsigned width = 0, height = 0;
                p.getSize(&width, &height);
                check(width == 17 && height == 23, "picture properties");
            } else if (scenario == "thumbnail") {
                handoff = p.createThumbnail(17, 23);
            } else check(false, "unknown test");
            if (handoff) picture(handoff);
        }
        if (handoff) {
            picture(handoff);
            PA_DisposePicture(handoff);
        }
        balanced();
    }
}

int main(int argc, char** argv)
{
    check(argc == 4, "scenario, empty representation, command outcome");
    nullEmpty = std::string(argv[2]) == "null";
    commandFailure = std::string(argv[3]) == "failure";
    gCall4D = host;
    @autoreleasepool {
        if (std::string(argv[1]) == "text") textTests();
        else pictureTests(argv[1]);
    }
    balanced();
    std::printf("PASS %s %s %s: exact content; strings=0 handles=0 picture refs=0\n",
                argv[1], argv[2], argv[3]);
}
