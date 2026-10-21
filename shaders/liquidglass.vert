#version 310 es

// 通用顶点着色器（GLSL ES 310）
//
// 注意：Qt 6 的 RHI 会先把着色器编成 SPIR-V，而 SPIR-V 只接受 GLSL ES 310+
// 的语法。用 ES 100 的 `attribute` / `varying` / `gl_FragColor` 写出来的
// ShaderEffect 会**静默失效** —— 既不报错也不渲染。所以这里显式指定版本。
//
// 另：#version 必须是文件第一行，前面不能有注释，否则 qsb 会报
// "statement must appear first in es-profile shader"。

layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;

// 自定义的 varying 必须占用 >0 的 location：
// Qt 会自动把 qt_TexCoord0 放在 location 0，若这里也写 0 会报重叠。
layout(location = 1) out vec2 qt_TexCoord0;
layout(location = 2) out vec2 fragCoord;

// uniform block 必须与 fragment shader **完全一致**（成员、顺序都要一样），
// 即使顶点着色器用不到后面几个。否则 Qt 会警告
// "ShaderEffect: 'xxx' does not have a matching property"，且数据可能错位。
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 uSize;
    vec2 uOffset;
    vec4 uCornerRadii;
    vec4 uParams;
};

void main()
{
    gl_Position = qt_Matrix * qt_Vertex;
    qt_TexCoord0 = qt_MultiTexCoord0;
    // ShaderEffect 的 fragment shader 里 gl_FragCoord 是未定义行为，
    // 统一从顶点阶段把 [0,1] 的矩形坐标传下去。
    fragCoord = qt_MultiTexCoord0 * uSize;
}
