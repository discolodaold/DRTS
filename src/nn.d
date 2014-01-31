module nn;

import util : GameRand;

GameRand rand;

template charge(uint NODE, uint NUM_NODES, uint LL_START, uint LL_COUNT) {
	static if(NODE == NUM_NODES)
		const char [] charge_hidden = "";
	else
		const char [] charge_hidden = "*e++ = trigger(*b++" ~ apply_weights!(LL_START, LL_START + LL_COUNT) ~ ");\n" ~ charge_hidden!(NODE + 1, NUM_NODES, LL_START, LL_COUNT);
}

template apply_weights(uint NODE, uint NUM_NODES) {
	static if(NODE == NUM_NODES)
		const char [] apply_weights = "";
	else
		const char [] apply_weights = " + energy[" ~ itoa!(NODE) ~ "] * *w++" ~ apply_weights!(NODE + 1, MAX_NODES);
}

class NN(uint INPUTS, uint HIDDEN, uint OUTPUTS, uint LAYERS, T = float, A = ushort) {
	// storage
	uint used_data;
	T[A.sizeof] _data;
	A[LAYERS][HIDDEN*INPUTS + OUTPUTS*HIDDEN] _weight;
	A[LAYERS][HIDDEN + OUTPUT] _bias;
	
	// runtime
	T[HIDDEN*INPUTS + OUTPUTS*HIDDEN] weight;
	T[HIDDEN + OUTPUT] bias;
	T[INPUT + HIDDEN + OUTPUT] energy;
	
    uint used_layers = 0;

    uint opCall() {
        int w = HIDDEN*INPUTS + OUTPUTS*HIDDEN;
        while(--w) {
            if(rand() & 7)
                _weight[used_layers][w] = rand() % used_data;
            else {
                _data[used_data] = rand.frac();
                _weight[used_layers][w] = used_data++;
            }
        }
        int b = HIDDEN + OUTPUTS;
        while(--b) {
            if(rand() & 7)
                _bias[used_layers][w] = rand() % used_data;
            else {
                _data[used_data] = rand.frac();
                _bias[used_layers][w] = used_data++;
            }
        }
        return used_layers++;
    }

	T[] opCall(uint layer, T[] inputs ...)
	in {
		assert(layer >= 0 && layer < LAYERS);
		assert(inputs.length == INPUTS);
	} body {
		energy[0 .. INPUTS] = inputs[0 .. $];
		
		T* b = bias.ptr;
		foreach(short index; _bias[layer])
			*b++ = _data[index];
		b = bias.ptr;
		
		T* w = weight.ptr;
		foreach(short index; _weight[layer])
			*w++ = _data[index];
		w = weight.ptr;
		
		T* e = energy.ptr + INPUTS;
		
		mixin(charge!(0, HIDDEN, 0, INPUTS));
		mixin(charge!(0, OUTPUT, INPUTS, HIDDEN));
		
		return energy[energy.length - OUTPUT .. $];
	}
	
	// nice side effect of using this fitness based distribution function is that layers can be updated in groups at any time
	real[uint] fitness;
	void set_fitness(uint layer, real fit) {
		fitness[layer] = fit;
	}
	
	void redistribute() {
		// get total fit, used for random distibution and allocation later
		real total_fit = 0.0;
		uint count = 0;
		foreach(real fit; fitness.values) {
			total_fit += fit;
			count++;
		}
		
		// the amount of segments to patch together
		real wf = cast(real)(HIDDEN*INPUTS + OUTPUTS*HIDDEN) / cast(real)count;
		real bf = cast(real)(HIDDEN + OUTPUTS) / cast(real)count;
		
		// new biases and weights, so we dont read from a patched layer
		A[LAYERS][HIDDEN*INPUTS + OUTPUTS*HIDDEN] new_weight;
		A[LAYERS][HIDDEN + OUTPUT] new_bias;
		
		// go through each layer and develop a new patch one
		// nothing of the old survives when the function ends
		uint[] fit_layers = new uint[](count), layers = fitness.keys;
		foreach(uint replace_layer; layers) {
			// use a probablility distribution to get a list of layers to patch this one with
			uint fit_layer = fit_layers.length;
			while(fit_layer--) {
				float energy = rand.frac() * total_fit;
				uint read_layer = rand() % layers.length;
				while(energy > 0 && ++read_layer)
					energy -= fitness[layers[read_layer % layers.length]];
				fit_layers[fit_layer] = read_layer % layers.length;
			}
			
			// patch together a new layer
			real wr = 0, br = 0, we = void, be = void;
			foreach(uint in_layer; fit_layers) {
				we = wr + wf;
				be = br + bf;
				new_bias[replace_layer][cast(uint)wr .. cast(uint)we] = _bias[in_layer][cast(uint)wr .. cast(uint)we];
				new_bias[replace_layer][cast(uint)br .. cast(uint)be] = _bias[in_layer][cast(uint)br .. cast(uint)be];
				wr = we;
				br = be;
			}
		}
		
		// finally clear the fitness and apply the new weights and biases
		foreach(uint key; fitness.keys) {
			_weight[key][] = new_weight[key][];
			_bias[key][] = new_bias[key][];
			fitness.remove(key);
		}
	}
	
	void mutate() {
		uint count = rand() % (used_data >> 5);
		while(count--)
			_data[rand() % (used_data - 1)] += rand.dfrac();
	}
}
