# Projekt FPGA SystemVerilog z modułem AI/ML i symulacją

Ten projekt łączy:

- logikę sterującą napisaną w SystemVerilog,
- testbenche i projekt symulacyjny w folderze `sim/`,
- warstwę FPGA dla płyty Basys3 w `fpga/`,
- wygenerowany silnik AI/ML w `rtl/ai/ml_net`,
- narzędzia uruchamiające symulację, syntezę i programowanie.

## Szybki start

1. Otwórz terminal w katalogu projektu:

   ```bash
   cd D:/programowanie/systemverilog/projekt
   ```

2. Jeśli używasz bash/WSL, załaduj środowisko:

   ```bash
   . env.sh
   ```

3. Sprawdź dostępne testy symulacyjne:

   ```bash
   tools/run_simulation.sh -l
   ```

4. Uruchom wybrany test, np. `top_gesture`:

   ```bash
   tools/run_simulation.sh -t top_gesture
   ```

5. Wygeneruj bitstream dla projektu FPGA:

   ```bash
   tools/generate_bitstream.sh
   ```

6. Wgraj bitstream na Basys3:

   ```bash
   tools/program_fpga.sh
   ```

## Struktura projektu

- `rtl/` — syntezowalna logika projektu.
- `rtl/ai/` — warstwa AI/ML i moduły sterujące modelem.
- `rtl/ai/ml_net/` — wygenerowane pliki sieci neuronowej dla modelu FPGA.
- `fpga/` — specyficzne pliki dla Basys3, w tym wrapper top i constraints.
- `fpga/scripts/project_details.tcl` — lista plików syntezy i dane projektu Vivado.
- `sim/` — katalog z testami symulacyjnymi.
- `tools/` — skrypty do symulacji, generowania bitstreamu, programowania i czyszczenia.
- `results/` — wynikowe pliki bitstreamu i raport ostrzeżeń.

## Symulacja

Testy symulacyjne znajdują się w katalogu `sim/` jako osobne foldery. Każdy test powinien mieć:

- `sim/<nazwa_testu>/<nazwa_testu>.prj`
- `sim/<nazwa_testu>/<nazwa_testu>_tb.sv`

Przykłady dostępnych testów:

- `sim/top_gesture/`
- `sim/top_sensor/`
- `sim/top_vga/`
- `sim/vga_timing/`
- `sim/bjack_fsm/`
- `sim/card_drawing/`

### Uruchamianie symulacji

- Lista testów:

  ```bash
  tools/run_simulation.sh -l
  ```

- Symulacja pojedynczego testu:

  ```bash
  tools/run_simulation.sh -t <nazwa_testu>
  ```

- Symulacja z GUI:

  ```bash
  tools/run_simulation.sh -gt <nazwa_testu>
  ```

- Uruchomienie wszystkich testów:

  ```bash
  tools/run_simulation.sh -a
  ```

## FPGA i generowanie bitstreamu

Skrypt `tools/generate_bitstream.sh` uruchamia Vivado w trybie TCL i buduje projekt FPGA.

W pliku `fpga/scripts/project_details.tcl` definiuje się:

- `project_name`,
- `top_module`,
- `target` (urządzenie FPGA),
- listę plików `sv_files`,
- listę plików `verilog_files`,
- pliki constraints `xdc`.

Po poprawnej kompilacji wygenerowany bitstream jest kopiowany do katalogu `results/`.

## Programowanie Basys3

Uruchom:

```bash
tools/program_fpga.sh
```

Skrypt znajduje plik `.bit` w katalogu `results/` i przekazuje go do Vivado TCL.

> Upewnij się, że w `results/` jest dokładnie jeden plik `.bit`.

## AI/ML w projekcie

Sekcja `rtl/ai/ml_net/` zawiera wygenerowane pliki modelu `myproject` używane w symulacji i syntezie.
Pliki te są odwoływane z projektu FPGA oraz z testów symulacyjnych, dlatego muszą być obecne w repozytorium.

## Czyszczenie projektu

Skrypt czyszczący:

```bash
tools/clean.sh
```

Usuwa pliki tymczasowe wygenerowane podczas symulacji i budowy. Przed użyciem sprawdź `.gitignore`, bo lista usuwanych elementów opiera się na plikach ignorowanych.

## Uwagi praktyczne

- `tools/run_simulation.sh` działa w katalogu `sim/` i wymaga środowiska Vivado oraz działających narzędzi `xelab`/`xsim`.
- `tools/generate_bitstream.sh` uruchamia czyszczenie `fpga/` i wymaga Vivado.
- `fpga/scripts/project_details.tcl` musi zawierać wszystkie używane pliki SV i Verilog.
- Jeśli projekt używa IP lub `glbl.v`, odpowiednie pliki muszą znaleźć się w pliku `.prj` testu.

## Kontakt

Jeśli chcesz zmienić test lub dodać nowy moduł AI, najpierw zaktualizuj:

- `sim/<nazwa_testu>/<nazwa_testu>.prj`
- `fpga/scripts/project_details.tcl`
