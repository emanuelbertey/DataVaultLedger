#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) readonly buffer InputBuffer {
	float data[];
} x;

layout(set = 0, binding = 1, std430) readonly buffer WeightBuffer {
	float data[];
} w;

layout(set = 0, binding = 2, std430) readonly buffer BiasBuffer {
	float data[];
} b;

layout(set = 0, binding = 3, std430) writeonly buffer OutputBuffer {
	float data[];
} y;

layout(push_constant) uniform Params {
	uint batch_size;
	uint in_features;
	uint out_features;
	uint activation; // 0: None, 1: ReLU, 2: Sigmoid, 3: GELU
	uint has_bias;   // 0: No, 1: Yes
	uint pad1;       // Padding to 32 bytes
	uint pad2;
	uint pad3;
} params;

// Simple GELU implementation
float gelu(float x) {
	return 0.5 * x * (1.0 + tanh(0.7978845608 * (x + 0.044715 * x * x * x)));
}

void main() {
	uint row = gl_GlobalInvocationID.y; // Batch index
	uint col = gl_GlobalInvocationID.x; // Out feature index

	if (row >= params.batch_size || col >= params.out_features) {
		return;
	}

	float sum = 0.0;
	for (uint i = 0; i < params.in_features; i++) {
		// x index: row * in_features + i
		// w index: col * in_features + i (Weights are usually Out x In)
		sum += x.data[row * params.in_features + i] * w.data[col * params.in_features + i];
	}

	if (params.has_bias == 1) {
		sum += b.data[col];
	}

	// Activations
	if (params.activation == 1) { // ReLU
		sum = max(0.0, sum);
	} else if (params.activation == 2) { // Sigmoid
		sum = 1.0 / (1.0 + exp(-sum));
	} else if (params.activation == 3) { // GELU
		sum = gelu(sum);
	}

	y.data[row * params.out_features + col] = sum;
}
