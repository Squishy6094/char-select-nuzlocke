const GeoLayout char_graffiti_geo[] = {
	GEO_NODE_START(),
	GEO_OPEN_NODE(),
		GEO_ASM(0, graffiti_geo_func),
		GEO_DISPLAY_LIST(LAYER_ALPHA, char_graffiti_char_graffiti_mesh_layer_4),
		GEO_DISPLAY_LIST(LAYER_ALPHA, char_graffiti_final_revert_mesh_layer_4),
	GEO_CLOSE_NODE(),
	GEO_END(),
};
