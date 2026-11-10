shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Auto Modellista & Initial D Manga Cel-Shaded Vehicle Shader
// Variable Pen-Pressure Smoothstep Inking + Auto Modellista Livery + Manga Speed Wedges

uniform vec4 paper_white : source_color = vec4(0.92, 0.90, 0.86, 1.0);  // Warm paper cream #EAE6DF
uniform vec4 slate_grey : source_color = vec4(0.43, 0.45, 0.52, 1.0);   // Slate grey lower flank #6E7485
uniform vec4 stripe_blue : source_color = vec4(0.00, 0.34, 0.88, 1.0);  // Auto Modellista Cobalt Blue #0057E0
uniform vec4 navy_diffuser : source_color = vec4(0.12, 0.22, 0.38, 1.0); // Lower rear diffuser navy #1F3861
uniform vec4 ink_black : source_color = vec4(0.04, 0.04, 0.06, 1.0);    // Bold manga ink #0A0914
uniform vec4 ink_shadow : source_color = vec4(0.05, 0.05, 0.09, 1.0);   // Deep core shadow ink
uniform vec4 paint_color : source_color = vec4(0.90, 0.88, 0.82, 1.0);  // Fallback single tone
uniform vec4 day_night_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);  // Ambient sky tint
uniform float sodium_intensity : hint_range(0.0, 1.0) = 0.0;            // Overhead sodium streetlight wash
uniform vec4 sodium_color : source_color = vec4(1.0, 0.65, 0.15, 1.0);
uniform vec3 sun_direction = vec3(-0.5, -0.8, -0.3);
uniform float shadow_cut : hint_range(0.0, 1.0) = 0.38;
uniform float hatch_base_spacing : hint_range(1.0, 15.0) = 3.6;
uniform bool is_two_tone = true;
uniform bool has_stripes = true;

// Interpolated vehicle-space coordinates in meters relative to car chassis
varying vec3 v_car_pos;
varying vec3 v_car_norm;

void vertex() {
	// Exact transformation from Muscle FBX mesh to chassis meters:
	// X_car: Left (-1.01m) to Right (+1.01m)
	// Y_car: Ground (0.20m rocker) to Roof (1.15m)
	// Z_car: Front (-2.17m) to Rear (+2.12m)
	v_car_pos = vec3(-72.0 * VERTEX.x, 0.427 + 72.0 * VERTEX.z, 72.0 * VERTEX.y);
	v_car_norm = normalize(vec3(-72.0 * NORMAL.x, 72.0 * NORMAL.z, 72.0 * NORMAL.y));
}

// Antialiased ink stroke evaluator
float stroke_dist(float dist, float width) {
	return 1.0 - smoothstep(width - 0.003, width + 0.003, dist);
}

void fragment() {
	float ax = abs(v_car_pos.x);
	float ay = v_car_pos.y;
	float az = v_car_pos.z;

	bool is_side = (ax > 0.68 || abs(v_car_norm.x) > 0.35);
	bool is_top = (v_car_norm.y > 0.40 && ay > 0.65);
	bool is_rear_fascia = (az > 1.82 && abs(v_car_norm.z) > 0.30);
	bool is_front_nose = (az < -1.82 && abs(v_car_norm.z) > 0.30);

	// =========================================================================
	// 1. BASE TWO-TONE PAINT SCHEME (Initial D / Auto Modellista)
	// =========================================================================
	bool is_lower = false;
	if (is_side) {
		is_lower = (ay < 0.52); // Slate grey below horizontal rub-strip
	} else if (is_front_nose) {
		is_lower = (ay < 0.42); // Lower front air dam
	} else if (is_rear_fascia) {
		is_lower = (ay < 0.42); // Lower rear diffuser
	}

	vec3 base_color;
	if (is_two_tone) {
		if (is_rear_fascia && ay < 0.42) {
			base_color = navy_diffuser.rgb; // Auto Modellista navy blue lower diffuser
		} else {
			base_color = is_lower ? slate_grey.rgb : paper_white.rgb;
		}
	} else {
		base_color = paint_color.rgb;
	}

	// =========================================================================
	// 2. DUAL COBALT BLUE RACING STRIPES (Hood, Roof, Trunk, Rear Fascia)
	// =========================================================================
	bool in_stripe_zone = (is_top || is_rear_fascia || (ay > 0.65 && abs(v_car_norm.z) > 0.25));
	if (is_rear_fascia && ay < 0.42) {
		in_stripe_zone = false;
	}

	bool is_blue_stripe = has_stripes && in_stripe_zone && (ax >= 0.055 && ax <= 0.22);
	bool is_stripe_edge_outer = has_stripes && in_stripe_zone && (abs(ax - 0.22) < 0.010);
	bool is_stripe_edge_inner = has_stripes && in_stripe_zone && (abs(ax - 0.055) < 0.010);

	if (is_blue_stripe) {
		base_color = stripe_blue.rgb;
	}

	// =========================================================================
	// 3. AUTO MODELLISTA REAR FASCIA GRAPHICS (Badge & TRD Racing Plate)
	// =========================================================================
	if (is_rear_fascia) {
		// (A) Auto Modellista Circular Emblem Badge (Tailgate left at ax ~ 0.45, ay ~ 0.58)
		float badge_dist = length(vec2(v_car_pos.x - (-0.45), ay - 0.58));
		if (badge_dist < 0.044) {
			base_color = vec3(0.96, 0.96, 0.98); // White badge disc
			if (badge_dist < 0.026) {
				base_color = stripe_blue.rgb; // Inner blue "a" logo
			}
		}

		// (B) Japanese Red "TRD" Racing License Box (Centered in lower fascia)
		if (ax < 0.17 && ay > 0.43 && ay < 0.505) {
			base_color = vec3(0.82, 0.12, 0.15); // Vibrant crimson TRD plate
			// Stylized white block letters "TRD" inside plate
			// 'T'
			if (v_car_pos.x > -0.14 && v_car_pos.x < -0.07) {
				if (ay > 0.485 || abs(v_car_pos.x - (-0.105)) < 0.010) {
					base_color = vec3(1.0, 0.98, 0.95);
				}
			}
			// 'R'
			if (v_car_pos.x > -0.05 && v_car_pos.x < 0.02) {
				if (abs(v_car_pos.x - (-0.04)) < 0.009 || (ay > 0.465 && (ay > 0.49 || abs(v_car_pos.x - 0.01) < 0.009)) || (ay <= 0.465 && abs(v_car_pos.x - (ay - 0.43) * 1.5 - (-0.03)) < 0.009)) {
					base_color = vec3(1.0, 0.98, 0.95);
				}
			}
			// 'D'
			if (v_car_pos.x > 0.04 && v_car_pos.x < 0.13) {
				if (abs(v_car_pos.x - 0.05) < 0.009 || ay > 0.49 || ay < 0.445 || abs(v_car_pos.x - 0.12) < 0.009) {
					base_color = vec3(1.0, 0.98, 0.95);
				}
			}
		}
	}

	// Sodium streetlamp wash (tunnels & nighttime)
	if (sodium_intensity > 0.01 && v_car_norm.y > 0.20) {
		base_color = mix(base_color, sodium_color.rgb, sodium_intensity * 0.45);
	}
	base_color *= day_night_tint.rgb;

	// =========================================================================
	// 4. VARIABLE-WEIGHT GRAPHIC INKING (Initial D Manga & Auto Modellista)
	// =========================================================================
	float ink_line = 0.0;

	// Dynamic Grazing / Curvature Taper:
	float NdotV = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float gaze_scale = mix(1.20, 0.85, NdotV);

	// (A) Racing Stripe Razor Hairline Borders (Crisp 7mm black ink border)
	if (is_stripe_edge_outer || is_stripe_edge_inner) {
		float dist_outer = abs(ax - 0.22);
		float dist_inner = abs(ax - 0.055);
		float stripe_border_w = 0.007 * gaze_scale;
		ink_line = max(ink_line, stroke_dist(min(dist_outer, dist_inner), stripe_border_w));
	}

	// (B) Bold Black Dividing Rub-Strip (Separates Cream & Slate Grey)
	if (is_side && abs(az) < 1.78) {
		float rub_dist_from_wheel = min(abs(az - (-1.16)), abs(az - 1.16));
		float rub_w = mix(0.024, 0.016, clamp(rub_dist_from_wheel / 0.70, 0.0, 1.0)) * gaze_scale;
		float end_fade = smoothstep(1.78, 1.68, abs(az));
		float r_line = stroke_dist(abs(ay - 0.52), rub_w) * end_fade;
		ink_line = max(ink_line, r_line);
	}

	// (C) Bottom Rocker Grounding Sill (Heavy anchor stroke 20mm)
	if (is_side && abs(az) < 1.76) {
		float sill_fade = smoothstep(1.76, 1.66, abs(az));
		float s_line = stroke_dist(abs(ay - 0.22), 0.020 * gaze_scale) * sill_fade;
		ink_line = max(ink_line, s_line);
	}

	// (D) Tapered Vertical Door Seams (Thick 20mm at bottom rocker, tapering to 7mm hairline at window)
	if (is_side && ay > 0.22 && ay < 0.71) {
		float t_door_y = clamp((ay - 0.22) / 0.48, 0.0, 1.0);
		float door_seam_w = mix(0.020, 0.007, t_door_y) * gaze_scale;
		float y_fade = smoothstep(0.71, 0.68, ay) * smoothstep(0.22, 0.25, ay);

		float d1 = stroke_dist(abs(az - (-0.58)), door_seam_w) * y_fade;
		float d2 = stroke_dist(abs(az - 0.02), door_seam_w) * y_fade;
		float d3 = stroke_dist(abs(az - 0.62), door_seam_w) * y_fade;

		ink_line = max(ink_line, max(d1, max(d2, d3)));
	}

	// (E) Crescent Wheel Arch Contours + Double-Arch Manga Accents
	if (is_side && ay > 0.22) {
		vec2 vf = vec2(az - (-1.16), (ay - 0.29) * 1.05);
		float df = length(vf);
		if (df > 0.18 && df < 0.58 && vf.y > 0.0) {
			float apex_f = clamp(vf.y / 0.36, 0.0, 1.0);
			float arch_w_f = mix(0.012, 0.036, apex_f) * gaze_scale;
			float arc_f = stroke_dist(abs(df - 0.36), arch_w_f);
			ink_line = max(ink_line, arc_f);

			if (apex_f > 0.35) {
				float flare_acc_w = 0.016 * sin((apex_f - 0.35) / 0.65 * 3.14159) * gaze_scale;
				float arc_acc = stroke_dist(abs(df - 0.43), flare_acc_w);
				ink_line = max(ink_line, arc_acc);
			}

			if (df > 0.32 && df < 0.36 && apex_f > 0.45) {
				float inner_lip = smoothstep(0.45, 0.85, apex_f);
				ink_line = max(ink_line, inner_lip * 0.95);
			}
		}

		vec2 vr = vec2(az - 1.16, (ay - 0.29) * 1.05);
		float dr = length(vr);
		if (dr > 0.18 && dr < 0.58 && vr.y > 0.0) {
			float apex_r = clamp(vr.y / 0.36, 0.0, 1.0);
			float arch_w_r = mix(0.012, 0.036, apex_r) * gaze_scale;
			float arc_r = stroke_dist(abs(dr - 0.36), arch_w_r);
			ink_line = max(ink_line, arc_r);

			if (apex_r > 0.35) {
				float flare_acc_r_w = 0.016 * sin((apex_r - 0.35) / 0.65 * 3.14159) * gaze_scale;
				float arc_acc_r = stroke_dist(abs(dr - 0.43), flare_acc_r_w);
				ink_line = max(ink_line, arc_acc_r);
			}

			if (dr > 0.32 && dr < 0.36 && apex_r > 0.45) {
				float inner_lip_r = smoothstep(0.45, 0.85, apex_r);
				ink_line = max(ink_line, inner_lip_r * 0.95);
			}
		}
	}

	// (F) DRAMATIC MANGA SPEED GOUGES / ACTION SHADOW WEDGES
	if (is_side) {
		// 1. FRONT FENDER SPEED WEDGE
		if (az > -1.68 && az < -0.85) {
			float t_fender = clamp((-0.85 - az) / 0.83, 0.0, 1.0);
			float wedge_y = 0.64 - 0.045 * t_fender;
			float wedge_half_h = 0.052 * pow(1.0 - t_fender, 1.2);
			if (abs(ay - wedge_y) < wedge_half_h) {
				ink_line = 1.0;
			}
		}

		// 2. Front lower bumper secondary speed slash
		if (az > -1.88 && az < -1.45) {
			float t_fb = clamp((az - (-1.88)) / 0.43, 0.0, 1.0);
			float fb_w = 0.024 * sin(t_fb * 3.14159);
			if (abs(ay - 0.38) < fb_w) {
				ink_line = 1.0;
			}
		}

		// 3. DOOR UPPER ACTION SLASH
		if (az > -0.55 && az < 0.35) {
			float t_slash1 = clamp((az - (-0.55)) / 0.90, 0.0, 1.0);
			float s1_y = 0.625 + 0.015 * sin(t_slash1 * 3.14159);
			float s1_w = 0.038 * sin(t_slash1 * 3.14159);
			if (abs(ay - s1_y) < s1_w) {
				ink_line = 1.0;
			}
		}

		// 4. DOOR LOWER ACTION SLASH
		if (az > -0.45 && az < 0.40) {
			float t_slash2 = clamp((az - (-0.45)) / 0.85, 0.0, 1.0);
			float s2_w = 0.030 * sin(t_slash2 * 3.14159);
			if (abs(ay - 0.43) < s2_w) {
				ink_line = 1.0;
			}
		}

		// 5. REAR QUARTER SPEED WEDGE
		if (az > 0.72 && az < 1.45) {
			float t_slash3 = clamp((az - 0.72) / 0.73, 0.0, 1.0);
			float s3_y = 0.63 + 0.025 * t_slash3;
			float s3_w = 0.038 * (1.0 - t_slash3) * sin(t_slash3 * 3.14159 * 0.92 + 0.08);
			if (abs(ay - s3_y) < s3_w) {
				ink_line = 1.0;
			}
		}

		// 6. Wheel Arch Triangular Underside Shadow Wedges
		if (az > -0.92 && az < -0.74 && ay > 0.26 && ay < 0.42) {
			float w_front = (-0.74 - az) * 0.75;
			if ((ay - 0.26) < w_front) { ink_line = 1.0; }
		}
		if (az > 1.36 && az < 1.54 && ay > 0.26 && ay < 0.42) {
			float w_rear = (1.54 - az) * 0.75;
			if ((ay - 0.26) < w_rear) { ink_line = 1.0; }
		}
	}

	// (G) Comic Door Handles with Drop Shadows
	if (is_side) {
		float dh_f = length(vec2((az - (-0.28)) * 0.40, ay - 0.58));
		if (abs(dh_f - 0.014) < 0.006) { ink_line = 1.0; }
		if (ay < 0.58 && ay > 0.552 && abs(az - (-0.28)) < 0.038) { ink_line = 1.0; }

		float dh_r = length(vec2((az - 0.32) * 0.40, ay - 0.58));
		if (abs(dh_r - 0.014) < 0.006) { ink_line = 1.0; }
		if (ay < 0.58 && ay > 0.552 && abs(az - 0.32) < 0.038) { ink_line = 1.0; }
	}

	// (H) Window Perimeter Frame Inking
	if (is_side) {
		if (abs(ay - 0.705) < 0.012 && abs(az) < 1.20) { ink_line = 1.0; }
		if (abs(ay - 0.98) < 0.018 && abs(az) < 1.05) { ink_line = 1.0; }
	}

	// (I) Hood & Character Shutlines
	if (is_top) {
		if (abs(az - (-1.85)) < 0.018 && ax < 0.78) { ink_line = 1.0; }
		if (abs(az - (-0.78)) < 0.014 && ax < 0.75) { ink_line = 1.0; }
		float t_hood = clamp((-az - 0.78) / 1.07, 0.0, 1.0);
		float hood_w = mix(0.008, 0.018, t_hood);
		if (abs(ax - 0.75) < hood_w && az > -1.85 && az < -0.78) { ink_line = 1.0; }
		if (abs(ax - 0.32) < 0.006 && az > -1.78 && az < -0.85) { ink_line = 1.0; }

		if (abs(az - 1.95) < 0.018 && ax < 0.72) { ink_line = 1.0; }
		if (abs(ax - 0.72) < 0.012 && az > 1.10 && az < 1.95) { ink_line = 1.0; }
	}

	// (J) AUTO MODELLISTA REAR FASCIA CLEAN LINEWORK
	if (is_rear_fascia) {
		if (abs(ay - 0.42) < 0.014 && ax < 0.78) {
			ink_line = 1.0;
		}
		if (ax < 0.175 && ay > 0.425 && ay < 0.510) {
			if (abs(ax - 0.17) < 0.008 || abs(ay - 0.43) < 0.008 || abs(ay - 0.505) < 0.008) {
				ink_line = 1.0;
			}
		}
		float b_ring = length(vec2(v_car_pos.x - (-0.45), ay - 0.58));
		if (abs(b_ring - 0.044) < 0.006) {
			ink_line = 1.0;
		}
	}

	// =========================================================================
	// 5. VARIABLE PEN-PRESSURE INKING FORMULA (USER SPECIFICATION)
	// =========================================================================
	vec3 light_dir_view = normalize((VIEW_MATRIX * vec4(-sun_direction, 0.0)).xyz);
	float NdotL = clamp(dot(NORMAL, light_dir_view), 0.0, 1.0);

	// 1. Calculate how deep into shadow the surface sits (0.0 = lit, 1.0 = pitch dark)
	float shadow_depth = clamp((shadow_cut - NdotL) / shadow_cut, 0.0, 1.0);

	// 2. Glancing edge factor: fatten ink strokes on curves turning away from camera
	float rim_factor = pow(1.0 - NdotV, 2.0);

	// 3. Dynamic Pen Thickness:
	// Hairline (0.04) near light border -> Heavy chisel stroke (0.42) in deep shadow/rims
	float half_width = mix(0.04, 0.42, clamp(shadow_depth * 0.75 + rim_factor * 0.40, 0.0, 1.0));

	// 4. Centered Stripe Coordinate [-0.5, 0.5]
	float coord = fract((FRAGCOORD.x + FRAGCOORD.y) / hatch_base_spacing) - 0.5;
	float dist_from_center = abs(coord);

	// 5. Anti-aliased, tapered ink edge (Smooth pen taper instead of hard binary step)
	float stroke = 1.0 - smoothstep(half_width - 0.04, half_width + 0.04, dist_from_center);

	// 6. Color Assignment
	vec3 lit_color;
	if (NdotL > shadow_cut) {
		// Highlight/Lit: Clean paint, zero hatch lines
		lit_color = base_color.rgb;
	} else if (shadow_depth > 0.82) {
		// Core shadow undercuts: Solid block of ink
		lit_color = ink_shadow.rgb;
	} else {
		// Transitional zones: Variable stroke weight
		// Thin strokes stay semi-translucent; thick strokes pool into rich dark ink
		float ink_density = mix(0.55, 1.0, shadow_depth);
		lit_color = mix(base_color.rgb, ink_shadow.rgb, stroke * ink_density);
	}

	// Composite graphic comic inking
	vec3 final_color = mix(lit_color, ink_black.rgb, clamp(ink_line, 0.0, 1.0));

	ALBEDO = final_color;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}
