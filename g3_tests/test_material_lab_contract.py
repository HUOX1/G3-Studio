from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SHADERS = ROOT / "g3_frontend" / "shaders"
SCRIPTS = ROOT / "g3_frontend" / "scripts"


def read_shader(name: str) -> str:
    return (SHADERS / name).read_text(encoding="utf-8")


def test_material_lab_is_registered_as_an_isolated_interaction_lab_page():
    interaction = (SCRIPTS / "interaction_lab.gd").read_text(encoding="utf-8")
    material_lab = (SCRIPTS / "material_lab.gd").read_text(encoding="utf-8")
    assert 'preload("res://scripts/material_lab.gd")' in interaction
    assert '"复古工业材质"' in interaction
    assert "_material_page.set_page_active(_active and _active_lab_page == 3)" in interaction
    assert "func set_page_active(active: bool) -> void:" in material_lab
    assert "func apply_game_theme_palette(palette: Dictionary) -> void:" in material_lab
    assert "func reset_game_theme_palette() -> void:" in material_lab


def test_material_lab_exposes_four_independent_canvas_item_shaders():
    material_lab = (SCRIPTS / "material_lab.gd").read_text(encoding="utf-8")
    for code, shader in [
        ("M01", "g3_material_aged_gunmetal.gdshader"),
        ("M02", "g3_material_glass_surface_b.gdshader"),
        ("M03", "g3_material_amber_phosphor.gdshader"),
        ("M04", "g3_material_internal_pcb.gdshader"),
    ]:
        assert shader in material_lab
        assert f'"{code}"' in material_lab
        source = read_shader(shader)
        assert "shader_type canvas_item;" in source
        assert "void fragment()" in source
        assert "#include \"g3_material_common.gdshaderinc\"" in source


def test_common_shader_include_provides_noise_and_sdf_primitives():
    common = read_shader("g3_material_common.gdshaderinc")
    assert "float g3_hash21(" in common
    assert "float g3_value_noise(" in common
    assert "float g3_fbm(" in common
    assert "float g3_sd_round_rect(" in common


def test_gunmetal_uses_directional_brushing_wear_and_rounded_edge_mask():
    source = read_shader("g3_material_aged_gunmetal.gdshader")
    for token in ["grain_scale", "wear_amount", "g3_fbm(", "g3_value_noise(", "scratch_mask", "g3_sd_round_rect("]:
        assert token in source
    assert "COLOR = vec4(clamp(metal, 0.0, 1.0), alpha);" in source


def test_smoked_acrylic_samples_background_and_has_adjustable_haze_and_edge_reflection():
    source = read_shader("g3_material_smoked_acrylic.gdshader")
    assert "hint_screen_texture" in source
    assert "SCREEN_UV" in source
    assert "SCREEN_PIXEL_SIZE" in source
    assert "uniform float haze" in source
    assert "uniform float edge_reflection" in source
    assert "g3_value_noise(" in source


def test_phosphor_and_pcb_have_independent_live_parameters():
    phosphor = read_shader("g3_material_amber_phosphor.gdshader")
    pcb = read_shader("g3_material_internal_pcb.gdshader")
    assert "uniform float glow_strength" in phosphor
    assert "uniform float pulse_speed" in phosphor
    assert "uniform float lens_roughness" in phosphor
    assert "uniform float pulse_speed" in pcb
    assert "uniform float trace_brightness" in pcb
    assert "uniform float detail_amount" in pcb
    assert "segment_distance(" in pcb


def test_material_lab_parameter_bindings_match_shader_uniforms():
    material_lab = (SCRIPTS / "material_lab.gd").read_text(encoding="utf-8")
    bindings = re.findall(r'SHADER_(GUNMETAL|GLASS_SURFACE_B|PHOSPHOR|PCB),\s*"[^"]+",\s*"([a-z_]+)"', material_lab)
    shader_by_kind = {
        "GUNMETAL": "g3_material_aged_gunmetal.gdshader",
        "GLASS_SURFACE_B": "g3_material_glass_surface_b.gdshader",
        "PHOSPHOR": "g3_material_amber_phosphor.gdshader",
        "PCB": "g3_material_internal_pcb.gdshader",
    }
    assert len(bindings) == 4
    for kind, parameter in bindings:
        source = read_shader(shader_by_kind[kind])
        assert re.search(rf"uniform\s+\w+\s+{re.escape(parameter)}\b", source)


def test_material_previews_use_contrasting_backdrops_and_shared_preview_dimensions():
    material_lab = (SCRIPTS / "material_lab.gd").read_text(encoding="utf-8")
    assert "dark_field.color" in material_lab
    assert "light_field.color" in material_lab
    assert "preview_back.add_child(dark_field)" in material_lab
    assert "preview_back.add_child(light_field)" in material_lab
    assert "const PREVIEW_ASPECT_RATIO: float = 2.5" in material_lab
    assert "preview_back.resized.connect(_sync_preview_dimensions.bind(preview_back, material, source_viewport, reflection_viewport))" in material_lab
    assert "material.set_shader_parameter(\"panel_size\", shader_size)" in material_lab
    assert "PREVIEW_SIZE" not in material_lab



def test_material_previews_keep_a_controlled_aspect_ratio_and_sync_shader_pixel_size():
    material_lab = (SCRIPTS / "material_lab.gd").read_text(encoding="utf-8")
    assert "const PREVIEW_ASPECT_RATIO: float = 2.5" in material_lab
    assert "PREVIEW_MIN_HEIGHT: float = 160.0" in material_lab
    assert "preview_width / PREVIEW_ASPECT_RATIO" in material_lab
    assert "material.set_shader_parameter(\"panel_size\", shader_size)" in material_lab


def test_phosphor_lens_uses_aspect_compensated_coordinates():
    source = read_shader("g3_material_amber_phosphor.gdshader")
    assert "float aspect = panel_size.x / max(panel_size.y, 1.0);" in source
    assert "vec2(aspect, 1.0)" in source


def test_pcb_traces_and_solder_pads_use_aspect_compensated_coordinates():
    source = read_shader("g3_material_internal_pcb.gdshader")
    assert "vec2 p = vec2(UV.x * aspect, UV.y);" in source
    assert "0.08 * aspect" in source
    assert "0.90 * aspect" in source



def test_smoked_acrylic_preview_has_real_objects_behind_the_screen_shader():
    material_lab = (SCRIPTS / "material_lab.gd").read_text(encoding="utf-8")
    assert "class AcrylicTestBed extends Control:" in material_lab
    assert 'test_bed.name = "AcrylicTransmissionTestBed"' in material_lab
    assert "B  /  GLASS SURFACE TEST" in material_lab
    assert "ABCDEFGHIJKLMNOPQRSTUVWXYZ  0123456789" in material_lab
    assert "PCB substrate, IC package, fine traces and copper pads." in material_lab
    assert "Amber and cyan indicators" in material_lab
    assert "source_viewport.add_child(test_bed)" in material_lab
    assert "preview.texture = transmission_viewport.get_texture()" in material_lab
    assert "source_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE" in material_lab


def test_glass_surface_b_exposes_independent_material_controls():
    material_lab = (SCRIPTS / "material_lab.gd").read_text(encoding="utf-8")
    assert 'SHADER_GLASS_SURFACE_B, "微折射上限 (px)", "refraction_strength_px"' in material_lab
    assert '_add_parameter_slider(column, material, "微表面尺度", "surface_frequency"' in material_lab
    assert '_add_parameter_slider(column, material, "环境反射", "reflection_strength"' in material_lab
    assert '_add_parameter_slider(column, material, "烟熏吸收", "smoke_density"' in material_lab
    assert '_add_parameter_slider(column, material, "表面粗糙度", "surface_roughness"' in material_lab
    assert '_add_parameter_slider(column, material, "边缘 Fresnel", "edge_reflection"' in material_lab
    assert 'glass_toggle.text = "玻璃表面开启"' in material_lab
    assert "preview.material = material if enabled else null" in material_lab



def test_refraction_a_uses_subviewport_texture_not_global_screen_sampling():
    source = read_shader("g3_material_refraction_a.gdshader")
    assert "shader_type canvas_item;" in source
    assert "TEXTURE_PIXEL_SIZE" in source
    assert "texture(TEXTURE, refracted_uv)" in source
    assert "hint_screen_texture" not in source
    assert "SCREEN_UV" not in source


def test_refraction_a_derives_uv_offset_from_analytic_surface_gradient():
    source = read_shader("g3_material_refraction_a.gdshader")
    assert "float surface_height(vec2 uv)" in source
    assert "(h_right - h_left)" in source
    assert "(h_down - h_up)" in source
    assert "gradient * refraction_strength_px * texel" in source


def test_refraction_a_is_isolated_from_production_and_other_materials():
    material_lab = (SCRIPTS / "material_lab.gd").read_text(encoding="utf-8")
    assert "AcrylicTransmissionSource" in material_lab
    assert "AcrylicEnvironmentReflection" in material_lab
    assert "AcrylicSoftboxEnvironment" in material_lab
    assert "AcrylicRefractionPreview" in material_lab
    assert "source_viewport.add_child(test_bed)" in material_lab
    assert "reflection_viewport.add_child(reflection_environment)" in material_lab
    assert 'material.set_shader_parameter("reflection_texture", reflection_viewport.get_texture())' in material_lab
    assert 'if material != null and code != "M02":' in material_lab



def test_glass_surface_b_uses_low_amplitude_refraction_not_periodic_wave_distortion():
    source = read_shader("g3_material_glass_surface_b.gdshader")
    assert "uniform float refraction_strength_px : hint_range(0.0, 2.0" in source
    assert "float surface_height(vec2 uv)" in source
    assert "g3_fbm(" in source
    assert "vec2 normal_xy = clamp(gradient * 0.22" in source
    assert "vec2 offset_uv = normal_xy * refraction_strength_px * texel;" in source
    assert "sin(" not in source
    assert "cos(" not in source


def test_glass_surface_b_has_environment_reflection_and_edge_fresnel():
    source = read_shader("g3_material_glass_surface_b.gdshader")
    assert "uniform sampler2D reflection_texture : filter_linear;" in source
    assert "texture(reflection_texture, reflected_uv)" in source
    assert "float edge_fresnel = exp(-edge_px / 11.0) * edge_reflection * 0.26;" in source
    assert "uniform float reflection_strength" in source
    assert "uniform float edge_reflection" in source


def test_glass_surface_b_has_subtle_smoke_absorption_and_roughness():
    source = read_shader("g3_material_glass_surface_b.gdshader")
    assert "uniform float smoke_density" in source
    assert "uniform float surface_roughness" in source
    assert "transmitted = mix(transmitted, transmission_soft, surface_roughness * 0.12);" in source
    assert "color = mix(color, smoke_tint, smoke_density);" in source



def test_glass_surface_b_uses_a_separate_environment_reflection_viewport():
    material_lab = (SCRIPTS / "material_lab.gd").read_text(encoding="utf-8")
    assert "class AcrylicReflectionEnvironment extends Control:" in material_lab
    assert "draw_line(light_a, light_b" in material_lab
    assert "draw_line(light_c, light_d" in material_lab
    assert "var reflection_viewport: SubViewport = null" in material_lab
    assert "AcrylicEnvironmentReflection" in material_lab
    assert "reflection_viewport.add_child(reflection_environment)" in material_lab
    assert "material.set_shader_parameter(\"reflection_texture\", reflection_viewport.get_texture())" in material_lab


def test_glass_surface_b_reflection_is_mixed_by_fresnel_not_drawn_as_a_border_ring():
    source = read_shader("g3_material_glass_surface_b.gdshader")
    assert "float face_fresnel = 0.06 + 0.94 * pow(1.0 - ndotv, 5.0);" in source
    assert "float edge_fresnel = exp(-edge_px / 11.0) * edge_reflection * 0.26;" in source
    assert "float reflection_weight = clamp(" in source
    assert "vec3 color = mix(transmitted, reflected, reflection_weight);" in source
    assert "softbox_reflection(" not in source
