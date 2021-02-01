import os
import itertools
dir_path = os.path.dirname(os.path.realpath(__file__))
class1 = list(os.walk(dir_path + "\\class1"))[1:]
class2 = list(os.walk(dir_path + "\\class2"))[1:]
class3 = list(os.walk(dir_path + "\\class3"))[1:]
classes = [class1,  class2, class3]

vertexShaders = []
pixelShaders = []
otherShaders = []
totalShaders = vertexShaders + pixelShaders + otherShaders
uniforms = []
directory = ""
for shaderClass in classes:
    for list in itertools.chain.from_iterable(shaderClass):
        if len(list) and "C:\\Users" in list:
            directory = list
        for element in list:
            if "V.glsl" in element and len(element) > 1:
                vertexShaders.append(directory + str("\\") + element)
            elif "F.glsl" in element and len(element) > 1:
                pixelShaders.append(directory + str("\\") + element)
            else:
                if ".glsl" in element:
                    otherShaders.append(directory + str("\\") + element)



# print(totalShaders)
# for shader in pixelShaders:
#     with open(shader, 'r') as f:
#         text = f.read()
#         text = text.splitlines()
#         uniforms += [line for line in text if "uniform " in line]
# for uniform in set(uniforms):
#     print(uniform)

# WONT FIX POST CRAP
# Pixel Shader fixup
# for shader in pixelShaders + otherShaders:
#     with open(shader, 'r') as f:
#         text = f.read()
#         if "VARYING_FLAT" in text:
#             print("VARYING_FLAT",shader)
#             text = text.replace("VARYING_FLAT", "in")
#         elif "VARYING" in text and "VARYING_FLAT" not in text:
#             text = text.replace("VARYING", "in")
#         with open(shader, 'w') as k:
#             text = k.write(text)
# # #
# # # Vertex Shader fixup
# for shader in vertexShaders:
#     with open(shader, 'r') as f:
#         text = f.read()
#         if "indexedTextureV" in str(shader):
#             if "VARYING_FLAT" in text:
#                 text = text.replace("VARYING_FLAT", "flat out")
#                 text = text.replace("ATTRIBUTE", "in")
#                 with open(shader, 'w') as k:
#                     text = k.write(text)
#         if "indexedTextureV" not in str(shader):
#             if "VARYING" in text or "ATTRIBUTE" in text:
#                 text = text.replace("VARYING", "out")
#                 text = text.replace("ATTRIBUTE", "in")
#                 if "in vec3 position;" in text:
#                     text = text.replace("in vec3 position;", "layout (location = 0) in vec3 position;")
#                 if "in vec3 normal" in text:
#                     text = text.replace("in vec3 normal;", "layout (location = 1) in vec3 normal;")
#                 if "in vec2 texcoord0" in text:
#                     text = text.replace("in vec2 texcoord0;", "layout (location = 2) in vec2 texcoord0;")
#                 if "in vec2 texcoord1" in text:
#                     text = text.replace("in vec2 texcoord1;", "layout (location = 3) in vec2 texcoord1;")
#                 if "in vec2 texcoord2" in text:
#                     text = text.replace("in vec2 texcoord2;", "layout (location = 4) in vec2 texcoord2;")
#                 if "in vec4 diffuse_color" in text:
#                     text = text.replace("in vec4 diffuse_color;", "layout(location = 6) in vec4 diffuse_color;")
#                 if "in vec4 tangent" in text:
#                     text = text.replace("in vec4 tangent;", "layout (location = 8) in vec4 tangent;")
#                 if "in vec4 weight" in text:
#                     text = text.replace("in vec4 weight;", "layout (location = 9) in vec4 weight;")
#                 if "in vec4 weight4" in text:
#                     text = text.replace("in vec4 weight4;", "layout (location = 10) in vec4 weight4;")
#                 with open(shader, 'w') as k:
#                     text = k.write(text)


for shader in pixelShaders + otherShaders + vertexShaders:
    with open(shader, 'r') as f:
        text = f.read()
#         # if "VARYING" in text:
#         #     print("VARYING", shader)
#         if "VARYING_FLAT" in text:
#             print("VARYING_FLAT", shader)
#         if "flat" in text:
#             print("flat", shader)
        # if "ATTRIBUTE" in text:
        #     print("ATTRIBUTE", shader)
#         if "texture2D" in text:
#             print("texture2D", shader)
        if "#ifdef DEFINE_GL_FRAGCOLOR\nout vec4 frag_color;\n#else\n#define frag_color gl_FragColor\n#endif" in text:
            text = text.replace("#ifdef DEFINE_GL_FRAGCOLOR\nout vec4 frag_color;\n#else\n#define frag_color gl_FragColor\n#endif", "out vec4 frag_color;")
            print(shader)
            print(text)
            with open(shader, 'w') as k:
                text = k.write(text)
