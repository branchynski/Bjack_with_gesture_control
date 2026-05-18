import hls4ml
import tensorflow as tf
import pprint

model = tf.keras.models.load_model("best_model.keras")

config = hls4ml.utils.config_from_keras_model(model, granularity='model')

# === KEY HARDWARE SETTINGS ===
config['Model']['Precision'] = 'ap_fixed<16,6>'
config['Model']['ReuseFactor'] = 64
config['Model']['Strategy'] = 'Latency'

print("hls4ml configuration:")
pprint.pprint(config)

# 3. Convert Keras model -> hls4ml
hls_model = hls4ml.converters.convert_from_keras_model(
    model,
    hls_config=config,
    output_dir='my_fpga_project',
    part='xc7a35tcpg236-1',
    backend='Vivado'
)

# 4. Compile HLS model (C++ verification)
print("\nCompiling HLS model...")
hls_model.compile()

# 5. Hardware synthesis
print("\nStarting hardware synthesis (Vivado HLS)...")
print("This may take several minutes depending on your PC's processor.")
hls_model.build(csim=False, synth=True, vsynth=False)

print("\nDone! Project generated in the 'my_fpga_project' folder.")