# ProjectRED

These are some Second Life shader and client modifications I conducted to the 3rd party client called firestorm. Most of the work here done was implemented based on the tutorials from https://learnopengl.com/ and from plenty of help from patient and brilliant individuals in a graphics programming discord. Most of this stuff is nothing more than an exercise of learning and teaching myself 3D graphics, but I have sadly reached the point where I need to work on rendering engines from scratch to really understand them rather than just modifying them. However, I still intend to keep poking at this project when I have time.

So whats changed?
- **Shader Side** Proper layout qualifiers instead of the dated varyings and out qualifiers.
- **Shader Side** Modified the SSAO shader and utilities in aoUtil.glsl to require a bit less math and added a few samples.
- **Shader Side** Small optimizations like reimplementing operations to use multiply, add, and divide operations to hopefully boost performance if the compiler misses them.
- **Shader Side** Swapping over deferred lighting BRDF used for pointlighting and environmental lighting. (This was primarily conducted in the materialsf.glsl, softenlightf.glsl, pointlightF.glsl in the class 1 and class 2 shaders.
- **Shader Side** Recycled some of the data provided by the client that was used for environmental lighting to allow for physically based reflectance, rather than the defualt non energy preserving strange normalized blinn phong model Linden Labs was using. Currently the shaders are inverting a gloss map that is packed in the alpha channel of the normal map to allow for roughness calculations, it recycles the environmental shine map packed in the specular alpha channel as a metallic map, as that seems to be the intent of it anyways, and lastly uses diffuse as albedo. TLDR, I've moving stuff to a roughness, metallic, and albedo model.
- **Client Side** Gutted as much as possible of preOpenGL 4.2 code and am currently remove as much fixed function or software rendering code from the client.


What needs to be done?
- **Shader Side** Currently there are three shader classes for different hardware spec, some of it very ancient, and I intent to do some pruning to simplify the amount of code that needs to be maintained.
- **Shader Side** Investigate going tall with the shaders and making some uber shaders that handle more or less all of the lighting.
- **Shader Side** Modernizing spotlights.
- **Shader Side** Reworking the incredibly dated SSAO and fix shadows.
- **Overall** Cleaning up the naming conventions, documenting stuff, and mapping out this monster.
- **Overall** Investigating abandoning one of the rendering modes and focusing purely on deferred or forward rendering. This would likely require engine changes, but I have already gutted a lot of fixed function or pre-OpenGl 4.2 stuff. My logic is that if this goes big or catches on, Im likely not effecting a lot of Second Life players or ones that invest into the game anyways.
- **Overall** Ideally, it would be nice to implement some sort of screen space reflections or global illumination system to atleast allow for radiosity.
- **Overall** Implement a better version of image-based lighting and BRDF look up table.
- **Shader Side** Fresnel still appears to be broken or something is messing with it.
- **Overall** Figure out how to implement a better texture caching system, as the current one if I understand it correctly has to decompress a texture from JPEG2000 and sent it to the card every time its loaded.
- **Overall** Learn more about C++ boost libraries and how to do threading right, as I suspect there is something very interesting or questionable going on. My C++ is very rusty, and the sheer size of this project necessitates that I have to learn several paradigms and chase spaghetti code.
- **Overall** Refactor, refactor, refactor, and use style conventions and definitions. Right now this code is a 20 year old mess, maintained and worked on by probably hundreds of people who didn't seem to be too concerned with maintaining any sort of guidelines.
-  **Overall** Write unit tests or some form of bug testing for bits and pieces of the code, as there doesnt seem to be much for the rendering side of things.


Why did I do this?
- I got tired of the game looking like garbage, running like garbage, and the lack of meaningful graphics development on the platform.
- People have been dreaming and salivating at the thought of physically based rendering in Second Life for quite some time, and I had hoped that if I fixed stuff up enough, it might force the developers to invest more in the graphics side of the game.
- I create and sell content in Second Life, and Ive looked at the rendering engine and noticed there is no shortage of data to work with and things should be able to look better. Specifically, I want metallic items to not resemble a grey muddied smear.
