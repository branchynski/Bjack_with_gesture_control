import os
import glob
import pandas as pd
import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, models, callbacks, regularizers
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix
from sklearn.utils.class_weight import compute_class_weight
import seaborn as sns
import matplotlib.pyplot as plt

# =========================================================
# 1. DATA LOADING
# =========================================================
dataset_dir = 'dataset'

class_mapping = {
    'tlo': 0,
    'swiper': 1,
    'knock': 2
}

X_list = []
y_list = []

print("Starting to load files...")

for folder_name, label in class_mapping.items():
    folder_path = os.path.join(dataset_dir, folder_name)
    file_pattern = os.path.join(folder_path, '*.csv')
    csv_files = glob.glob(file_pattern)

    print(f"Found {len(csv_files)} files in folder '{folder_name}' (class {label})")

    for file_path in csv_files:
        try:
            df = pd.read_csv(file_path)
            sensor_data = df[['gx', 'gy', 'gz', 'ax', 'ay', 'az']].values

            if sensor_data.shape == (208, 6):
                X_list.append(sensor_data)
                y_list.append(label)
            else:
                print(f"[WARNING] Incorrect dimension {sensor_data.shape} in file: {file_path}. Skipping.")

        except Exception as e:
            print(f"[ERROR] Failed to load file {file_path}: {e}")

X = np.array(X_list)
y = np.array(y_list)

print(f"\nLoading complete! X shape: {X.shape}, y shape: {y.shape}")
print(f"Class distribution: { {k: int(np.sum(y == v)) for k, v in class_mapping.items()} }")

if len(X) == 0:
    raise ValueError("No valid data found! Check paths and folder names.")

# =========================================================
# 2. HARDWARE-FRIENDLY NORMALIZATION (Bit-shifting)
# =========================================================
scale_factors = np.array([256.0, 256.0, 256.0, 16384.0, 16384.0, 16384.0])
X_scaled = X / scale_factors

# =========================================================
# 3. SPLIT TRAIN / VALIDATION / TEST
# =========================================================
X_train, X_temp, y_train, y_temp = train_test_split(
    X_scaled, y, test_size=0.3, random_state=42, stratify=y
)
X_val, X_test, y_val, y_test = train_test_split(
    X_temp, y_temp, test_size=0.5, random_state=42, stratify=y_temp
)

print(f"\nTrain: {len(X_train)} | Val: {len(X_val)} | Test: {len(X_test)}")

# =========================================================
# 4. HANDLING IMBALANCED CLASSES
# =========================================================
class_weights = compute_class_weight(
    class_weight='balanced',
    classes=np.unique(y_train),
    y=y_train
)
class_weight_dict = dict(enumerate(class_weights))
print(f"Class weights: {class_weight_dict}")

# =========================================================
# 5. MODEL BUILDING
# =========================================================

model = models.Sequential([
    layers.Input(shape=(208, 6)),

    # Block 1: catches short patterns (impulses, jerks)
    layers.Conv1D(filters=8, kernel_size=5, strides=2, padding='valid', use_bias=False),
    layers.BatchNormalization(),
    layers.ReLU(),
    layers.MaxPooling1D(pool_size=2),

    # Block 2: catches higher-order patterns (gesture shape)
    layers.Conv1D(filters=8, kernel_size=3, strides=2, padding='valid', use_bias=False),
    layers.BatchNormalization(),
    layers.ReLU(),
    layers.MaxPooling1D(pool_size=2),

    layers.Flatten(),

    layers.Dropout(0.3),

    layers.Dense(32, use_bias=False),
    layers.BatchNormalization(),
    layers.ReLU(),

    layers.Dense(3, use_bias=False)
])

model.compile(
    optimizer='adam',
    loss=tf.keras.losses.SparseCategoricalCrossentropy(from_logits=True),
    metrics=['accuracy']
)

# =========================================================
# 6. CALLBACKS
# =========================================================
early_stop = callbacks.EarlyStopping(
    monitor='val_loss',
    patience=10,  # Wait 10 epochs without improvement before stopping
    restore_best_weights=True
)

checkpoint = callbacks.ModelCheckpoint(
    filepath='best_model.keras',
    monitor='val_accuracy',
    save_best_only=True,
    verbose=1
)

reduce_lr = callbacks.ReduceLROnPlateau(
    monitor='val_loss',
    factor=0.5,
    patience=5,
    min_lr=1e-6,
    verbose=1
)

# =========================================================
# 7. TRAINING
# =========================================================
print("\nStarting model training...")
history = model.fit(
    X_train, y_train,
    epochs=100,
    batch_size=32,
    validation_data=(X_val, y_val),
    class_weight=class_weight_dict,
    callbacks=[early_stop, checkpoint, reduce_lr],
    verbose=1
)

best_epoch = np.argmin(history.history['val_loss']) + 1
print(f"\nTraining completed. Best epoch: {best_epoch}/{len(history.history['val_loss'])}")

# =========================================================
# 8. EVALUATION
# =========================================================
print("\n=== Model Summary ===")
model.summary()

y_pred_logits = model.predict(X_test)
y_pred = np.argmax(y_pred_logits, axis=1)

target_names = ["Background (Rest)", "Swipe", "Knock"]

print("\n=== Classification Report ===")
print(classification_report(y_test, y_pred, target_names=target_names, zero_division=0))

cm = confusion_matrix(y_test, y_pred)

print("\n=== Confusion Matrix ===")
plt.figure(figsize=(8, 6))
sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', xticklabels=target_names, yticklabels=target_names)
plt.ylabel('True Class')
plt.xlabel('Predicted Class')
plt.title('Confusion Matrix')
plt.show()

model.save("final_model.keras")
print("\nModel saved: 'final_model.keras' (last) + 'best_model.keras' (best val_acc)")