#[compute]
#version 450

// Requerido para usar tipos de 16 bits reales (FP16)
#extension GL_EXT_shader_explicit_arithmetic_types_float16 : require

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) readonly buffer InputBuffer {
	float16_t data[];
} x;

layout(set = 0, binding = 1, std430) readonly buffer WeightBuffer {
	float16_t data[];
} w;

layout(set = 0, binding = 2, std430) readonly buffer BiasBuffer {
	float16_t data[];
} b;

layout(set = 0, binding = 3, std430) writeonly buffer OutputBuffer {
	float16_t data[];
} y;

layout(push_constant) uniform Params {
	uint batch_size;
	uint in_features;
	uint out_features;
	uint activation;
	uint has_bias;
	uint pad1;
	uint pad2;
	uint pad3;
} params;

void main() {
	uint row = gl_GlobalInvocationID.y;
	uint col = gl_GlobalInvocationID.x;

	if (row >= params.batch_size || col >= params.out_features) {
		return;
	}

	float16_t sum = float16_t(0.0);
	for (uint i = 0; i < params.in_features; i++) {
		sum += x.data[row * params.in_features + i] * w.data[col * params.in_features + i];
	}

	if (params.has_bias == 1) {
		sum += b.data[col];
	}

	// Activaciones (16 bits)
	if (params.activation == 1) { // ReLU
		sum = max(float16_t(0.0), sum);
	}

	y.data[row * params.out_features + col] = sum;
}
