//
//  SynthesizeSingleton.h
//
//  Created by Matt Gallagher on 20/10/08.
//

#define SYNTHESIZE_SINGLETON_FOR_CLASS(classname) \
\
+(classname *)singleton\
{\
    static classname *shared##classname = nil;\
    static dispatch_once_t once = 0; \
    dispatch_once(&once, ^ { shared##classname = [[self alloc] init]; });\
    return shared##classname;\
}\

