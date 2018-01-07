-- Minetest: builtin/ffi.lua

--
-- LuaJIT FFI definitions of core functions exported as C
--

-- LuaJIT-only
if not jit then return end

local ffi = require("ffi")

ffi.cdef([[
	typedef uint8_t u8;
	typedef uint16_t u16;

	void PerlinNoiseMap_get2dMap_flat(void **pnmp, double px, double py,
		float *buffer);
	void PerlinNoiseMap_get3dMap_flat(void **pnmp,
		double px, double py, double pz, float *buffer);
	void PerlinNoiseMap_getMapSlice(void **pnmp,
		u16 ofsx, u16 ofsy, u16 ofsz, u16 sizex, u16 sizey, u16 sizez,
		float *buffer);
	int VoxelManip_get_volume(void **vm);
	void VoxelManip_get_data(void **vm, u16 *data);
	void VoxelManip_set_data(void **vm, u16 *data);
	void VoxelManip_get_light_data(void **vm, u8 *data);
	void VoxelManip_set_light_data(void **vm, u8 *data);
	void VoxelManip_get_param2_data(void **vm, u8 *data);
	void VoxelManip_set_param2_data(void **vm, u8 *data);
]])
