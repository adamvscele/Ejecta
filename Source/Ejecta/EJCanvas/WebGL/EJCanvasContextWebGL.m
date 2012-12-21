#import "EJCanvasContextWebGL.h"
#import "EJApp.h"

@implementation EJCanvasContextWebGL

@synthesize useRetinaResolution;
@synthesize backingStoreRatio;
@synthesize scalingMode;

- (id)initWithWidth:(short)widthp height:(short)heightp {
	if( self = [super init] ) {
		glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2 sharegroup:[EJApp instance].glSharegroup];
		[EAGLContext setCurrentContext:glContext];
		
		bufferWidth = width = widthp;
		bufferHeight = height = heightp;
		
		msaaEnabled = NO;
		msaaSamples = 2;
	}
	return self;
}

- (void)create {
	// Work out the final screen size - this takes the scalingMode, canvas size,
	// screen size and retina properties into account
	CGRect frame = CGRectMake(0, 0, width, height);
	CGSize screen = [EJApp instance].view.bounds.size;
    float contentScale = (useRetinaResolution && [UIScreen mainScreen].scale == 2) ? 2 : 1;
	float aspect = frame.size.width / frame.size.height;
	
	if( scalingMode == kEJScalingModeFitWidth ) {
		frame.size.width = screen.width;
		frame.size.height = screen.width / aspect;
	}
	else if( scalingMode == kEJScalingModeFitHeight ) {
		frame.size.width = screen.height * aspect;
		frame.size.height = screen.height;
	}
	float internalScaling = frame.size.width / (float)width;
	[EJApp instance].internalScaling = internalScaling;
	
    backingStoreRatio = internalScaling * contentScale;
	
	NSLog(
		@"Creating ScreenCanvas (WebGL): "
			@"size: %dx%d, aspect ratio: %.3f, "
			@"scaled: %.3f = %.0fx%.0f, "
			@"retina: %@ = %.0fx%.0f",
		width, height, aspect,
		internalScaling, frame.size.width, frame.size.height,
		(useRetinaResolution ? @"yes" : @"no"),
		frame.size.width * contentScale, frame.size.height * contentScale
	);
	
	// Create the OpenGL UIView with final screen size and content scaling (retina)
	glview = [[EAGLView alloc] initWithFrame:frame contentScale:contentScale retainedBacking:NO];
    
	// Create the frame- and renderbuffers
    glGenFramebuffers(1, &viewFrameBuffer);
	glBindFramebuffer(GL_FRAMEBUFFER, viewFrameBuffer);
	
	glGenRenderbuffers(1, &viewRenderBuffer);
	glBindRenderbuffer(GL_RENDERBUFFER, viewRenderBuffer);
	   
	// Set up the renderbuffer and some initial OpenGL properties
	[glContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)glview.layer];
	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, viewRenderBuffer);

    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &bufferWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &bufferHeight);

    glGenRenderbuffers(1, &depthRenderBuffer);
	glBindRenderbuffer(GL_RENDERBUFFER, depthRenderBuffer);
    
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, bufferWidth, bufferHeight);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRenderBuffer);
    
	// Append the OpenGL view to Impact's main view
	[[EJApp instance] hideLoadingScreen];
	[[EJApp instance].view addSubview:glview];
}

- (void)dealloc {
    if( viewFrameBuffer ) { glDeleteFramebuffers( 1, &viewFrameBuffer); }
	if( viewRenderBuffer ) { glDeleteRenderbuffers(1, &viewRenderBuffer); }
    if( depthRenderBuffer ) { glDeleteRenderbuffers(1, &depthRenderBuffer); }
	[glview release];
	[EAGLContext setCurrentContext:NULL];
	[glContext release];
	[super dealloc];
}

- (void)prepare {
    glBindFramebuffer(GL_FRAMEBUFFER, viewFrameBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, viewRenderBuffer);
}

- (void)finish {
	glFinish();
}

- (void)present {
    [glContext presentRenderbuffer:GL_RENDERBUFFER];
}

@end
