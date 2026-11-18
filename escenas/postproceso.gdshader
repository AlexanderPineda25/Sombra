// Postproceso del museo: viñeta, grano de película, aberración cromática en
// la persecución, tinte rojo de alarma y desaturación verde al esconderse.
// Los uniformes los fija escenas/main.gd a partir de los estados de los AFD.
shader_type canvas_item;

uniform sampler2D pantalla : hint_screen_texture, filter_linear_mipmap;
uniform float tiempo = 0.0;
uniform float vineta = 0.55;          // fuerza de la viñeta
uniform float grano = 0.035;          // ruido de película
uniform float aberracion = 0.0;       // 0..1 (persecución)
uniform float alarma = 0.0;           // 0..1 (tinte rojo que late)
uniform float oculto = 0.0;           // 0..1 (escondido en un arbusto)
uniform float tension = 0.0;          // 0..1 (sospecha / búsqueda: contraste)
uniform vec2 foco = vec2(0.5, 0.5);   // posición del ladrón en UV

float azar(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 desde = uv - foco;
	float desplaz = aberracion * 0.004;
	vec3 c;
	c.r = texture(pantalla, uv + desde * desplaz * 2.0).r;
	c.g = texture(pantalla, uv).g;
	c.b = texture(pantalla, uv - desde * desplaz * 2.0).b;

	// contraste un poco mayor cuando sospechan
	c = mix(c, smoothstep(0.0, 1.0, c), tension * 0.35);

	// escondido: menos color y un velo verde de hojas
	float gris = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(gris) * vec3(0.85, 1.05, 0.9), oculto * 0.55);

	// alarma: tinte rojo pulsante
	float pulso = 0.5 + 0.5 * sin(tiempo * 6.0);
	c = mix(c, c * vec3(1.35, 0.6, 0.6) + vec3(0.06, 0.0, 0.0), alarma * (0.35 + 0.25 * pulso));

	// viñeta centrada (más cerrada al esconderse: visión de túnel)
	vec2 centro = UV - 0.5;
	float d = length(centro * vec2(1.0, 0.75));
	float v = smoothstep(0.75 - oculto * 0.18, 0.25, d);
	c *= mix(1.0, v, vineta);

	// grano
	c += (azar(UV * 731.0 + fract(tiempo * 13.7)) - 0.5) * grano;
	COLOR = vec4(c, 1.0);
}
