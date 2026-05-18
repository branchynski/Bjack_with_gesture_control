import serial
import numpy as np
import tensorflow as tf
from collections import deque, Counter
import time
import logging
import sys
import threading
import queue

# =========================================================
# 1. LOGGER CONFIGURATION
# =========================================================
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%H:%M:%S'
)
log = logging.getLogger(__name__)

# =========================================================
# 2. CONFIGURATION
# =========================================================
PORT = 'COM3'
BAUD = 115200
MODEL_PATH = 'best_model.keras'
WINDOW_SIZE = 208
INFERENCE_STEP = 20
RECONNECT_DELAY = 3.0

SCALE_FACTORS = np.array([256.0, 256.0, 256.0, 16384.0, 16384.0, 16384.0])

SENSOR_MIN = -35000.0
SENSOR_MAX =  35000.0

CLASS_MAPPING = {
    0: '🟢 Background (Rest)',
    1: '➡️ Swipe Right',
    2: '💥 Knock'
}

VOTE_HISTORY_SIZE = 5
REQUIRED_VOTES = 3
COOLDOWN_DURATION = 1.5


# =========================================================
# 3. SERIAL READER THREAD
# =========================================================

def serial_reader(ser, data_queue, stop_event):
    while not stop_event.is_set():
        try:
            line = ser.readline().decode('utf-8', errors='ignore').strip()
            if line:
                data_queue.put(line)
        except serial.SerialException as e:
            log.error(f"Serial error in reading thread: {e}")
            stop_event.set()
            break
        except Exception as e:
            log.warning(f"Unexpected error in serial thread: {e}")


def parse_line(line: str) -> list[float] | None:
    parts = line.split(',')
    if len(parts) != 7:
        return None

    try:
        values = [float(x) for x in parts[1:]]  # Skip timestamp
    except ValueError:
        return None

    if any(v < SENSOR_MIN or v > SENSOR_MAX for v in values):
        log.debug(f"Sample out of range — skipping: {values}")
        return None

    return values


def load_model_safe(model_path: str):
    log.info(f"Loading model from '{model_path}'...")
    try:
        model = tf.keras.models.load_model(model_path)
        log.info("Model loaded successfully.")
        return model
    except FileNotFoundError:
        log.error(f"Model file does not exist: {model_path}")
        sys.exit(1)
    except Exception as e:
        log.error(f"Error loading model: {e}")
        sys.exit(1)


def run_inference(model, window: np.ndarray) -> int:
    x_input = window / SCALE_FACTORS
    x_input = np.expand_dims(x_input, axis=0).astype(np.float32)

    logits = model(x_input, training=False)
    return int(np.argmax(logits.numpy(), axis=1)[0])


def open_serial(port: str, baud: int) -> serial.Serial | None:
    try:
        ser = serial.Serial(port, baud, timeout=1)
        log.info(f"Connected to port {port} @ {baud} baud.")
        return ser
    except serial.SerialException as e:
        log.error(f"Cannot open port {port}: {e}")
        return None


def main():
    model = load_model_safe(MODEL_PATH)

    buffer = deque(maxlen=WINDOW_SIZE)
    prediction_history = deque(maxlen=VOTE_HISTORY_SIZE)

    last_detection_time = -COOLDOWN_DURATION

    step_counter = 0
    ser = None
    stop_event = threading.Event()
    reader_thread = None
    data_queue = queue.Queue(maxsize=1000)

    log.info("=" * 50)
    log.info("🔥 SYSTEM ACTIVE. Perform gestures...")
    log.info("=" * 50)

    try:
        while True:
            if ser is None or not ser.is_open or stop_event.is_set():
                if reader_thread and reader_thread.is_alive():
                    stop_event.set()
                    reader_thread.join(timeout=2)

                log.info(f"Attempting to connect to {PORT}...")
                ser = open_serial(PORT, BAUD)

                if ser is None:
                    log.info(f"Retrying in {RECONNECT_DELAY}s...")
                    time.sleep(RECONNECT_DELAY)
                    continue

                ser.reset_input_buffer()
                buffer.clear()
                prediction_history.clear()
                step_counter = 0
                stop_event.clear()
                data_queue = queue.Queue(maxsize=1000)

                reader_thread = threading.Thread(
                    target=serial_reader,
                    args=(ser, data_queue, stop_event),
                    daemon=True
                )
                reader_thread.start()

            try:
                line = data_queue.get(timeout=2.0)
            except queue.Empty:
                log.warning("No data from serial for 2s — check connection.")
                continue

            values = parse_line(line)
            if values is None:
                continue

            buffer.append(values)

            if len(buffer) < WINDOW_SIZE:
                continue

            step_counter += 1

            if step_counter % INFERENCE_STEP != 0:
                continue

            current_time = time.monotonic()

            if current_time - last_detection_time < COOLDOWN_DURATION:
                continue

            predicted_class = run_inference(model, np.array(buffer))
            prediction_history.append(predicted_class)

            if len(prediction_history) < VOTE_HISTORY_SIZE:
                print(".", end="", flush=True)
                continue

            votes = Counter(prediction_history)
            most_common_class, num_votes = votes.most_common(1)[0]

            if most_common_class != 0 and num_votes >= REQUIRED_VOTES:
                log.info(
                    f"[!!!] DETECTED: {CLASS_MAPPING[most_common_class]} "
                    f"(Votes: {num_votes}/{VOTE_HISTORY_SIZE})"
                )
                last_detection_time = current_time
                prediction_history.clear()
                buffer.clear()
            else:
                print(".", end="", flush=True)

    except KeyboardInterrupt:
        log.info("\nClosing program (Ctrl+C)...")

    finally:
        stop_event.set()
        if reader_thread and reader_thread.is_alive():
            reader_thread.join(timeout=2)
        if ser and ser.is_open:
            ser.close()
            log.info("Serial port closed.")


if __name__ == "__main__":
    main()