require "pipelines/common"

addFramebuffer(this, "default", {
	width = 1024,
	height = 1024,
	renderbuffers = {
		{ format = "rgba8" },
	}
})

addFramebuffer(this, "g_buffer", {
	width = 1024,
	height = 1024,
	screen_size = true,
	renderbuffers = {
		{ format = "rgba8" },
		{ format = "rgba8" },
		{ format = "rgba8" },
		{ format = "depth32" }
	}
})

parameters.hdr = true
parameters.debug_gbuffer0 = false
parameters.debug_gbuffer1 = false
parameters.debug_gbuffer2 = false
parameters.debug_gbuffer_depth = false
parameters.sky_enabled = true

function initScene(this)
	hdr_exposure_param = addRenderParamFloat(this, "HDR exposure", 1.0)
	dof_focal_distance_param = addRenderParamFloat(this, "DOF focal distance", 10.0)
	dof_focal_range_param = addRenderParamFloat(this, "DOF focal range", 10.0)
end


texture_uniform = createUniform(this, "u_texture")
gbuffer0_uniform = createUniform(this, "u_gbuffer0")
gbuffer1_uniform = createUniform(this, "u_gbuffer1")
gbuffer2_uniform = createUniform(this, "u_gbuffer2")
gbuffer_depth_uniform = createUniform(this, "u_gbuffer_depth")
blur_material = loadMaterial(this, "shaders/blur.mat")
deferred_material = loadMaterial(this, "shaders/deferred.mat")
screen_space_material = loadMaterial(this, "shaders/screen_space.mat")
deferred_point_light_material =loadMaterial(this, "shaders/deferredpointlight.mat")
sky_material = loadMaterial(this, "shaders/sky.mat")
initHDR(this)
initShadowmap(this)


function deferred()
	deferred_view = newView(this, "deferred")
		setPass(this, "DEFERRED")
		setFramebuffer(this, "g_buffer")
		applyCamera(this, "editor")
		clear(this, CLEAR_ALL, 0x00000000)
		
		setStencil(this, STENCIL_OP_PASS_Z_REPLACE 
			| STENCIL_OP_FAIL_Z_KEEP 
			| STENCIL_OP_FAIL_S_KEEP 
			| STENCIL_TEST_ALWAYS)
		setStencilRMask(this, 0xff)
		setStencilRef(this, 1)
		
		renderModels(this, {deferred_view})
		
	newView(this, "copyRenderbuffer");
		copyRenderbuffer(this, "g_buffer", 3, "hdr", 1)
		
	newView(this, "main")
		setPass(this, "MAIN")
		setFramebuffer(this, "hdr")
		applyCamera(this, "editor")
		clear(this, CLEAR_COLOR | CLEAR_DEPTH, 0x00000000)
		
		bindFramebufferTexture(this, "g_buffer", 0, gbuffer0_uniform)
		bindFramebufferTexture(this, "g_buffer", 1, gbuffer1_uniform)
		bindFramebufferTexture(this, "g_buffer", 2, gbuffer2_uniform)
		bindFramebufferTexture(this, "g_buffer", 3, gbuffer_depth_uniform)
		bindFramebufferTexture(this, "shadowmap", 0, shadowmap_uniform)
		drawQuad(this, -1, 1, 2, -2, deferred_material)
	
	newView(this, "deferred_local_light")
		setPass(this, "MAIN")
		setFramebuffer(this, "hdr")
		disableDepthWrite(this)
		enableBlending(this, "add")
		applyCamera(this, "editor")
		renderLightVolumes(this, deferred_point_light_material)
		disableBlending(this)
		
	if parameters.sky_enabled then
		newView(this, "sky")
			setPass(this, "SKY")
			setStencil(this, STENCIL_OP_PASS_Z_KEEP 
				| STENCIL_OP_FAIL_Z_KEEP 
				| STENCIL_OP_FAIL_S_KEEP 
				| STENCIL_TEST_NOTEQUAL)
			setStencilRMask(this, 1)
			setStencilRef(this, 1)

			setFramebuffer(this, "hdr")
			setActiveGlobalLightUniforms(this)
			disableDepthWrite(this)
			drawQuad(this, -1, -1, 2, 2, sky_material)
	end
end


function debugDeferred()
	local x = 0.5
	if parameters.debug_gbuffer0 then
		newView(this, "debug_gbuffer0")
			disableDepthWrite(this)
			setPass(this, "SCREEN_SPACE")
			setFramebuffer(this, "default")
			bindFramebufferTexture(this, "g_buffer", 0, texture_uniform)
			drawQuad(this, x, 1.0, 0.5, -0.5, screen_space_material)
			x = x - 0.51
	end
	if parameters.debug_gbuffer1 then
		newView(this, "debug_gbuffer1")
			disableDepthWrite(this)
			setPass(this, "SCREEN_SPACE")
			setFramebuffer(this, "default")
			bindFramebufferTexture(this, "g_buffer", 1, texture_uniform)
			drawQuad(this, x, 1.0, 0.5, -0.5, screen_space_material)
			x = x - 0.51
	end
	if parameters.debug_gbuffer2 then
		newView(this, "debug_gbuffer2")
			disableDepthWrite(this)
			setPass(this, "SCREEN_SPACE")
			setFramebuffer(this, "default")
			bindFramebufferTexture(this, "g_buffer", 2, texture_uniform)
			drawQuad(this, x, 1.0, 0.5, -0.5, screen_space_material)
			x = x - 0.51
	end
	if parameters.debug_gbuffer_depth then
		newView(this, "debug_gbuffer_depth")
			disableDepthWrite(this)
			setPass(this, "SCREEN_SPACE")
			setFramebuffer(this, "default")
			bindFramebufferTexture(this, "g_buffer", 3, texture_uniform)
			drawQuad(this, x, 1.0, 0.5, -0.5, screen_space_material)
			x = x - 0.51
	end
end

function debugShapes()
	newView(this, "debug_shapes")
		setPass(this, "MAIN")
		applyCamera(this,"editor")
		setFramebuffer(this, "hdr")
		renderDebugShapes(this)
end


function render()
	shadowmap("editor")
	deferred(this)
	particles("editor")
	debugShapes()
	hdr("editor")
	

	editor(this)
	debugDeferred(this)
	shadowmapDebug(this)
end
