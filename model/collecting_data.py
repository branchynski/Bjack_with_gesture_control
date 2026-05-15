import serial
import pandas as pd
import matplotlib.pyplot as plt
import time
import os

# --- Configuration ---
PORT = 'COM3'
BAUD = 115200
DATASET_DIR = "dataset"
SAMPLES_TO_RECORD = 208


def plot_frame(df):
    t = (df['timestamp'] - df['timestamp'].iloc[0]) / 1_000_000.0

    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 6))
    fig.suptitle('Złapana ramka (2 sekundy) - Odrzucić czy Zapisać?')

    ax1.plot(t, df['ax'], label='Acc X', color='r')
    ax1.plot(t, df['ay'], label='Acc Y', color='g')
    ax1.plot(t, df['az'], label='Acc Z', color='b')
    ax1.set_ylabel('Akcelerometr (Raw)')
    ax1.legend(loc='upper right')
    ax1.grid(True)

    ax2.plot(t, df['gx'], label='Gyro X', color='r', linestyle='--')
    ax2.plot(t, df['gy'], label='Gyro Y', color='g', linestyle='--')
    ax2.plot(t, df['gz'], label='Gyro Z', color='b', linestyle='--')
    ax2.set_xlabel('Czas [s]')
    ax2.set_ylabel('Żyroskop (Raw)')
    ax2.legend(loc='upper right')
    ax2.grid(True)

    plt.tight_layout()
    plt.show(block=False)
    plt.pause(0.1)
    return fig


def main():
    if not os.path.exists(DATASET_DIR):
        os.makedirs(DATASET_DIR)

    print(f"Łączenie z portem {PORT}...")
    try:
        ser = serial.Serial(PORT, BAUD, timeout=1)
    except Exception as e:
        print(f"Błąd połączenia: {e}")
        return

    print("Połączono! Oczekiwanie na dane z ESP32S3...")

    while True:
        try:
            print("\n" + "=" * 50)
            input("Wciśnij [ENTER] i NATYCHMIAST wykonaj gest...")

            time.sleep(0.1)
            ser.reset_input_buffer()

            ser.readline()

            print("🔴 Nagrywanie (2 sekundy)...")
            raw_data = []

            start_time = time.time()
            while len(raw_data) < SAMPLES_TO_RECORD:
                if time.time() - start_time > 5.0:  # timeout 5s
                    print("⚠️ Timeout! Zebrano tylko", len(raw_data), "próbek.")
                    break

                line = ser.readline().decode('utf-8', errors='ignore').strip()
                if line:
                    parts = line.split(',')
                    if len(parts) == 7:
                        raw_data.append(parts)

            print("✅ Koniec nagrywania.")

            df = pd.DataFrame(raw_data, columns=['timestamp', 'gx', 'gy', 'gz', 'ax', 'ay', 'az'])
            df = df.astype(float)

            fig = plot_frame(df)

            print("\nOceń wykres:")
            print(" -> Wpisz nazwę (np. 'kolo') aby ZAPISAĆ.")
            print(" -> Zostaw puste [ENTER] aby ODRZUCIĆ i spróbować ponownie.")
            label = input("Nazwa gestu: ").strip()

            plt.close(fig)

            if label:
                label_dir = os.path.join(DATASET_DIR, label)
                os.makedirs(label_dir, exist_ok=True)
                filename = os.path.join(label_dir, f"{label}_{int(time.time() * 1000)}.csv")
                df.to_csv(filename, index=False)
                print(f"[ZAPISANO] -> {filename}")
            else:
                print("[ODRZUCONO] Nic nie zapisano.")

        except KeyboardInterrupt:
            print("\nZamykanie programu...")
            break
        except Exception as e:
            print(f"Wystąpił błąd: {e}")

    ser.close()

if __name__ == "__main__":
    main()