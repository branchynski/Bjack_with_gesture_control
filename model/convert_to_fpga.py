import hls4ml
import tensorflow as tf
import numpy as np
import pprint

model = tf.keras.models.load_model("best_model.keras")
model.summary()

config = hls4ml.utils.config_from_keras_model(model, granularity='naimport hls4ml
import tensorflow as tf
import numpy as np
import pprint

model = tf.keras.models.load_model("best_model.keras")
model.summary()

config = hls4ml.utils.config_from_keras_model(model, granularity='name')

config['Model']['Precision']   = 'ap_fixed<16,6>'
config['Model']['ReuseFactor'] = 1
config['Model']['Strategy']    = 'Resource'
config['Model']['IOType']      = 'io_stream'

config['LayerName']['input_layer']['Precision'] = 'ap_fixed<16,6>'

if 'BramFactor' in config['Model']:
    del config['Model']['BramFactor']

for layer in config['LayerName']:
    layer_cfg = config['LayerName'][layer]
    layer_cfg['Strategy'] = 'Resource'

    if 'dense' in layer:
        layer_cfg['Precision']  = 'ap_fixed<16,6>'
        layer_cfg['accum_t']    = 'ap_fixed<20,8>'
        layer_cfg['result_t']   = 'ap_fixed<16,6>'
        layer_cfg['ReuseFactor'] = 96

    elif 'conv' in layer:
        layer_cfg['Precision']  = 'ap_fixed<16,6>'
        layer_cfg['accum_t']    = 'ap_fixed<20,8>'
        layer_cfg['result_t']   = 'ap_fixed<16,6>'
        layer_cfg['ReuseFactor'] = 24

    elif 'batch_normalization' in layer or 'norm' in layer:
        layer_cfg['Precision']   = 'ap_fixed<16,6>'
        layer_cfg['ReuseFactor'] = 1

    else:
        layer_cfg['ReuseFactor'] = 1

print("hls4ml config:")
pprint.pprint(config)

# =========================================================
# VERIFICATION — compare Keras vs HLS output
# =========================================================
test_sample = np.random.uniform(-10, 10, size=(1, 208, 6)).astype(np.float32)

keras_pred = model.predict(test_sample)
print(f"\nKeras output: {keras_pred}")

# =========================================================
# CONVERSION
# =========================================================
hls_model = hls4ml.converters.convert_from_keras_model(
    model,
    hls_config=config,
    output_dir='my_fpga_project_basys',
    clock_period=15.38,
    io_type='io_stream',
    part='xc7a35tcpg236-1',
    backend='Vivado'
)

hls4ml.utils.plot_model(
    hls_model,
    show_shapes=True,
    show_precision=True,
    to_file='model_hls4ml.png'
)

print("\nCompiling HLS model...")
hls_model.compile()

hls_pred = hls_model.predict(test_sample)
print(f"HLS output:   {hls_pred}")

diff = np.max(np.abs(keras_pred - hls_pred))
print(f"Max diff Keras vs HLS: {diff:.4f}")

if diff < 0.5:
    print("✅ Precision is acceptable (< 0.5)")
elif diff < 1.0:
    print("⚠️  Moderate difference — may affect borderline cases")
else:
    print("❌ Large difference — consider increasing precision")

print("\nSynthesizing...")
hls_model.build(csim=False, synth=True, vsynth=False)
print("\nDone!")me')

# === KEY HARDWARE SETTINGS ===
config['Model']['Precision'] = 'ap_fixed<8,4>'
config['Model']['ReuseFactor'] = 1
config['Model']['Strategy'] = 'Resource'
config['LayerName']['input_layer']['Precision'] = 'ap_fixed<16,6>'
config['Model']['IOType'] = 'io_stream'
#config['Model']['BramFactor'] = 0

if 'BramFactor' in config['Model']:
    del config['Model']['BramFactor']

for layer in config['LayerName']:
    layer_cfg = config['LayerName'][layer]
    layer_cfg['Strategy'] = 'Resource'

    if 'dense' in layer:
        layer_cfg['Precision'] = 'ap_fixed<16,6>'
        layer_cfg['accum_t'] = 'ap_fixed<12,6>'  
        layer_cfg['result_t'] = 'ap_fixed<16,6>'
        layer_cfg['ReuseFactor'] = 96

    elif 'conv' in layer:
        layer_cfg['Precision'] = 'ap_fixed<16,6>'
        layer_cfg['accum_t'] = 'ap_fixed<12,6>' 
        layer_cfg['result_t'] = 'ap_fixed<16,6>'
        layer_cfg['ReuseFactor'] = 24

    elif 'norm' in layer or 'batch' in layer:
        layer_cfg['Precision'] = 'ap_fixed<10,5>'
        layer_cfg['ReuseFactor'] = 1

    else:
        layer_cfg['ReuseFactor'] = 1

print("hls4ml configuration:")
pprint.pprint(config)

# 3. Convert Keras model -> hls4ml
hls_model = hls4ml.converters.convert_from_keras_model(
    model,
    hls_config=config,
    output_dir='my_fpga_project_basys',
    clock_period=15.38,
    io_type='io_stream',
    part='xc7a35tcpg236-1',
    backend='Vivado'
)

hls4ml.utils.plot_model(
    hls_model,
    show_shapes=True,
    show_precision=True,
    to_file='model_hls4ml.png'
)

# 4. Compile HLS model (C++ verification)
print("\nCompiling HLS model...")
hls_model.compile()

# 5. Hardware synthesis
print("\nStarting hardware synthesis (Vivado HLS)...")
print("This may take several minutes depending on your PC's processor.")
hls_model.build(csim=False, synth=True, vsynth=False)

print("\nDone! Project generated in the 'my_fpga_project' folder.")