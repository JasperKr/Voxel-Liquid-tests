function Renderer.internal.updateSSRSettings(settings)
    local ssrSettings = settings.screenSpaceReflections
    local shaders = Renderer.internal.shaders

    local shader = shaders.screenSpaceReflections
    local transparency = shaders.transparencyShader

    shader:send("SSREnabled", ssrSettings.enabled)
    shader:send("rayDistance", ssrSettings.rayDistance)
    shader:send("steps", ssrSettings.steps)
    shader:send("thickness", ssrSettings.thickness)
    shader:send("offset", ssrSettings.offset)

    transparency:send("rayDistance", ssrSettings.rayDistance)
    transparency:send("steps", ssrSettings.steps)
    transparency:send("thickness", ssrSettings.thickness)
    transparency:send("offset", ssrSettings.offset)

    transparency:send("rayDistance", ssrSettings.rayDistance)
    transparency:send("steps", ssrSettings.steps)
    transparency:send("thickness", ssrSettings.thickness)
    transparency:send("SSREnabled", ssrSettings.enabled)


    if Renderer.internal.gui.reflectionsValues then
        Renderer.internal.gui.reflectionsValues.enabled[0] = ssrSettings.enabled
        Renderer.internal.gui.reflectionsValues.rayDistance[0] = ssrSettings.rayDistance
        Renderer.internal.gui.reflectionsValues.steps[0] = ssrSettings.steps
        Renderer.internal.gui.reflectionsValues.thickness[0] = ssrSettings.thickness
        Renderer.internal.gui.reflectionsValues.offset[0] = ssrSettings.offset
    end
end

function Renderer.internal.updateShaderVariables(settings)
    local graphicsData = Renderer.internal.graphicsData
    local shaders = Renderer.internal.shaders

    local transparency = shaders.transparencyShader
    local main = shaders.main
    local volumetric = shaders.volumetricLightingVariants

    transparency:send("SkyboxBrightness", settings.skybox.brightness)

    shaders.cubemaps:send("SkyboxBrightness", settings.skybox.brightness)
    shaders.cubemaps:send("iblRoughnessOneLevel", Renderer.internal.iblRoughnessOneLevel)
    transparency:send("iblRoughnessOneLevel", Renderer.internal.iblRoughnessOneLevel)

    if graphicsData then
        shaders.main:send("SkyboxTexture", graphicsData.skybox)
        shaders.main:send("SkyboxBrightness", settings.skybox.brightness)

        shaders.cubemaps:send("iblRoughnessOneLevel", Renderer.internal.iblRoughnessOneLevel)
        shaders.cubemaps:send("SkyboxBrightness", settings.skybox.brightness)
    end

    if Renderer.internal.spotlightShadowMaps then
        main:send("SpotLightShadowmaps", Renderer.internal.spotlightShadowMaps)
        Renderer.internal.computeShaders.sampleVolumes:send("SpotLightShadowmaps", Renderer.internal.spotlightShadowMaps)
        transparency:send("SpotLightShadowmaps", Renderer.internal.spotlightShadowMaps)

        main:send("DirectionalLightShadowmaps", Renderer.internal.directionallightShadowMaps)
        Renderer.internal.computeShaders.sampleVolumes:send("DirectionalLightShadowmaps",
            Renderer.internal.directionallightShadowMaps)
        transparency:send("DirectionalLightShadowmaps", Renderer.internal.directionallightShadowMaps)

        main:send("DirectionalLightColoredShadowmaps1", Renderer.internal.directionalLightColoredShadowmaps1)
        transparency:send("DirectionalLightColoredShadowmaps1", Renderer.internal.directionalLightColoredShadowmaps1)

        main:send("DirectionalLightColoredShadowmaps2", Renderer.internal.directionalLightColoredShadowmaps2)
        transparency:send("DirectionalLightColoredShadowmaps2", Renderer.internal.directionalLightColoredShadowmaps2)
    end

    local cubemaps = shaders.cubemaps

    cubemaps:send("SpecularTextures", Renderer.internal.specularMaps)
    cubemaps:send("IrradianceTextures", Renderer.internal.irradianceMaps)

    local transparencyShader = shaders.transparencyShader

    transparencyShader:send("SpecularTextures", Renderer.internal.specularMaps)
    transparencyShader:send("IrradianceTextures", Renderer.internal.irradianceMaps)

    Renderer.internal.updateSSRSettings(settings)
end
