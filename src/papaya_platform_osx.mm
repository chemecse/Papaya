#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>
#import <CoreVideo/CVDisplayLink.h>

#include <mach/mach_time.h>
#include <libproc.h>
#include <string.h>
#include <stdio.h>

#include "papaya_platform.h"
#include "papaya_core.h"
#include "libs/imgui/imgui.h"
#include "libs/gl_lite.h"

#define OSX_INITIAL_WINDOW_WIDTH 800
#define OSX_INITIAL_WINDOW_HEIGHT 600

static CVReturn GlobalDisplayLinkCallback(CVDisplayLinkRef DisplayLink, const CVTimeStamp* Now, const CVTimeStamp* OutputTime, CVOptionFlags FlagsIn, CVOptionFlags* FlagsOut, void* DisplayLinkContext);

@interface FileDialogReturn : NSObject {
@public
	NSURL* Url;
}
@end

@implementation FileDialogReturn
@end

@interface PapayaView : NSOpenGLView<NSWindowDelegate> {
@public
	CVDisplayLinkRef DisplayLink;
	bool32 IsInitialized;
	bool32 DidResize;
}
- (NSPoint)getWindowOrigin;
- (void)resizeSurfaceBacking;
- (void)openFileDialog:(FileDialogReturn*)Return;
- (void)saveFileDialog:(FileDialogReturn*)Return;
@end

global_variable PapayaMemory Mem;
global_variable PapayaView* View;
global_variable mach_timebase_info_data_t MachClockFrequency;

void platform::print(char* Message)
{
	printf("%s", Message);
}

void platform::start_mouse_capture()
{
	//
}

void platform::stop_mouse_capture()
{
	//
}

void platform::set_mouse_position(int32 x, int32 y)
{
	NSPoint Origin = [View getWindowOrigin];
	CGPoint Point = {Origin.x + x, Origin.y + y};
	CGWarpMouseCursorPosition(Point);
}

void platform::set_cursor_visibility(bool Visible)
{
	if (Visible) {
		CGDisplayShowCursor(kCGDirectMainDisplay);
	}
	else {
		CGDisplayHideCursor(kCGDirectMainDisplay);
	}
}

char* platform::open_file_dialog()
{
	char* FilePath = NULL;
	FileDialogReturn* Return = [FileDialogReturn alloc];
	[View performSelectorOnMainThread:@selector(openFileDialog:) withObject:Return waitUntilDone:YES];
	if (Return->Url) {
		const char* UrlPath = [Return->Url fileSystemRepresentation];
		FilePath = (char*)malloc(strlen(UrlPath) + 1);
		strcpy(FilePath, UrlPath);
	}
	[Return dealloc];
	return FilePath;
}

char* platform::save_file_dialog()
{
	char* FilePath = NULL;
	FileDialogReturn* Return = [FileDialogReturn alloc];
	[View performSelectorOnMainThread:@selector(saveFileDialog:) withObject:Return waitUntilDone:YES];
	if (Return->Url) {
		const char* UrlPath = [Return->Url fileSystemRepresentation];
		FilePath = (char*)malloc(strlen(UrlPath) + 1);
		strcpy(FilePath, UrlPath);
	}
	[Return dealloc];
	return FilePath;
}

double platform::get_milliseconds()
{
	return (double)(mach_absolute_time() * (MachClockFrequency.numer / MachClockFrequency.denom) / 1000000.0);
}

@implementation PapayaView
- (id)initWithFrame:(NSRect)frame
{
	IsInitialized = 0;
	DidResize = 0;
	Mem.is_running = 0;

	NSOpenGLPixelFormatAttribute PixelFormatAttrs[] = {
		NSOpenGLPFADoubleBuffer,
		NSOpenGLPFAAccelerated,
		NSOpenGLPFAColorSize, 32,
		NSOpenGLPFAAlphaSize, 8,
		NSOpenGLPFADepthSize, 24,
		NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersionLegacy,
		0
	};
	NSOpenGLPixelFormat* PixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:PixelFormatAttrs];
	if (!PixelFormat) {
		return nil;
	}
	self = [super initWithFrame:frame pixelFormat:[PixelFormat autorelease]];
	return self;
}

- (void)prepareOpenGL
{
	[super prepareOpenGL];

	[[self window] setLevel:NSNormalWindowLevel];
	[[self window] makeKeyAndOrderFront:self];

	[[self openGLContext] makeCurrentContext];
	GLint SwapInterval = 1;
	[[self openGLContext] setValues:&SwapInterval forParameter:NSOpenGLCPSwapInterval];

	CVDisplayLinkCreateWithActiveCGDisplays(&DisplayLink);
	CVDisplayLinkSetOutputCallback(DisplayLink, &GlobalDisplayLinkCallback, self);

	CGLContextObj CGLContext = (CGLContextObj)[[self openGLContext] CGLContextObj];
	CGLPixelFormatObj PixelFormat = (CGLPixelFormatObj)[[self pixelFormat] CGLPixelFormatObj];
	CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(DisplayLink, CGLContext, PixelFormat);

	[self resizeSurfaceBacking];

	CGLLockContext((CGLContextObj)[[self openGLContext] CGLContextObj]);
    if (!gl_lite_init()) { exit(1); }
	CGLUnlockContext((CGLContextObj)[[self openGLContext] CGLContextObj]);

	CVDisplayLinkStart(DisplayLink);
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

static void OnMouseMoveEvent(NSEvent* event)
{
	NSPoint Point = [View convertPoint:[event locationInWindow] fromView:nil];
	ImGui::GetIO().MousePos.x = Point.x;
	ImGui::GetIO().MousePos.y = Point.y;
}

- (void)mouseMoved:(NSEvent*)event
{
	OnMouseMoveEvent(event);
}

- (void)mouseDragged:(NSEvent*)event
{
	OnMouseMoveEvent(event);
}

- (void)mouseDown:(NSEvent*)event
{
	ImGui::GetIO().MouseDown[0] = 1;
}

- (void)mouseUp:(NSEvent*)event
{
	ImGui::GetIO().MouseDown[0] = 0;
}

- (void)rightMouseDown:(NSEvent*)event
{
	ImGui::GetIO().MouseDown[1] = 1;
}

- (void)rightMouseUp:(NSEvent*)event
{
	ImGui::GetIO().MouseDown[1] = 0;
}

- (void)otherMouseDown:(NSEvent*)event
{
	ImGui::GetIO().MouseDown[2] = 1;
}

- (void)otherMouseUp:(NSEvent*)event
{
	ImGui::GetIO().MouseDown[2] = 0;
}

- (void)mouseEntered:(NSEvent*)event
{
	//
}

- (void)mouseExited:(NSEvent*)event
{
	//
}

- (void)keyDown:(NSEvent*)event
{
	bool32 IsZKeyDown = (tolower([[event charactersIgnoringModifiers] characterAtIndex:0]) == 'z');
	if (IsZKeyDown) { ImGui::GetIO().KeysDown['z'] = 1; }
}

- (void)keyUp:(NSEvent*)event
{
	bool32 IsZKeyUp = (tolower([[event charactersIgnoringModifiers] characterAtIndex:0]) == 'z');
	if (IsZKeyUp) { ImGui::GetIO().KeysDown['z'] = 0; }
}

- (void)flagsChanged:(NSEvent*)event
{
	uint32 Modifiers = [event modifierFlags];

	bool32 IsCtrlDown  = ((Modifiers & NSControlKeyMask) || (Modifiers & NSCommandKeyMask));
	bool32 IsShiftDown = ((Modifiers & NSShiftKeyMask) != 0);
	bool32 IsAltDown   = ((Modifiers & NSAlternateKeyMask) != 0);

	ImGui::GetIO().KeyCtrl  = IsCtrlDown;
	ImGui::GetIO().KeyShift = IsShiftDown;
	ImGui::GetIO().KeyAlt   = IsAltDown;
}

- (CVReturn)getFrameForTime:(const CVTimeStamp*)OutputTime
{
	[[self openGLContext] makeCurrentContext];
	CGLLockContext((CGLContextObj)[[self openGLContext] CGLContextObj]);

	if (!IsInitialized) {
		core::init(&Mem);
		ImGuiIO& io = ImGui::GetIO();
		io.RenderDrawListsFn = core::render_imgui;
		io.KeyMap[ImGuiKey_Z] = 'z';

		timer::stop(&Mem.profile.timers[Timer_Startup]);
		Mem.is_running = 1;
		IsInitialized = 1;
	}

	timer::start(&Mem.profile.timers[Timer_Frame]);

	float CurTime = (float)(mach_absolute_time() * (MachClockFrequency.numer / MachClockFrequency.denom) / 1000000000.0f);
	ImGui::GetIO().DeltaTime = (float)(CurTime - Mem.profile.last_frame_time);
	Mem.profile.last_frame_time = CurTime;

	if (DidResize) {
		NSSize FrameSize = [[_window contentView] frame].size;
		ImGui::GetIO().DisplaySize = ImVec2((float)FrameSize.width, (float)FrameSize.height);
		Mem.window.width = FrameSize.width;
		Mem.window.height = FrameSize.height;

		[self resizeSurfaceBacking];

		DidResize = 0;
	}

	ImGui::NewFrame();

	core::update(&Mem);

	CGLFlushDrawable((CGLContextObj)[[self openGLContext] CGLContextObj]);

	CGLUnlockContext((CGLContextObj)[[self openGLContext] CGLContextObj]);

	if (!Mem.is_running) {
		[NSApp terminate:self];
	}

	// NOTE: keyUp() is not fired when a modifier + normal key is released
	//       so we need to clear 'z' at the end of every frame
	ImGui::GetIO().KeysDown['z'] = 0;

	timer::stop(&Mem.profile.timers[Timer_Frame]);
	double FrameRate = (Mem.current_tool == PapayaTool_Brush) ? 500.0 : 60.0;
	double FrameTime = 1000.0 / FrameRate;
	double SleepTime = FrameTime - Mem.profile.timers[Timer_Frame].elapsed_ms;
	Mem.profile.timers[Timer_Sleep].elapsed_ms = SleepTime;
	if (SleepTime > 0) { usleep((uint32)SleepTime * 1000); }

	return kCVReturnSuccess;
}

- (void)windowDidResize:(NSNotification*)notification
{
	DidResize = 1;
}

- (void)resumeDisplayRenderer
{
	CVDisplayLinkStop(DisplayLink);
}

- (void)haltDisplayRenderer
{
	CVDisplayLinkStop(DisplayLink);
}

- (void)windowWillClose:(NSNotification*)notification
{
	if (Mem.is_running) {
		Mem.is_running = 0;
		core::destroy(&Mem);
		CVDisplayLinkStop(DisplayLink);
		CVDisplayLinkRelease(DisplayLink);
	}
	[NSApp terminate:self];
}

- (BOOL)isFlipped
{
	// NOTE: set the upper-left corner as the origin for mouse coordinates
	return YES;
}

- (NSPoint)getWindowOrigin
{
	return [_window convertRectToScreen:[[_window contentView] frame]].origin;
}

// openGLContext must be current and locked around this function call
- (void)resizeSurfaceBacking
{
	CGLContextObj CGLContext = (CGLContextObj)[[self openGLContext] CGLContextObj];

	GLint WindowSize[2] = {Mem.window.width, Mem.window.height};
	CGLSetParameter(CGLContext, kCGLCPSurfaceBackingSize, WindowSize);
	CGLEnable(CGLContext, kCGLCESurfaceBackingSize);
}

- (void)openFileDialog:(FileDialogReturn*)Return
{
	Return->Url = nil;
	NSOpenPanel* Panel = [NSOpenPanel openPanel];
	[Panel makeKeyAndOrderFront:self];
	int32_t PanelRunResult = [Panel runModal];
	if (PanelRunResult == NSFileHandlingPanelOKButton) {
		NSArray* Urls = [Panel URLs];
		if ([Urls count] > 0) {
			NSURL* Url = [Urls objectAtIndex:0];
			Return->Url = Url;
		}
	}
}

- (void)saveFileDialog:(FileDialogReturn*)Return
{
	Return->Url = nil;
	NSSavePanel* Panel = [NSSavePanel savePanel];
	[Panel makeKeyAndOrderFront:self];
	int32 PanelRunResult = [Panel runModal];
	if (PanelRunResult == NSFileHandlingPanelOKButton) {
		Return->Url = [[Panel URL] copy];
	}
}

- (void)dealloc
{
	[super dealloc];
}
@end

static CVReturn GlobalDisplayLinkCallback(CVDisplayLinkRef DisplayLink, const CVTimeStamp* Now, const CVTimeStamp* OutputTime, CVOptionFlags FlagsIn, CVOptionFlags* FlagsOut, void* DisplayLinkContext)
{
	CVReturn Result = [(PapayaView*)DisplayLinkContext getFrameForTime:OutputTime];
	return Result;
}

int main(int argc, char* argv[])
{
	memset(&Mem, 0, sizeof(PapayaMemory));

	MachClockFrequency.numer = 0;
	MachClockFrequency.denom = 0;
	mach_timebase_info(&MachClockFrequency);

	timer::init(1000.0);
	timer::start(&Mem.profile.timers[Timer_Startup]);

	char PathBuffer[PATH_MAX];
	proc_pidpath(getpid(), PathBuffer, sizeof(PathBuffer) - 1);
	if (PathBuffer[0])
	{
		char *LastSlash = strrchr(PathBuffer, '/');
		if (LastSlash != NULL) { *LastSlash = '\0'; }
		chdir(PathBuffer);
	}

	NSAutoreleasePool* Pool = [[NSAutoreleasePool alloc] init];

	[NSApplication sharedApplication];

	NSRect ScreenDimensions = [[NSScreen mainScreen] frame];
	int32 ScreenWidth = ScreenDimensions.size.width;
	int32 ScreenHeight = ScreenDimensions.size.height;

	Mem.window.width = OSX_INITIAL_WINDOW_WIDTH;
	Mem.window.height = OSX_INITIAL_WINDOW_HEIGHT;
	ImGui::GetIO().DisplaySize = ImVec2((float)Mem.window.width, (float)Mem.window.height);
	NSRect WindowRect = NSMakeRect((ScreenWidth - Mem.window.width) / 2, (ScreenHeight - Mem.window.height) / 2, Mem.window.width, Mem.window.height);

	NSUInteger WindowStyle = NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask;
	NSWindow* Window = [[NSWindow alloc] initWithContentRect:WindowRect styleMask:WindowStyle backing:NSBackingStoreBuffered defer:NO];
	[Window autorelease];

	// NOTE: activation policy needs to be set unless XCode is used to build the project
	[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

	id MenuBar = [[NSMenu new] autorelease];
	id AppMenuItem = [[NSMenuItem new] autorelease];
	[MenuBar addItem:AppMenuItem];
	[NSApp setMainMenu:MenuBar];

	id AppMenu = [[NSMenu new] autorelease];
	id AppName = [[NSProcessInfo processInfo] processName];
	id QuitTitle = [@"Quit " stringByAppendingString:AppName];
	id QuitMenuItem = [[[NSMenuItem alloc] initWithTitle:QuitTitle action:@selector(terminate:) keyEquivalent:@"q"] autorelease];
	[AppMenu addItem:QuitMenuItem];
	[AppMenuItem setSubmenu:AppMenu];

	View = [[[PapayaView alloc] initWithFrame:WindowRect] autorelease];

	[Window setAcceptsMouseMovedEvents:YES];
	[Window setContentView:View];
	[Window setDelegate:View];
	[Window setTitle:AppName];

	// bring window to front of other windows
	[Window orderFrontRegardless];

	// bring window into focus
	[NSApp activateIgnoringOtherApps:true];

	[NSApp run];

	[Pool drain];
	return (0);
}

