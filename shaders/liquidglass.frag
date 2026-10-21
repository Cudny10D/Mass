#version 310 es

// 液态玻璃：圆角矩形 SDF 边缘折射（移植自 AndroidLiquidGlass / kyant0 backdrop）
//
// 原理：用圆角矩形的有符号距离场（SDF）求边缘法线，只在靠近边缘
// refractionHeight 的范围内把采样坐标沿法线方向推出去，形成「玻璃边缘把
// 背后画面掰弯」的透镜感；中心区域原样输出。
//
// AGSL -> GLSL ES 310 的对应关系：
//   uniform shader content  -> uniform sampler2D content
//   content.eval(c)         -> texture(content, c / uSize)
//   half4                   -> vec4
//   float4 / float2         -> vec4 / vec2
//
// 三条必须遵守的约束（每一条踩过都会「静默失效」）：
//  1. 必须 GLSL ES 310+。ES 100 的 varying / gl_FragColor 会被 RHI 静默丢弃。
//  2. qsb 编 SPIR-V 时不允许「块外的非不透明 uniform」。
//  3. Qt Quick **只支持一个 uniform block**；第二个块会被忽略并警告
//     "Multiple uniform blocks found in shader"。
//  => 所有自定义 uniform 只能放进唯一的 buf 块里，靠 QML 侧同名 property 赋值。
//
// 另：#version 必须是文件第一行，前面不能有注释。

precision highp float;

layout(location = 0) in vec2 qt_TexCoord0;
// 与 liquidglass.vert 的 location 必须一致（Qt 占了 0）
layout(location = 2) in vec2 fragCoord;

layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    vec2 uSize;          // 折射层尺寸（px，含外扩）
    vec2 uOffset;        // 玻璃矩形左上角在折射层内的偏移
    vec4 uCornerRadii;   // x=左上 y=右上 z=右下 w=左下
    vec4 uParams;    // x=refractionHeight y=refractionAmount z=depthEffect w=aberration
};

// SPIR-V 要求 sampler 显式声明 binding
layout(binding = 1) uniform sampler2D content;

// ── 圆角矩形 SDF ────────────────────────────────────────────────
float radiusAt(vec2 coord, vec4 radii)
{
    if (coord.x >= 0.0) {
        if (coord.y <= 0.0) return radii.y;
        else return radii.z;
    } else {
        if (coord.y <= 0.0) return radii.x;
        else return radii.w;
    }
}

float sdRoundedRect(vec2 coord, vec2 halfSize, float radius)
{
    vec2 cornerCoord = abs(coord) - (halfSize - vec2(radius));
    float outside = length(max(cornerCoord, 0.0)) - radius;
    float inside = min(max(cornerCoord.x, cornerCoord.y), 0.0);
    return outside + inside;
}

vec2 gradSdRoundedRect(vec2 coord, vec2 halfSize, float radius)
{
    vec2 cornerCoord = abs(coord) - (halfSize - vec2(radius));
    if (cornerCoord.x >= 0.0 || cornerCoord.y >= 0.0) {
        return sign(coord) * normalize(max(cornerCoord, vec2(0.0)));
    } else {
        float gradX = step(cornerCoord.y, cornerCoord.x);
        return sign(coord) * vec2(gradX, 1.0 - gradX);
    }
}

float circleMap(float x)
{
    return 1.0 - sqrt(max(0.0, 1.0 - x * x));
}

vec4 sampleContent(vec2 coord)
{
    return texture(content, coord / uSize);
}

void main()
{
    // Qt 的 ShaderEffect 里 gl_FragCoord 不可靠，用顶点传下来的矩形坐标
    vec2 coord = fragCoord;

    float refractionHeight = uParams.x;
    float refractionAmount = uParams.y;
    float depthEffect = uParams.z;
    float aberration = uParams.w;

    if (refractionHeight <= 0.0) {
        fragColor = sampleContent(coord) * qt_Opacity;
        return;
    }

    vec2 halfSize = uSize * 0.5;
    vec2 centeredCoord = (coord + uOffset) - halfSize;
    float radius = radiusAt(coord, uCornerRadii);

    float sd = sdRoundedRect(centeredCoord, halfSize, radius);

    // 折射层比玻璃本身大一圈（外扩 lensPadding 供边缘采样）。圆角矩形之外的
    // 像素必须丢弃，否则会把捕获到的背景画成一圈矩形光晕 —— 表现为高光/毛玻璃
    // 溢出到胶囊范围以外。这里用 1px 平滑过渡避免硬边。
    float coverage = 1.0 - smoothstep(-1.0, 0.5, sd);
    if (coverage <= 0.001) {
        fragColor = vec4(0.0);
        return;
    }

    // 离边缘超过 refractionHeight 的区域：原样输出，不折射
    if (-sd >= refractionHeight) {
        fragColor = sampleContent(coord) * qt_Opacity * coverage;
        return;
    }
    sd = min(sd, 0.0);

    float d = circleMap(1.0 - (-sd) / refractionHeight) * refractionAmount;
    float gradRadius = min(radius * 1.5, min(halfSize.x, halfSize.y));
    vec2 grad = normalize(gradSdRoundedRect(centeredCoord, halfSize, gradRadius)
                          + depthEffect * normalize(centeredCoord));

    vec2 refractedCoord = coord + d * grad;

    vec4 color;
    if (aberration > 0.5) {
        // 色散：沿折射方向按彩虹顺序采 7 次，模拟玻璃边缘的彩色分离
        float dispersionIntensity =
            (centeredCoord.x * centeredCoord.y) / (halfSize.x * halfSize.y);
        vec2 dispersedCoord = d * grad * dispersionIntensity;

        vec4 c = vec4(0.0);
        vec4 red = sampleContent(refractedCoord + dispersedCoord);
        c.r += red.r / 3.5; c.a += red.a / 7.0;
        vec4 orange = sampleContent(refractedCoord + dispersedCoord * (2.0 / 3.0));
        c.r += orange.r / 3.5; c.g += orange.g / 7.0; c.a += orange.a / 7.0;
        vec4 yellow = sampleContent(refractedCoord + dispersedCoord * (1.0 / 3.0));
        c.r += yellow.r / 3.5; c.g += yellow.g / 3.5; c.a += yellow.a / 7.0;
        vec4 green = sampleContent(refractedCoord);
        c.g += green.g / 3.5; c.a += green.a / 7.0;
        vec4 cyan = sampleContent(refractedCoord - dispersedCoord * (1.0 / 3.0));
        c.g += cyan.g / 3.5; c.b += cyan.b / 3.0; c.a += cyan.a / 7.0;
        vec4 blue = sampleContent(refractedCoord - dispersedCoord * (2.0 / 3.0));
        c.b += blue.b / 3.0; c.a += blue.a / 7.0;
        vec4 purple = sampleContent(refractedCoord - dispersedCoord);
        c.r += purple.r / 7.0; c.b += purple.b / 3.0; c.a += purple.a / 7.0;
        color = c;
    } else {
        color = sampleContent(refractedCoord);
    }

    // 染色由 QML 侧的覆盖层完成，这里只负责折射
    fragColor = color * qt_Opacity * coverage;
}
